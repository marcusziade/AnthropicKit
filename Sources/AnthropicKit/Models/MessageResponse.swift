import Foundation

/// A response from Claude containing the generated message and metadata.
///
/// `MessageResponse` contains Claude's response along with useful metadata
/// like token usage, stop reason, and the model used.
///
/// ## Accessing Content
///
/// ```swift
/// let response = try await client.createMessage(request)
///
/// // Get text content
/// if let text = response.content.first?.text {
///     print(text)
/// }
///
/// // Check for tool use
/// for block in response.content {
///     if case .toolUse(let toolUse) = block {
///         print("Claude wants to use tool: \(toolUse.name)")
///     }
/// }
/// ```
///
/// ## Understanding Stop Reasons
///
/// ```swift
/// switch response.stopReason {
/// case .endTurn:
///     // Claude finished naturally
/// case .maxTokens:
///     // Hit token limit - response may be truncated
/// case .stopSequence:
///     // Hit a stop sequence
/// case .toolUse:
///     // Claude wants to use a tool
/// case nil:
///     // Still generating (in streaming context)
/// }
/// ```
///
/// ## Monitoring Usage
///
/// ```swift
/// print("Input tokens: \(response.usage.inputTokens)")
/// print("Output tokens: \(response.usage.outputTokens)")
/// print("Total tokens: \(response.usage.inputTokens + response.usage.outputTokens)")
/// ```
public struct MessageResponse: Codable, Equatable, Sendable {
    /// Unique identifier for the message.
    ///
    /// Use this for logging, debugging, or referencing specific responses.
    public let id: String
    
    /// The type of object (always "message").
    public let type: String
    
    /// The role of the response (always "assistant").
    public let role: String
    
    /// The model used for the response.
    ///
    /// This may differ from the requested model if the API used a fallback.
    public let model: String
    
    /// The content blocks in the response.
    ///
    /// Content can include:
    /// - Text responses
    /// - Tool use requests
    /// - Mixed content types
    ///
    /// Example:
    /// ```swift
    /// for block in response.content {
    ///     switch block.type {
    ///     case .text:
    ///         print(block.text ?? "")
    ///     case .toolUse:
    ///         handleToolUse(block)
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public let content: [ContentBlock]
    
    /// The reason the model stopped generating.
    ///
    /// Important for understanding if the response is complete:
    /// - `.endTurn`: Normal completion
    /// - `.maxTokens`: May be truncated
    /// - `.stopSequence`: Hit a defined stop sequence
    /// - `.toolUse`: Claude needs to use a tool
    public let stopReason: StopReason?
    
    /// The stop sequence that caused generation to stop.
    ///
    /// Only present when `stopReason` is `.stopSequence`.
    public let stopSequence: String?
    
    /// Token usage information.
    ///
    /// Use this to:
    /// - Monitor costs
    /// - Track token consumption
    /// - Optimize prompt length
    public let usage: Usage
    
    private enum CodingKeys: String, CodingKey {
        case id, type, role, model, content
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

/// Reason why the model stopped generating.
///
/// Understanding stop reasons helps you handle responses appropriately and
/// determine if additional action is needed.
///
/// ## Example
///
/// ```swift
/// switch response.stopReason {
/// case .endTurn:
///     // Normal completion - Claude finished its thought
///     print("Response complete")
///     
/// case .maxTokens:
///     // Hit token limit - response might be cut off
///     print("Warning: Response may be truncated")
///     // Consider continuing with a follow-up request
///     
/// case .stopSequence:
///     // Hit a stop sequence you defined
///     print("Stopped at: \(response.stopSequence ?? "")")
///     
/// case .toolUse:
///     // Claude wants to use a tool
///     print("Processing tool request...")
///     
/// case nil:
///     // Should not happen in completed responses
///     print("Unexpected: No stop reason")
/// }
/// ```
public enum StopReason: String, Codable, Equatable, Sendable {
    /// Claude completed its response naturally
    case endTurn = "end_turn"
    
    /// Response hit the maximum token limit and may be truncated
    case maxTokens = "max_tokens"
    
    /// Response stopped due to encountering a stop sequence
    case stopSequence = "stop_sequence"
    
    /// Claude is requesting to use a tool
    case toolUse = "tool_use"
}

/// Token usage information for a request.
///
/// Tokens are the fundamental units of text that Claude processes.
/// Understanding token usage helps you:
/// - Monitor and control costs
/// - Optimize prompt efficiency
/// - Stay within model limits
///
/// ## Calculating Costs
///
/// ```swift
/// let usage = response.usage
/// let totalTokens = usage.inputTokens + usage.outputTokens
///
/// // Approximate cost calculation (prices vary by model)
/// let inputCost = Double(usage.inputTokens) / 1_000_000 * 15.00  // $15/M tokens
/// let outputCost = Double(usage.outputTokens) / 1_000_000 * 75.00 // $75/M tokens
/// let totalCost = inputCost + outputCost
///
/// print("Estimated cost: $\(String(format: "%.4f", totalCost))")
/// ```
///
/// ## Token Optimization
///
/// ```swift
/// // Monitor token efficiency
/// let efficiency = Double(response.content.first?.text?.count ?? 0) / Double(usage.outputTokens)
/// print("Characters per token: \(efficiency)")
/// ```
public struct Usage: Codable, Equatable, Sendable {
    /// Number of input tokens.
    ///
    /// Includes all messages, system prompt, and tool definitions.
    public let inputTokens: Int
    
    /// Number of output tokens.
    ///
    /// The tokens in Claude's response.
    public let outputTokens: Int
    
    /// Number of cache creation input tokens (optional).
    ///
    /// Tokens used to create cached content (beta feature).
    public let cacheCreationInputTokens: Int?
    
    /// Number of cache read input tokens (optional).
    ///
    /// Tokens read from cache, which are cheaper than regular input tokens.
    public let cacheReadInputTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

/// A streaming event from the messages API.
///
/// When streaming responses, Claude sends a series of events that allow you
/// to process the response incrementally as it's generated.
///
/// ## Event Flow
///
/// A typical stream follows this sequence:
/// 1. `messageStart` - Initial message metadata
/// 2. `contentBlockStart` - Beginning of content
/// 3. `contentBlockDelta` - Incremental text updates (multiple)
/// 4. `contentBlockStop` - End of content block
/// 5. `messageStop` - Stream complete
///
/// ## Processing Events
///
/// ```swift
/// let stream = try await client.streamMessage(request)
///
/// for await event in stream {
///     switch event {
///     case .messageStart(let start):
///         print("Stream started: \(start.message.id)")
///         
///     case .contentBlockStart(let start):
///         print("Content block \(start.index) started")
///         
///     case .contentBlockDelta(let delta):
///         // Main content updates
///         print(delta.delta.text ?? "", terminator: "")
///         
///     case .contentBlockStop(let stop):
///         print("\nContent block \(stop.index) complete")
///         
///     case .messageStop:
///         print("\nStream complete")
///         
///     case .ping:
///         // Keep-alive signal, no action needed
///         break
///         
///     case .error(let error):
///         print("Stream error: \(error)")
///     
///     default:
///         break
///     }
/// }
/// ```
public enum StreamEvent: Equatable, Sendable {
    /// Stream started with initial message metadata
    case messageStart(MessageStartEvent)
    
    /// A new content block started
    case contentBlockStart(ContentBlockStartEvent)
    
    /// Incremental update to a content block
    case contentBlockDelta(ContentBlockDeltaEvent)
    
    /// A content block finished
    case contentBlockStop(ContentBlockStopEvent)
    
    /// Update to message-level information
    case messageDelta(MessageDeltaEvent)
    
    /// Stream completed successfully
    case messageStop(MessageStopEvent)
    
    /// Keep-alive ping (can be ignored)
    case ping
    
    /// An error occurred during streaming
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