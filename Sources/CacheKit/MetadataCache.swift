import Foundation

/// 落盘 JSON 缓存：唯一缓存策略（TTL / refresh / 离线回退）。
///
/// 对齐 `docs/spec/behavior.md` B1 与 Python `orzmc/infra/cache.py`。
/// 无内存状态（状态即磁盘），因此是 `Sendable` 值类型；所有 IO 用原子写。
///
/// 用法：
/// ```swift
/// let cache = MetadataCache(directory: cacheDir)
/// let manifest: Manifest = try await cache.get(at: cache.manifestURL) {
///     try await fetchManifest()
/// }
/// ```
public struct MetadataCache {
    public let directory: URL
    public let policy: CachePolicy
    /// 为真时所有读都绕过缓存（对应 CLI `--refresh`）。
    public let refresh: Bool

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date
    private let report: @Sendable (String) -> Void

    public init(
        directory: URL,
        policy: CachePolicy = .standard,
        refresh: Bool = false,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        now: @escaping @Sendable () -> Date = { Date() },
        report: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.directory = directory
        self.policy = policy
        self.refresh = refresh
        self.encoder = encoder
        self.decoder = decoder
        self.now = now
        self.report = report
    }

    /// 版本清单等固定文件路径：`<directory>/<name>`。
    public func fileURL(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// 第三方 API 缓存路径：`<directory>/meta/<parts>.json`。
    public func metaURL(_ parts: String...) -> URL {
        var url = directory.appendingPathComponent("meta", isDirectory: true)
        for part in parts { url.appendPathComponent(Self.safe(part)) }
        return url.appendingPathExtension("json")
    }

    public func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// 磁盘副本是否新鲜（可选追加 `refresh`）。
    public func isFresh(at url: URL, refresh: Bool = false) -> Bool {
        guard exists(at: url) else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date
        else { return false }
        return policy.isFresh(mtime: mtime, now: now(), refresh: refresh || self.refresh)
    }

    /// 仅当新鲜时读取，否则 `nil`。
    public func read<T: Decodable>(_ type: T.Type = T.self, at url: URL) -> T? {
        guard isFresh(at: url) else { return nil }
        return readIgnoringFreshness(type, at: url)
    }

    /// 原子写盘（自动建父目录）。
    public func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: url, options: .atomic)
    }

    /// 缓存命中优先；否则 `fetch` 并写盘；`fetch` 失败时回退旧副本（若有）并提示，否则抛出。
    public func get<T: Codable>(
        _ type: T.Type = T.self,
        at url: URL,
        refresh: Bool = false,
        fetch: () async throws -> T
    ) async throws -> T {
        let force = refresh || self.refresh
        if !force, let cached = read(type, at: url) {
            report("使用缓存: \(url.lastPathComponent)")
            return cached
        }
        do {
            let value = try await fetch()
            try write(value, to: url)
            return value
        } catch {
            if let stale = readIgnoringFreshness(type, at: url) {
                report("获取失败，回退到本地缓存: \(url.lastPathComponent) (\(error))")
                return stale
            }
            throw error
        }
    }

    // MARK: - Internal

    func readIgnoringFreshness<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// 让一个 cache-key 片段可移植（去除路径分隔符与 Windows 保留字符）。
    static func safe(_ part: String) -> String {
        let unsafe: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]
        let cleaned = String(part.map { unsafe.contains($0) ? "_" : $0 })
        return cleaned.isEmpty ? "_" : cleaned
    }
}
