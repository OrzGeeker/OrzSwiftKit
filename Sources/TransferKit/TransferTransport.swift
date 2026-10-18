import Foundation

// Linux/Windows 把 URLSession/URLRequest 放在 FoundationNetworking（决策 D8：跨平台）。
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct TransferResponse: Sendable {
    public let statusCode: Int
    public let contentLength: Int64?

    public init(statusCode: Int, contentLength: Int64?) {
        self.statusCode = statusCode
        self.contentLength = contentLength
    }
}

/// HTTP 传输接缝：生产实现用 `URLSession`；测试用假实现离线模拟 Range/回退/中断。
public protocol TransferTransport: Sendable {
    /// 目标资源总长度（HEAD），未知返回 `nil`。
    func contentLength(of url: URL) async -> Int64?

    /// 执行请求并把响应体写入 `destination`；`onBytes` 报告（已写, 总长?）。
    @discardableResult
    func fetch(
        _ request: URLRequest,
        into destination: URL,
        onBytes: (@Sendable (Int64, Int64?) -> Void)?
    ) async throws -> TransferResponse
}

/// 生产实现：`URLSession` 下载任务（流式落盘）。
public struct URLSessionTransferTransport: TransferTransport {
    public let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public func contentLength(of url: URL) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              http.expectedContentLength > 0
        else { return nil }
        return http.expectedContentLength
    }

    @discardableResult
    public func fetch(
        _ request: URLRequest,
        into destination: URL,
        onBytes: (@Sendable (Int64, Int64?) -> Void)?
    ) async throws -> TransferResponse {
        let delegate = onBytes.map { ByteProgressDelegate(handler: $0) }
        let (temporary, response) = try await session.download(for: request, delegate: delegate)
        let http = response as? HTTPURLResponse
        let length = http?.expectedContentLength
        let resolvedLength = (length ?? -1) > 0 ? length : nil

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        do {
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try fileManager.copyItem(at: temporary, to: destination)
            try? fileManager.removeItem(at: temporary)
        }
        return TransferResponse(statusCode: http?.statusCode ?? 0, contentLength: resolvedLength)
    }
}

final class ByteProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let handler: @Sendable (Int64, Int64?) -> Void

    init(handler: @escaping @Sendable (Int64, Int64?) -> Void) {
        self.handler = handler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        handler(totalBytesWritten, totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
