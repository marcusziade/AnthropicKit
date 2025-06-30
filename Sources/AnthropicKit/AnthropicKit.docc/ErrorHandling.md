# Error Handling

Learn how to handle errors gracefully and build resilient applications with AnthropicKit.

## Overview

AnthropicKit provides comprehensive error handling to help you build robust applications. All errors are strongly typed, making it easy to handle specific error cases and provide appropriate user feedback.

## Error Types

### AnthropicError

The main error type that encapsulates all possible errors:

```swift
public enum AnthropicError: Error {
    case apiError(APIError)          // API-specific errors
    case networkError(Error)         // Network connectivity issues
    case decodingError(Error)        // JSON decoding failures
    case streamError(StreamError)    // Streaming-specific errors
}
```

### APIError

Errors returned by the Anthropic API:

```swift
public struct APIError: Error, Codable {
    public let type: String
    public let message: String
}
```

Common API error types:
- `invalid_request_error`: Malformed request
- `authentication_error`: Invalid API key
- `permission_error`: Insufficient permissions
- `not_found_error`: Resource not found
- `rate_limit_error`: Too many requests
- `overloaded_error`: Server temporarily overloaded

### StreamError

Errors specific to streaming operations:

```swift
public enum StreamError: Error {
    case invalidEventData         // Malformed SSE data
    case connectionClosed        // Stream ended unexpectedly
    case decodingFailed(Error)   // Failed to decode stream event
}
```

## Basic Error Handling

### Simple Try-Catch

```swift
do {
    let response = try await client.createMessage(request)
    // Handle successful response
} catch {
    print("Error: \(error)")
}
```

### Specific Error Handling

```swift
do {
    let response = try await client.createMessage(request)
    processResponse(response)
} catch let error as AnthropicError {
    switch error {
    case .apiError(let apiError):
        handleAPIError(apiError)
    case .networkError(let networkError):
        handleNetworkError(networkError)
    case .decodingError(let decodingError):
        handleDecodingError(decodingError)
    case .streamError(let streamError):
        handleStreamError(streamError)
    }
} catch {
    // Handle unexpected errors
    print("Unexpected error: \(error)")
}
```

## Handling Specific Error Cases

### Rate Limiting

Handle rate limits with exponential backoff:

```swift
func handleAPIError(_ error: APIError) async {
    switch error.type {
    case "rate_limit_error":
        // Extract retry-after header if available
        print("Rate limited. Waiting before retry...")
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        // Retry the request
        
    case "authentication_error":
        print("Invalid API key. Please check your credentials.")
        // Prompt user to update API key
        
    case "invalid_request_error":
        print("Invalid request: \(error.message)")
        // Fix request parameters
        
    default:
        print("API Error: \(error.message)")
    }
}
```

### Network Errors

```swift
func handleNetworkError(_ error: Error) {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            print("No internet connection")
        case .timedOut:
            print("Request timed out")
        case .cannotFindHost:
            print("Cannot reach Anthropic servers")
        default:
            print("Network error: \(urlError.localizedDescription)")
        }
    }
}
```

### Stream Error Recovery

```swift
func streamWithRecovery(_ request: MessageRequest) async throws {
    var retryCount = 0
    let maxRetries = 3
    
    while retryCount < maxRetries {
        do {
            let stream = try await client.streamMessage(request)
            
            for await event in stream {
                switch event {
                case .delta(let delta):
                    processDelta(delta)
                case .error(let error):
                    throw error
                default:
                    break
                }
            }
            break // Success, exit retry loop
            
        } catch let error as AnthropicError {
            if case .streamError(.connectionClosed) = error {
                retryCount += 1
                print("Stream disconnected. Retry \(retryCount)/\(maxRetries)")
                try await Task.sleep(nanoseconds: UInt64(retryCount) * 1_000_000_000)
                continue
            }
            throw error
        }
    }
}
```

## Advanced Error Handling Patterns

### Retry with Exponential Backoff

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch let error as AnthropicError {
            lastError = error
            
            // Only retry on transient errors
            if case .apiError(let apiError) = error {
                let shouldRetry = ["rate_limit_error", "overloaded_error"].contains(apiError.type)
                if shouldRetry && attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            }
            throw error
        }
    }
    
    throw lastError ?? AnthropicError.apiError(APIError(
        type: "max_retries_exceeded",
        message: "Operation failed after \(maxAttempts) attempts"
    ))
}

// Usage
let response = try await withRetry {
    try await client.createMessage(request)
}
```

### Circuit Breaker Pattern

```swift
actor CircuitBreaker {
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let threshold = 5
    private let timeout: TimeInterval = 60
    
    private var isOpen: Bool {
        guard failureCount >= threshold else { return false }
        guard let lastFailure = lastFailureTime else { return false }
        return Date().timeIntervalSince(lastFailure) < timeout
    }
    
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        if isOpen {
            throw AnthropicError.apiError(APIError(
                type: "circuit_breaker_open",
                message: "Circuit breaker is open. Service temporarily unavailable."
            ))
        }
        
        do {
            let result = try await operation()
            await reset()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }
    
    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
    }
    
    private func reset() {
        failureCount = 0
        lastFailureTime = nil
    }
}
```

### Error Aggregation for Batch Operations

```swift
struct BatchError: Error {
    let errors: [(index: Int, error: Error)]
    
    var description: String {
        errors.map { "[\($0.index)]: \($0.error)" }.joined(separator: "\n")
    }
}

func processBatch(_ requests: [MessageRequest]) async -> ([MessageResponse?], [Error?]) {
    await withTaskGroup(of: (Int, Result<MessageResponse, Error>).self) { group in
        for (index, request) in requests.enumerated() {
            group.addTask {
                do {
                    let response = try await client.createMessage(request)
                    return (index, .success(response))
                } catch {
                    return (index, .failure(error))
                }
            }
        }
        
        var responses = [MessageResponse?](repeating: nil, count: requests.count)
        var errors = [Error?](repeating: nil, count: requests.count)
        
        for await (index, result) in group {
            switch result {
            case .success(let response):
                responses[index] = response
            case .failure(let error):
                errors[index] = error
            }
        }
        
        return (responses, errors)
    }
}
```

## Error Logging and Monitoring

### Structured Error Logging

```swift
struct ErrorLogger {
    static func log(_ error: AnthropicError, context: [String: Any] = [:]) {
        var errorInfo: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "context": context
        ]
        
        switch error {
        case .apiError(let apiError):
            errorInfo["type"] = "api_error"
            errorInfo["error_type"] = apiError.type
            errorInfo["message"] = apiError.message
            
        case .networkError(let networkError):
            errorInfo["type"] = "network_error"
            errorInfo["message"] = networkError.localizedDescription
            
        case .decodingError(let decodingError):
            errorInfo["type"] = "decoding_error"
            errorInfo["message"] = String(describing: decodingError)
            
        case .streamError(let streamError):
            errorInfo["type"] = "stream_error"
            errorInfo["stream_error_type"] = String(describing: streamError)
        }
        
        // Send to logging service
        print("ERROR: \(errorInfo)")
    }
}

// Usage
do {
    let response = try await client.createMessage(request)
} catch let error as AnthropicError {
    ErrorLogger.log(error, context: [
        "model": request.model,
        "message_count": request.messages.count
    ])
}
```

## Best Practices

### 1. Always Handle Errors Explicitly

```swift
// ❌ Bad: Silent failure
let response = try? await client.createMessage(request)

// ✅ Good: Explicit handling
do {
    let response = try await client.createMessage(request)
} catch {
    // Handle error appropriately
    logger.error("Failed to create message: \(error)")
    throw error
}
```

### 2. Provide User-Friendly Error Messages

```swift
extension AnthropicError {
    var userFriendlyMessage: String {
        switch self {
        case .apiError(let error):
            switch error.type {
            case "rate_limit_error":
                return "Too many requests. Please try again in a moment."
            case "authentication_error":
                return "Invalid API key. Please check your settings."
            default:
                return "Something went wrong. Please try again."
            }
        case .networkError:
            return "Network connection issue. Please check your internet."
        case .decodingError:
            return "Unexpected response format. Please try again."
        case .streamError:
            return "Stream interrupted. Please retry your request."
        }
    }
}
```

### 3. Implement Graceful Degradation

```swift
func getResponseWithFallback(_ request: MessageRequest) async -> String {
    do {
        // Try primary model
        let response = try await client.createMessage(request)
        return response.content.first?.text ?? ""
    } catch {
        // Fall back to a simpler model
        var fallbackRequest = request
        fallbackRequest.model = "claude-3-5-haiku-20241022"
        
        do {
            let response = try await client.createMessage(fallbackRequest)
            return response.content.first?.text ?? ""
        } catch {
            // Final fallback
            return "I'm temporarily unable to process your request. Please try again later."
        }
    }
}
```

## Testing Error Scenarios

```swift
// Mock client for testing
class MockAnthropicAPI: AnthropicAPIProtocol {
    var shouldFailWithError: AnthropicError?
    
    func createMessage(_ request: MessageRequest) async throws -> MessageResponse {
        if let error = shouldFailWithError {
            throw error
        }
        // Return mock response
        return MessageResponse(/* mock data */)
    }
}

// Test error handling
func testRateLimitHandling() async throws {
    let mockClient = MockAnthropicAPI()
    mockClient.shouldFailWithError = .apiError(APIError(
        type: "rate_limit_error",
        message: "Rate limit exceeded"
    ))
    
    // Test your error handling logic
    do {
        _ = try await mockClient.createMessage(testRequest)
        XCTFail("Should have thrown error")
    } catch let error as AnthropicError {
        if case .apiError(let apiError) = error {
            XCTAssertEqual(apiError.type, "rate_limit_error")
        }
    }
}
```

## Summary

Proper error handling is crucial for building reliable applications with AnthropicKit. By understanding the error types, implementing appropriate retry strategies, and following best practices, you can create resilient applications that gracefully handle failures and provide excellent user experiences.

For more advanced topics, see:
- <doc:StreamingResponses> for stream-specific error handling
- <doc:BatchProcessing> for handling errors in batch operations
- ``AnthropicError`` for the complete error type reference