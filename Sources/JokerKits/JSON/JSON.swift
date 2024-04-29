//
//  File.swift
//  
//
//  Created by wangzhizhou on 2021/12/26.
//

import Foundation

public struct JSON {
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromKebabCaseOrSnakeCase
        return decoder
    }()
    
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
