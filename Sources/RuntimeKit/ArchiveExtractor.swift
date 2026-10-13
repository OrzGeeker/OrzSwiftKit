import Foundation

public enum ArchiveError: Error, Equatable {
    case unsupportedExtension(String)
    case commandFailed(String, Int32)
}

/// 归档解压原语（`.tar.gz` / `.tgz` / `.zip`），用系统 `tar`/`unzip`。
public enum ArchiveExtractor {
    public static func extract(
        archive: URL,
        into directory: URL,
        fileManager: FileManager = .default
    ) throws {
        let name = archive.lastPathComponent.lowercased()
        let arguments: [String]
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") {
            arguments = ["tar", "-xzf", archive.path, "-C", directory.path]
        } else if name.hasSuffix(".zip") {
            arguments = ["unzip", "-q", archive.path, "-d", directory.path]
        } else {
            throw ArchiveError.unsupportedExtension(name)
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
}
