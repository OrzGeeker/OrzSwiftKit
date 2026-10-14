import Foundation
import Testing

@testable import TransferKit

@Suite
struct TransferTests {
    private func makeDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transferkit-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func upToDateWhenHashMatches() throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("hello.txt")
        // sha1("hello") = aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        let transfer = Transfer()
        let good = DownloadItem(
            url: URL(string: "https://example.invalid/hello.txt")!,
            destination: file,
            hash: "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d",
            hashKind: .sha1
        )
        #expect(transfer.isUpToDate(good))

        let bad = DownloadItem(
            url: good.url,
            destination: file,
            hash: "0000000000000000000000000000000000000000",
            hashKind: .sha1
        )
        #expect(!transfer.isUpToDate(bad))
    }

    @Test func notUpToDateWhenMissing() {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = dir.appendingPathComponent("nope.txt")
        let item = DownloadItem(url: URL(string: "https://example.invalid/nope")!, destination: missing)
        #expect(!Transfer().isUpToDate(item))
    }
}
