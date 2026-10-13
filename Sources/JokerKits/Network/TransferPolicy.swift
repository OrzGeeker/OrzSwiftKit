import Foundation

/// 下载并发与大文件分块的**纯策略**（对齐 `docs/spec/behavior.md` B2）。
///
/// 与 Python `orzmc/infra/transfer.py` 对齐：默认并发 16（范围 1–64）；
/// ≥ 8MB 的文件分 4 路 `Range` 并行取再拼接。
public struct TransferPolicy: Sendable {
    /// 默认并发数。
    public static let defaultThreads = 16
    /// 并发上限。
    public static let maxThreads = 64
    /// 触发分块的字节阈值（8MB）。
    public static let rangeThreshold = 8 * 1024 * 1024
    /// 分块路数。
    public static let rangeParts = 4

    /// 把任意并发数夹到 `1...maxThreads`。
    public static func clampThreads(_ threads: Int) -> Int {
        max(1, min(maxThreads, threads))
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

    /// 按文件大小决定单流还是分块。
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
