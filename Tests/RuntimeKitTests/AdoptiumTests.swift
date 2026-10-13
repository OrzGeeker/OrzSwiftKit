import Foundation
import Testing
import Utils

@testable import RuntimeKit

@Suite
struct AdoptiumTests {
    @Test func buildsAssetListURL() throws {
        let query = AdoptiumQuery(featureVersion: 17, os: "mac", arch: "aarch64")
        let url = try #require(query.assetListURL)
        #expect(url.path == "/v3/assets/latest/17/hotspot")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        #expect(items["architecture"] == "aarch64")
        #expect(items["os"] == "mac")
        #expect(items["image_type"] == "jre")
    }

    @Test func mapsPlatform() {
        #expect(AdoptiumQuery.osName(.macOS) == "mac")
        #expect(AdoptiumQuery.osName(.linux) == "linux")
        #expect(AdoptiumQuery.osName(.windows) == "windows")
        #expect(AdoptiumQuery.osName(.iOS) == nil)
        #expect(AdoptiumQuery.archName(.x64) == "x64")
        #expect(AdoptiumQuery.archName(.arm64) == "aarch64")
        #expect(AdoptiumQuery.archName(.i386) == "x86")
        #expect(AdoptiumQuery.archName(.unknowned) == nil)
    }

    @Test func selectsFirstAsset() throws {
        let json = """
        [
          {
            "binary": {
              "package": {
                "name": "OpenJDK17U-jre_aarch64_mac_hotspot_17.0.11_9.tar.gz",
                "link": "https://github.com/adoptium/temurin17/x/OpenJDK17U-jre_aarch64_mac_hotspot.tar.gz",
                "checksum": "abc123",
                "size": 42
              }
            },
            "release_name": "jdk-17.0.11+9"
          }
        ]
        """
        let asset = try AdoptiumAssetSelector.select(from: Data(json.utf8))
        #expect(asset.checksum == "abc123")
        #expect(asset.size == 42)
        #expect(asset.releaseName == "jdk-17.0.11+9")
        #expect(asset.link.lastPathComponent.hasSuffix(".tar.gz"))
    }

    @Test func emptyListThrows() {
        var threw = false
        do {
            _ = try AdoptiumAssetSelector.select(from: Data("[]".utf8))
        } catch {
            threw = true
        }
        #expect(threw)
    }

    @Test func findsRuntimeHomeUnderContentsHome() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let home = base.appendingPathComponent("jdk-17.0.11+9-jre/Contents/Home", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("bin", isDirectory: true),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: home.appendingPathComponent("bin/java").path,
            contents: Data()
        )
        defer { try? FileManager.default.removeItem(at: base) }
        #expect(JavaRuntimeInstaller.findRuntimeHome(in: base) == home)
    }
}
