#if os(Linux)
import Foundation
@preconcurrency import FoundationNetworking

/// cURL-based HTTP client for Linux with proper streaming support.
final class CURLHTTPClient: HTTPClient {
    
    private func performNonStreamingRequest(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            resultData = data
            resultResponse = response
            resultError = error
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        if let error = resultError {
            throw error
        }
        
        guard let data = resultData,
              let httpResponse = resultResponse as? HTTPURLResponse else {
            throw AnthropicError.networkError("Invalid response")
        }
        
        return (data, httpResponse)
    }
    
    func perform(_ request: URLRequest, streaming: Bool) async throws -> (Data, HTTPURLResponse) {
        if streaming {
            // For streaming requests, we need to collect the full response
            var fullData = Data()
            let stream = try await performStreaming(request)
            for try await chunk in stream {
                fullData.append(chunk)
            }
            
            // Create a mock response since we can't get headers from streaming
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            
            return (fullData, response)
        }
        
        // Non-streaming requests also use curl
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try performNonStreamingRequest(request)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func performStreaming(_ request: URLRequest) async throws -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                    
                    // Build curl arguments
                    var args = [
                        "-X", request.httpMethod ?? "POST",
                        request.url!.absoluteString,
                        "-N",           // No buffering
                        "--no-buffer",  // Disable buffering
                        "-s",           // Silent mode
                        "-i",           // Include headers
                        "-w", "\n\n__CURL_HTTP_CODE__:%{http_code}"
                    ]
                    
                    // Add headers
                    if let headers = request.allHTTPHeaderFields {
                        for (key, value) in headers {
                            args.append(contentsOf: ["-H", "\(key): \(value)"])
                        }
                    }
                    
                    // Add body data
                    if let bodyData = request.httpBody {
                        args.append(contentsOf: ["-d", String(data: bodyData, encoding: .utf8) ?? ""])
                    }
                    
                    process.arguments = args
                    
                    // Set up pipes
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe
                    
                    // Start the process
                    try process.run()
                    
                    let handle = stdoutPipe.fileHandleForReading
                    var headersParsed = false
                    var buffer = Data()
                    
                    // Read data from curl
                    while process.isRunning || handle.availableData.count > 0 {
                        let chunk = handle.availableData
                        
                        if chunk.isEmpty {
                            try? await Task.sleep(for: .milliseconds(10))
                            continue
                        }
                        
                        buffer.append(chunk)
                        
                        if !headersParsed {
                            // Look for end of headers (double newline)
                            if let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) ?? 
                                                  buffer.range(of: Data("\n\n".utf8)) {
                                // Parse headers
                                let headerData = buffer[..<headerEndRange.lowerBound]
                                let headerString = String(data: headerData, encoding: .utf8) ?? ""
                                
                                // Check status code
                                if headerString.contains("HTTP/") {
                                    let lines = headerString.components(separatedBy: .newlines)
                                    if let statusLine = lines.first,
                                       let statusCode = statusLine.split(separator: " ").dropFirst().first,
                                       let code = Int(statusCode),
                                       code >= 400 {
                                        continuation.finish(throwing: AnthropicError.networkError("HTTP \(code)"))
                                        process.terminate()
                                        return
                                    }
                                }
                                
                                // Remove headers from buffer
                                buffer = buffer[headerEndRange.upperBound...]
                                headersParsed = true
                            }
                        }
                        
                        if headersParsed && !buffer.isEmpty {
                            // Emit data lines for SSE
                            while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                                let line = buffer[..<newlineRange.upperBound]
                                if !line.isEmpty {
                                    continuation.yield(line)
                                }
                                buffer.removeSubrange(..<newlineRange.upperBound)
                            }
                        }
                    }
                    
                    // Emit any remaining data
                    if !buffer.isEmpty && headersParsed {
                        continuation.yield(buffer)
                    }
                    
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.finish(throwing: AnthropicError.networkError("cURL error: \(errorMessage)"))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func uploadFile(_ request: URLRequest, fileData: Data, filename: String, mimeType: String) async throws -> (Data, HTTPURLResponse) {
        // Use URLSession's multipart upload
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
        
        return try await perform(modifiedRequest, streaming: false)
    }
}
#endif