import Foundation

/// A request to generate a message from Claude.
///
/// `MessageRequest` encapsulates all parameters needed to interact with Claude,
/// including the conversation history, model selection, generation parameters,
/// and optional features like tool use.
///
/// ## Basic Usage
///
/// ```swift
/// // Simple request
/// let request = MessageRequest(
///     model: "claude-opus-4-20250514",
///     maxTokens: 1024,
///     messages: [Message.text("Hello, Claude!", role: .user)]
/// )
///
/// // With system prompt and temperature
/// let request = MessageRequest(
///     model: "claude-opus-4-20250514",
///     maxTokens: 2048,
///     messages: messages,
///     system: "You are a helpful coding assistant.",
///     temperature: 0.7
/// )
/// ```
///
/// ## Advanced Features
///
/// ```swift
/// // With tools
/// let request = MessageRequest(
///     model: "claude-opus-4-20250514",
///     maxTokens: 1024,
///     messages: messages,
///     tools: [weatherTool, calculatorTool],
///     toolChoice: .auto
/// )
///
/// // With stop sequences
/// let request = MessageRequest(
///     model: "claude-opus-4-20250514",
///     maxTokens: 500,
///     messages: messages,
///     stopSequences: ["\n\n", "END"]
/// )
/// ```
///
/// ## Model Selection
///
/// Available models:
/// - `"claude-opus-4-20250514"`: Most capable model for complex tasks
/// - `"claude-3-5-sonnet-20241022"`: Balanced performance and speed
/// - `"claude-3-5-haiku-20241022"`: Fast, efficient for simple tasks
public struct MessageRequest: Codable, Equatable, Sendable {
    /// The model to use for the request.
    ///
    /// Choose based on your needs:
    /// - `"claude-opus-4-20250514"`: Best for complex reasoning, analysis, and creative tasks
    /// - `"claude-3-5-sonnet-20241022"`: Great balance of capability and speed
    /// - `"claude-3-5-haiku-20241022"`: Fastest option for simple tasks
    public let model: String
    
    /// The maximum number of tokens to generate.
    ///
    /// This limits the length of Claude's response. One token is roughly 4 characters.
    /// - Typical range: 256-4096
    /// - Maximum varies by model (up to 8192 for some models)
    public let maxTokens: Int
    
    /// The messages in the conversation.
    ///
    /// Messages should be in chronological order, alternating between user and assistant roles.
    /// System messages, if used, typically come first.
    public let messages: [Message]
    
    /// The system prompt (optional).
    ///
    /// Sets the context, personality, or instructions for Claude's behavior throughout
    /// the conversation. This is more concise than adding a system message.
    ///
    /// Example: `"You are a helpful coding assistant. Be concise and provide code examples."`
    public let system: String?
    
    /// Metadata about the request (optional).
    ///
    /// Attach metadata like user IDs for tracking and filtering in logs.
    public let metadata: MessageMetadata?
    
    /// Stop sequences (optional).
    ///
    /// Claude will stop generating when it encounters any of these strings.
    /// Useful for structured outputs or limiting responses.
    ///
    /// Example: `["\n\nHuman:", "\n\nAssistant:", "</output>"]`
    public let stopSequences: [String]?
    
    /// Temperature for sampling (optional).
    ///
    /// Controls randomness in responses:
    /// - `0.0`: Most deterministic, best for analysis/coding
    /// - `0.5`: Balanced creativity and consistency
    /// - `1.0`: Most creative, good for brainstorming
    /// - Default: `1.0`
    public let temperature: Double?
    
    /// Top-p nucleus sampling (optional).
    ///
    /// Alternative to temperature. Considers only tokens whose cumulative
    /// probability is below this threshold.
    /// - Range: `0.0` to `1.0`
    /// - Lower values = more focused responses
    public let topP: Double?
    
    /// Top-k sampling (optional).
    ///
    /// Limits token selection to the k most likely options.
    /// - Lower values = more predictable responses
    /// - Typical range: 10-100
    public let topK: Int?
    
    /// Whether to stream the response (optional).
    ///
    /// Set by the API client automatically:
    /// - `true` for `streamMessage()`
    /// - `false` for `createMessage()`
    public let stream: Bool?
    
    /// Tool definitions (optional).
    ///
    /// Define functions Claude can call. Claude will decide when and how
    /// to use these tools based on the conversation context.
    public let tools: [Tool]?
    
    /// Tool choice configuration (optional).
    ///
    /// Controls how Claude uses tools:
    /// - `.auto`: Claude decides when to use tools
    /// - `.specific(name)`: Force use of a specific tool
    /// - `.none`: Disable tool use
    public let toolChoice: ToolChoice?
    
    private enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case metadata
        case stopSequences = "stop_sequences"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case tools
        case toolChoice = "tool_choice"
    }
    
    /// Creates a new message request with comprehensive configuration options.
    ///
    /// - Parameters:
    ///   - model: The Claude model to use (e.g., "claude-opus-4-20250514")
    ///   - maxTokens: Maximum tokens in response (typically 256-4096)
    ///   - messages: Conversation history in chronological order
    ///   - system: Optional system prompt for setting context
    ///   - metadata: Optional metadata for request tracking
    ///   - stopSequences: Optional strings that stop generation
    ///   - temperature: Optional randomness control (0.0-2.0, default 1.0)
    ///   - topP: Optional nucleus sampling threshold
    ///   - topK: Optional top-k sampling limit
    ///   - stream: Whether to stream response (set automatically by client)
    ///   - tools: Optional tool definitions for function calling
    ///   - toolChoice: Optional tool selection strategy
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Basic conversation
    /// let request = MessageRequest(
    ///     model: "claude-opus-4-20250514",
    ///     maxTokens: 1024,
    ///     messages: [
    ///         Message.text("What is Swift?", role: .user)
    ///     ]
    /// )
    ///
    /// // With system context and parameters
    /// let request = MessageRequest(
    ///     model: "claude-opus-4-20250514",
    ///     maxTokens: 2048,
    ///     messages: messages,
    ///     system: "You are an expert Swift developer.",
    ///     temperature: 0.3,  // More focused responses
    ///     topK: 50          // Limit token choices
    /// )
    ///
    /// // With tools
    /// let request = MessageRequest(
    ///     model: "claude-opus-4-20250514",
    ///     maxTokens: 1024,
    ///     messages: messages,
    ///     tools: [searchTool, calculatorTool],
    ///     toolChoice: .auto  // Let Claude decide when to use tools
    /// )
    /// ```
    public init(
        model: String,
        maxTokens: Int,
        messages: [Message],
        system: String? = nil,
        metadata: MessageMetadata? = nil,
        stopSequences: [String]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stream: Bool? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.system = system
        self.metadata = metadata
        self.stopSequences = stopSequences
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stream = stream
        self.tools = tools
        self.toolChoice = toolChoice
    }
}

/// Metadata to attach to a message request for tracking and filtering.
///
/// Use metadata to associate requests with users, sessions, or other
/// identifiers that help with debugging, analytics, and compliance.
///
/// ## Example
///
/// ```swift
/// let metadata = MessageMetadata(userId: "user_123")
///
/// let request = MessageRequest(
///     model: "claude-opus-4-20250514",
///     maxTokens: 1024,
///     messages: messages,
///     metadata: metadata
/// )
/// ```
public struct MessageMetadata: Codable, Equatable, Sendable {
    /// User ID associated with the request.
    ///
    /// Useful for:
    /// - Tracking usage per user
    /// - Filtering logs and analytics
    /// - Compliance and audit trails
    public let userId: String?
    
    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
    
    /// Creates new message metadata.
    public init(userId: String? = nil) {
        self.userId = userId
    }
}

/// A tool that can be used by the assistant.
public struct Tool: Codable, Equatable, Sendable {
    /// The name of the tool.
    public let name: String
    
    /// Description of what the tool does.
    public let description: String?
    
    /// JSON Schema describing the tool's input.
    public let inputSchema: JSONSchema
    
    private enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
    
    /// Creates a new tool.
    public init(name: String, description: String? = nil, inputSchema: JSONSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema definition.
public struct JSONSchema: Codable, Equatable, Sendable {
    /// The type of the schema.
    public let type: String
    
    /// Properties for object schemas.
    public let properties: [String: JSONSchemaProperty]?
    
    /// Required properties for object schemas.
    public let required: [String]?
    
    /// Creates a new JSON schema.
    public init(type: String, properties: [String: JSONSchemaProperty]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// A property in a JSON schema.
public struct JSONSchemaProperty: Codable, Equatable, Sendable {
    /// The type of the property.
    public let type: String
    
    /// Description of the property.
    public let description: String?
    
    /// Enum values for the property.
    public let `enum`: [String]?
    
    /// Creates a new JSON schema property.
    public init(type: String, description: String? = nil, enum: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
    }
}

/// Tool choice configuration.
public enum ToolChoice: Codable, Equatable, Sendable {
    case auto
    case any
    case tool(name: String)
    
    private enum CodingKeys: String, CodingKey {
        case type, name
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .any:
            try container.encode("any", forKey: .type)
        case .tool(let name):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "auto":
            self = .auto
        case "any":
            self = .any
        case "tool":
            let name = try container.decode(String.self, forKey: .name)
            self = .tool(name: name)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown tool choice type: \(type)"
                )
            )
        }
    }
}