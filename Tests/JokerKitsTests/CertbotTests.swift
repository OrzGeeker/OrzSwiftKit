//
//  CertbotTests.swift
//
//
//  Created by joker on 2023/2/6.
//

import Testing

@testable import JokerKits

@Test
func testExample() throws {
    #if os(macOS)
        _ = try "brew info".exec()
    #endif
}
