import Foundation

/// 下载基础设施（对齐 `docs/spec/behavior.md` B2 / Python `orzmc/infra/transfer.py`）。
///
/// - 单一 `URLSession` 实现（不依赖三方网络库）；
/// - 命中哈希则跳过；
/// - ≥ 8MB 走 4 路 `Range` 并行取再拼接；服务器忽略 `Range`（返回 200）时回退单流；
/// - 写入前用 `.part` 临时文件，完成后校验哈希再落盘；连接池 ≥ 并发数。
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

    public func download(_ item: DownloadItem) async throws {
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
            if try await downloadRanged(item, total: total) { return }
        }
        try await downloadSingle(item)
    }

    /// 批量下载：并发受 `clampThreads` 限制，按完成计数回报进度。
    public func download(
        _ items: [DownloadItem],
        concurrency: Int = TransferPolicy.defaultThreads,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
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

    // MARK: - internals

    private func downloadSingle(_ item: DownloadItem) async throws {
        let (temporary, _) = try await session.download(from: item.url)
        try replace(temporary, with: item.destination)
        try verify(item)
    }

    /// 返回 `false` 表示服务器忽略 `Range`，调用方应回退单流。
    private func downloadRanged(_ item: DownloadItem, total: Int64) async throws -> Bool {
        let ranges = TransferPolicy.ranges(total: Int(total), count: TransferPolicy.rangeParts)
        guard !ranges.isEmpty else { return false }

        let parts: [URL]? = try await withThrowingTaskGroup(of: (Int, URL?).self) { group in
            for (index, range) in ranges.enumerated() {
                group.addTask {
                    var request = URLRequest(url: item.url)
                    request.setValue(
                        "bytes=\(range.lowerBound)-\(range.upperBound - 1)",
                        forHTTPHeaderField: "Range"
                    )
                    let (temporary, response) = try await self.session.download(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode == 206 {
                        return (index, temporary)
                    }
                    try? self.fileManager.removeItem(at: temporary)
                    return (index, nil)
                }
            }
            var collected: [Int: URL] = [:]
            var allRanged = true
            for try await (index, temporary) in group {
                if let temporary {
                    collected[index] = temporary
                } else {
                    allRanged = false
                }
            }
            guard allRanged else {
                for (_, url) in collected { try? self.fileManager.removeItem(at: url) }
                return nil
            }
            return (0..<ranges.count).compactMap { collected[$0] }
        }

        guard let parts else { return false }

        let assembled = item.destination.appendingPathExtension("part")
        fileManager.createFile(atPath: assembled.path, contents: nil)
        let handle = try FileHandle(forWritingTo: assembled)
        var received: Int64 = 0
        for url in parts {
            let data = try Data(contentsOf: url)
            try handle.write(contentsOf: data)
            received += Int64(data.count)
            try? fileManager.removeItem(at: url)
        }
        try handle.close()

        guard received == total else {
            try? fileManager.removeItem(at: assembled)
            throw TransferError.sizeMismatch(expected: total, actual: received)
        }
        try replace(assembled, with: item.destination)
        try verify(item)
        return true
    }

    private func verify(_ item: DownloadItem) throws {
        guard let expected = item.hash, let kind = item.hashKind else { return }
        let actual = try hash(of: item.destination, kind: kind)
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            try? fileManager.removeItem(at: item.destination)
            throw TransferError.hashMismatch(expected: expected, actual: actual)
        }
    }

    private func hash(of url: URL, kind: HashKind) throws -> String {
        Hashing.hex(try Data(contentsOf: url), kind: kind)
    }

    private func replace(_ temporary: URL, with destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporary, to: destination)
        try? fileManager.removeItem(at: temporary)
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

private actor ProgressCounter {
    private var done = 0
    private let total: Int
    private let onProgress: (@Sendable (Int, Int) -> Void)?

    init(total: Int, onProgress: (@Sendable (Int, Int) -> Void)?) {
        self.total = total
        self.onProgress = onProgress
    }

    func increment() {
        done += 1
        onProgress?(done, total)
    }
}
