# Getting Started

Get up and running with AnthropicKit in minutes. This guide covers installation, basic configuration, and common usage patterns to help you integrate Claude into your Swift applications.

## Installation

### Swift Package Manager

AnthropicKit supports Swift Package Manager for easy integration. Choose one of the following methods:

#### Xcode

1. Open your project in Xcode
2. Go to **File > Add Package Dependencies**
3. Enter the repository URL: `https://github.com/guitaripod/AnthropicKit.git`
4. Choose your version requirements (we recommend "Up to Next Major Version")
5. Click **Add Package**

#### Package.swift

Add AnthropicKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/guitaripod/AnthropicKit.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["AnthropicKit"]
)
```

### System Requirements

- **Swift**: 6.0 or later
- **Platforms**: macOS 13+, iOS 16+, watchOS 9+, tvOS 16+, visionOS 1+, Linux
- **Xcode**: 15.0 or later (for Apple platforms)

## Configuration

### API Key Setup

First, obtain your API key from the [Anthropic Console](https://console.anthropic.com/).

**Important**: Never hardcode API keys in your source code. Use environment variables or secure storage.

```swift
import AnthropicKit

// From environment variable (recommended)
let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
let client = AnthropicAPI(apiKey: apiKey)

// With custom configuration
let config = APIConfiguration(
    apiKey: apiKey,
    baseURL: URL(string: "https://api.anthropic.com")!,
    headers: ["Custom-Header": "Value"]
)
let client = AnthropicAPI(configuration: config)
```

## Basic Usage

### Simple Conversation

Here's the simplest way to have a conversation with Claude:

```swift
import AnthropicKit

// Create a client
let client = AnthropicAPI(apiKey: "your-api-key")

// Send a message
let response = try await client.createMessage(
    MessageRequest(
        model: "claude-opus-4-20250514",
        maxTokens: 1024,
        messages: [
            Message.text("What is the capital of France?", role: .user)
        ]
    )
)

// Print Claude's response
if let text = response.content.first?.text {
    print(text) // "The capital of France is Paris."
}
```

### Multi-turn Conversation

Build conversations by maintaining message history:

```swift
var messages: [Message] = []

// User asks a question
messages.append(Message.text("What's the weather like in Paris?", role: .user))

// Get Claude's response
let response1 = try await client.createMessage(
    MessageRequest(model: "claude-opus-4-20250514", maxTokens: 1024, messages: messages)
)

// Add Claude's response to history
if let assistantMessage = response1.asMessage {
    messages.append(assistantMessage)
}

// Continue the conversation
messages.append(Message.text("What about in London?", role: .user))

let response2 = try await client.createMessage(
    MessageRequest(model: "claude-opus-4-20250514", maxTokens: 1024, messages: messages)
)
```

### Working with Images

Claude can analyze images alongside text:

```swift
// Load image data
let imageData = try Data(contentsOf: URL(fileURLWithPath: "path/to/image.jpg"))

// Create a message with both text and image
let message = Message(
    role: .user,
    content: [
        .text("What's in this image?"),
        .image(ImageContent(data: imageData, mediaType: .jpeg))
    ]
)

let response = try await client.createMessage(
    MessageRequest(model: "claude-opus-4-20250514", maxTokens: 1024, messages: [message])
)
```

### Streaming Responses

Stream responses for real-time output, perfect for chat interfaces:

```swift
let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 1024,
    messages: [Message.text("Tell me a story about a brave knight", role: .user)]
)

let stream = try await client.streamMessage(request)

for await event in stream {
    switch event {
    case .start(let message):
        print("Started streaming with ID: \(message.id)")
        
    case .delta(let delta):
        // Print text as it arrives
        print(delta.text ?? "", terminator: "")
        
    case .stop:
        print("\n\nStreaming completed")
        
    case .error(let error):
        print("Error: \(error)")
        
    default:
        break
    }
}
```

### Error Handling

Always handle potential errors gracefully:

```swift
do {
    let response = try await client.createMessage(request)
    // Process response
} catch let error as AnthropicError {
    switch error {
    case .apiError(let apiError):
        print("API Error: \(apiError.message)")
        // Handle rate limits, invalid requests, etc.
        
    case .networkError(let urlError):
        print("Network Error: \(urlError.localizedDescription)")
        // Handle connectivity issues
        
    case .decodingError(let decodingError):
        print("Decoding Error: \(decodingError)")
        // Handle unexpected response format
        
    case .streamError(let streamError):
        print("Stream Error: \(streamError)")
        // Handle streaming-specific issues
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Model Selection

Choose the right model for your use case:

```swift
// For complex reasoning and analysis
let opusRequest = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 4096,
    messages: messages
)

// For balanced performance and cost
let sonnetRequest = MessageRequest(
    model: "claude-3-5-sonnet-20241022",
    maxTokens: 4096,
    messages: messages
)

// For fast, lightweight responses
let haikuRequest = MessageRequest(
    model: "claude-3-5-haiku-20241022",
    maxTokens: 4096,
    messages: messages
)
```

## Best Practices

### 1. Manage Rate Limits

Implement exponential backoff for rate limit errors:

```swift
func sendMessageWithRetry(_ request: MessageRequest, maxAttempts: Int = 3) async throws -> MessageResponse {
    for attempt in 1...maxAttempts {
        do {
            return try await client.createMessage(request)
        } catch let error as AnthropicError {
            if case .apiError(let apiError) = error,
               apiError.type == "rate_limit_error",
               attempt < maxAttempts {
                // Exponential backoff
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }
            throw error
        }
    }
    throw AnthropicError.apiError(APIError(
        type: "max_retries_exceeded",
        message: "Maximum retry attempts reached"
    ))
}
```

### 2. Optimize Token Usage

```swift
// Set appropriate max tokens
let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 500,  // Only request what you need
    messages: messages,
    temperature: 0.7  // Adjust creativity vs consistency
)

// Monitor usage
print("Input tokens: \(response.usage.inputTokens)")
print("Output tokens: \(response.usage.outputTokens)")
```

### 3. System Messages

Use system messages to set context and behavior:

```swift
let messages = [
    Message(
        role: .system,
        content: "You are a helpful Swift programming assistant. Provide concise, accurate code examples."
    ),
    Message.text("How do I sort an array in Swift?", role: .user)
]
```

## Next Steps

- **Explore Advanced Features**: Learn about <doc:StreamingResponses>, <doc:ToolUse>, and <doc:BatchProcessing>
- **Handle Errors Properly**: Read our comprehensive <doc:ErrorHandling> guide
- **Check out Tutorials**: Build a complete AI assistant with our interactive tutorials
- **API Reference**: Dive deep into the ``AnthropicAPI`` documentation

## Need Help?

- 📚 Browse the [full documentation](https://swiftpackageindex.com/guitaripod/AnthropicKit/documentation)
- 💬 Join the community discussions on [GitHub](https://github.com/guitaripod/AnthropicKit/discussions)
- 🐛 Report issues on our [issue tracker](https://github.com/guitaripod/AnthropicKit/issues)
- 📧 Contact Anthropic support for API-related questions