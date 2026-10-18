import Foundation

// Linux/Windows 把 URLSession/URLRequest 放在 FoundationNetworking（决策 D8：跨平台）。
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ArchiveError: Error, Equatable {
    case unsupportedExtension(String)
    case commandFailed(String, Int32)
}

/// 归档解压原语（`.tar.gz` / `.tgz` / `.zip`），用系统 `tar`/`unzip`。
///
/// 首选按扩展名分派；扩展名缺失或不认识时回退读**魔数**（`URLSession.download`
/// 返回的临时文件常为 `.tmp`，仅凭文件名会误判为不支持）。
public enum ArchiveExtractor {
    enum Tool {
        case tarGz
        case zip
    }

    public static func extract(
        archive: URL,
        into directory: URL,
        fileManager: FileManager = .default
    ) throws {
        let name = archive.lastPathComponent.lowercased()
        let tool = try detectTool(archive: archive, name: name)
        let arguments: [String]
        switch tool {
        case .tarGz:
            arguments = ["tar", "-xzf", archive.path, "-C", directory.path]
        case .zip:
            arguments = ["unzip", "-q", archive.path, "-d", directory.path]
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ArchiveError.commandFailed(name, process.terminationStatus)
        }
    }

    /// 扩展名优先，回退到魔数（gzip `1f 8b` / zip `PK\x03\x04`）。
    static func detectTool(archive: URL, name: String) throws -> Tool {
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") {
            return .tarGz
        }
        if name.hasSuffix(".zip") {
            return .zip
        }
        if let handle = try? FileHandle(forReadingFrom: archive) {
            defer { try? handle.close() }
            let magic = handle.readData(ofLength: 4)
            if magic.count >= 2, magic[magic.startIndex] == 0x1f, magic[magic.startIndex + 1] == 0x8b {
                return .tarGz
            }
            if magic.count >= 4, magic[magic.startIndex] == 0x50, magic[magic.startIndex + 1] == 0x4b {
                return .zip
            }
        }
        throw ArchiveError.unsupportedExtension(name)
    }
}
