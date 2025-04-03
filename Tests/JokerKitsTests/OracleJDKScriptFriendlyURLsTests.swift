//
//  OracleJDKScriptFriendlyURLsTests.swift
//
//
//  Created by joker on 2022/10/13.
//

import Testing
import Foundation

@testable import JokerKits

struct OracleJDKScriptFriendlyURLsTests {
    
    private let jdkVersion = "24"

    @Test
    func JDKUrl() throws {

        let jdk19 = OracleJDKScriptFriendlyURLs(
            version: "19", type: .latest, os: .linux, arch: .x64, pkgOpt: .targz)
        #expect(
            jdk19.url == "https://download.oracle.com/java/19/latest/jdk-19_linux-x64_bin.tar.gz")
        #expect(
            jdk19.sha256Url
                == "https://download.oracle.com/java/19/latest/jdk-19_linux-x64_bin.tar.gz.sha256")

        let jdk17 = OracleJDKScriptFriendlyURLs(
            version: "17", type: .archive, os: .linux, arch: .x64, pkgOpt: .targz)
        #expect(
            jdk17.url == "https://download.oracle.com/java/17/archive/jdk-17_linux-x64_bin.tar.gz")

        let jdk17_0_1 = OracleJDKScriptFriendlyURLs(
            version: "17", type: .archive, semver: "17.0.1", os: .linux, arch: .x64, pkgOpt: .targz)
        #expect(
            jdk17_0_1.url
                == "https://download.oracle.com/java/17/archive/jdk-17.0.1_linux-x64_bin.tar.gz")
        #expect(
            jdk17_0_1.sha256Url
                == "https://download.oracle.com/java/17/archive/jdk-17.0.1_linux-x64_bin.tar.gz.sha256"
        )

        let jdk19_0_1 = OracleJDKScriptFriendlyURLs(
            version: "19", type: .archive, semver: "19.0.1", os: .linux, arch: .x64, pkgOpt: .targz)
        #expect(
            jdk19_0_1.url
                == "https://download.oracle.com/java/19/archive/jdk-19.0.1_linux-x64_bin.tar.gz")
    }
    
    @Test
    func sha256sum() async throws {
        let jdk = OracleJDKScriptFriendlyURLs(version: jdkVersion, type: .latest, os: .macos, arch: .aarch64, pkgOpt: .dmg)
        
        #expect(jdk.url == "https://download.oracle.com/java/\(jdkVersion)/latest/jdk-\(jdkVersion)_macos-aarch64_bin.dmg")
    
        #expect(try await jdk.sha256sum == "009695152a1f6d967f1f3488fd7f26761f31601ea85e5dfea4d83e4aa2c36289")
        
    }

    @Test
    func downloadJDK() async throws {
        let jdk = OracleJDKScriptFriendlyURLs(
            version: jdkVersion,
            type: .latest,
            os: .macos,
            arch: .aarch64,
            pkgOpt: .dmg
        )
        let downloadURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let dstFileURL = try await jdk.download(to: downloadURL) { progress in
            let log = String(format: "downloading: %.2f %%", progress * 100)
            print(log)
        }
        let fileURL = try #require(dstFileURL)
        #expect(fileURL.isFileURL && fileURL.pathExtension == "dmg" && FileManager.default.fileExists(atPath: fileURL.path()))
    }
}
