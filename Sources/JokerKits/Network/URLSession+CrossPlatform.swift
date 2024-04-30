//
//  File.swift
//  
//
//  Created by joker on 2022/3/21.
//

import Foundation

/// [适配Linux Foundation](https://www.xknote.com/ask/611147cca0f56.html)
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 跨Linux、MacOS平台网络请求处理
/// [参考文章](https://diegolavalle.com/posts/2021-11-11-urlsession-concurrency-linux/)
public extension URLSession {
    static func dataTask(for request: URLRequest) async throws -> (Data, URLResponse) {
#if canImport(FoundationNetworking)
        return await withCheckedContinuation({ continuation in
            URLSession.shared.dataTask(with: request) { data, response, _ in
                guard let data = data, let response = response else {
                    fatalError()
                }
                continuation.resume(returning: (data, response))
            }.resume()
        })
#else
        return try await URLSession.shared.data(for: request)
#endif
    }
    static func dataTask(from url: URL) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url)
        return try await URLSession.dataTask(for: request)
    }
}
