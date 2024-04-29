//
//  Downloader.swift
//  
//
//  Created by joker on 2022/1/3.
//

import Foundation
import Alamofire
import ConsoleKit

public struct DownloadItemInfo {
    
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
    
    public enum HashType {
        case sha1
        case sha256
    }
}

extension Array where Element == DownloadItemInfo {
    public var asyncSequence: DownloadAsyncSequence { DownloadAsyncSequence(items: self) }
    public struct DownloadAsyncSequence: AsyncSequence {
        let items: [DownloadItemInfo]
        public typealias AsyncIterator = DownloadAsyncIterator
        public struct DownloadAsyncIterator: AsyncIteratorProtocol {
            var itemsIterator: IndexingIterator<[DownloadItemInfo]>
            public mutating func next() async throws -> DownloadItemInfo? {
                guard let item = itemsIterator.next()
                else {
                    return nil
                }
                try await Downloader.download(item)
                return item
            }
        }
        public func makeAsyncIterator() -> DownloadAsyncIterator {
            return DownloadAsyncIterator(itemsIterator: self.items.makeIterator())
        }
    }
}

public struct Downloader {
    
    public static func download(_ sourceURL: URL) -> (DownloadTask<URL>, StreamOf<Progress>) {
        let retryPolicy = RetryPolicy(
            retryLimit: 5,
            exponentialBackoffBase: 2,
            exponentialBackoffScale: 1)
        let request = AF.download(sourceURL, interceptor: retryPolicy)
        return (request.serializingDownloadedFileURL(), request.downloadProgress())
    }
    
    public static func download(_ item: DownloadItemInfo, progressBar: ActivityIndicator<ProgressBar>? = nil) async throws {
        progressBar?.start(refreshRate: 100)
        if let hash = item.hash, let hashType = item.hashType, item.dstFileURL.path.isExist() {
            var hashValue: String? = nil
            switch hashType {
            case .sha1:
                hashValue = try item.dstFileURL.fileSHA1Value
            case .sha256:
                hashValue = try item.dstFileURL.fileSHA256Value
            }
            guard hashValue != hash else {
                progressBar?.succeed()
                return
            }
        }
        let (downloadURLTask, downloadProgressStream) = Downloader.download(item.sourceURL)
        if let progressBar = progressBar {
            for try await progress in downloadProgressStream {
                try progressBar.updateProgress(progress.fractionCompleted)
            }
            progressBar.succeed()
        }
        try FileManager.moveFile(fromFilePath: try await downloadURLTask.value.path, toFilePath: item.dstFileURL.path, overwrite: true)
    }
    
    public static func download(
        _ items: [DownloadItemInfo],
        progressBar: ActivityIndicator<ProgressBar>? = nil) async throws {
            
        try await withThrowingTaskGroup(of: Void.self, body: { group in

            // 资源信息转获为下载任务，添加到下载任务组中，下载任务并发进行
            for item in items {
                group.addTask {
                    try await Downloader.download(item)
                }
            }

            // 要显示进度时
            if let progressBar  {
                let total = items.count
                var index = 0
                progressBar.start(refreshRate: 100)
                // 更新进度条显示资源下载进度
                for try await _ in group {
                    index += 1
                    let progress = Double(index) / Double(total)
                    try progressBar.updateProgress(progress)
                }
                progressBar.succeed()
            }
            
            // 不显示进度时
            else {
                try await group.waitForAll()
            }
        })
    }
}

extension ActivityIndicator where A == ProgressBar {
    func updateProgress(_ progress: Double) throws {
        self.activity.currentProgress = progress
        let progressDesc = String(format: "%d%%", arguments: [Int(self.activity.currentProgress * 100)])
        var title = self.activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(location: 0, length: title.count)
        let regex = try NSRegularExpression(pattern: "\\d+%$")
        if let _ = regex.firstMatch(in: title, range: range) {
            title = regex.stringByReplacingMatches(in: title, range: range, withTemplate: progressDesc)
        } else {
            title.append(" ")
            title.append(progressDesc)
        }
        self.activity.title = title
    }
}
