//
//  OracleJDKScriptFriendlyURLsTests.swift
//  
//
//  Created by joker on 2022/10/13.
//

import XCTest
@testable import JokerKits

final class OracleJDKScriptFriendlyURLsTests: XCTestCase {

    func testJDKUrl() throws {

        let jdk19 = OracleJDKScriptFriendlyURLs(version: "19", type: .latest, os: .linux, arch: .x64, pkgOpt: .targz)
        XCTAssertEqual(jdk19.url, "https://download.oracle.com/java/19/latest/jdk-19_linux-x64_bin.tar.gz")
        XCTAssertEqual(jdk19.sha256Url, "https://download.oracle.com/java/19/latest/jdk-19_linux-x64_bin.tar.gz.sha256")
        
        let jdk17 = OracleJDKScriptFriendlyURLs(version: "17", type: .archive, os: .linux, arch: .x64, pkgOpt: .targz)
        XCTAssertEqual(jdk17.url, "https://download.oracle.com/java/17/archive/jdk-17_linux-x64_bin.tar.gz")
        
        let jdk17_0_1 = OracleJDKScriptFriendlyURLs(version: "17", type: .archive, semver: "17.0.1", os: .linux, arch: .x64, pkgOpt: .targz)
        XCTAssertEqual(jdk17_0_1.url, "https://download.oracle.com/java/17/archive/jdk-17.0.1_linux-x64_bin.tar.gz")
        XCTAssertEqual(jdk17_0_1.sha256Url, "https://download.oracle.com/java/17/archive/jdk-17.0.1_linux-x64_bin.tar.gz.sha256")
        
        let jdk19_0_1 = OracleJDKScriptFriendlyURLs(version: "19", type: .archive, semver: "19.0.1", os: .linux, arch: .x64, pkgOpt: .targz)
        XCTAssertEqual(jdk19_0_1.url, "https://download.oracle.com/java/19/archive/jdk-19.0.1_linux-x64_bin.tar.gz")
        
    }

}
