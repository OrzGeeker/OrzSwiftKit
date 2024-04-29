//
//  File.swift
//  
//
//  Created by joker on 2022/10/9.
//

import Foundation

extension JSONDecoder.KeyDecodingStrategy {
    
    static var convertFromKebabCase: JSONDecoder.KeyDecodingStrategy = .custom { keys in
        let codingKey = keys.last!
        let key = codingKey.stringValue
        guard key.contains("-") else { return codingKey }
        let words = key.components(separatedBy: "-")
        let camelCased = words[0] + words[1...].map(\.capitalized).joined()
        return AnyCodingKey(stringValue: camelCased)!
    }
    
    static var convertFromKebabCaseOrSnakeCase: JSONDecoder.KeyDecodingStrategy = .custom { keys in
        let codingKey = keys.last!
        let key = codingKey.stringValue
        
        if key.contains("-") {
            let words = key.components(separatedBy: "-")
            let camelCased = words[0] + words[1...].map(\.capitalized).joined()
            return AnyCodingKey(stringValue: camelCased)!
        }
        else if key.contains("_") {
            let words = key.components(separatedBy: "_")
            let camelCased = words[0] + words[1...].map(\.capitalized).joined()
            return AnyCodingKey(stringValue: camelCased)!
        }
        else {
            return codingKey
        }
    }
    
    struct AnyCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        var intValue: Int?
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }
    }
}
