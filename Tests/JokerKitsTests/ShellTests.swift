//
//  ShellTests.swift
//  
//
//  Created by joker on 2022/10/9.
//
#if os(macOS)
import XCTest
@testable import JokerKits

final class ShellTests: XCTestCase {
    
    func testShellSyncExecSuccess() throws {
        let ret = try Shell.runCommand(with: ["which", "ls"])
        XCTAssertEqual(ret, "/bin/ls\n")
    }
    
    func testShellSyncExecFailed() throws {
        let ret = try Shell.runCommand(with: ["which", "invalidCmd"])
        XCTAssertEqual(ret, "")
    }
    
    func testShellAsyncExecWithCallback() throws {
        let expectation = XCTestExpectation(description: "Shell Async Exec Completed")

        try Shell.runCommand(with: ["which","bash"]) { process in
            XCTAssertEqual(process.terminationStatus, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testShellAsyncExecWithAsyncAwait() async throws {
        let ret = await Shell.runCommand(with: ["which", "bash"])
        XCTAssertEqual(ret, true)
    }

    func testPidFetch() throws {
        let ret = try Shell.pids(of: "timed")
        XCTAssert(!ret.isEmpty, "process not existed")
    }
}
#endif
