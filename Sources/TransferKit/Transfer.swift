import Foundation

/// 下载基础设施（对齐 `docs/spec/behavior.md` B2/B8）。
///
/// - HTTP 走可注入的 `TransferTransport`（生产 `URLSession`，测试可离线替身）；
/// - 命中哈希则跳过；
/// - **断点续传**：进度持久化到 `.part` / `.partN`，重跑用 `Range` 续传；
/// - ≥ 阈值走多路 `Range` 并行取再拼接；服务器返回 200（忽略 `Range`）时回退单流；
/// - **结构化进度**：单流报 `bytes`、批量报 `count`；
/// - 完成后校验哈希再落盘。
public struct Transfer: @unchecked Sendable {
    public let policy: TransferPolicy
    private let transport: TransferTransport
    private let fileManager: FileManager

    public init(
        policy: TransferPolicy = TransferPolicy(),
        concurrency: Int = TransferPolicy.defaultThreads,
        session: URLSession? = nil,
        fileManager: FileManager = .default,
        transport: TransferTransport? = nil
    ) {
        self.policy = policy
        self.fileManager = fileManager
        self.transport = transport ?? URLSessionTransferTransport(
            session: session ?? Self.makeSession(maxConnectionsPerHost: policy.clampThreads(concurrency))
        )
    }

    static func makeSession(maxConnectionsPerHost: Int) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = maxConnectionsPerHost
        return URLSession(configuration: configuration)
    }

    // MARK: - 判定

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
            resolvedSize = await transport.contentLength(of: item.url)
        }
        if let total = resolvedSize,
           total >= Int64(policy.thresholdBytes),
           policy.plan(sizeBytes: Int(total)).mode == .ranged {
            if try await downloadRanged(item, total: total, onProgress: onProgress) { return }
        }
        try await downloadSingle(item, total: resolvedSize, onProgress: onProgress)
    }

    public func download(
        _ items: [DownloadItem],
        concurrency: Int = TransferPolicy.defaultThreads,
        onProgress: (@Sendable (TransferProgress) -> Void)? = nil
    ) async throws {
        let limit = policy.clampThreads(concurrency)
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

        let scratch = partsURL(item.destination, suffix: "fetch")
        let name = item.destination.lastPathComponent
        var lastError: Error?
        for _ in 0..<policy.maxAttempts {
            var request = URLRequest(url: item.url)
            if have > 0 {
                request.setValue("bytes=\(have)-", forHTTPHeaderField: "Range")
            }
            try? fileManager.removeItem(at: scratch)

            let response: TransferResponse
            do {
                response = try await transport.fetch(request, into: scratch) { written, length in
                    onProgress?(TransferProgress(kind: .bytes, description: name, total: length, current: written))
                }
            } catch {
                // 运行内重试：保留已落盘部分（若传输层支持），用 Range 续传。
                lastError = error
                appendIfPresent(scratch, to: part)
                have = fileSize(part)
                continue
            }

            if response.statusCode == 206 {
                try append(scratch, to: part)
            } else {
                have = 0
                try moveOver(scratch, to: part)
            }

            if let total {
                guard fileSize(part) == total else {
                    try? fileManager.removeItem(at: part)
                    throw TransferError.sizeMismatch(expected: total, actual: fileSize(part))
                }
            }
            try verifyAndFinish(part, item)
            return
        }
        throw lastError ?? TransferError.sizeMismatch(expected: total ?? -1, actual: fileSize(part))
    }

    // MARK: - 多路 Range（可续传）

    /// 返回 `false` 表示需要回退单流（服务器忽略 `Range`）。
    private func downloadRanged(
        _ item: DownloadItem,
        total: Int64,
        onProgress: (@Sendable (TransferProgress) -> Void)?
    ) async throws -> Bool {
        let ranges = TransferPolicy.ranges(total: Int(total), count: policy.partCount)
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

                    var have = self.fileSize(part)
                    let scratch = self.partsURL(item.destination, suffix: "fetch\(index)")
                    var lastError: Error?
                    for _ in 0..<self.policy.maxAttempts {
                        let start = range.lowerBound + Int(have)
                        var request = URLRequest(url: item.url)
                        request.setValue(
                            "bytes=\(start)-\(range.upperBound - 1)",
                            forHTTPHeaderField: "Range"
                        )
                        try? self.fileManager.removeItem(at: scratch)

                        let response: TransferResponse
                        do {
                            response = try await self.transport.fetch(request, into: scratch, onBytes: nil)
                        } catch {
                            // 运行内重试：保住已落盘部分，下一轮从续传偏移重试本块。
                            lastError = error
                            self.appendIfPresent(scratch, to: part)
                            have = self.fileSize(part)
                            continue
                        }
                        if response.statusCode == 206 {
                            try self.append(scratch, to: part)
                            await accumulator.add(Int64(range.count) - have)
                            return false
                        }
                        try? self.fileManager.removeItem(at: scratch)
                        return true
                    }
                    throw lastError
                        ?? TransferError.sizeMismatch(expected: Int64(range.count), actual: self.fileSize(part))
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

    /// 把传输层失败时可能留下的部分字节并入已落盘的 `.part`（无则不动）。
    private func appendIfPresent(_ scratch: URL, to part: URL) {
        guard fileManager.fileExists(atPath: scratch.path) else { return }
        try? append(scratch, to: part)
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
