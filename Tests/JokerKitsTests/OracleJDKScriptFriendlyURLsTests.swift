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
        
        let jdk22 = OracleJDKScriptFriendlyURLs(version: "22", type: .latest, os: .macos, arch: .aarch64, pkgOpt: .dmg)
        
        #expect(jdk22.url == "https://download.oracle.com/java/22/latest/jdk-22_macos-aarch64_bin.dmg")
    
        #expect(jdk22.sha256sum == "c0370183e3689fac4d44831c9e6a3e706510f05fd29b1f1cb0a4670e5721375d")
        
    }
    @MainActor
    @Test
    func downloadJDK() async throws {
        let jdk = OracleJDKScriptFriendlyURLs(
            version: "22",
            type: .latest,
            os: .macos,
            arch: .aarch64,
            pkgOpt: .dmg
        )
        let downloadURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let dstFileURL = try await jdk.download(to: downloadURL) { progress in
            let log = String(format: "downloading: %.2f %%", progress.fractionCompleted * 100)
            print(log)
        }
        let fileURL = try #require(dstFileURL)
        #expect(fileURL.isFileURL && fileURL.pathExtension == "dmg" && FileManager.default.fileExists(atPath: fileURL.path()))
    }
}
