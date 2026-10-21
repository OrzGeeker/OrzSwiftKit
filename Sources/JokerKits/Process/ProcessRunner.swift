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

    /// 是否可以用 `send(_:)` 往子进程 stdin 写命令。
    ///
    /// `false` 表示子进程**直接继承了父进程的 stdin**（终端场景：用户在终端里打字，
    /// 由终端把输入交给子进程，前端不需要也不该再写管道）。
    public var canSendCommands: Bool { stdin != nil }

    init(process: Process, stdin: FileHandle?, policy: Policy) {
        self.process = process
        self.stdin = stdin
        self.policy = policy
    }

    public var isRunning: Bool { process.isRunning }
    public var processIdentifier: Int32 { process.processIdentifier }

    /// 往子进程 stdin 送一行命令（自动补 `\n`）。
    ///
    /// 服务端控制台的前端（GUI）用它把用户输入的命令送进服务端：
    /// `stop` / `say hello` / `op someone` 都走这里。CLI 侧不需要（终端本身就是 stdin）。
    ///
    /// - Returns: 是否写入成功（进程已退出 / stdin 已关闭 / 写失败 → `false`，不抛）。
    @discardableResult
    public func send(_ command: String) -> Bool {
        guard process.isRunning, let stdin else { return false }
        let line = command.hasSuffix("\n") ? command : command + "\n"
        do {
            try stdin.write(contentsOf: Data(line.utf8))
            return true
        } catch {
            return false
        }
    }

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

    /// 等退出，最多 `timeout` 秒；返回是否**已退出**。
    ///
    /// 前端用它实现"停止/重启"里的等待（`stop()` 之后确认进程真的没了再启动）。
    public func waitForExit(timeout: TimeInterval) async -> Bool {
        await wait(timeout: timeout)
    }

    /// 强制终止：`SIGTERM` → 等 `terminateTimeout` → `SIGKILL`。
    ///
    /// 服务端管理里的「**终止**」用它：立刻要进程消失（玩家会被直接断开、世界可能来不及保存），
    /// 与「停止」（先送 `stop` 命令让服务端自己优雅退出，见 `stop()`）区分开。
    public func terminate() async {
        guard process.isRunning else { return }
        process.terminate()  // SIGTERM
        if await wait(timeout: policy.terminateTimeout) { return }
        #if os(Windows)
        process.terminate()
        #else
        Self.signal(SIGKILL, to: process.processIdentifier)
        #endif
        _ = await wait(timeout: 5)
    }

    /// 更狠：直接 `SIGKILL`，不给服务端任何保存时间（进程卡死、`terminate()` 也没反应时用）。
    ///
    /// 起名 `forceKill()` 是为了不和全局 `kill(2)` 撞名（在同一类型里会被解析成实例方法）。
    public func forceKill() async {
        guard process.isRunning else { return }
        #if os(Windows)
        process.terminate()
        #else
        Self.signal(SIGKILL, to: process.processIdentifier)
        #endif
        _ = await wait(timeout: 5)
    }

    #if !os(Windows)
    /// `kill(2)` 包一层：本类型里的方法名会和全局函数抢解析。
    private static func signal(_ sig: Int32, to pid: Int32) {
        #if canImport(Darwin)
        _ = Darwin.kill(pid, sig)
        #else
        _ = Glibc.kill(pid, sig)
        #endif
    }
    #endif

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
    /// - Parameters:
    ///   - onLine: 提供时把子进程 stdout/stderr 逐块回调（用于透传服务端日志）。
    ///   - inheritStandardInput: **让子进程直接继承父进程的 stdin**（终端场景）。
    ///     CLI 启动服务端时用它：用户在终端里打字，输入直达服务端控制台
    ///     （与 Python 侧 `subprocess.Popen` 不传 `stdin=` 的语义一致）。
    ///     GUI 不要开——GUI 用 `ManagedProcess.send(_:)` 显式写管道。
    @discardableResult
    public static func run(
        executable: String,
        args: [String],
        workDirectory: String? = nil,
        policy: ManagedProcess.Policy = .standard,
        onLine: (@Sendable (String) -> Void)? = nil,
        inheritStandardInput: Bool = false
    ) throws -> ManagedProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let workDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
        }

        var pipeInput: Pipe?
        if inheritStandardInput {
            // 直接继承终端 stdin：用户在终端输入的命令由终端交给子进程。
            process.standardInput = FileHandle.standardInput
        } else {
            let input = Pipe()
            process.standardInput = input
            pipeInput = input
        }

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
        return ManagedProcess(
            process: process,
            stdin: pipeInput?.fileHandleForWriting,
            policy: policy
        )
    }
}
