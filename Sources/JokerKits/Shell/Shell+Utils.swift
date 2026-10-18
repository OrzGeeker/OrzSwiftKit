//
//  Shell+Utils.swift
//
//
//  Created by joker on 2024/1/16.
//

// `Shell` 本体只用 `Process` + `/bin`、`/usr/bin` 里的系统工具（`env/ps/pgrep/kill`），
// Linux 同样具备；Windows 没有这些路径与工具，故仍排除（决策 D8：跨平台）。
#if !os(Windows)
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
        let ret = await run(path: Executable.kill.binPath, args: ["-s", signalName.rawValue, pid], silent: true)
        return ret
    }

    @discardableResult
    /// 判断pid对应的进程是否存在
    /// - Parameter pid: 进程PID
    /// - Returns: 进程是否存在
    static func exist(of pid: String) async -> Bool {
        let ret = await run(path: Executable.ps.binPath, args: ["-p", pid], silent: true)
        return ret
    }

    static func pids(of keyword: String) throws -> [String] {
        let output = try run(path: Executable.pgrep.userBinPath, args: [
            "-f",
            keyword
        ])
        let pids = output
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return pids
    }
}
#endif
