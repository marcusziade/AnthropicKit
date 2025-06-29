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
        
        print("Welcome to Smart Assistant!")
        print("Ask me anything:")
        
        let message = try await client.messages.create(
            model: .claude3Sonnet,
            messages: [
                Message(role: .user, content: "Hello! What can you help me with today?")
            ],
            maxTokens: 1024
        )
        
        if let textContent = message.content.first?.text {
            print("\nAssistant: \(textContent)")
        }
    }
}