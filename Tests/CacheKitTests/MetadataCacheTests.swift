import Foundation
import Testing

@testable import CacheKit

private struct Payload: Codable, Equatable {
    let value: Int
    let name: String
}

private struct Boom: Error {}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

@Suite
struct MetadataCacheTests {
    private func makeDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cachekit-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func age(_ url: URL, by seconds: TimeInterval) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(seconds)],
            ofItemAtPath: url.path
        )
    }

    @Test func writeThenReadFresh() throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = MetadataCache(directory: dir)
        let url = dir.appendingPathComponent("a.json")
        try cache.write(Payload(value: 1, name: "x"), to: url)
        #expect(cache.read(Payload.self, at: url) == Payload(value: 1, name: "x"))
    }

    @Test func freshCacheDoesNotFetch() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = MetadataCache(directory: dir)
        let url = dir.appendingPathComponent("a.json")
        try cache.write(Payload(value: 7, name: "cached"), to: url)
        let counter = Counter()
        let value = try await cache.get(Payload.self, at: url) {
            await counter.increment()
            return Payload(value: 0, name: "fetched")
        }
        #expect(value.name == "cached")
        let calls = await counter.value
        #expect(calls == 0)
    }

    @Test func staleRefetchesAndWrites() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = MetadataCache(directory: dir)
        let url = dir.appendingPathComponent("a.json")
        try cache.write(Payload(value: 1, name: "old"), to: url)
        try age(url, by: -90_000)
        let value = try await cache.get(Payload.self, at: url) { Payload(value: 2, name: "new") }
        #expect(value.name == "new")
        #expect(cache.read(Payload.self, at: url)?.name == "new")
    }

    @Test func fallsBackToStaleOnFailure() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = MetadataCache(directory: dir)
        let url = dir.appendingPathComponent("a.json")
        try cache.write(Payload(value: 1, name: "stale"), to: url)
        try age(url, by: -90_000)
        let value = try await cache.get(Payload.self, at: url) { throw Boom() }
        #expect(value.name == "stale")
    }

    @Test func throwsWhenNoCacheAndFetchFails() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = MetadataCache(directory: dir)
        let url = dir.appendingPathComponent("missing.json")
        var threw = false
        do {
            _ = try await cache.get(Payload.self, at: url) { throw Boom() }
        } catch is Boom {
            threw = true
        }
        #expect(threw)
    }

    @Test func refreshBypassesCache() async throws {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = MetadataCache(directory: dir)
        let url = dir.appendingPathComponent("a.json")
        try cache.write(Payload(value: 1, name: "cached"), to: url)
        let value = try await cache.get(Payload.self, at: url, refresh: true) {
            Payload(value: 2, name: "fresh")
        }
        #expect(value.name == "fresh")
    }

    @Test func metaURLSanitizesKeyParts() {
        let cache = MetadataCache(directory: URL(fileURLWithPath: "/tmp/cache"))
        let url = cache.metaURL("fabric-meta", "1.20.4/loader")
        #expect(url.path == "/tmp/cache/meta/fabric-meta/1.20.4_loader.json")
    }
}
