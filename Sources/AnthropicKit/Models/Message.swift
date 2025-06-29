import Foundation

/// A message in a conversation.
public struct Message: Codable, Equatable, Sendable {
    /// The role of the message sender.
    public let role: Role
    
    /// The content of the message.
    public let content: Content
    
    /// The name of the sender (optional).
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
    /// - Parameters:
    ///   - role: The role of the message sender.
    ///   - text: The text content of the message.
    /// - Returns: A new message with text content.
    public static func text(_ text: String, role: Role) -> Message {
        Message(role: role, content: .text(text))
    }
}

/// The role of a message sender.
public enum Role: String, Codable, Equatable, Sendable {
    case user
    case assistant
    case system
}

/// The content of a message.
public enum Content: Codable, Equatable, Sendable {
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

/// Image source for image content blocks.
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
    /// - Parameters:
    ///   - mediaType: The media type (e.g., "image/jpeg", "image/png").
    ///   - data: The base64-encoded image data.
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
public struct AnyCodable: Codable, Equatable, Sendable {
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