import Foundation
import Testing

@testable import TransferKit

/// 离线假传输：按 `Range` 头切片，可模拟「忽略 Range」「断点」。
final class FakeTransport: TransferTransport, @unchecked Sendable {
    let body: Data
    let supportsRange: Bool

    private let lock = NSLock()
    private var _ranges: [String] = []

    init(body: Data, supportsRange: Bool = true) {
        self.body = body
        self.supportsRange = supportsRange
    }

    var ranges: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _ranges
    }

    private func record(_ range: String) {
        lock.lock()
        _ranges.append(range)
        lock.unlock()
    }

    func contentLength(of url: URL) async -> Int64? { Int64(body.count) }

    @discardableResult
    func fetch(
        _ request: URLRequest,
        into destination: URL,
        onBytes: (@Sendable (Int64, Int64?) -> Void)?
    ) async throws -> TransferResponse {
        if let range = request.value(forHTTPHeaderField: "Range") {
            record(range)
            if supportsRange, let sliceRange = Self.parse(range: range, total: body.count) {
                let slice = body.subdata(in: sliceRange)
                try slice.write(to: destination)
                onBytes?(Int64(slice.count), Int64(body.count))
                return TransferResponse(statusCode: 206, contentLength: Int64(slice.count))
            }
        }
        try body.write(to: destination)
        onBytes?(Int64(body.count), Int64(body.count))
        return TransferResponse(statusCode: 200, contentLength: Int64(body.count))
    }

    /// `bytes=<lower>-<upper>`（`upper` 可省略）。
    static func parse(range: String, total: Int) -> Range<Int>? {
        guard range.hasPrefix("bytes=") else { return nil }
        let parts = range.dropFirst("bytes=".count).split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let lower = Int(parts[0]) else { return nil }
        let upper = parts.count > 1 && !parts[1].isEmpty ? Int(parts[1]) : total - 1
        guard let upper, lower <= upper, upper < total else { return nil }
        return lower..<(upper + 1)
    }
}

@Suite
struct TransferDownloadTests {
    private func makeDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transferkit-dl", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func url() -> URL { URL(string: "https://example.invalid/out")! }

    @Test func singleStreamWritesAndVerifies() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data("hello world".utf8)
        let transfer = Transfer(policy: .init(thresholdBytes: 1_000_000), transport: FakeTransport(body: body))
        let destination = dir.appendingPathComponent("out.bin")
        let item = DownloadItem(
            url: url(),
            destination: destination,
            hash: Hashing.sha1(body),
            hashKind: .sha1
        )
        try await transfer.download(item)
        #expect(try Data(contentsOf: destination) == body)
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathExtension("part").path))
    }

    @Test func rangedAssemblesInOrder() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data((0..<100).map { UInt8($0 % 256) })
        let transport = FakeTransport(body: body)
        let transfer = Transfer(policy: .init(thresholdBytes: 10, partCount: 4), transport: transport)
        let destination = dir.appendingPathComponent("out.bin")
        try await transfer.download(DownloadItem(url: url(), destination: destination))
        #expect(try Data(contentsOf: destination) == body)
        #expect(transport.ranges.count == 4)
    }

    @Test func fallsBackToSingleWhenRangeIgnored() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data(repeating: 7, count: 100)
        let transport = FakeTransport(body: body, supportsRange: false)
        let transfer = Transfer(policy: .init(thresholdBytes: 10, partCount: 4), transport: transport)
        let destination = dir.appendingPathComponent("out.bin")
        try await transfer.download(DownloadItem(url: url(), destination: destination))
        #expect(try Data(contentsOf: destination) == body)
    }

    @Test func resumesFromExistingPart() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = Data("0123456789".utf8)
        let transport = FakeTransport(body: body)
        let transfer = Transfer(policy: .init(thresholdBytes: 1_000_000), transport: transport)
        let destination = dir.appendingPathComponent("out.bin")
        try body.prefix(4).write(to: destination.appendingPathExtension("part"))
        let item = DownloadItem(
            url: url(),
            destination: destination,
            hash: Hashing.sha1(body),
            hashKind: .sha1
        )
        try await transfer.download(item)
        #expect(try Data(contentsOf: destination) == body)
        #expect(transport.ranges == ["bytes=4-"])
    }

    @Test func rejectsHashMismatch() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let transfer = Transfer(policy: .init(thresholdBytes: 1_000_000), transport: FakeTransport(body: Data("abc".utf8)))
        let destination = dir.appendingPathComponent("out.bin")
        let item = DownloadItem(url: url(), destination: destination, hash: "deadbeef", hashKind: .sha1)
        var threw = false
        do { try await transfer.download(item) } catch { threw = true }
        #expect(threw)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
