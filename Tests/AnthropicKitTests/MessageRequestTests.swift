import XCTest
@testable import AnthropicKit

final class MessageRequestTests: XCTestCase {
    
    func testBasicMessageRequest() {
        let messages = [Message.text("Hello", role: .user)]
        let request = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 100,
            messages: messages
        )
        
        XCTAssertEqual(request.model, "claude-opus-4-20250514")
        XCTAssertEqual(request.maxTokens, 100)
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertNil(request.system)
        XCTAssertNil(request.temperature)
    }
    
    func testFullMessageRequest() {
        let messages = [Message.text("Test", role: .user)]
        let metadata = MessageMetadata(userId: "user123")
        let tool = Tool(
            name: "calculator",
            description: "Performs calculations",
            inputSchema: JSONSchema(type: "object")
        )
        
        let request = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 200,
            messages: messages,
            system: "You are a helpful assistant",
            metadata: metadata,
            stopSequences: ["END"],
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stream: false,
            tools: [tool],
            toolChoice: .auto
        )
        
        XCTAssertEqual(request.system, "You are a helpful assistant")
        XCTAssertEqual(request.metadata?.userId, "user123")
        XCTAssertEqual(request.stopSequences, ["END"])
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertEqual(request.topP, 0.9)
        XCTAssertEqual(request.topK, 40)
        XCTAssertEqual(request.stream, false)
        XCTAssertEqual(request.tools?.count, 1)
        XCTAssertEqual(request.toolChoice, .auto)
    }
    
    func testToolCreation() {
        let properties = [
            "x": JSONSchemaProperty(type: "number", description: "First number"),
            "y": JSONSchemaProperty(type: "number", description: "Second number")
        ]
        let schema = JSONSchema(type: "object", properties: properties, required: ["x", "y"])
        let tool = Tool(name: "add", description: "Adds two numbers", inputSchema: schema)
        
        XCTAssertEqual(tool.name, "add")
        XCTAssertEqual(tool.description, "Adds two numbers")
        XCTAssertEqual(tool.inputSchema.type, "object")
        XCTAssertEqual(tool.inputSchema.properties?.count, 2)
        XCTAssertEqual(tool.inputSchema.required, ["x", "y"])
    }
    
    func testToolChoiceEncoding() throws {
        let encoder = JSONEncoder()
        
        // Test auto
        let autoData = try encoder.encode(ToolChoice.auto)
        let autoJson = String(data: autoData, encoding: .utf8)
        XCTAssertTrue(autoJson?.contains("\"type\":\"auto\"") ?? false)
        
        // Test any
        let anyData = try encoder.encode(ToolChoice.any)
        let anyJson = String(data: anyData, encoding: .utf8)
        XCTAssertTrue(anyJson?.contains("\"type\":\"any\"") ?? false)
        
        // Test specific tool
        let toolData = try encoder.encode(ToolChoice.tool(name: "calculator"))
        let toolJson = String(data: toolData, encoding: .utf8)
        XCTAssertTrue(toolJson?.contains("\"type\":\"tool\"") ?? false)
        XCTAssertTrue(toolJson?.contains("\"name\":\"calculator\"") ?? false)
    }
    
    func testToolChoiceDecoding() throws {
        let decoder = JSONDecoder()
        
        // Test auto
        let autoJson = "{\"type\":\"auto\"}"
        let auto = try decoder.decode(ToolChoice.self, from: autoJson.data(using: .utf8)!)
        XCTAssertEqual(auto, .auto)
        
        // Test any
        let anyJson = "{\"type\":\"any\"}"
        let any = try decoder.decode(ToolChoice.self, from: anyJson.data(using: .utf8)!)
        XCTAssertEqual(any, .any)
        
        // Test specific tool
        let toolJson = "{\"type\":\"tool\",\"name\":\"calculator\"}"
        let tool = try decoder.decode(ToolChoice.self, from: toolJson.data(using: .utf8)!)
        if case .tool(let name) = tool {
            XCTAssertEqual(name, "calculator")
        } else {
            XCTFail("Expected tool choice with name")
        }
    }
    
    func testMessageRequestEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let request = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 100,
            messages: [Message.text("Hello", role: .user)],
            temperature: 0.5
        )
        
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"model\":\"claude-opus-4-20250514\""))
        XCTAssertTrue(json.contains("\"max_tokens\":100"))
        XCTAssertTrue(json.contains("\"temperature\":0.5"))
        XCTAssertTrue(json.contains("\"messages\""))
    }
}