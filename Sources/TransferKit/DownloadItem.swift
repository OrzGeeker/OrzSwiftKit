import Foundation

public enum HashKind: Sendable {
    case sha1
    case sha256
}

/// 一个下载项：源地址 + 目标路径（+ 可选哈希校验）。
public struct DownloadItem: Sendable, Equatable {
    public let url: URL
    public let destination: URL
    public let hash: String?
    public let hashKind: HashKind?
    public let size: Int64?

    public init(
        url: URL,
        destination: URL,
        hash: String? = nil,
        hashKind: HashKind? = nil,
        size: Int64? = nil
    ) {
        self.url = url
        self.destination = destination
        self.hash = hash
        self.hashKind = hashKind
        self.size = size
    }
}

public enum TransferError: Error, Equatable {
    case hashMismatch(expected: String, actual: String)
    case sizeMismatch(expected: Int64, actual: Int64)
}
