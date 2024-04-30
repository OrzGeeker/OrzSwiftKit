//
//  File.swift
//
//
//  Created by joker on 2022/1/15.
//
#if os(macOS)
import Foundation
import RegexBuilder
public enum JDK {
    case jdk17
    
    var downloadUrl: URL {
        get async throws {
            return URL(fileURLWithPath: ".")
        }
    }
    
    enum JDKError: Error {
        case unsupportOS
        case unsupportArch
    }
}

public struct JDKInfo {
    let version: String
    var type: String?
    var date: String?
    var arch: String?
    var path: String?
    var extra: String?
}

extension Substring {
    
    var string: String {
        String(self)
    }
}

/// JDK安装
///
/// [Oracle Java Installation Guide](https://docs.oracle.com/en/java/javase/17/install/index.html)
///
/// [Oracle JDK Script Friendly urls](https://www.oracle.com/java/technologies/jdk-script-friendly-urls/)
public struct OracleJava {
    
    /// 获取当前系统安装的Java版本信息
    /// - Returns: 返回的Java版本信息
    static public func currentJDK() throws -> JDKInfo? {
        let javaVersion = try Shell.runCommand(with: ["java", "--version"])
        let sep = CharacterClass.whitespace
        let regex = Regex {
            OneOrMore(sep)
            Capture {
                OneOrMore(.word)
            }
            sep
            Capture {
                OneOrMore {
                    NegativeLookahead { sep }
                    CharacterClass.any
                }
            }
            sep
            Capture {
                OneOrMore {
                    NegativeLookahead { sep }
                    CharacterClass.any
                }
            }
        }
        guard let jdk = javaVersion.firstMatch(of: regex)?.output
        else {
            return nil
        }
        return JDKInfo(
            version: String(jdk.2),
            type: String(jdk.1),
            date: String(jdk.3)
        )
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
}
#endif
