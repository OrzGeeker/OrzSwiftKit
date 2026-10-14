import Foundation
import Testing

@testable import JokerKits

@Suite
struct ProcessRunnerTests {
    @Test func gracefulStopExitsZero() async throws {
        // sh 从 stdin 读一行后退出；stop 写入 "stop\n"。
        let handle = try ProcessRunner.run(executable: "/bin/sh", args: ["-c", "read line; exit 0"])
        let exitTask = Task { await handle.waitForExit() }
        try await Task.sleep(nanoseconds: 200_000_000)
        await handle.stop()
        #expect(await exitTask.value == 0)
    }

    @Test func escalatesToKillWhenIgnoringTerm() async throws {
        let handle = try ProcessRunner.run(
            executable: "/bin/sh",
            args: ["-c", "trap '' TERM INT; sleep 30"],
            policy: .init(gracefulTimeout: 0.3, terminateTimeout: 0.3)
        )
        let exitTask = Task { await handle.waitForExit() }
        try await Task.sleep(nanoseconds: 300_000_000)
        await handle.stop()
        // SIGKILL 不可捕获 → 128 + 9
        #expect(await exitTask.value == 128 + 9)
    }

    @Test func reportsNormalExitCode() async throws {
        let handle = try ProcessRunner.run(executable: "/bin/sh", args: ["-c", "exit 3"])
        #expect(await handle.waitForExit() == 3)
    }
}
