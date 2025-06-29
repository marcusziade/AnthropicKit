import Foundation
#if os(Linux)
@preconcurrency import FoundationNetworking
#endif

/// Protocol for HTTP client implementations.
public protocol HTTPClient: Sendable {
    /// Performs an HTTP request.
    /// - Parameters:
    ///   - request: The URL request to perform.
    ///   - streaming: Whether this is a streaming request.
    /// - Returns: The response data and HTTP response.
    func perform(_ request: URLRequest, streaming: Bool) async throws -> (Data, HTTPURLResponse)
    
    /// Performs a streaming HTTP request.
    /// - Parameter request: The URL request to perform.
    /// - Returns: An async stream of data chunks.
    func performStreaming(_ request: URLRequest) async throws -> AsyncThrowingStream<Data, Error>
    
    /// Uploads a file.
    /// - Parameters:
    ///   - request: The URL request.
    ///   - fileData: The file data to upload.
    ///   - filename: The filename.
    ///   - mimeType: The MIME type.
    /// - Returns: The response data and HTTP response.
    func uploadFile(_ request: URLRequest, fileData: Data, filename: String, mimeType: String) async throws -> (Data, HTTPURLResponse)
}

/// Creates the appropriate HTTP client for the current platform.
public func createHTTPClient() -> HTTPClient {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    return URLSessionHTTPClient()
    #else
    return CURLHTTPClient()
    #endif
}

/// HTTP method enumeration.
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// Extension to create URL requests more easily.
extension URLRequest {
    /// Creates a new URL request with the given parameters.
    /// - Parameters:
    ///   - url: The URL for the request.
    ///   - method: The HTTP method.
    ///   - headers: Headers to include.
    ///   - body: The request body data.
    ///   - timeoutInterval: The timeout interval.
    /// - Returns: A configured URL request.
    static func create(
        url: URL,
        method: HTTPMethod,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = body
        
        return request
    }
}