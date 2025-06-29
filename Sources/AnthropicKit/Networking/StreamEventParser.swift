import Foundation

/// Parser for Server-Sent Events (SSE) stream.
public struct StreamEventParser {
    
    /// Parses SSE data into stream events.
    /// - Parameter data: The raw SSE data.
    /// - Returns: An array of parsed stream events.
    public static func parse(_ data: Data) throws -> [StreamEvent] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw AnthropicError.streamParsingError("Invalid UTF-8 data")
        }
        
        var events: [StreamEvent] = []
        var currentEvent: String?
        var currentData: String?
        
        for line in string.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                // End of event
                if let event = currentEvent, let data = currentData {
                    if let parsed = try parseEvent(type: event, data: data) {
                        events.append(parsed)
                    }
                }
                currentEvent = nil
                currentData = nil
                continue
            }
            
            if trimmedLine.hasPrefix("event:") {
                currentEvent = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmedLine.hasPrefix("data:") {
                let dataLine = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if currentData == nil {
                    currentData = dataLine
                } else {
                    currentData! += "\n" + dataLine
                }
            }
        }
        
        // Handle any remaining event
        if let event = currentEvent, let data = currentData {
            if let parsed = try parseEvent(type: event, data: data) {
                events.append(parsed)
            }
        }
        
        return events
    }
    
    private static func parseEvent(type: String, data: String) throws -> StreamEvent? {
        guard !data.isEmpty, data != "[DONE]" else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        switch type {
        case "message_start":
            let event = try decoder.decode(MessageStartEvent.self, from: Data(data.utf8))
            return .messageStart(event)
            
        case "content_block_start":
            let event = try decoder.decode(ContentBlockStartEvent.self, from: Data(data.utf8))
            return .contentBlockStart(event)
            
        case "content_block_delta":
            let event = try decoder.decode(ContentBlockDeltaEvent.self, from: Data(data.utf8))
            return .contentBlockDelta(event)
            
        case "content_block_stop":
            let event = try decoder.decode(ContentBlockStopEvent.self, from: Data(data.utf8))
            return .contentBlockStop(event)
            
        case "message_delta":
            let event = try decoder.decode(MessageDeltaEvent.self, from: Data(data.utf8))
            return .messageDelta(event)
            
        case "message_stop":
            let event = try decoder.decode(MessageStopEvent.self, from: Data(data.utf8))
            return .messageStop(event)
            
        case "ping":
            return .ping
            
        case "error":
            let error = try decoder.decode(StreamError.self, from: Data(data.utf8))
            return .error(error)
            
        default:
            // Unknown event type, ignore
            return nil
        }
    }
}

/// Helper to accumulate streaming message content.
public actor StreamingMessageAccumulator {
    
    /// Creates a new streaming message accumulator.
    public init() {}
    private var message: MessageResponse?
    private var contentBlocks: [ContentBlock] = []
    private var currentBlockTexts: [Int: String] = [:]
    
    /// Processes a stream event and returns the accumulated message if complete.
    /// - Parameter event: The stream event to process.
    /// - Returns: The complete message if the stream has ended, nil otherwise.
    public func process(_ event: StreamEvent) -> MessageResponse? {
        switch event {
        case .messageStart(let start):
            self.message = start.message
            self.contentBlocks = start.message.content
            
        case .contentBlockStart(let start):
            while contentBlocks.count <= start.index {
                contentBlocks.append(ContentBlock(
                    type: .text,
                    text: "",
                    source: nil,
                    id: nil,
                    name: nil,
                    input: nil,
                    toolUseId: nil,
                    content: nil,
                    isError: nil
                ))
            }
            contentBlocks[start.index] = start.contentBlock
            
        case .contentBlockDelta(let delta):
            if let text = delta.delta.text {
                currentBlockTexts[delta.index, default: ""] += text
                if delta.index < contentBlocks.count {
                    let block = contentBlocks[delta.index]
                    let newText = currentBlockTexts[delta.index] ?? ""
                    contentBlocks[delta.index] = ContentBlock(
                        type: block.type,
                        text: newText,
                        source: block.source,
                        id: block.id,
                        name: block.name,
                        input: block.input,
                        toolUseId: block.toolUseId,
                        content: block.content,
                        isError: block.isError
                    )
                }
            }
            
        case .messageDelta(let delta):
            if let msg = message {
                if let stopReason = delta.delta.stopReason {
                    message = MessageResponse(
                        id: msg.id,
                        type: msg.type,
                        role: msg.role,
                        model: msg.model,
                        content: contentBlocks,
                        stopReason: stopReason,
                        stopSequence: delta.delta.stopSequence,
                        usage: msg.usage
                    )
                } else if let streamingUsage = delta.usage {
                    // Update output tokens from streaming usage
                    let updatedUsage = Usage(
                        inputTokens: msg.usage.inputTokens,
                        outputTokens: streamingUsage.outputTokens,
                        cacheCreationInputTokens: msg.usage.cacheCreationInputTokens,
                        cacheReadInputTokens: msg.usage.cacheReadInputTokens
                    )
                    message = MessageResponse(
                        id: msg.id,
                        type: msg.type,
                        role: msg.role,
                        model: msg.model,
                        content: contentBlocks,
                        stopReason: msg.stopReason,
                        stopSequence: msg.stopSequence,
                        usage: updatedUsage
                    )
                }
            }
            
        case .messageStop:
            if let msg = message {
                return MessageResponse(
                    id: msg.id,
                    type: msg.type,
                    role: msg.role,
                    model: msg.model,
                    content: contentBlocks,
                    stopReason: msg.stopReason,
                    stopSequence: msg.stopSequence,
                    usage: msg.usage
                )
            }
            
        default:
            break
        }
        
        return nil
    }
}