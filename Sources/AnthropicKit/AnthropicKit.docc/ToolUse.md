# Using Tools and Function Calling

Extend Claude's capabilities by integrating external tools and functions into your Swift applications.

## Overview

Tool use (also known as function calling) allows Claude to interact with external systems, APIs, and functions. This enables Claude to perform actions beyond text generation, such as calculations, data retrieval, or system operations.

## How Tool Use Works

1. Define available tools with schemas
2. Claude analyzes the conversation and decides when to use tools
3. Claude generates tool calls with appropriate parameters
4. Your application executes the tools and returns results
5. Claude incorporates results into its response

## Defining Tools

### Tool Structure

```swift
struct Tool: Codable {
    let name: String
    let description: String
    let inputSchema: JSONSchema
}

struct JSONSchema: Codable {
    let type: String = "object"
    let properties: [String: Property]
    let required: [String]
    
    struct Property: Codable {
        let type: String
        let description: String
        let enumValues: [String]?
        let items: Items?
        
        enum CodingKeys: String, CodingKey {
            case type, description
            case enumValues = "enum"
            case items
        }
    }
    
    struct Items: Codable {
        let type: String
    }
}
```

### Basic Tool Definition

```swift
// Weather lookup tool
let weatherTool = Tool(
    name: "get_weather",
    description: "Get the current weather for a given location",
    inputSchema: JSONSchema(
        properties: [
            "location": JSONSchema.Property(
                type: "string",
                description: "The city and country, e.g., 'London, UK'",
                enumValues: nil,
                items: nil
            ),
            "unit": JSONSchema.Property(
                type: "string",
                description: "Temperature unit",
                enumValues: ["celsius", "fahrenheit"],
                items: nil
            )
        ],
        required: ["location"]
    )
)

// Calculator tool
let calculatorTool = Tool(
    name: "calculate",
    description: "Perform mathematical calculations",
    inputSchema: JSONSchema(
        properties: [
            "expression": JSONSchema.Property(
                type: "string",
                description: "Mathematical expression to evaluate",
                enumValues: nil,
                items: nil
            )
        ],
        required: ["expression"]
    )
)
```

## Making Requests with Tools

### Basic Tool Use

```swift
let request = MessageRequest(
    model: "claude-opus-4-20250514",
    maxTokens: 1024,
    messages: [
        Message.text("What's the weather like in Tokyo?", role: .user)
    ],
    tools: [weatherTool]
)

let response = try await client.createMessage(request)

// Check if Claude wants to use a tool
for content in response.content {
    if case .toolUse(let toolUse) = content {
        print("Claude wants to use tool: \(toolUse.name)")
        print("With input: \(toolUse.input)")
        
        // Execute the tool and get result
        let result = try await executeWeatherTool(toolUse.input)
        
        // Send result back to Claude
        let followUp = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 1024,
            messages: [
                Message.text("What's the weather like in Tokyo?", role: .user),
                response.asMessage!,
                Message(
                    role: .user,
                    content: [.toolResult(ToolResultContent(
                        toolUseId: toolUse.id,
                        content: result
                    ))]
                )
            ]
        )
        
        let finalResponse = try await client.createMessage(followUp)
        print(finalResponse.content.first?.text ?? "")
    }
}
```

## Complete Tool Use Example

### Weather Assistant

```swift
class WeatherAssistant {
    private let client: AnthropicAPIProtocol
    private let weatherAPI: WeatherAPIProtocol
    
    init(client: AnthropicAPIProtocol, weatherAPI: WeatherAPIProtocol) {
        self.client = client
        self.weatherAPI = weatherAPI
    }
    
    private var tools: [Tool] {
        [
            Tool(
                name: "get_current_weather",
                description: "Get current weather for a location",
                inputSchema: JSONSchema(
                    properties: [
                        "location": JSONSchema.Property(
                            type: "string",
                            description: "City name or coordinates",
                            enumValues: nil,
                            items: nil
                        ),
                        "units": JSONSchema.Property(
                            type: "string",
                            description: "Temperature units",
                            enumValues: ["celsius", "fahrenheit", "kelvin"],
                            items: nil
                        )
                    ],
                    required: ["location"]
                )
            ),
            Tool(
                name: "get_forecast",
                description: "Get weather forecast for the next 5 days",
                inputSchema: JSONSchema(
                    properties: [
                        "location": JSONSchema.Property(
                            type: "string",
                            description: "City name or coordinates",
                            enumValues: nil,
                            items: nil
                        ),
                        "days": JSONSchema.Property(
                            type: "integer",
                            description: "Number of days (1-5)",
                            enumValues: nil,
                            items: nil
                        )
                    ],
                    required: ["location"]
                )
            )
        ]
    }
    
    func chat(_ message: String) async throws -> String {
        var messages: [Message] = [Message.text(message, role: .user)]
        
        // Initial request with tools
        let request = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 1024,
            messages: messages,
            tools: tools
        )
        
        let response = try await client.createMessage(request)
        
        // Process tool calls if any
        var toolResults: [Content] = []
        
        for content in response.content {
            if case .toolUse(let toolUse) = content {
                let result = try await executeTool(
                    name: toolUse.name,
                    input: toolUse.input
                )
                
                toolResults.append(.toolResult(ToolResultContent(
                    toolUseId: toolUse.id,
                    content: result
                )))
            }
        }
        
        // If tools were used, send results back
        if !toolResults.isEmpty {
            messages.append(response.asMessage!)
            messages.append(Message(role: .user, content: toolResults))
            
            let finalRequest = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 1024,
                messages: messages
            )
            
            let finalResponse = try await client.createMessage(finalRequest)
            return finalResponse.content.compactMap { 
                if case .text(let text) = $0 { return text }
                return nil
            }.joined()
        }
        
        // Return initial response if no tools were used
        return response.content.compactMap { 
            if case .text(let text) = $0 { return text }
            return nil
        }.joined()
    }
    
    private func executeTool(name: String, input: String) async throws -> String {
        // Parse input JSON
        guard let inputData = input.data(using: .utf8),
              let params = try? JSONDecoder().decode([String: Any].self, from: inputData) else {
            throw ToolError.invalidInput
        }
        
        switch name {
        case "get_current_weather":
            let location = params["location"] as? String ?? ""
            let units = params["units"] as? String ?? "celsius"
            
            let weather = try await weatherAPI.getCurrentWeather(
                location: location,
                units: units
            )
            
            return """
            Current weather in \(location):
            Temperature: \(weather.temperature)°\(units == "celsius" ? "C" : "F")
            Conditions: \(weather.conditions)
            Humidity: \(weather.humidity)%
            Wind: \(weather.windSpeed) km/h
            """
            
        case "get_forecast":
            let location = params["location"] as? String ?? ""
            let days = params["days"] as? Int ?? 3
            
            let forecast = try await weatherAPI.getForecast(
                location: location,
                days: min(days, 5)
            )
            
            return forecast.map { day in
                "\(day.date): \(day.low)°-\(day.high)°, \(day.conditions)"
            }.joined(separator: "\n")
            
        default:
            throw ToolError.unknownTool(name)
        }
    }
}

// Usage
let assistant = WeatherAssistant(client: anthropicAPI, weatherAPI: weatherService)
let response = try await assistant.chat("What's the weather forecast for Paris this week?")
print(response)
// Claude will use the tools to fetch weather data and provide a natural language response
```

## Advanced Tool Patterns

### Multiple Tool Calls

Claude can call multiple tools in a single turn:

```swift
struct MultiToolHandler {
    func handleMultipleTools(_ response: MessageResponse) async throws -> [ToolResultContent] {
        var results: [ToolResultContent] = []
        
        // Process all tool calls concurrently
        await withTaskGroup(of: (String, Result<String, Error>).self) { group in
            for content in response.content {
                if case .toolUse(let toolUse) = content {
                    group.addTask {
                        do {
                            let result = try await self.executeTool(toolUse)
                            return (toolUse.id, .success(result))
                        } catch {
                            return (toolUse.id, .failure(error))
                        }
                    }
                }
            }
            
            for await (toolId, result) in group {
                switch result {
                case .success(let output):
                    results.append(ToolResultContent(
                        toolUseId: toolId,
                        content: output
                    ))
                case .failure(let error):
                    results.append(ToolResultContent(
                        toolUseId: toolId,
                        content: "Error: \(error.localizedDescription)"
                    ))
                }
            }
        }
        
        return results
    }
}
```

### Database Query Tool

```swift
let databaseTool = Tool(
    name: "query_database",
    description: "Query the application database",
    inputSchema: JSONSchema(
        properties: [
            "table": JSONSchema.Property(
                type: "string",
                description: "Table name to query",
                enumValues: ["users", "orders", "products"],
                items: nil
            ),
            "conditions": JSONSchema.Property(
                type: "array",
                description: "WHERE conditions",
                enumValues: nil,
                items: JSONSchema.Items(type: "object")
            ),
            "limit": JSONSchema.Property(
                type: "integer",
                description: "Maximum number of results",
                enumValues: nil,
                items: nil
            )
        ],
        required: ["table"]
    )
)

class DatabaseToolExecutor {
    func execute(_ input: String) async throws -> String {
        let params = try JSONDecoder().decode(DatabaseQuery.self, from: input.data(using: .utf8)!)
        
        // Build safe query
        var query = "SELECT * FROM \(params.table)"
        
        if let conditions = params.conditions, !conditions.isEmpty {
            let whereClause = conditions.map { "\($0.field) = '\($0.value)'" }.joined(separator: " AND ")
            query += " WHERE \(whereClause)"
        }
        
        if let limit = params.limit {
            query += " LIMIT \(limit)"
        }
        
        // Execute query (implementation depends on your database)
        let results = try await database.execute(query)
        
        // Format results as JSON
        return try JSONEncoder().encode(results).string
    }
}
```

### File System Tool

```swift
let fileSystemTool = Tool(
    name: "file_operations",
    description: "Perform file system operations",
    inputSchema: JSONSchema(
        properties: [
            "operation": JSONSchema.Property(
                type: "string",
                description: "Operation to perform",
                enumValues: ["read", "write", "list", "delete"],
                items: nil
            ),
            "path": JSONSchema.Property(
                type: "string",
                description: "File or directory path",
                enumValues: nil,
                items: nil
            ),
            "content": JSONSchema.Property(
                type: "string",
                description: "Content for write operations",
                enumValues: nil,
                items: nil
            )
        ],
        required: ["operation", "path"]
    )
)

class FileSystemToolExecutor {
    private let allowedDirectory: URL
    
    init(allowedDirectory: URL) {
        self.allowedDirectory = allowedDirectory
    }
    
    func execute(_ input: String) async throws -> String {
        let params = try JSONDecoder().decode(FileOperation.self, from: input.data(using: .utf8)!)
        
        // Validate path is within allowed directory
        let url = allowedDirectory.appendingPathComponent(params.path)
        guard url.path.hasPrefix(allowedDirectory.path) else {
            throw ToolError.securityViolation("Access denied")
        }
        
        switch params.operation {
        case "read":
            let content = try String(contentsOf: url)
            return content
            
        case "write":
            guard let content = params.content else {
                throw ToolError.missingParameter("content")
            }
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "File written successfully"
            
        case "list":
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return contents.map { $0.lastPathComponent }.joined(separator: "\n")
            
        case "delete":
            try FileManager.default.removeItem(at: url)
            return "File deleted successfully"
            
        default:
            throw ToolError.invalidOperation
        }
    }
}
```

## Streaming with Tools

```swift
func streamWithTools(_ message: String) async throws {
    let request = MessageRequest(
        model: "claude-opus-4-20250514",
        maxTokens: 1024,
        messages: [Message.text(message, role: .user)],
        tools: tools
    )
    
    let stream = try await client.streamMessage(request)
    var toolCalls: [ToolUse] = []
    var currentText = ""
    
    for await event in stream {
        switch event {
        case .delta(let delta):
            if let text = delta.text {
                currentText += text
                print(text, terminator: "")
            }
            
        case .contentBlockStart(let block):
            if case .toolUse(let toolUse) = block {
                print("\n🔧 Using tool: \(toolUse.name)")
            }
            
        case .stop:
            // Execute any collected tool calls
            if !toolCalls.isEmpty {
                await executeToolCalls(toolCalls)
            }
            
        default:
            break
        }
    }
}
```

## Tool Use Best Practices

### 1. Clear Tool Descriptions

```swift
// ❌ Vague description
Tool(
    name: "search",
    description: "Search for things",
    inputSchema: ...
)

// ✅ Clear, specific description
Tool(
    name: "search_products",
    description: "Search the product catalog by name, category, or SKU. Returns matching products with prices and availability.",
    inputSchema: ...
)
```

### 2. Validate Tool Inputs

```swift
func validateToolInput<T: Decodable>(_ input: String, type: T.Type) throws -> T {
    guard let data = input.data(using: .utf8) else {
        throw ToolError.invalidInput("Input is not valid UTF-8")
    }
    
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        throw ToolError.invalidInput("Failed to parse input: \(error)")
    }
}

// Usage
let params = try validateToolInput(toolUse.input, type: WeatherParams.self)
```

### 3. Handle Tool Errors Gracefully

```swift
func executeTool(_ toolUse: ToolUse) async -> ToolResultContent {
    do {
        let result = try await actuallyExecuteTool(toolUse)
        return ToolResultContent(
            toolUseId: toolUse.id,
            content: result
        )
    } catch {
        // Return error as tool result so Claude can handle it
        return ToolResultContent(
            toolUseId: toolUse.id,
            content: "Error executing \(toolUse.name): \(error.localizedDescription)"
        )
    }
}
```

### 4. Implement Tool Timeouts

```swift
func executeWithTimeout(_ toolUse: ToolUse, timeout: TimeInterval = 10) async throws -> String {
    let task = Task {
        try await executeTool(toolUse)
    }
    
    let timeoutTask = Task {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        task.cancel()
        throw ToolError.timeout
    }
    
    let result = await withTaskGroup(of: String?.self) { group in
        group.addTask { try? await task.value }
        group.addTask { try? await timeoutTask.value }
        
        if let first = await group.next() ?? nil {
            group.cancelAll()
            return first
        }
        
        throw ToolError.timeout
    }
    
    return result
}
```

## Testing Tool Use

```swift
class MockToolClient: AnthropicAPIProtocol {
    var mockToolCall: ToolUse?
    
    func createMessage(_ request: MessageRequest) async throws -> MessageResponse {
        if let toolCall = mockToolCall {
            return MessageResponse(
                id: "msg_mock",
                type: "message",
                role: .assistant,
                content: [.toolUse(toolCall)],
                model: request.model,
                stopReason: .toolUse,
                usage: Usage(inputTokens: 10, outputTokens: 20)
            )
        }
        
        return MessageResponse(
            id: "msg_mock",
            type: "message",
            role: .assistant,
            content: [.text("No tool needed")],
            model: request.model,
            stopReason: .endTurn,
            usage: Usage(inputTokens: 10, outputTokens: 20)
        )
    }
}

// Test tool execution
func testWeatherTool() async throws {
    let mockClient = MockToolClient()
    mockClient.mockToolCall = ToolUse(
        id: "tool_123",
        name: "get_weather",
        input: #"{"location": "Tokyo", "unit": "celsius"}"#
    )
    
    let assistant = WeatherAssistant(client: mockClient, weatherAPI: mockWeatherAPI)
    let response = try await assistant.chat("What's the weather?")
    
    XCTAssertTrue(response.contains("Tokyo"))
}
```

## Summary

Tool use enables Claude to interact with external systems and perform actions beyond text generation. By defining clear tool schemas, handling responses properly, and following best practices, you can build powerful AI assistants that seamlessly integrate with your application's functionality.

For more information, see:
- <doc:StreamingResponses> for streaming with tools
- <doc:ErrorHandling> for handling tool errors
- ``Tool`` and ``ToolUse`` for complete API reference