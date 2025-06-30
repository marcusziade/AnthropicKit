# Streaming Responses

Learn how to use streaming for real-time AI responses in your Swift applications.

## Overview

Streaming allows you to receive Claude's responses in real-time as they're generated, rather than waiting for the complete response. This creates more responsive user interfaces and enables you to start processing results immediately.

## How Streaming Works

When you request a streaming response, AnthropicKit returns an `AsyncThrowingStream<StreamEvent>` that emits events as they arrive from the API. This leverages Swift's modern concurrency features for efficient, backpressure-aware streaming.

```swift
// Instead of waiting for the complete response:
let response = try await client.createMessage(request) // Waits for full response

// Stream events as they arrive:
let stream = try await client.streamMessage(request) // Returns immediately
for await event in stream {
    // Process each event as it arrives
}
```

## Stream Events

### Event Types

```swift
public enum StreamEvent: Decodable, Sendable {
    case start(MessageResponse)           // Initial message metadata
    case delta(ContentDelta)             // Incremental content updates
    case stop                            // Stream completed successfully
    case contentBlockStart(ContentBlock) // New content block started
    case contentBlockStop                // Content block completed
    case error(StreamError)              // Error occurred
}
```

### Event Flow

A typical streaming session follows this pattern:

1. `start`: Initial message with ID and metadata
2. `contentBlockStart`: Beginning of a content block
3. `delta`: Multiple incremental text updates
4. `contentBlockStop`: End of content block
5. `stop`: Stream completed

## Basic Streaming

### Simple Text Streaming

```swift
let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 1024,
    messages: [Message.text("Write a haiku about Swift programming", role: .user)]
)

let stream = try await client.streamMessage(request)

for await event in stream {
    switch event {
    case .delta(let delta):
        // Print text as it arrives
        print(delta.text ?? "", terminator: "")
        
    case .stop:
        print("\n\nStream completed")
        
    case .error(let error):
        print("Stream error: \(error)")
        
    default:
        break // Handle other events as needed
    }
}
```

### Collecting Full Response

```swift
var fullText = ""
var messageId = ""

for await event in stream {
    switch event {
    case .start(let message):
        messageId = message.id
        print("Started streaming message: \(messageId)")
        
    case .delta(let delta):
        if let text = delta.text {
            fullText += text
        }
        
    case .stop:
        print("Complete response: \(fullText)")
        
    case .error(let error):
        throw error
        
    default:
        break
    }
}
```

## Advanced Streaming Patterns

### Building a Chat Interface

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    
    private let client: AnthropicAPIProtocol
    private var streamTask: Task<Void, Never>?
    
    init(client: AnthropicAPIProtocol) {
        self.client = client
    }
    
    func sendMessage(_ text: String) {
        // Cancel any existing stream
        streamTask?.cancel()
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // Start assistant message
        var assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        
        isStreaming = true
        
        streamTask = Task {
            do {
                let request = MessageRequest(
                    model: "claude-opus-4-20250514",
                    maxTokens: 1024,
                    messages: messages.map { $0.toAPIMessage() }
                )
                
                let stream = try await client.streamMessage(request)
                
                for await event in stream {
                    if Task.isCancelled { break }
                    
                    switch event {
                    case .delta(let delta):
                        if let text = delta.text {
                            assistantMessage.content += text
                            messages[messages.count - 1] = assistantMessage
                        }
                        
                    case .stop:
                        isStreaming = false
                        
                    case .error(let error):
                        assistantMessage.content = "Error: \(error)"
                        messages[messages.count - 1] = assistantMessage
                        isStreaming = false
                        
                    default:
                        break
                    }
                }
            } catch {
                assistantMessage.content = "Error: \(error)"
                messages[messages.count - 1] = assistantMessage
                isStreaming = false
            }
        }
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
    }
}
```

### Stream with Progress Tracking

```swift
struct StreamProgress {
    var charactersReceived = 0
    var startTime = Date()
    
    var charactersPerSecond: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed > 0 ? Double(charactersReceived) / elapsed : 0
    }
}

func streamWithProgress(_ request: MessageRequest) async throws {
    var progress = StreamProgress()
    let stream = try await client.streamMessage(request)
    
    for await event in stream {
        switch event {
        case .start:
            progress.startTime = Date()
            print("Streaming started...")
            
        case .delta(let delta):
            if let text = delta.text {
                progress.charactersReceived += text.count
                print("\(text)", terminator: "")
                
                // Update UI with progress
                updateProgressBar(
                    characters: progress.charactersReceived,
                    rate: progress.charactersPerSecond
                )
            }
            
        case .stop:
            print("\n\nStreaming completed")
            print("Total characters: \(progress.charactersReceived)")
            print("Average speed: \(progress.charactersPerSecond) chars/sec")
            
        default:
            break
        }
    }
}
```

### Implementing Typewriter Effect

```swift
@MainActor
class TypewriterViewModel: ObservableObject {
    @Published var displayText = ""
    private var fullText = ""
    private var typewriterTask: Task<Void, Never>?
    
    func streamWithTypewriter(_ request: MessageRequest) {
        typewriterTask?.cancel()
        displayText = ""
        fullText = ""
        
        Task {
            do {
                let stream = try await client.streamMessage(request)
                
                // Collect text in background
                Task {
                    for await event in stream {
                        if case .delta(let delta) = event,
                           let text = delta.text {
                            fullText += text
                        }
                    }
                }
                
                // Animate display
                typewriterTask = Task {
                    var index = 0
                    while index < fullText.count {
                        if Task.isCancelled { break }
                        
                        let currentIndex = fullText.index(
                            fullText.startIndex,
                            offsetBy: index
                        )
                        displayText = String(fullText[..<currentIndex])
                        
                        index += 1
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }
                    displayText = fullText // Ensure complete text is shown
                }
            } catch {
                displayText = "Error: \(error)"
            }
        }
    }
}
```

## Error Handling in Streams

### Handling Stream Interruptions

```swift
func robustStreaming(_ request: MessageRequest) async throws -> String {
    var retryCount = 0
    let maxRetries = 3
    var collectedText = ""
    
    while retryCount < maxRetries {
        do {
            let stream = try await client.streamMessage(request)
            
            for await event in stream {
                switch event {
                case .delta(let delta):
                    if let text = delta.text {
                        collectedText += text
                    }
                    
                case .error(let error):
                    throw AnthropicError.streamError(error)
                    
                case .stop:
                    return collectedText
                    
                default:
                    break
                }
            }
            
            // If we get here, stream ended without .stop
            if !collectedText.isEmpty {
                return collectedText
            }
            
        } catch let error as AnthropicError {
            if case .streamError(.connectionClosed) = error,
               retryCount < maxRetries - 1 {
                retryCount += 1
                print("Stream interrupted. Retrying... (\(retryCount)/\(maxRetries))")
                
                // Exponential backoff
                let delay = Double(retryCount) * 2.0
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Continue with collected text
                continue
            }
            throw error
        }
    }
    
    throw AnthropicError.streamError(.connectionClosed)
}
```

### Timeout Handling

```swift
func streamWithTimeout(
    _ request: MessageRequest,
    timeout: TimeInterval = 30
) async throws -> String {
    var collectedText = ""
    
    let task = Task {
        let stream = try await client.streamMessage(request)
        
        for await event in stream {
            if Task.isCancelled { break }
            
            if case .delta(let delta) = event,
               let text = delta.text {
                collectedText += text
            }
        }
        
        return collectedText
    }
    
    // Race between stream completion and timeout
    let result = await withTaskGroup(
        of: String.self,
        returning: String.self
    ) { group in
        group.addTask { try await task.value }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            task.cancel()
            throw AnthropicError.streamError(.connectionClosed)
        }
        
        if let first = try await group.next() {
            group.cancelAll()
            return first
        }
        
        throw AnthropicError.streamError(.connectionClosed)
    }
    
    return result
}
```

## Performance Optimization

### Buffering Stream Events

```swift
actor StreamBuffer {
    private var buffer: [String] = []
    private let flushThreshold = 10
    
    func add(_ text: String) async -> String? {
        buffer.append(text)
        
        if buffer.count >= flushThreshold {
            return flush()
        }
        return nil
    }
    
    func flush() -> String {
        let combined = buffer.joined()
        buffer.removeAll(keepingCapacity: true)
        return combined
    }
}

func streamWithBuffering(_ request: MessageRequest) async throws {
    let buffer = StreamBuffer()
    let stream = try await client.streamMessage(request)
    
    for await event in stream {
        switch event {
        case .delta(let delta):
            if let text = delta.text {
                if let buffered = await buffer.add(text) {
                    // Process buffered text
                    processLargeChunk(buffered)
                }
            }
            
        case .stop:
            // Flush remaining buffer
            let remaining = await buffer.flush()
            if !remaining.isEmpty {
                processLargeChunk(remaining)
            }
            
        default:
            break
        }
    }
}
```

### Concurrent Stream Processing

```swift
func processMultipleStreams(_ requests: [MessageRequest]) async throws {
    await withThrowingTaskGroup(of: (Int, String).self) { group in
        for (index, request) in requests.enumerated() {
            group.addTask {
                var result = ""
                let stream = try await client.streamMessage(request)
                
                for await event in stream {
                    if case .delta(let delta) = event,
                       let text = delta.text {
                        result += text
                    }
                }
                
                return (index, result)
            }
        }
        
        // Collect results as they complete
        var results = [(Int, String)]()
        for try await (index, text) in group {
            results.append((index, text))
            print("Stream \(index) completed: \(text.prefix(50))...")
        }
    }
}
```

## Best Practices

### 1. Always Handle Cancellation

```swift
func cancellableStream(_ request: MessageRequest) async throws {
    let stream = try await client.streamMessage(request)
    
    for await event in stream {
        // Check for cancellation
        try Task.checkCancellation()
        
        switch event {
        case .delta(let delta):
            processData(delta)
        default:
            break
        }
    }
}
```

### 2. Provide Visual Feedback

```swift
struct StreamingIndicator {
    static func show(for event: StreamEvent) -> String? {
        switch event {
        case .start:
            return "🔄 Starting..."
        case .contentBlockStart:
            return "📝 Generating response..."
        case .stop:
            return "✅ Complete"
        case .error:
            return "❌ Error occurred"
        default:
            return nil
        }
    }
}
```

### 3. Memory Management

```swift
class StreamManager {
    private var activeStreams = Set<UUID>()
    
    func stream(_ request: MessageRequest) async throws {
        let streamId = UUID()
        activeStreams.insert(streamId)
        
        defer {
            activeStreams.remove(streamId)
        }
        
        let stream = try await client.streamMessage(request)
        
        for await event in stream {
            // Process events
        }
    }
    
    func cancelAllStreams() {
        // Cancel all active operations
        activeStreams.removeAll()
    }
}
```

## Testing Streaming

```swift
// Mock streaming for tests
class MockStreamingAPI: AnthropicAPIProtocol {
    func streamMessage(_ request: MessageRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Simulate streaming
                continuation.yield(.start(MessageResponse(/* mock data */)))
                
                let text = "Hello, world!"
                for char in text {
                    continuation.yield(.delta(ContentDelta(text: String(char))))
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                
                continuation.yield(.stop)
                continuation.finish()
            }
        }
    }
}
```

## Summary

Streaming responses provide a powerful way to create responsive, real-time AI experiences in your Swift applications. By understanding the event flow, implementing proper error handling, and following best practices, you can build robust streaming interfaces that delight your users.

For related topics, see:
- <doc:ErrorHandling> for comprehensive error handling strategies
- <doc:GettingStarted> for basic setup and configuration
- ``StreamEvent`` for complete event type reference