//
//  JSONTests.swift
//
//
//  Created by joker on 2022/10/9.
//

import Testing

@testable import JokerKits

struct JSONTests {

    struct TestModel: Codable, JsonRepresentable {
        let camelCase: String
        let snakeCase: String
        let kebabCase: String
    }

    let model = TestModel(
        camelCase: "camel case",
        snakeCase: "snake case",
        kebabCase: "kebab case")

    let encodeModelJson = """
        {
          "camel_case" : "camel case",
          "kebab_case" : "kebab case",
          "snake_case" : "snake case"
        }
        """

    @Test
    func JSONEncoder() throws {

        let data = try JSON.encoder.encode(model)

        let jsonContent = String(data: data, encoding: .utf8)!

        #expect(jsonContent == encodeModelJson)
    }

    @Test
    func JSONDecoder() throws {

        let jsonString = """
            {
                "camelCase" : "camel case",
                "snake_case": "snake case",
                "kebab-case": "kebab case",
            }
            """

        let model = try JSON.decoder.decode(TestModel.self, from: jsonString.data(using: .utf8)!)

        #expect(model.camelCase == "camel case")
        #expect(model.snakeCase == "snake case")
        #expect(model.kebabCase == "kebab case")
    }

    @Test
    func JSONRepresentable() throws {
        #expect(try model.jsonRepresentation() == encodeModelJson)
    }
}
