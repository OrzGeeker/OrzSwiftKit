import Foundation

/// Adoptium 返回的下载资产（一次 `assets/latest` 响应的首项）。
public struct AdoptiumAsset: Sendable, Equatable {
    public let name: String
    public let link: URL
    public let checksum: String?
    public let size: Int?
    public let releaseName: String?

    public init(name: String, link: URL, checksum: String? = nil, size: Int? = nil, releaseName: String? = nil) {
        self.name = name
        self.link = link
        self.checksum = checksum
        self.size = size
        self.releaseName = releaseName
    }
}

public enum AdoptiumSelectionError: Error, Equatable {
    case empty
    case malformed
}

/// 从 Adoptium `assets/latest` 的 JSON 响应中选取资产（纯函数，便于测试）。
public enum AdoptiumAssetSelector {
    public static func select(from data: Data) throws -> AdoptiumAsset {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AdoptiumSelectionError.malformed
        }
        guard let first = array.first else {
            throw AdoptiumSelectionError.empty
        }
        guard
            let binary = first["binary"] as? [String: Any],
            let package = binary["package"] as? [String: Any],
            let linkString = package["link"] as? String,
            let link = URL(string: linkString),
            let name = package["name"] as? String
        else {
            throw AdoptiumSelectionError.malformed
        }
        return AdoptiumAsset(
            name: name,
            link: link,
            checksum: package["checksum"] as? String,
            size: package["size"] as? Int,
            releaseName: first["release_name"] as? String
        )
    }
}
