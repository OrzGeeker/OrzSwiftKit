//
//  CertbotTests.swift
//  
//
//  Created by joker on 2023/2/6.
//

import XCTest
@testable import JokerKits

final class CertbotTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
#if os(macOS)
        _ = try "brew info".exec()
#endif
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
