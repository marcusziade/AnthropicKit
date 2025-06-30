# ``AnthropicKit``

Build intelligent Swift applications with Claude's powerful AI capabilities.

## Overview

AnthropicKit is a modern, lightweight Swift SDK that provides seamless integration with Anthropic's Claude API. Designed with Swift's best practices in mind, it offers a type-safe, performant, and intuitive interface for building AI-powered applications across Apple platforms and Linux.

### Why AnthropicKit?

- **Swift-First Design**: Built from the ground up for Swift developers, leveraging the language's powerful type system and modern concurrency features
- **Production-Ready**: Battle-tested implementation with comprehensive error handling and retry logic
- **Flexible Architecture**: Protocol-based design allows for easy testing, mocking, and customization
- **Minimal Dependencies**: Zero external dependencies for maximum compatibility and security
- **Comprehensive Features**: Full support for all Claude API capabilities including streaming, tool use, and batch processing

### Key Features

- **Type-Safe API**: Leverage Swift's type system for compile-time safety and better IDE support
- **Modern Concurrency**: Built with async/await and AsyncSequence for clean, efficient code
- **Streaming Support**: Real-time response streaming with backpressure handling
- **Tool Use**: Seamlessly integrate Claude with external tools and functions
- **Cross-Platform**: Universal compatibility across macOS, iOS, watchOS, tvOS, visionOS, and Linux
- **Networking Flexibility**: Choose between URLSession (Apple platforms) or cURL (Linux)
- **Comprehensive Error Handling**: Detailed error types with automatic retry for transient failures

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:ErrorHandling>

### Essentials

- ``AnthropicAPI``
- ``Message``
- ``Model``
- ``MessageRequest``
- ``MessageResponse``
- ``StreamEvent``

### Advanced Features

- <doc:StreamingResponses>
- <doc:ToolUse>
- <doc:BatchProcessing>

### API Components

- ``Content``
- ``ContentBlock``
- ``ToolResultContent``
- ``ImageContent``
- ``DocumentContent``
- ``PDFContent``

### Configuration & Error Handling

- ``APIConfiguration``
- ``AnthropicError``
- ``APIError``
- ``StreamError``

### Protocol & Types

- ``AnthropicAPIProtocol``
- ``Role``
- ``StopReason``
- ``Usage``