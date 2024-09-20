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
    
    var semver: String?
    
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
    
    var sha256sum: String? {
        
        guard let sha256URL = URL(string: sha256Url),
              let sha256sumData = try? Data(contentsOf: sha256URL)
        else {
            return nil
        }
        
        let sha256sum = String(data: sha256sumData, encoding: .utf8)
        
        return sha256sum
    }
}

import CryptoKit
extension OracleJDKScriptFriendlyURLs {
    
    func download(to dst: URL? = nil, progressHandler: ((Progress) -> Void)? = nil, validation: Bool = true) async throws -> URL? {
        
        guard let jdkURL = URL(string: self.url)
        else {
            return nil
        }
        
        // download jdk file to local disk
        let (downloadURLTask, downloadProgressStream) = Downloader.download(jdkURL)
        if let progressHandler {
            for try await progress in downloadProgressStream {
                progressHandler(progress)
            }
        }
        
        let jdkLocalFilePath = try await downloadURLTask.value.path
        
        // validation of sha256sum
        if validation {
            let jdkFileURL = URL(filePath: jdkLocalFilePath)
            let jdkData = try Data(contentsOf: jdkFileURL)
            let digest = SHA256.hash(data: jdkData)
            let computedSHA256Sum = digest.compactMap { String(format: "%02x", $0) }.joined()
            guard computedSHA256Sum == self.sha256sum
            else {
                return nil
            }
        }
        
        // return the local file URL
        let localFileURL = URL(filePath: jdkLocalFilePath)
        var dstFileURL = localFileURL.deletingLastPathComponent().appending(component: jdkURL.lastPathComponent)
        if let dst {
            dstFileURL = dst.isFileURL ? dst : dst.appending(component: jdkURL.lastPathComponent)
        }
        try FileManager.moveFile(fromFilePath: localFileURL.path, toFilePath: dstFileURL.path, overwrite: true)
        
        return dstFileURL
    }
}
