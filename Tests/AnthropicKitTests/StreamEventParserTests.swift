import XCTest
@testable import AnthropicKit

final class StreamEventParserTests: XCTestCase {
    
    func testParseMessageStartEvent() throws {
        let sseData = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_123","type":"message","role":"assistant","model":"claude-opus-4-20250514","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}
        
        """
        
        let events = try StreamEventParser.parse(sseData.data(using: .utf8)!)
        XCTAssertEqual(events.count, 1)
        
        if case .messageStart(let event) = events[0] {
            XCTAssertEqual(event.message.id, "msg_123")
            XCTAssertEqual(event.message.role, "assistant")
            XCTAssertEqual(event.message.model, "claude-opus-4-20250514")
        } else {
            XCTFail("Expected message_start event")
        }
    }
    
    func testParseContentBlockDelta() throws {
        let sseData = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" World"}}
        
        """
        
        let events = try StreamEventParser.parse(sseData.data(using: .utf8)!)
        XCTAssertEqual(events.count, 1)
        
        if case .contentBlockDelta(let event) = events[0] {
            XCTAssertEqual(event.index, 0)
            XCTAssertEqual(event.delta.type, "text_delta")
            XCTAssertEqual(event.delta.text, " World")
        } else {
            XCTFail("Expected content_block_delta event")
        }
    }
    
    func testParsePingEvent() throws {
        let sseData = """
        event: ping
        data: {}
        
        """
        
        let events = try StreamEventParser.parse(sseData.data(using: .utf8)!)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0], .ping)
    }
    
    func testParseMultipleEvents() throws {
        let sseData = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_123","type":"message","role":"assistant","model":"claude-opus-4-20250514","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}
        
        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
        
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
        
        """
        
        let events = try StreamEventParser.parse(sseData.data(using: .utf8)!)
        XCTAssertEqual(events.count, 3)
        
        XCTAssertTrue(events[0].isMessageStart)
        XCTAssertTrue(events[1].isContentBlockStart)
        XCTAssertTrue(events[2].isContentBlockDelta)
    }
    
    func testParseDoneMessage() throws {
        let sseData = """
        event: done
        data: [DONE]
        
        """
        
        let events = try StreamEventParser.parse(sseData.data(using: .utf8)!)
        XCTAssertEqual(events.count, 0) // [DONE] should be filtered out
    }
    
    func testParseEmptyData() throws {
        let sseData = """
        event: message_stop
        data: {"type":"message_stop"}
        
        """
        
        let events = try StreamEventParser.parse(sseData.data(using: .utf8)!)
        XCTAssertEqual(events.count, 1)
        
        if case .messageStop = events[0] {
            // Success
        } else {
            XCTFail("Expected message_stop event")
        }
    }
}

// Helper extension for testing
extension StreamEvent {
    var isMessageStart: Bool {
        if case .messageStart = self { return true }
        return false
    }
    
    var isContentBlockStart: Bool {
        if case .contentBlockStart = self { return true }
        return false
    }
    
    var isContentBlockDelta: Bool {
        if case .contentBlockDelta = self { return true }
        return false
    }
}