# Getting Started with AnthropicKit

This guide will help you get started with AnthropicKit, the Swift SDK for the Anthropic API.

## Prerequisites

- Swift 5.9 or later
- macOS 12.0+ or Linux
- An Anthropic API key ([get one here](https://console.anthropic.com/))

## Installation

### Swift Package Manager

Add AnthropicKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/AnthropicKit.git", from: "1.0.0")
]
```

## Quick Start

### 1. Set up your API key

```bash
export ANTHROPIC_API_KEY="your-api-key"
```

### 2. Create a simple Swift file

```swift
import AnthropicKit

@main
struct MyApp {
    static func main() async throws {
        // Create client
        let client = AnthropicAPI(apiKey: "your-api-key")
        
        // Or use environment variable
        // let client = AnthropicAPI.fromEnvironment()!
        
        // Send a message
        let request = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 1024,
            messages: [
                Message.text("Hello, Claude!", role: .user)
            ]
        )
        
        let response = try await client.createMessage(request)
        print(response.content.first?.text ?? "")
    }
}
```

### 3. Run your code

```bash
swift run
```

## Common Use Cases

### Conversation with Context

```swift
let messages = [
    Message.text("What is Swift?", role: .user),
    Message.text("Swift is a powerful programming language...", role: .assistant),
    Message.text("What makes it different from Objective-C?", role: .user)
]

let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 1024,
    messages: messages
)
```

### Using System Prompts

```swift
let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 1024,
    messages: [Message.text("Explain quantum computing", role: .user)],
    system: "You are a physics professor. Explain concepts clearly and use analogies."
)
```

### Streaming Responses

```swift
let stream = try await client.createStreamingMessage(request)

for try await event in stream {
    switch event {
    case .contentBlockDelta(let delta):
        if let text = delta.delta.text {
            print(text, terminator: "")
        }
    case .messageStop:
        print("\n\nDone!")
    default:
        break
    }
}
```

### Error Handling

```swift
do {
    let response = try await client.createMessage(request)
    // Process response
} catch let error as AnthropicError {
    switch error {
    case .apiError(let apiError):
        print("API Error: \(apiError.message)")
    case .networkError(let message):
        print("Network Error: \(message)")
    case .rateLimitError:
        print("Rate limit exceeded, please wait")
    default:
        print("Error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## CLI Tool

AnthropicKit includes a CLI tool for testing:

```bash
# Build the CLI
swift build -c release

# Use it
./.build/release/anthropic-cli message "Hello!"
./.build/release/anthropic-cli stream "Write a poem"
./.build/release/anthropic-cli test
```

## Next Steps

- Check out the [full documentation](https://marcusziade.github.io/AnthropicKit/)
- Explore the [Examples](Examples/) directory
- Read the [API reference](https://docs.anthropic.com/)
- Join the discussion on [GitHub](https://github.com/marcusziade/AnthropicKit/discussions)

## Need Help?

- [Open an issue](https://github.com/marcusziade/AnthropicKit/issues)
- Check the [troubleshooting guide](https://github.com/marcusziade/AnthropicKit/wiki/Troubleshooting)
- Read the [FAQ](https://github.com/marcusziade/AnthropicKit/wiki/FAQ)