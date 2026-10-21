import XCTest
@testable import JokerKits

/// `ManagedProcess`：向子进程 stdin 送命令 + stdout 回调（服务端控制台的基础设施）。
final class ManagedProcessTests: XCTestCase {
    #if !os(Windows)
    /// 每读到一行就回一行（模拟服务端读命令、写日志）。
    private func makeEchoProcess(_ collector: LineCollector) throws -> ManagedProcess {
        try ProcessRunner.run(
            executable: "/bin/sh",
            args: ["-c", "while IFS= read -r line; do echo \"log:$line\"; done"],
            onLine: { collector.append($0) }
        )
    }

    /// 轮询等待 collector 里出现目标文本（stdout 是**块**，不保证一次一行）。
    private func waitFor(
        _ needle: String,
        in collector: LineCollector,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if collector.text.contains(needle) { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("等不到 \"\(needle)\"，实际输出：\(collector.text)", file: file, line: line)
    }

    func testSendWritesLineToChildStdin() async throws {
        let collector = LineCollector()
        let process = try makeEchoProcess(collector)

        XCTAssertTrue(process.send("say hello"))
        await waitFor("log:say hello", in: collector)
        await process.stop()
    }

    func testSendAppendsNewlineOnlyOnce() async throws {
        let collector = LineCollector()
        let process = try makeEchoProcess(collector)

        XCTAssertTrue(process.send("cmd"))
        XCTAssertTrue(process.send("cmd2\n"))
        await waitFor("log:cmd", in: collector)
        await waitFor("log:cmd2", in: collector)
        await process.stop()
    }

    func testSendAfterExitReturnsFalse() async throws {
        let process = try ProcessRunner.run(executable: "/bin/sh", args: ["-c", "exit 0"])
        _ = await process.waitForExit()
        XCTAssertFalse(process.send("stop"), "进程已退出就不能再写 stdin")
    }
    #endif
}

private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""

    func append(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer += text
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}

/// `inheritStandardInput`：CLI 让子进程继承终端 stdin（GUI 不用，走 `send`）。
final class ManagedProcessStandardInputTests: XCTestCase {
    #if !os(Windows)
    func testPipeModeCanSendCommands() throws {
        let process = try ProcessRunner.run(executable: "/bin/sh", args: ["-c", "cat"])
        defer { Task { await process.stop() } }
        XCTAssertTrue(process.canSendCommands)
        XCTAssertTrue(process.send("hi"))
        _ = process
    }

    func testInheritModeDoesNotExposeSend() async throws {
        // 继承终端 stdin 时没有我们自己的管道 → 不该假装能 send（否则会和终端抢输入）。
        let process = try ProcessRunner.run(
            executable: "/bin/sh",
            args: ["-c", "sleep 1"],
            inheritStandardInput: true
        )
        XCTAssertFalse(process.canSendCommands)
        XCTAssertFalse(process.send("hi"))
        _ = await process.waitForExit()   // 让它自然退出，避免悬挂
    }
    #endif
}

/// 生命周期强制终止：`terminate()`（SIGTERM）与 `kill()`（SIGKILL），以及带超时的等待。
final class ManagedProcessTerminationTests: XCTestCase {
    #if !os(Windows)
    func testTerminateStopsLongRunningChild() async throws {
        // 一个不理 SIGTERM 的普通子进程仍会被 SIGTERM 结束（默认处置）。
        let process = try ProcessRunner.run(executable: "/bin/sh", args: ["-c", "sleep 30"])
        XCTAssertTrue(process.isRunning)
        await process.terminate()
        XCTAssertFalse(process.isRunning, "terminate() 之后进程应已退出")
    }

    func testKillStopsChildIgnoringTerminate() async throws {
        // `trap '' TERM` → SIGTERM 被忽略，只有 SIGKILL 能停。
        let process = try ProcessRunner.run(
            executable: "/bin/sh",
            args: ["-c", "trap '' TERM; sleep 30"]
        )
        try await Task.sleep(nanoseconds: 300_000_000)
        await process.forceKill()
        XCTAssertFalse(process.isRunning, "kill() 用 SIGKILL，忽略 SIGTERM 的进程也应退出")
    }

    func testWaitForExitTimeoutReturnsFalseWhileRunning() async throws {
        let process = try ProcessRunner.run(executable: "/bin/sh", args: ["-c", "sleep 30"])
        let exited = await process.waitForExit(timeout: 0.3)
        XCTAssertFalse(exited, "0.3s 内不会退出 → false")
        await process.forceKill()
        let exitedAfterKill = await process.waitForExit(timeout: 5)
        XCTAssertTrue(exitedAfterKill)
    }
    #endif
}
