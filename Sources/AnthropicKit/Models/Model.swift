import Foundation

/// A model available in the API.
public struct Model: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the model.
    public let id: String
    
    /// The type of object (always "model").
    public let type: String
    
    /// Display name for the model.
    public let displayName: String
    
    /// When the model was created.
    public let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, type
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

/// Response from listing models.
public struct ListModelsResponse: Codable, Equatable, Sendable {
    /// The list of models.
    public let data: [Model]
    
    /// Whether there are more items.
    public let hasMore: Bool
    
    /// ID of the first item in the list.
    public let firstId: String?
    
    /// ID of the last item in the list.
    public let lastId: String?
    
    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
}

/// Token count request.
public struct TokenCountRequest: Codable, Equatable, Sendable {
    /// The model to use for counting.
    public let model: String
    
    /// The messages to count tokens for.
    public let messages: [Message]
    
    /// The system prompt (optional).
    public let system: String?
    
    /// Tool definitions (optional).
    public let tools: [Tool]?
    
    /// Creates a new token count request.
    public init(
        model: String,
        messages: [Message],
        system: String? = nil,
        tools: [Tool]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.system = system
        self.tools = tools
    }
}

/// Token count response.
public struct TokenCountResponse: Codable, Equatable, Sendable {
    /// The number of input tokens.
    public let inputTokens: Int
    
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
    }
}