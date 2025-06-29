# Getting Started

Learn how to install and use AnthropicKit in your Swift projects.

## Installation

### Swift Package Manager

Add AnthropicKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/AnthropicKit.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["AnthropicKit"]
)
```

## Basic Usage

### Creating a Client

```swift
import AnthropicKit

let client = AnthropicAPI(apiKey: "your-api-key")
```

### Sending a Message

```swift
let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 1024,
    messages: [
        Message.text("Hello, Claude!", role: .user)
    ]
)

let response = try await client.createMessage(request)
print(response.content.first?.text ?? "")
```

### Using Streaming

```swift
let stream = try await client.streamMessage(request)

for await event in stream {
    switch event {
    case .delta(let delta):
        print(delta.text ?? "", terminator: "")
    case .error(let error):
        print("Error: \(error)")
    default:
        break
    }
}
```

## Next Steps

Ready to build something more complex? Check out our interactive tutorials to learn how to build a complete AI assistant.