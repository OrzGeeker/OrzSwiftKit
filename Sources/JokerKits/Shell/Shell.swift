//
//  File.swift
//  
//
//  Created by joker on 2022/1/5.
//

// `Shell` 本体只用 `Process`；POSIX 平台借 `/bin`、`/usr/bin` 里的系统工具
// （`env/ps/pgrep/kill`），Windows 对应 `cmd/tasklist/taskkill/powershell`（D14 跨平台）。
import Foundation

public struct Shell {

    #if os(Windows)
    /// Windows 没有 `env`：走 `cmd.exe /c`。
    static let envPath = "cmd.exe"

    /// `cmd.exe /c` 需要的参数前缀（`runCommand` 用）。
    static let commandPrefix = ["/c"]
    #else
    enum Executable: String, CaseIterable {
        case env
        case bash
        case pgrep
        case ps
        case kill
        var binPath: String { "\(Executable.binPath)/\(self.rawValue)" }
        var userBinPath: String { "\(Executable.userBinPath)/\(self.rawValue)" }
        private static let binPath = "/bin"
        private static let userBinPath = "/usr/bin"
    }

    static let envPath = Executable.env.userBinPath

    static let commandPrefix: [String] = []
    #endif

    @discardableResult
    public static func runCommand(with args: [String], workDirectory: String? = nil) throws -> String {
        return try self.run(path: envPath, args: commandPrefix + args, workDirectory: workDirectory)
    }
    
    @discardableResult
    public static func runCommand(with args: [String], workDirectory: String? = nil, terminationHandler: (@Sendable (Process) -> Void)? = nil) throws -> Process {
        return try self.run(
            path: envPath,
            args: commandPrefix + args,
            workDirectory: workDirectory,
            terminationHandler: terminationHandler
        )
    }
    
    @discardableResult
    public static func runCommand(with args: [String], workDirectory: String? = nil) async -> Bool {
        return await self.run(path: envPath, args: commandPrefix + args, workDirectory: workDirectory)
    }
}

extension Shell {
    
    @discardableResult
    /// 同步执行Shell命令
    /// - Parameters:
    ///   - path: 命令二进制路径
    ///   - args: 命令参数数组
    ///   - workDirectory: 运行命令时所在的目录
    /// - Returns: 执行结果字符串，成功时返回标准输出内容，失败时返回空字符串
    public static func run(path: String, args: [String], workDirectory: String? = nil) throws -> String {
        
        let process = Process()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        if let workDirectory = workDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
        }
        
        try process.run()
        process.waitUntilExit()
        
        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
        return result
    }
    
    @discardableResult
    /// 异步执行Shell命令
    /// - Parameters:
    ///   - path: 命令二进制文件路径
    ///   - args: 命令参数数组
    ///   - workDirectory: 运行命令时所在的目录
    ///   - terminationHandler: 执行结果回调
    public static func run(path: String, args: [String], workDirectory: String? = nil, terminationHandler: (@Sendable (Process) -> Void)? = nil) throws -> Process {
        let fileURL = URL(fileURLWithPath: path)
        let process = Process()
        process.executableURL = fileURL
        process.arguments = args
        
        if let workDirectory = workDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
        }
        process.terminationHandler = terminationHandler
        try process.run()
        
        return process
    }
    
    @discardableResult
    /// 异步执行Shell命令
    /// - Parameters:
    ///   - path: 命令二进制文件路径
    ///   - args: 命令参数数组
    ///   - workDirectory: 运行命令时所在的目录
    /// - Returns: 是否执行成功
    public static func run(path: String, args: [String], workDirectory: String? = nil, silent: Bool = false) async -> Bool {
        return await withCheckedContinuation({ continuation in
            let fileURL = URL(fileURLWithPath: path)
            let process = Process()
            process.executableURL = fileURL
            process.arguments = args

            if silent {
                process.standardOutput = FileHandle.nullDevice
            }

            if let workDirectory = workDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
            }
            process.terminationHandler = { task in
                let ret = task.terminationStatus == 0
                continuation.resume(returning: ret)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        })
    }
}
