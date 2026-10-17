//
//  Downloader.swift
//
//
//  Created by joker on 2022/1/3.
//

import ConsoleKit
import Foundation
import TransferKit

public struct DownloadItemInfo: Sendable {

    public let sourceURL: URL
    public let dstFileURL: URL

    public let hash: String?
    public let hashType: HashType?

    public init(sourceURL: URL, dstFileURL: URL, hash: String? = nil, hashType: HashType? = nil) {
        self.sourceURL = sourceURL
        self.dstFileURL = dstFileURL
        self.hash = hash
        self.hashType = hashType
    }

    public enum HashType: Sendable {
        case sha1
        case sha256
    }
}

extension DownloadItemInfo {
    var transferItem: DownloadItem {
        DownloadItem(url: sourceURL, destination: dstFileURL, hash: hash, hashKind: hashType?.kind)
    }
}

extension DownloadItemInfo.HashType {
    var kind: HashKind {
        switch self {
        case .sha1: return .sha1
        case .sha256: return .sha256
        }
    }
}

extension Array where Element == DownloadItemInfo {
    public struct DownloadAsyncIterator: AsyncIteratorProtocol {
        var itemsIterator: IndexingIterator<[DownloadItemInfo]>
        public mutating func next() async throws -> DownloadItemInfo? {
            guard let item = itemsIterator.next() else { return nil }
            try await Downloader.download(item)
            return item
        }
    }

    public struct DownloadAsyncSequence: AsyncSequence {
        let items: [DownloadItemInfo]
        public func makeAsyncIterator() -> DownloadAsyncIterator {
            DownloadAsyncIterator(itemsIterator: items.makeIterator())
        }
    }

    public var asyncSequence: DownloadAsyncSequence { DownloadAsyncSequence(items: self) }
}

/// 下载入口（基于 `TransferKit` 的统一实现：哈希跳过 / 4 路 Range / 连接池）。
///
/// `onEvent` 给出**结构化**进度（`kind` = count/bytes、`total`/`current`，对齐
/// `docs/spec/behavior.md` B8）：`total == nil` 即不定长，调用方不该自行假设 0%。
/// `onProgress`（分数）保留给旧的 GUI/渲染用途。
public struct Downloader {

    /// 下载并发上限（默认 `TransferPolicy.defaultThreads`）。CLI 可在启动时按 `--download-threads` 设置。
    nonisolated(unsafe) public static var concurrency: Int = TransferPolicy.defaultThreads

    private static var transfer: Transfer { Transfer(concurrency: concurrency) }

    public static func download(
        _ item: DownloadItemInfo,
        progressBar: ActivityIndicator<ProgressBar>? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil,
        onEvent: (@Sendable (TransferProgress) -> Void)? = nil
    ) async throws {
        progressBar?.start(refreshRate: 100)
        try await transfer.download(item.transferItem) { progress in
            onEvent?(progress)
            if let fraction = progress.fraction {
                try? progressBar?.updateProgress(fraction)
                onProgress?(fraction)
            }
        }
        progressBar?.succeed()
    }

    public static func download(
        _ items: [DownloadItemInfo],
        progressBar: ActivityIndicator<ProgressBar>? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil,
        onEvent: (@Sendable (TransferProgress) -> Void)? = nil
    ) async throws {
        progressBar?.start(refreshRate: 100)
        try await transfer.download(items.map(\.transferItem)) { progress in
            onEvent?(progress)
            if let fraction = progress.fraction {
                try? progressBar?.updateProgress(fraction)
                onProgress?(fraction)
            }
        }
        progressBar?.succeed()
    }
}

extension ActivityIndicator where A == ProgressBar {
    func updateProgress(_ progress: Double) throws {
        self.activity.currentProgress = progress
        let progressDesc = String(format: "%d%%", arguments: [Int(self.activity.currentProgress * 100)])
        var title = self.activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(location: 0, length: title.count)
        let regex = try NSRegularExpression(pattern: "\\d+%$")
        if regex.firstMatch(in: title, range: range) != nil {
            title = regex.stringByReplacingMatches(in: title, range: range, withTemplate: progressDesc)
        } else {
            title.append(" ")
            title.append(progressDesc)
        }
        self.activity.title = title
    }
}
