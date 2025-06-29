# AnthropicKit

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Linux-blue)](https://swift.org)
[![CI](https://github.com/marcusziade/AnthropicKit/workflows/CI/badge.svg)](https://github.com/marcusziade/AnthropicKit/actions)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Swift SDK for the Anthropic API with full Linux support and streaming capabilities.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/AnthropicKit.git", from: "1.0.0")
]
```

## Quick Start

```swift
import AnthropicKit

let client = AnthropicAPI(apiKey: "your-api-key")

// Simple message
let response = try await client.createMessage(MessageRequest(
    model: "claude-3-5-haiku-20241022",
    maxTokens: 1024,
    messages: [.text("Hello!", role: .user)]
))
print(response.content.first?.text ?? "")

// Streaming
let stream = try await client.createStreamingMessage(request)
for try await event in stream {
    if case .contentBlockDelta(let delta) = event,
       let text = delta.delta.text {
        print(text, terminator: "")
    }
}
```

## Features

- **Full API Coverage**: Messages, streaming, batches, files, models, organizations
- **Cross-Platform**: macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, visionOS 1+, Linux
- **Type-Safe**: Leverages Swift's type system
- **Async/Await**: Modern Swift concurrency
- **CLI Tool**: Comprehensive testing tool included

## CLI Usage

```bash
swift build -c release
export ANTHROPIC_API_KEY="your-api-key"

# Send message
./.build/release/anthropic-cli message "Hello"

# Stream response
./.build/release/anthropic-cli stream "Write a poem"

# Count tokens
./.build/release/anthropic-cli count-tokens "Test message"

# Batch operations
./.build/release/anthropic-cli batch create --count 3
```

## Docker

```bash
# Build and run
docker build -t anthropickit .
docker run --rm -e ANTHROPIC_API_KEY="your-key" anthropickit test

# Development
docker-compose run dev
```

## API Examples

### System Prompts

```swift
let request = MessageRequest(
    model: "claude-3-5-haiku-20241022",
    maxTokens: 200,
    messages: [.text("Tell me a joke", role: .user)],
    system: "You are a comedian."
)
```

### Batch Processing

```swift
let batch = try await client.createBatch(BatchRequest(requests: [
    BatchRequestItem(customId: "1", params: messageRequest1),
    BatchRequestItem(customId: "2", params: messageRequest2)
]))
```

### Token Counting

```swift
let count = try await client.countTokens(TokenCountRequest(
    model: "claude-3-5-haiku-20241022",
    messages: [.text("Count my tokens", role: .user)]
))
```

## License

MIT - see [LICENSE](LICENSE)