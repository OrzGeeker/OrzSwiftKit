//
//  JSONTests.swift
//  
//
//  Created by joker on 2022/10/9.
//

import XCTest
@testable import JokerKits

final class JSONTests: XCTestCase {
    
    struct TestModel: Codable, JsonRepresentable {
        let camelCase: String
        let snakeCase: String
        let kebabCase: String
    }
    
    let model = TestModel(camelCase: "camel case",
                          snakeCase: "snake case",
                          kebabCase: "kebab case")
    
    let encodeModelJson = """
        {
          "camel_case" : "camel case",
          "kebab_case" : "kebab case",
          "snake_case" : "snake case"
        }
        """
    
    /// 测试编码
    func testJSONEncoder() throws {
                
        let data = try JSON.encoder.encode(model)
        
        let jsonContent = String(data: data, encoding: .utf8)!

        XCTAssertEqual(jsonContent, encodeModelJson)
    }
    
    /// 测试解码
    func testJSONDecoder() throws {
        
        let jsonString = """
        {
            "camelCase" : "camel case",
            "snake_case": "snake case",
            "kebab-case": "kebab case",
        }
        """
        
        let model = try JSON.decoder.decode(TestModel.self, from: jsonString.data(using: .utf8)!)
        
        XCTAssertEqual(model.camelCase, "camel case")
        XCTAssertEqual(model.snakeCase, "snake case")
        XCTAssertEqual(model.kebabCase, "kebab case")
    }

    // 测试JSON解码字符串表示
    func testJSONRepresentable() throws {
        XCTAssertEqual(try model.jsonRepresentation(), encodeModelJson)
    }
}
