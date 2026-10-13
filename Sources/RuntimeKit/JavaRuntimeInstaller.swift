import Foundation
import JokerKits
import Utils

public enum RuntimeInstallError: Error, Equatable {
    case noAssetListURL
    case checksumMismatch(expected: String, actual: String)
    case runtimeHomeNotFound
}

public struct JavaRuntimeInstallation: Sendable {
    public let home: URL
    public let executable: URL
}

/// JRE 获取原语（D-b）：查询 Adoptium → 下载 → 校验 SHA-256 → 解压 → 定位 `bin/java`。
///
/// 只负责「拿到一份可运行的 JRE」；选择 major、落点（`java/<major>`）属于引擎策略。
public struct JavaRuntimeInstaller: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func install(query: AdoptiumQuery, into directory: URL) async throws -> JavaRuntimeInstallation {
        guard let listURL = query.assetListURL else {
            throw RuntimeInstallError.noAssetListURL
        }

        let (data, _) = try await session.data(from: listURL)
        let asset = try AdoptiumAssetSelector.select(from: data)

        let (tempURL, _) = try await session.download(from: asset.link)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        if let expected = asset.checksum, !expected.isEmpty {
            let actual = try tempURL.fileSHA256Value
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                throw RuntimeInstallError.checksumMismatch(expected: expected, actual: actual)
            }
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ArchiveExtractor.extract(archive: tempURL, into: directory)

        guard let home = Self.findRuntimeHome(in: directory) else {
            throw RuntimeInstallError.runtimeHomeNotFound
        }
        let executable = home
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(Self.javaExecutableName)
        return JavaRuntimeInstallation(home: home, executable: executable)
    }

    /// 在解压结果中定位含 `bin/java` 的运行时根（macOS 额外有一层 `Contents/Home`）。
    static func findRuntimeHome(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        let executableName = javaExecutableName

        func containsJava(_ dir: URL) -> Bool {
            fileManager.fileExists(
                atPath: dir.appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent(executableName).path
            )
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return nil }

        for child in children {
            if containsJava(child) { return child }
            let contentsHome = child
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Home", isDirectory: true)
            if containsJava(contentsHome) { return contentsHome }
        }
        return nil
    }

    static var javaExecutableName: String {
        Platform.os == .windows ? "java.exe" : "java"
    }
}
