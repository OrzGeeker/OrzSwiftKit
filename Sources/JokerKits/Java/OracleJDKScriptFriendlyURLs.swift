//
//  OracleJDKScriptFriendlyURLs.swift
//  
//
//  Created by joker on 2022/10/13.
//

import Foundation

struct OracleJDKScriptFriendlyURLs {
    
    let version: String
    
    let type: `Type`
    
    var semver: String? = nil
    
    let os: OperatingSystems
    
    let arch: Architecture
    
    let pkgOpt: PackagingOptions
    
    /// [Oracle JDK Script Friendly urls](https://www.oracle.com/java/technologies/jdk-script-friendly-urls/)
    enum OperatingSystems: String {
        case linux
        case macos
        case windows
    }
    
    enum Architecture: String {
        case aarch64
        case x64
    }
    
    enum PackagingOptions: String {
        case rpm
        case targz = "tar.gz"
        case deb
        case dmg
        case exe
        case msi
        case zip
    }
    
    enum `Type`: String {
        case latest
        case archive
    }
    
    var url: String {
        "https://download.oracle.com/java/\(version)/\(type)/jdk-\(semver ?? version)_\(os)-\(arch)_bin.\(pkgOpt.rawValue)"
    }
    
    var sha256Url: String {
        "\(url).sha256"
    }
}
