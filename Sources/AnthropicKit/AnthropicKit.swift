/// AnthropicKit - A Swift SDK for the Anthropic API
///
/// AnthropicKit provides a comprehensive, protocol-oriented Swift interface to the Anthropic API.
/// It supports all API endpoints including messages, batches, files, models, and organizations.
///
/// ## Getting Started
///
/// ```swift
/// import AnthropicKit
///
/// // Create an API client
/// let client = AnthropicAPI(apiKey: "your-api-key")
///
/// // Create a simple message
/// let request = MessageRequest(
///     model: "claude-opus-4-20250514",
///     maxTokens: 1024,
///     messages: [
///         Message.text("Hello, Claude!", role: .user)
///     ]
/// )
///
/// // Send the message
/// let response = try await client.createMessage(request)
/// print(response.content.first?.text ?? "")
/// ```
///
/// ## Features
///
/// - Full API coverage including messages, batches, files, models, and organizations
/// - Cross-platform support (macOS and Linux)
/// - Streaming message support with Server-Sent Events
/// - Comprehensive error handling
/// - Protocol-oriented design for testability
/// - Async/await support throughout
///
/// ## Topics
///
/// ### API Client
/// - ``AnthropicAPI``
/// - ``AnthropicAPIProtocol``
/// - ``APIConfiguration``
///
/// ### Messages
/// - ``Message``
/// - ``MessageRequest``
/// - ``MessageResponse``
/// - ``StreamEvent``
///
/// ### Models
/// - ``Model``
/// - ``TokenCountRequest``
/// - ``TokenCountResponse``
///
/// ### Files
/// - ``File``
/// - ``ListFilesRequest``
/// - ``ListFilesResponse``
///
/// ### Batches
/// - ``Batch``
/// - ``BatchRequest``
/// - ``BatchResult``
///
/// ### Organizations
/// - ``WorkspaceMember``
/// - ``APIKey``
/// - ``WorkspaceRole``
///
/// ### Errors
/// - ``AnthropicError``
/// - ``APIError``
/// - ``ErrorType``

// This file serves as the main module documentation.
// All types are already public and available when importing AnthropicKit.