import Foundation

/// 缓存的最终动作（对齐 `docs/spec/behavior.md` B1）。
public enum CacheAction: String, Sendable {
    case hit
    case miss
    case refresh
    case fallback
    case error
}

/// 元数据缓存策略：纯值类型、可注入时钟，便于测试与跨语言一致性校验。
///
/// 语义对齐 Python `orzmc/infra/cache.py`：
/// - TTL 默认 24h，`ttl <= 0` 表示永不复用；
/// - `refresh` 绕过所有缓存读；
/// - 容忍小幅未来时间戳（Windows 文件时间 + 粗粒度时钟）。
public struct CachePolicy: Sendable {
    /// 默认 TTL：24 小时。
    public static let defaultTTL: TimeInterval = 24 * 60 * 60
    /// 容忍的未来时间偏移：5 分钟。
    public static let defaultFutureSkew: TimeInterval = 300

    public var ttl: TimeInterval
    public var futureSkew: TimeInterval

    public init(
        ttl: TimeInterval = CachePolicy.defaultTTL,
        futureSkew: TimeInterval = CachePolicy.defaultFutureSkew
    ) {
        self.ttl = ttl
        self.futureSkew = futureSkew
    }

    public static let standard = CachePolicy()

    /// 磁盘副本是否仍可用（命中）。`refresh` 与 `ttl <= 0` 一律判为不可用。
    public func isFresh(mtime: Date, now: Date, refresh: Bool = false) -> Bool {
        if refresh { return false }
        if ttl <= 0 { return false }
        let age = now.timeIntervalSince(mtime)
        return -futureSkew <= age && age < ttl
    }

    /// 纯判定：给定 `mtime/now/refresh/offline/hasStale` 返回应执行的动作。
    public func decide(
        mtime: Date?,
        now: Date,
        refresh: Bool,
        offline: Bool,
        hasStale: Bool
    ) -> CacheAction {
        if refresh { return .refresh }
        if let mtime, isFresh(mtime: mtime, now: now) { return .hit }
        if offline {
            return hasStale ? .fallback : .error
        }
        return .miss
    }
}
