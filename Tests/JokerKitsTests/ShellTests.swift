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
        func shellSyncExecSuccess() throws {
            let ret = try Shell.runCommand(with: ["which", "ls"])
            #expect(ret == "/bin/ls\n")
        }

        @Test
        func shellSyncExecFailed() throws {
            let ret = try Shell.runCommand(with: ["which", "invalidCmd"])
            #expect(ret == "")
        }
        @Test
        func shellAsyncExecWithCallback() async throws {
            _ = try await confirmation("Shell Async Exec Completed") { confirmation in
                try Shell.runCommand(with: ["which", "bash"]) { process in
                    #expect(process.terminationStatus == 0)
                    confirmation()
                }
            }
        }
        @Test
        func shellAsyncExecWithAsyncAwait() async throws {
            let ret = await Shell.runCommand(with: ["which", "bash"])
            #expect(ret == true)
        }
        @Test
        func pidFetch() throws {
            let ret = try Shell.pids(of: "timed")
            #expect(ret.isEmpty == false, "process not existed")
        }
    }
#endif
