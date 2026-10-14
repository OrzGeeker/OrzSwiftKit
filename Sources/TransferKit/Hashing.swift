import Foundation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// 文件哈希（SHA-1 / SHA-256），Apple 用 CryptoKit、其它平台用 swift-crypto。
enum Hashing {
    static func sha1(_ data: Data) -> String {
        Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hex(_ data: Data, kind: HashKind) -> String {
        switch kind {
        case .sha1: return sha1(data)
        case .sha256: return sha256(data)
        }
    }
}
