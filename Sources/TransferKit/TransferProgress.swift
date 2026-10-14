import Foundation

/// 结构化进度事件（对齐 `docs/spec/behavior.md` B8 / `data-model.md` §7）。
///
/// `count`（文件计数）与 `bytes`（字节）**必须区分**：速度/百分比对两者语义不同。
public struct TransferProgress: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case count
        case bytes
    }

    public let kind: Kind
    public let description: String?
    /// 总数；`nil` 表示不定长。
    public let total: Int64?
    public let current: Int64

    public init(kind: Kind, description: String? = nil, total: Int64?, current: Int64) {
        self.kind = kind
        self.description = description
        self.total = total
        self.current = current
    }

    /// 归一化进度（不定长时为 `nil`）。
    public var fraction: Double? {
        guard let total, total > 0 else { return nil }
        return min(1, max(0, Double(current) / Double(total)))
    }
}
