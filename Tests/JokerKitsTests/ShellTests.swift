//
//  ShellTests.swift
//
//
//  Created by joker on 2022/10/9.
//
#if os(macOS)
    import Testing
    @testable import JokerKits

    struct ShellTests {
        @Test
        func testShellSyncExecSuccess() throws {
            let ret = try Shell.runCommand(with: ["which", "ls"])
            #expect(ret == "/bin/ls\n")
        }

        func testShellSyncExecFailed() throws {
            let ret = try Shell.runCommand(with: ["which", "invalidCmd"])
            #expect(ret == "")
        }

        func testShellAsyncExecWithCallback() async throws {
            _ = try await confirmation("Shell Async Exec Completed") { confirmation in
                try Shell.runCommand(with: ["which", "bash"]) { process in
                    #expect(process.terminationStatus == 0)
                    confirmation()
                }
            }
        }

        func testShellAsyncExecWithAsyncAwait() async throws {
            let ret = await Shell.runCommand(with: ["which", "bash"])
            #expect(ret == true)
        }

        func testPidFetch() throws {
            let ret = try Shell.pids(of: "timed")
            #expect(ret.isEmpty == false, "process not existed")
        }
    }
#endif
