import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// 受管子进程：优雅停止 → `SIGTERM` → `SIGKILL`，退出码归一（信号 → `128 + signal`）。
///
/// 对齐 `docs/spec/behavior.md` B7：终端 `stop`/取消时优雅退出，超时升级，不遗留孤儿。
public final class ManagedProcess: @unchecked Sendable {
    public struct Policy: Sendable {
        /// 发送 `stop` 后等待自然退出的时长。
        public var gracefulTimeout: TimeInterval
        /// `SIGTERM` 后等待的时长。
        public var terminateTimeout: TimeInterval

        public init(gracefulTimeout: TimeInterval = 60, terminateTimeout: TimeInterval = 5) {
            self.gracefulTimeout = gracefulTimeout
            self.terminateTimeout = terminateTimeout
        }

        public static let standard = Policy()
    }

    /// 用户取消（Ctrl-C）的规范退出码。
    public static let cancelledExitCode: Int32 = 130

    private let process: Process
    private let stdin: FileHandle?
    private let policy: Policy

    init(process: Process, stdin: FileHandle?, policy: Policy) {
        self.process = process
        self.stdin = stdin
        self.policy = policy
    }

    public var isRunning: Bool { process.isRunning }
    public var processIdentifier: Int32 { process.processIdentifier }

    /// 等待退出并返回归一化退出码。
    public func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            if !process.isRunning {
                continuation.resume(returning: Self.exitCode(of: process))
                return
            }
            process.terminationHandler = { finished in
                continuation.resume(returning: Self.exitCode(of: finished))
            }
        }
    }

    /// 优雅停止；必要时升级到 `SIGTERM` / `SIGKILL`。
    public func stop() async {
        guard process.isRunning else { return }

        if let stdin {
            try? stdin.write(contentsOf: Data("stop\n".utf8))
            try? stdin.close()
        }
        if await wait(timeout: policy.gracefulTimeout) { return }

        process.terminate()  // SIGTERM
        if await wait(timeout: policy.terminateTimeout) { return }

        #if os(Windows)
        // Windows 没有 POSIX 信号：`terminate()` 走 TerminateProcess，本身就是硬终止。
        process.terminate()
        #else
        kill(process.processIdentifier, SIGKILL)
        #endif
        _ = await wait(timeout: 5)
    }

    private func wait(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return !process.isRunning
    }

    static func exitCode(of process: Process) -> Int32 {
        process.terminationReason == .uncaughtSignal
            ? 128 + process.terminationStatus
            : process.terminationStatus
    }
}

public enum ProcessRunner {
    /// 启动子进程并返回受管句柄。
    ///
    /// - Parameter onLine: 提供时把子进程 stdout/stderr 逐块回调（用于透传服务端日志）。
    @discardableResult
    public static func run(
        executable: String,
        args: [String],
        workDirectory: String? = nil,
        policy: ManagedProcess.Policy = .standard,
        onLine: (@Sendable (String) -> Void)? = nil
    ) throws -> ManagedProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let workDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
        }

        let input = Pipe()
        process.standardInput = input

        if let onLine {
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            output.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                onLine(text)
            }
        }

        try process.run()
        return ManagedProcess(process: process, stdin: input.fileHandleForWriting, policy: policy)
    }
}
