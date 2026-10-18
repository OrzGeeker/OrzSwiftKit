//
//  Shell+Utils.swift
//
//
//  Created by joker on 2024/1/16.
//

// 进程工具：POSIX 走 `ps/pgrep/kill`，Windows 走 `tasklist/taskkill/powershell`（D14 跨平台）。
import Foundation

public extension Shell {
    
    enum SignalName: String {
        case hangup = "HUP"
        case interrupt = "INT"
        case quit = "QUIT"
        case abort = "ABRT"
        case kill = "KILL"
        case alarm = "ALRM"
        case terminal = "TERM"
    }

    @discardableResult
    /// 结束进程
    /// - Parameter pid: 进程PID
    /// - Returns: 是否结束成功
    static func kill(with pid: String, signalName: SignalName = .kill) async -> Bool {
        #if os(Windows)
        // Windows 没有信号：`taskkill /F` 等价 SIGKILL；不带 `/F` 等价「礼貌结束」。
        var args = ["/PID", pid]
        if signalName == .kill { args.append("/F") }
        return await run(path: "taskkill.exe", args: args, silent: true)
        #else
        let ret = await run(path: Executable.kill.binPath, args: ["-s", signalName.rawValue, pid], silent: true)
        return ret
        #endif
    }

    @discardableResult
    /// 判断pid对应的进程是否存在
    /// - Parameter pid: 进程PID
    /// - Returns: 进程是否存在
    static func exist(of pid: String) async -> Bool {
        #if os(Windows)
        // `tasklist` 找不到 PID 时退出码仍是 0，要查输出里是否含该 PID。
        // 注意：`run` 有多个重载（`-> String` / `-> Process` / async `-> Bool`），
        // 必须显式标注类型，否则在 async 上下文里会选中 Bool 重载。
        let output: String
        do {
            output = try run(path: "tasklist.exe", args: ["/FI", "PID eq \(pid)", "/NH"])
        } catch {
            return false
        }
        return output.contains(pid)
        #else
        let ret = await run(path: Executable.ps.binPath, args: ["-p", pid], silent: true)
        return ret
        #endif
    }

    static func pids(of keyword: String) throws -> [String] {
        #if os(Windows)
        // `pgrep -f` 的对应物：按命令行匹配取 PID。
        let script = "(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*\(keyword)*' }).ProcessId"
        let output = try run(path: "powershell.exe", args: ["-NoProfile", "-Command", script])
        #else
        let output = try run(path: Executable.pgrep.userBinPath, args: [
            "-f",
            keyword
        ])
        #endif
        let pids = output
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return pids
    }
}
