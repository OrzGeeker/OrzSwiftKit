import Foundation
import Testing

import TransferKit

/// 真实网络冒烟（默认跳过；设 `ORZMC_NETWORK_SMOKE=1` 时启用）。
///
/// 用**内容寻址**的 Mojang 对象（URL 路径里的 sha1 即内容哈希）验证 Swift 侧
/// 真实下载 + 哈希校验，覆盖单流与多路 `Range`（把阈值调低以触发分块）。
/// 放在默认套件之外是为了让常规 `swift test` 保持离线、稳定。
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ORZMC_NETWORK_SMOKE"] == "1"))
struct TransferNetworkSmokeTests {
    // Minecraft 1.20.4 资产索引：~428KB，Mojang 内容寻址（sha1 在 URL 里）。
    private static let url = URL(
        string: "https://piston-meta.mojang.com/v1/packages/129fc8163fdedb50c886731a839751c22aa0dbc6/12.json"
    )!
    private static let sha1 = "129fc8163fdedb50c886731a839751c22aa0dbc6"
    private static let size: Int64 = 437_886

    private func makeDest() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transferkit-smoke-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("12.json")
    }

    private func item(destination: URL) -> DownloadItem {
        DownloadItem(url: Self.url, destination: destination, hash: Self.sha1, hashKind: .sha1, size: Self.size)
    }

    @Test func singleStreamDownloadsAndVerifies() async throws {
        let dest = makeDest()
        defer { try? FileManager.default.removeItem(at: dest.deletingLastPathComponent()) }
        // 阈值拉满 → 单流；哈希不符时 `Transfer` 会自动抛错。
        try await Transfer(policy: .init(thresholdBytes: .max, partCount: 1)).download(item(destination: dest))
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    @Test func rangedDownloadsAndVerifies() async throws {
        let dest = makeDest()
        defer { try? FileManager.default.removeItem(at: dest.deletingLastPathComponent()) }
        // 阈值调低 → 强制 2 路 Range 并行取再拼接。
        try await Transfer(policy: .init(thresholdBytes: 100_000, partCount: 2)).download(item(destination: dest))
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }
}
