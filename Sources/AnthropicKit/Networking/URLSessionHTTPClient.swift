#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation

/// URLSession-based HTTP client for Apple platforms.
final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    
    init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }
    
    func perform(_ request: URLRequest, streaming: Bool) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.networkError("Invalid response type")
        }
        
        return (data, httpResponse)
    }
    
    func performStreaming(_ request: URLRequest) async throws -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AnthropicError.networkError("Invalid response type"))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Read error response
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        
                        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: AnthropicError.apiError(errorResponse.error))
                        } else {
                            continuation.finish(throwing: AnthropicError.networkError("HTTP \(httpResponse.statusCode)"))
                        }
                        return
                    }
                    
                    // Stream the response
                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        
                        // Check for newline to emit complete chunks
                        if byte == 10 { // '\n'
                            if !buffer.isEmpty {
                                continuation.yield(buffer)
                                buffer.removeAll()
                            }
                        }
                    }
                    
                    // Emit any remaining data
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func uploadFile(_ request: URLRequest, fileData: Data, filename: String, mimeType: String) async throws -> (Data, HTTPURLResponse) {
        let boundary = UUID().uuidString
        var modifiedRequest = request
        modifiedRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        modifiedRequest.httpBody = body
        
        let (data, response) = try await session.data(for: modifiedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.networkError("Invalid response type")
        }
        
        return (data, httpResponse)
    }
}
#endif