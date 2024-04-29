//
//  Shell+Utils.swift
//
//
//  Created by joker on 2024/1/16.
//

#if os(macOS)
import Foundation

public extension Shell {

    @discardableResult
    /// 结束进程
    /// - Parameter pid: 进程PID
    /// - Returns: 是否结束成功
    static func kill(with pid: String) async -> Bool {
        let ret = await run(path: Executable.kill.binPath, args: ["-9", pid], silent: true)
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
            .filter{ !$0.isEmpty }
        return pids
    }
}
#endif
