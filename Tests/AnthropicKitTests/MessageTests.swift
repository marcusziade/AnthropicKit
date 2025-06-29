import XCTest
@testable import AnthropicKit

final class MessageTests: XCTestCase {
    
    func testMessageCreation() {
        let message = Message(role: .user, content: .text("Hello"))
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, .text("Hello"))
        XCTAssertNil(message.name)
    }
    
    func testMessageWithName() {
        let message = Message(role: .assistant, content: .text("Hi"), name: "Claude")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, .text("Hi"))
        XCTAssertEqual(message.name, "Claude")
    }
    
    func testTextMessageHelper() {
        let message = Message.text("Test message", role: .system)
        XCTAssertEqual(message.role, .system)
        XCTAssertEqual(message.content, .text("Test message"))
    }
    
    func testContentEncoding() throws {
        let encoder = JSONEncoder()
        
        // Test text content
        let textContent = Content.text("Hello")
        let textData = try encoder.encode(textContent)
        let textString = String(data: textData, encoding: .utf8)
        XCTAssertEqual(textString, "\"Hello\"")
        
        // Test blocks content
        let blocks = [
            ContentBlock(type: .text, text: "Hello", source: nil, id: nil, name: nil, input: nil, toolUseId: nil, content: nil, isError: nil)
        ]
        let blocksContent = Content.blocks(blocks)
        let blocksData = try encoder.encode(blocksContent)
        XCTAssertNotNil(blocksData)
    }
    
    func testContentDecoding() throws {
        let decoder = JSONDecoder()
        
        // Test text content
        let textJson = "\"Hello World\""
        let textContent = try decoder.decode(Content.self, from: textJson.data(using: .utf8)!)
        XCTAssertEqual(textContent, .text("Hello World"))
        
        // Test blocks content
        let blocksJson = """
        [{
            "type": "text",
            "text": "Hello"
        }]
        """
        let blocksContent = try decoder.decode(Content.self, from: blocksJson.data(using: .utf8)!)
        if case .blocks(let blocks) = blocksContent {
            XCTAssertEqual(blocks.count, 1)
            XCTAssertEqual(blocks[0].type, .text)
            XCTAssertEqual(blocks[0].text, "Hello")
        } else {
            XCTFail("Expected blocks content")
        }
    }
    
    func testImageSourceCreation() {
        let imageSource = ImageSource(mediaType: "image/jpeg", data: "base64data")
        XCTAssertEqual(imageSource.type, "base64")
        XCTAssertEqual(imageSource.mediaType, "image/jpeg")
        XCTAssertEqual(imageSource.data, "base64data")
    }
    
    func testContentBlockTypes() {
        XCTAssertEqual(ContentBlockType.text.rawValue, "text")
        XCTAssertEqual(ContentBlockType.image.rawValue, "image")
        XCTAssertEqual(ContentBlockType.toolUse.rawValue, "tool_use")
        XCTAssertEqual(ContentBlockType.toolResult.rawValue, "tool_result")
    }
    
    func testRoleValues() {
        XCTAssertEqual(Role.user.rawValue, "user")
        XCTAssertEqual(Role.assistant.rawValue, "assistant")
        XCTAssertEqual(Role.system.rawValue, "system")
    }
}