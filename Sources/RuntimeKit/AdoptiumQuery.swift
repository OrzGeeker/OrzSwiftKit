import Foundation
import Utils

/// Adoptium API 的查询参数：把 `(major, os, arch)` 映射为一次「最新 JRE」资产请求。
///
/// 对应 dev 决策 D-b：Java 运行时的**获取原语**放在通用工具层；
/// 「用哪个 major、装到 `java/<major>`」的策略由引擎（`Game`）持有。
public struct AdoptiumQuery: Sendable, Equatable {
    public let featureVersion: Int
    /// Adoptium os：`mac` / `linux` / `windows`。
    public let os: String
    /// Adoptium arch：`x64` / `x86` / `aarch64` / `arm`。
    public let arch: String
    public let imageType: String
    public let vendor: String

    public init(
        featureVersion: Int,
        os: String,
        arch: String,
        imageType: String = "jre",
        vendor: String = "eclipse"
    ) {
        self.featureVersion = featureVersion
        self.os = os
        self.arch = arch
        self.imageType = imageType
        self.vendor = vendor
    }

    /// `assets/latest` 资产清单地址。
    public var assetListURL: URL? {
        var components = URLComponents(
            string: "https://api.adoptium.net/v3/assets/latest/\(featureVersion)/hotspot"
        )
        components?.queryItems = [
            URLQueryItem(name: "architecture", value: arch),
            URLQueryItem(name: "image_type", value: imageType),
            URLQueryItem(name: "os", value: os),
            URLQueryItem(name: "vendor", value: vendor),
        ]
        return components?.url
    }

    /// 由当前平台构造（用于「本机该装哪个 JRE」）。
    public static func currentPlatform(featureVersion: Int) -> AdoptiumQuery? {
        guard let os = osName(Platform.os), let arch = archName(Platform.arch) else { return nil }
        return AdoptiumQuery(featureVersion: featureVersion, os: os, arch: arch)
    }

    /// `Utils.Platform.os` → Adoptium os 名（不支持的平台返回 nil）。
    public static func osName(_ platform: Platform) -> String? {
        switch platform {
        case .macOS: return "mac"
        case .linux: return "linux"
        case .windows: return "windows"
        default: return nil
        }
    }

    /// `Utils.Platform.Arch` → Adoptium arch 名。
    public static func archName(_ arch: Platform.Arch) -> String? {
        switch arch {
        case .x64: return "x64"
        case .i386: return "x86"
        case .arm64: return "aarch64"
        case .arm: return "arm"
        case .unknowned: return nil
        }
    }
}
