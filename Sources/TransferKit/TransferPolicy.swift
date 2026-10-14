import Foundation

/// 下载并发与大文件分块的**策略**（对齐 `docs/spec/behavior.md` B2）。
///
/// 默认：并发 16（范围 1–64）；≥ 8MB 分 4 路 `Range`。策略可实例化配置（测试用小阈值）。
public struct TransferPolicy: Sendable {
    /// 默认并发数。
    public static let defaultThreads = 16
    /// 并发上限。
    public static let maxThreads = 64
    /// 触发分块的字节阈值（8MB）。
    public static let rangeThreshold = 8 * 1024 * 1024
    /// 分块路数。
    public static let rangeParts = 4

    public var thresholdBytes: Int
    public var partCount: Int
    public var maxConcurrency: Int

    public init(
        thresholdBytes: Int = TransferPolicy.rangeThreshold,
        partCount: Int = TransferPolicy.rangeParts,
        maxConcurrency: Int = TransferPolicy.maxThreads
    ) {
        self.thresholdBytes = thresholdBytes
        self.partCount = partCount
        self.maxConcurrency = maxConcurrency
    }

    public enum Mode: String, Sendable {
        case single
        case ranged
    }

    public struct Plan: Sendable, Equatable {
        public let mode: Mode
        public let parts: Int
        public init(mode: Mode, parts: Int) {
            self.mode = mode
            self.parts = parts
        }
    }

    public func clampThreads(_ threads: Int) -> Int {
        max(1, min(maxConcurrency, threads))
    }

    public func plan(sizeBytes: Int) -> Plan {
        sizeBytes >= thresholdBytes ? Plan(mode: .ranged, parts: partCount) : Plan(mode: .single, parts: 1)
    }

    // MARK: - 静态（规范默认，供一致性适配器使用）

    public static func clampThreads(_ threads: Int) -> Int {
        max(1, min(maxThreads, threads))
    }

    public static func plan(sizeBytes: Int) -> Plan {
        sizeBytes >= rangeThreshold
            ? Plan(mode: .ranged, parts: rangeParts)
            : Plan(mode: .single, parts: 1)
    }

    /// 把 `[0, total)` 均分为 `count` 段（最后一段吃掉余数）。
    public static func ranges(total: Int, count: Int) -> [Range<Int>] {
        guard total > 0 else { return [] }
        let parts = max(1, count)
        let base = total / parts
        var result: [Range<Int>] = []
        var start = 0
        for index in 0..<parts {
            let length = index == parts - 1 ? total - start : base
            guard length > 0 else { break }
            result.append(start..<(start + length))
            start += length
        }
        return result
    }
}
