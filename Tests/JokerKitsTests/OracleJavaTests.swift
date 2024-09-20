//
//  OracleJavaTests.swift
//
//
//  Created by wangzhizhou on 2022/2/7.
//

#if os(macOS)
    import Testing
    @testable import JokerKits
    import Foundation

    class OracleJavaTests {
        @Test
        func currentJDK() throws {
            let jdk = try OracleJava.currentJDK()
            _ = try #require(jdk, "No JDK installed!")
            if let jdk {
                #expect(jdk.version.isEmpty == false, "jdk version invalid")
            }
        }

        @Test
        func installedJDKs() throws {
            let jdks = try OracleJava.installedJDKs()
            try #require(jdks.isEmpty == false, "No JDK installed!")
            jdks.forEach { jdk in
                #expect(jdk.version.isEmpty == false, "jdk version invalid")
                if let jdkPath = jdk.path {
                    #expect(FileManager.default.fileExists(atPath: jdkPath), "jdk path invalid")
                }
            }
        }

        @Test func installJDK() async throws {

        }
    }
#endif
