import Foundation
import AnthropicKit

@main
struct SmartAssistant {
    static func main() async throws {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        guard !apiKey.isEmpty else {
            print("Error: ANTHROPIC_API_KEY environment variable not set")
            exit(1)
        }
        
        let client = AnthropicClient(apiKey: apiKey)
        var messages: [Message] = []
        
        print("Welcome to Smart Assistant!")
        print("Type 'quit' to exit\n")
        
        while true {
            print("You: ", terminator: "")
            guard let input = readLine(), !input.isEmpty else { continue }
            
            if input.lowercased() == "quit" {
                print("Goodbye!")
                break
            }
            
            messages.append(Message(role: .user, content: input))
            
            let response = try await client.messages.create(
                model: .claude3Sonnet,
                messages: messages,
                maxTokens: 1024
            )
            
            if let textContent = response.content.first?.text {
                print("\nAssistant: \(textContent)\n")
                messages.append(Message(role: .assistant, content: textContent))
            }
        }
    }
}