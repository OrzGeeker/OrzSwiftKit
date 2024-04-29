//
//  File.swift
//  
//
//  Created by joker on 2022/10/9.
//

import Foundation

public protocol JsonRepresentable where Self: Encodable {
    func jsonRepresentation(_ keyCodingStrategy: JSONEncoder.KeyEncodingStrategy?) throws -> String?
}

public extension JsonRepresentable {
    func jsonRepresentation(_ keyCodingStrategy: JSONEncoder.KeyEncodingStrategy? = nil) throws -> String? {
        let encoder = JSON.encoder
        if let strategy = keyCodingStrategy {
            encoder.keyEncodingStrategy = strategy
        }
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)
    }
}
