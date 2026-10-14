import Foundation
import Testing

@testable import TransferKit

/// 前 `failures` 次 `fetch` 抛错，之后委托给 `FakeTransport`（模拟中途断连的有界重试）。
final class FlakyTransport: TransferTransport, @unchecked Sendable {
    let inner: FakeTransport

    private let lock = NSLock()
    private var remainingFailures: Int
    private var _attempts = 0

    init(inner: FakeTransport, failures: Int) {
        self.inner = inner
        self.remainingFailures = failures
    }

    var attempts: Int {
        lock.lock()
        defer { lock.unlock() }
        return _attempts
    }

    /// 记录一次尝试并返回是否应抛出（同步方法，避免在 async 上下文直接用 NSLock）。
    private func beginAttempt() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _attempts += 1
        guard remainingFailures > 0 else { return false }
        remainingFailures -= 1
        return true
    }

    func contentLength(of url: URL) async -> Int64? { await inner.contentLength(of: url) }

    @discardableResult
    func fetch(
        _ request: URLRequest,
        into destination: URL,
        onBytes: (@Sendable (Int64, Int64?) -> Void)?
    ) async throws -> TransferResponse {
        if beginAttempt() { throw URLError(.networkConnectionLost) }
        return try await inner.fetch(request, into: destination, onBytes: onBytes)
    }
}

@Suite
struct TransferRetryTests {
    private func makeDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transferkit-retry", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func url() -> URL { URL(string: "https://example.invalid/out")! }

    @Test func retriesSingleStreamWithinRun() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data("hello world".utf8)
        let transport = FlakyTransport(inner: FakeTransport(body: body), failures: 2)
        let transfer = Transfer(policy: .init(thresholdBytes: 1_000_000, maxAttempts: 4), transport: transport)
        let destination = dir.appendingPathComponent("out.bin")

        try await transfer.download(DownloadItem(url: url(), destination: destination))
        #expect(try Data(contentsOf: destination) == body)
        #expect(transport.attempts == 3)
    }

    @Test func retriesRangedChunkWithinRun() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data((0..<400).map { UInt8($0 % 256) })
        let transport = FlakyTransport(inner: FakeTransport(body: body), failures: 2)
        let transfer = Transfer(policy: .init(thresholdBytes: 10, partCount: 4, maxAttempts: 4), transport: transport)
        let destination = dir.appendingPathComponent("out.bin")

        try await transfer.download(DownloadItem(url: url(), destination: destination))
        #expect(try Data(contentsOf: destination) == body)
        #expect(transport.attempts >= 6)
    }

    @Test func throwsWhenRetriesExhausted() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data("hello world".utf8)
        let transport = FlakyTransport(inner: FakeTransport(body: body), failures: 99)
        let transfer = Transfer(policy: .init(thresholdBytes: 1_000_000, maxAttempts: 2), transport: transport)
        let destination = dir.appendingPathComponent("out.bin")

        await #expect(throws: (any Error).self) {
            try await transfer.download(DownloadItem(url: url(), destination: destination))
        }
        #expect(transport.attempts == 2)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
