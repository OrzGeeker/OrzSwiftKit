//
//  URL+GetData.swift
//
//
//  Created by wangzhizhou on 2021/12/26.
//

import Foundation

// Linux/Windows 把 URLSession/URLRequest 放在 FoundationNetworking（决策 D8：跨平台）。
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URL {

    var getData: Data? {
        get async throws {
            let (data, response) = try await URLSession.dataTask(from: self)
            guard (response as? HTTPURLResponse)?.statusCode == 200
            else {
                return nil
            }
            return data
        }
    }
}
