//
//  File.swift
//
//
//  Created by joker on 2022/1/15.
//
#if os(macOS)
import Foundation
import RegexBuilder
import Utils

/// JDK安装
/// [Oracle Java Installation Guide](https://docs.oracle.com/en/java/javase/17/install/index.html)
/// [Oracle JDK Script Friendly urls](https://www.oracle.com/java/technologies/jdk-script-friendly-urls/)
public struct OracleJava {
    
    public struct JDKInfo {
        public let version: String
        var type: String?
        var date: String?
        var arch: String?
        var path: String?
        var extra: String?
    }
    
    /// 获取当前系统安装的Java版本信息
    /// - Returns: 返回的Java版本信息
    static public func currentJDK() throws -> JDKInfo? {
        let javaVersion = try Shell.runCommand(with: ["java", "--version"]).split(separator: .newlineSequence).first?.string
        let components = javaVersion?.split(separator: .whitespace).map { $0.string.lowercased() }
        if let components, components.count == 3 {
            return JDKInfo(
                version: components[1],
                type: components[0],
                date: components[2]
            )
        } else {
            return nil
        }
    }
    
    /// 获取当前设备上安装的所有JVM信息
    /// - Returns: 返回值，字符串
    static public func installedJDKs() throws -> [JDKInfo] {
        let allJavaInfo = try Shell.run(path: "/usr/libexec/java_home", args: ["-V"])
        let sep = CharacterClass.whitespace
        let regex = Regex {
            Capture {
                OneOrMore(.digit)
                OneOrMore {
                    NegativeLookahead { sep }
                    CharacterClass.any
                }
            }
            sep
            "("
            Capture {
                OneOrMore {
                    NegativeLookahead { sep }
                    CharacterClass.any
                }
            }
            ")"
            sep
            Capture {
                "\""
                OneOrMore {
                    NegativeLookahead { CharacterClass.newlineSequence}
                    CharacterClass.any
                }
                "\""
            }
            sep
            Capture {
                OneOrMore {
                    NegativeLookahead { CharacterClass.newlineSequence }
                    CharacterClass.any
                }
            }
        }
        var jdks = [JDKInfo]()
        allJavaInfo
            .matches(of: regex)
            .compactMap { $0.output }
            .forEach { output in
                let jdk = JDKInfo(
                    version: String(output.1),
                    arch: String(output.2),
                    path: String(output.4),
                    extra: String(output.3)
                )
                jdks.append(jdk)
            }
        return jdks
    }
    
    static public func downloadJDK(_ version: String, dstFileURL: URL? = nil, progressHandler: (@Sendable (Double) -> Void)? = nil) async throws -> URL? {
        
        guard Platform.os == .macOS
        else {
            return nil
        }
        
        var arch: OracleJDKScriptFriendlyURLs.Architecture = .aarch64
        switch Platform.arch {
        case .arm64:
            arch = .aarch64
        case .x64:
            arch = .x64
        default:
            return nil
        }
        
        return try await OracleJDKScriptFriendlyURLs(
            version: version,
            type: .latest,
            os: .macos,
            arch: arch,
            pkgOpt: .dmg
        )
        .download(to: dstFileURL, progressHandler: progressHandler, validation: true)
    }
}

extension Substring {
    
    var string: String {
        String(self)
    }
}
#endif
