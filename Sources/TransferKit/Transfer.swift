import Foundation

/// 下载基础设施（对齐 `docs/spec/behavior.md` B2/B8 / Python `orzmc/infra/transfer.py`）。
///
/// - 单一 `URLSession` 实现（不依赖三方网络库）；
/// - 命中哈希则跳过；
/// - **断点续传**：进度持久化到与目标同级的 `.part` / `.partN`，重跑时用 `Range` 续传；
/// - ≥ 8MB 走 4 路 `Range` 并行取再拼接；服务器返回 200（忽略 `Range`）时回退单流；
/// - **结构化进度**：单流报 `bytes`（`didWriteData`）、批量报 `count`；
/// - 完成后校验哈希再落盘；连接池 ≥ 并发数。
public struct Transfer: @unchecked Sendable {
    public let policy: TransferPolicy
    private let session: URLSession
    private let fileManager: FileManager

    public init(
        policy: TransferPolicy = TransferPolicy(),
        concurrency: Int = TransferPolicy.defaultThreads,
        session: URLSession? = nil,
        fileManager: FileManager = .default
    ) {
        self.policy = policy
        self.fileManager = fileManager
        self.session = session ?? Self.makeSession(
            maxConnectionsPerHost: TransferPolicy.clampThreads(concurrency)
        )
    }

    static func makeSession(maxConnectionsPerHost: Int) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = maxConnectionsPerHost
        return URLSession(configuration: configuration)
    }

    // MARK: - 判定

    /// 目标已存在且哈希匹配（无哈希则只要存在即视为完成）。
    public func isUpToDate(_ item: DownloadItem) -> Bool {
        guard fileManager.fileExists(atPath: item.destination.path) else { return false }
        guard let expected = item.hash, let kind = item.hashKind else { return true }
        guard let actual = try? hash(of: item.destination, kind: kind) else { return false }
        return actual.caseInsensitiveCompare(expected) == .orderedSame
    }

    // MARK: - 下载

    public func download(
        _ item: DownloadItem,
        onProgress: (@Sendable (TransferProgress) -> Void)? = nil
    ) async throws {
        if isUpToDate(item) { return }
        try fileManager.createDirectory(
            at: item.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var resolvedSize: Int64?
        if let size = item.size {
            resolvedSize = size
        } else {
            resolvedSize = await contentLength(item.url)
        }
        if let total = resolvedSize,
           total >= Int64(TransferPolicy.rangeThreshold),
           TransferPolicy.plan(sizeBytes: Int(total)).mode == .ranged {
            if try await downloadRanged(item, total: total, onProgress: onProgress) { return }
        }
        try await downloadSingle(item, total: resolvedSize, onProgress: onProgress)
    }

    /// 批量下载：并发受 `clampThreads` 限制，报 `count` 进度。
    public func download(
        _ items: [DownloadItem],
        concurrency: Int = TransferPolicy.defaultThreads,
        onProgress: (@Sendable (TransferProgress) -> Void)? = nil
    ) async throws {
        let limit = TransferPolicy.clampThreads(concurrency)
        let counter = ProgressCounter(total: items.count, onProgress: onProgress)
        try await withThrowingTaskGroup(of: Void.self) { group in
            var next = 0
            let initial = min(limit, items.count)
            while next < initial {
                let item = items[next]
                next += 1
                group.addTask { try await self.download(item) }
            }
            while let _ = try await group.next() {
                await counter.increment()
                if next < items.count {
                    let item = items[next]
                    next += 1
                    group.addTask { try await self.download(item) }
                }
            }
        }
    }

    // MARK: - 单流（可续传）

    private func downloadSingle(
        _ item: DownloadItem,
        total: Int64?,
        onProgress: (@Sendable (TransferProgress) -> Void)?
    ) async throws {
        let part = partsURL(item.destination, suffix: "part")
        var have = fileSize(part)

        if let total, have == total {
            try verifyAndFinish(part, item)
            return
        }

        var request = URLRequest(url: item.url)
        if have > 0 {
            request.setValue("bytes=\(have)-", forHTTPHeaderField: "Range")
        }
        let delegate = onProgress.map { ByteProgressDelegate(description: item.destination.lastPathComponent, handler: $0) }
        let (temporary, response) = try await session.download(for: request, delegate: delegate)
        let status = (response as? HTTPURLResponse)?.statusCode

        if status == 206 {
            try append(temporary, to: part)
        } else {
            have = 0
            try moveOver(temporary, to: part)
        }

        if let total {
            guard fileSize(part) == total else {
                try? fileManager.removeItem(at: part)
                throw TransferError.sizeMismatch(expected: total, actual: fileSize(part))
            }
        }
        try verifyAndFinish(part, item)
    }

    // MARK: - 4 路 Range（可续传）

    /// 返回 `false` 表示需要回退单流（服务器忽略 `Range`）。
    private func downloadRanged(
        _ item: DownloadItem,
        total: Int64,
        onProgress: (@Sendable (TransferProgress) -> Void)?
    ) async throws -> Bool {
        let ranges = TransferPolicy.ranges(total: Int(total), count: TransferPolicy.rangeParts)
        guard !ranges.isEmpty else { return false }

        let accumulator = ByteAccumulator(total: total, description: item.destination.lastPathComponent, onProgress: onProgress)
        let needsFallback = try await withThrowingTaskGroup(of: Bool.self) { group in
            for (index, range) in ranges.enumerated() {
                group.addTask {
                    let part = self.partsURL(item.destination, suffix: "part\(index)")
                    if self.fileSize(part) == Int64(range.count) {
                        await accumulator.add(Int64(range.count))
                        return false
                    }

                    let have = self.fileSize(part)
                    let start = range.lowerBound + Int(have)
                    var request = URLRequest(url: item.url)
                    request.setValue(
                        "bytes=\(start)-\(range.upperBound - 1)",
                        forHTTPHeaderField: "Range"
                    )
                    let (temporary, response) = try await self.session.download(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        try? self.fileManager.removeItem(at: temporary)
                        return true
                    }
                    if http.statusCode == 206 {
                        try self.append(temporary, to: part)
                        try? self.fileManager.removeItem(at: temporary)
                        await accumulator.add(Int64(range.count) - have)
                        return false
                    }
                    try? self.fileManager.removeItem(at: temporary)
                    return true
                }
            }
            var fallback = false
            for try await item in group { fallback = fallback || item }
            return fallback
        }

        if needsFallback {
            for index in 0..<ranges.count {
                try? fileManager.removeItem(at: partsURL(item.destination, suffix: "part\(index)"))
            }
            return false
        }

        for (index, range) in ranges.enumerated()
        where fileSize(partsURL(item.destination, suffix: "part\(index)")) != Int64(range.count) {
            return false
        }

        let assembled = partsURL(item.destination, suffix: "part")
        fileManager.createFile(atPath: assembled.path, contents: nil)
        let handle = try FileHandle(forWritingTo: assembled)
        for index in 0..<ranges.count {
            let part = partsURL(item.destination, suffix: "part\(index)")
            try handle.write(contentsOf: try Data(contentsOf: part))
            try? fileManager.removeItem(at: part)
        }
        try handle.close()

        guard fileSize(assembled) == total else {
            try? fileManager.removeItem(at: assembled)
            throw TransferError.sizeMismatch(expected: total, actual: fileSize(assembled))
        }
        try verifyAndFinish(assembled, item)
        return true
    }

    // MARK: - helpers

    private func partsURL(_ destination: URL, suffix: String) -> URL {
        destination.appendingPathExtension(suffix)
    }

    private func fileSize(_ url: URL) -> Int64 {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func append(_ temporary: URL, to part: URL) throws {
        let data = try Data(contentsOf: temporary)
        if !fileManager.fileExists(atPath: part.path) {
            fileManager.createFile(atPath: part.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: part)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
        try? fileManager.removeItem(at: temporary)
    }

    private func moveOver(_ temporary: URL, to part: URL) throws {
        if fileManager.fileExists(atPath: part.path) {
            try fileManager.removeItem(at: part)
        }
        try fileManager.copyItem(at: temporary, to: part)
        try? fileManager.removeItem(at: temporary)
    }

    private func verifyAndFinish(_ part: URL, _ item: DownloadItem) throws {
        if let expected = item.hash, let kind = item.hashKind {
            let actual = try hash(of: part, kind: kind)
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                try? fileManager.removeItem(at: part)
                try? fileManager.removeItem(at: item.destination)
                throw TransferError.hashMismatch(expected: expected, actual: actual)
            }
        }
        try moveOver(part, to: item.destination)
    }

    private func hash(of url: URL, kind: HashKind) throws -> String {
        Hashing.hex(try Data(contentsOf: url), kind: kind)
    }

    private func contentLength(_ url: URL) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              http.expectedContentLength > 0
        else { return nil }
        return http.expectedContentLength
    }
}

// MARK: - progress

/// 单流字节进度回调。
private final class ByteProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let label: String?
    private let handler: @Sendable (TransferProgress) -> Void

    init(description: String?, handler: @escaping @Sendable (TransferProgress) -> Void) {
        self.label = description
        self.handler = handler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        handler(TransferProgress(kind: .bytes, description: label, total: total, current: totalBytesWritten))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

/// 分块字节进度聚合（按块完成累计）。
private actor ByteAccumulator {
    private var current: Int64 = 0
    private let total: Int64
    private let description: String?
    private let onProgress: (@Sendable (TransferProgress) -> Void)?

    init(total: Int64, description: String?, onProgress: (@Sendable (TransferProgress) -> Void)?) {
        self.total = total
        self.description = description
        self.onProgress = onProgress
    }

    func add(_ bytes: Int64) {
        current += bytes
        onProgress?(TransferProgress(kind: .bytes, description: description, total: total, current: current))
    }
}

/// 批量计数进度。
private actor ProgressCounter {
    private var done = 0
    private let total: Int
    private let onProgress: (@Sendable (TransferProgress) -> Void)?

    init(total: Int, onProgress: (@Sendable (TransferProgress) -> Void)?) {
        self.total = total
        self.onProgress = onProgress
    }

    func increment() {
        done += 1
        onProgress?(TransferProgress(kind: .count, total: Int64(total), current: Int64(done)))
    }
}
