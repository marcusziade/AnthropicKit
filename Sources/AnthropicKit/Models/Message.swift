import Foundation

/// Represents a message in a conversation with Claude.
///
/// Messages form the core of interactions with the Claude API. Each message has a role
/// (user, assistant, or system) and content that can be text, images, or tool-related blocks.
///
/// ## Creating Messages
///
/// ```swift
/// // Simple text message
/// let userMessage = Message.text("Hello, Claude!", role: .user)
///
/// // Message with image
/// let imageData = try Data(contentsOf: imageURL)
/// let message = Message(
///     role: .user,
///     content: .blocks([
///         ContentBlock(type: .text, text: "What's in this image?"),
///         ContentBlock(
///             type: .image,
///             source: ImageSource(
///                 mediaType: "image/jpeg",
///                 data: imageData.base64EncodedString()
///             )
///         )
///     ])
/// )
///
/// // System message for context
/// let systemMessage = Message(
///     role: .system,
///     content: .text("You are a helpful coding assistant specializing in Swift.")
/// )
/// ```
///
/// ## Building Conversations
///
/// ```swift
/// var messages: [Message] = []
///
/// // Add system context
/// messages.append(Message(
///     role: .system,
///     content: .text("You are a creative writing assistant.")
/// ))
///
/// // Add user message
/// messages.append(Message.text("Write a haiku about coding", role: .user))
///
/// // Get response and add to conversation
/// let response = try await client.createMessage(
///     MessageRequest(model: "claude-opus-4-20250514", maxTokens: 1024, messages: messages)
/// )
///
/// if let assistantMessage = response.asMessage {
///     messages.append(assistantMessage)
/// }
/// ```
public struct Message: Codable, Equatable, Sendable {
    /// The role of the message sender.
    ///
    /// - `.user`: Messages from the human user
    /// - `.assistant`: Messages from Claude
    /// - `.system`: System messages that set context or behavior
    public let role: Role
    
    /// The content of the message.
    ///
    /// Content can be:
    /// - Simple text: `.text("Hello")`
    /// - Complex blocks: `.blocks([...])` for images, tool use, etc.
    public let content: Content
    
    /// The name of the sender (optional).
    ///
    /// Useful for multi-user conversations or role-playing scenarios.
    public let name: String?
    
    /// Creates a new message.
    /// - Parameters:
    ///   - role: The role of the message sender.
    ///   - content: The content of the message.
    ///   - name: The name of the sender (optional).
    public init(role: Role, content: Content, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
    
    /// Creates a simple text message.
    ///
    /// This is a convenience method for the most common use case of creating
    /// plain text messages without images or tool interactions.
    ///
    /// - Parameters:
    ///   - text: The text content of the message.
    ///   - role: The role of the message sender.
    /// - Returns: A new message with text content.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let userMessage = Message.text("What is machine learning?", role: .user)
    /// let assistantMessage = Message.text("Machine learning is...", role: .assistant)
    /// ```
    public static func text(_ text: String, role: Role) -> Message {
        Message(role: role, content: .text(text))
    }
}

/// The role of a message sender in a conversation.
///
/// Roles determine how Claude interprets and responds to messages:
///
/// - `.user`: Input from the human user. Claude will respond to these messages.
/// - `.assistant`: Previous responses from Claude. Include these to maintain conversation context.
/// - `.system`: Instructions that guide Claude's behavior and responses.
///
/// ## Example
///
/// ```swift
/// let messages = [
///     Message(role: .system, content: .text("You are a helpful math tutor.")),
///     Message(role: .user, content: .text("What is 2+2?")),
///     Message(role: .assistant, content: .text("2+2 equals 4.")),
///     Message(role: .user, content: .text("Why?"))
/// ]
/// ```
public enum Role: String, Codable, Equatable, Sendable {
    /// Messages from the human user
    case user
    /// Messages from Claude (the AI assistant)
    case assistant
    /// System messages that set context or behavior
    case system
}

/// The content of a message, which can be simple text or complex content blocks.
///
/// Content supports two formats:
/// - `.text`: Simple string content for basic text messages
/// - `.blocks`: Array of content blocks for rich content (images, tool use, etc.)
///
/// ## Examples
///
/// ```swift
/// // Simple text
/// let textContent = Content.text("Hello, Claude!")
///
/// // Multiple content blocks
/// let richContent = Content.blocks([
///     ContentBlock(type: .text, text: "Analyze this image:"),
///     ContentBlock(
///         type: .image,
///         source: ImageSource(mediaType: "image/png", data: imageBase64)
///     )
/// ])
///
/// // Tool use result
/// let toolContent = Content.blocks([
///     ContentBlock(
///         type: .toolResult,
///         toolUseId: "tool_123",
///         content: .text("Weather: 72°F, sunny")
///     )
/// ])
/// ```
public enum Content: Codable, Equatable, Sendable {
    /// Simple text content
    case text(String)
    /// Array of content blocks for rich content
    case blocks([ContentBlock])
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .blocks(let blocks):
            var container = encoder.singleValueContainer()
            try container.encode(blocks)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Content must be either a string or an array of content blocks"
                )
            )
        }
    }
}

/// A content block within a message.
public struct ContentBlock: Codable, Equatable, Sendable {
    /// The type of content block.
    public let type: ContentBlockType
    
    /// Text content (when type is text).
    public let text: String?
    
    /// Image source (when type is image).
    public let source: ImageSource?
    
    /// Tool use information (when type is tool_use).
    public let id: String?
    public let name: String?
    public let input: AnyCodable?
    
    /// Tool result information (when type is tool_result).
    public let toolUseId: String?
    public let content: ToolResultContent?
    public let isError: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }
}

/// The type of a content block.
public enum ContentBlockType: String, Codable, Equatable, Sendable {
    case text
    case image
    case toolUse = "tool_use"
    case toolResult = "tool_result"
}

/// Represents image data for image content blocks.
///
/// Images must be base64-encoded and include their media type.
/// Supported formats include JPEG, PNG, GIF, and WebP.
///
/// ## Example
///
/// ```swift
/// // Load and encode an image
/// let imageData = try Data(contentsOf: imageURL)
/// let imageSource = ImageSource(
///     mediaType: "image/jpeg",
///     data: imageData.base64EncodedString()
/// )
///
/// // Create message with image
/// let message = Message(
///     role: .user,
///     content: .blocks([
///         ContentBlock(type: .text, text: "What's in this image?"),
///         ContentBlock(type: .image, source: imageSource)
///     ])
/// )
/// ```
///
/// ## Size Limits
///
/// - Maximum image size: 5MB
/// - Supported formats: JPEG, PNG, GIF, WebP
/// - Images are automatically resized if needed
public struct ImageSource: Codable, Equatable, Sendable {
    /// The type of image source.
    public let type: String
    
    /// The media type of the image.
    public let mediaType: String
    
    /// The base64-encoded image data.
    public let data: String
    
    private enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
    
    /// Creates a new image source.
    ///
    /// - Parameters:
    ///   - mediaType: The MIME type of the image (e.g., "image/jpeg", "image/png", "image/gif", "image/webp").
    ///   - data: The base64-encoded image data.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // From file
    /// let imageData = try Data(contentsOf: URL(fileURLWithPath: "photo.jpg"))
    /// let source = ImageSource(
    ///     mediaType: "image/jpeg",
    ///     data: imageData.base64EncodedString()
    /// )
    ///
    /// // From UIImage (iOS)
    /// if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
    ///     let source = ImageSource(
    ///         mediaType: "image/jpeg",
    ///         data: jpegData.base64EncodedString()
    ///     )
    /// }
    /// ```
    public init(mediaType: String, data: String) {
        self.type = "base64"
        self.mediaType = mediaType
        self.data = data
    }
}

/// Content returned in a tool result.
public enum ToolResultContent: Codable, Equatable, Sendable {
    case text(String)
    case blocks([ContentBlock])
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .blocks(let blocks):
            var container = encoder.singleValueContainer()
            try container.encode(blocks)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Tool result content must be either a string or an array of content blocks"
                )
            )
        }
    }
}

/// A type-erased codable value.
public struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality check for common types
        switch (lhs.value, rhs.value) {
        case (let l as Bool, let r as Bool): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as String, let r as String): return l == r
        default: return false
        }
    }
}