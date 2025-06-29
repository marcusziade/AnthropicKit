import Foundation

/// A response from the messages API.
public struct MessageResponse: Codable, Equatable, Sendable {
    /// Unique identifier for the message.
    public let id: String
    
    /// The type of object (always "message").
    public let type: String
    
    /// The role of the response (always "assistant").
    public let role: String
    
    /// The model used for the response.
    public let model: String
    
    /// The content blocks in the response.
    public let content: [ContentBlock]
    
    /// The reason the model stopped generating.
    public let stopReason: StopReason?
    
    /// The stop sequence that caused generation to stop.
    public let stopSequence: String?
    
    /// Token usage information.
    public let usage: Usage
    
    private enum CodingKeys: String, CodingKey {
        case id, type, role, model, content
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

/// Reason why the model stopped generating.
public enum StopReason: String, Codable, Equatable, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
}

/// Token usage information.
public struct Usage: Codable, Equatable, Sendable {
    /// Number of input tokens.
    public let inputTokens: Int
    
    /// Number of output tokens.
    public let outputTokens: Int
    
    /// Number of cache creation input tokens (optional).
    public let cacheCreationInputTokens: Int?
    
    /// Number of cache read input tokens (optional).
    public let cacheReadInputTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

/// A streaming event from the messages API.
public enum StreamEvent: Equatable, Sendable {
    case messageStart(MessageStartEvent)
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop(ContentBlockStopEvent)
    case messageDelta(MessageDeltaEvent)
    case messageStop(MessageStopEvent)
    case ping
    case error(StreamError)
}

/// Message start event.
public struct MessageStartEvent: Codable, Equatable, Sendable {
    public let type: String
    public let message: MessageResponse
}

/// Content block start event.
public struct ContentBlockStartEvent: Codable, Equatable, Sendable {
    public let type: String
    public let index: Int
    public let contentBlock: ContentBlock
    
    private enum CodingKeys: String, CodingKey {
        case type, index
        case contentBlock = "content_block"
    }
}

/// Content block delta event.
public struct ContentBlockDeltaEvent: Codable, Equatable, Sendable {
    public let type: String
    public let index: Int
    public let delta: Delta
    
    public struct Delta: Codable, Equatable, Sendable {
        public let type: String
        public let text: String?
        public let partialJson: String?
        
        private enum CodingKeys: String, CodingKey {
            case type, text
            case partialJson = "partial_json"
        }
    }
}

/// Content block stop event.
public struct ContentBlockStopEvent: Codable, Equatable, Sendable {
    public let type: String
    public let index: Int
}

/// Message delta event.
public struct MessageDeltaEvent: Codable, Equatable, Sendable {
    public let type: String
    public let delta: Delta
    public let usage: StreamingUsage?
    
    public struct Delta: Codable, Equatable, Sendable {
        public let stopReason: StopReason?
        public let stopSequence: String?
        
        private enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
        }
    }
}

/// Usage information for streaming events.
public struct StreamingUsage: Codable, Equatable, Sendable {
    /// Number of output tokens (streaming only provides output tokens).
    public let outputTokens: Int
    
    private enum CodingKeys: String, CodingKey {
        case outputTokens = "output_tokens"
    }
}

/// Message stop event.
public struct MessageStopEvent: Codable, Equatable, Sendable {
    public let type: String
}

/// Stream error event.
public struct StreamError: Codable, Equatable, Sendable {
    public let type: String
    public let error: APIError
}