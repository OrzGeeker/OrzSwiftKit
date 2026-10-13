import Foundation
import Testing

@testable import RuntimeKit

@Suite
struct ArchiveExtractorTests {
    @Test func extractsTarGz() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let payload = base.appendingPathComponent("src/payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try "hi".write(
            to: payload.appendingPathComponent("hello.txt"),
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: base) }

        let archive = base.appendingPathComponent("payload.tar.gz")
        try run(["tar", "-czf", archive.path, "-C", base.appendingPathComponent("src").path, "payload"])

        let destination = base.appendingPathComponent("out", isDirectory: true)
        try ArchiveExtractor.extract(archive: archive, into: destination)
        #expect(
            FileManager.default.fileExists(
                atPath: destination.appendingPathComponent("payload/hello.txt").path
            )
        )
    }

    @Test func rejectsUnsupportedExtension() {
        var threw = false
        do {
            try ArchiveExtractor.extract(
                archive: URL(fileURLWithPath: "/tmp/whatever.rar"),
                into: URL(fileURLWithPath: "/tmp/orzmc-archive-test")
            )
        } catch {
            threw = true
        }
        #expect(threw)
    }

    private func run(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ArchiveError.commandFailed("tar", process.terminationStatus)
        }
    }
}
