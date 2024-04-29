//
//  OracleJavaTests.swift
//
//
//  Created by wangzhizhou on 2022/2/7.
//

import XCTest
@testable import JokerKits

class OracleJavaTests: XCTestCase {
    
    func testCurrentJDK() throws {
        let jdk = try OracleJava.currentJDK()
        XCTAssertNotNil(jdk, "No JDK installed!")
        if let jdk = jdk {
            XCTAssertFalse(jdk.version.isEmpty, "jdk version invalid")
        }
    }
    
    func testInstalledJDKs() throws {
        let jdks = try OracleJava.installedJDKs()
        XCTAssertFalse(jdks.isEmpty, "No JDK installed!")
        jdks.forEach { jdk in
            XCTAssertFalse(jdk.version.isEmpty, "jdk version invalid")
            if let jdkPath = jdk.path {
                XCTAssertTrue(FileManager.default.fileExists(atPath: jdkPath), "jdk path invalid")
            }
        }
    }
}
