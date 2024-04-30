//
//  URL+FileHash.swift
//  
//
//  Created by wangzhizhou on 2022/4/7.
//

import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#else
import Crypto
#endif

public extension URL {
    var fileSHA1Value: String {
        get throws {
            guard self.isFileURL
            else {
                throw URLError(.badURL)
            }
            let data = try Data(contentsOf: self)
            
#if canImport(CommonCrypto)
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            data.withUnsafeBytes {
                _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
            }
            let hexBytes = digest.map { String(format: "%02hhx", $0) }
#else
            let digest = Insecure.SHA1.hash(data: data)
            let hexBytes = digest.map { String(format: "%02hhx", $0) }
#endif
            
            return hexBytes.joined()
        }
    }
    var fileSHA256Value: String {
        get throws {
            guard self.isFileURL
            else {
                throw URLError(.badURL)
            }
            let data = try Data(contentsOf: self)
#if canImport(CommonCrypto)
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
            }
            let hexBytes = digest.map { String(format: "%02hhx", $0) }
#else
            let digest = SHA256.hash(data: data)
            let hexBytes = digest.map { String(format: "%02hhx", $0) }
#endif
            return hexBytes.joined()
        }
    }
}
