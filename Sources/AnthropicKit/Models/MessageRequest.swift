import Foundation

/// A request to create a message.
public struct MessageRequest: Codable, Equatable, Sendable {
    /// The model to use for the request.
    public let model: String
    
    /// The maximum number of tokens to generate.
    public let maxTokens: Int
    
    /// The messages in the conversation.
    public let messages: [Message]
    
    /// The system prompt (optional).
    public let system: String?
    
    /// Metadata about the request (optional).
    public let metadata: MessageMetadata?
    
    /// Stop sequences (optional).
    public let stopSequences: [String]?
    
    /// Temperature for sampling (optional).
    public let temperature: Double?
    
    /// Top-p nucleus sampling (optional).
    public let topP: Double?
    
    /// Top-k sampling (optional).
    public let topK: Int?
    
    /// Whether to stream the response (optional).
    public let stream: Bool?
    
    /// Tool definitions (optional).
    public let tools: [Tool]?
    
    /// Tool choice configuration (optional).
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
    
    /// Creates a new message request.
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

/// Metadata about a message request.
public struct MessageMetadata: Codable, Equatable, Sendable {
    /// User ID associated with the request.
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