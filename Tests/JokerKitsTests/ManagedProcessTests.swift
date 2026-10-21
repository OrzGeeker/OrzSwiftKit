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
