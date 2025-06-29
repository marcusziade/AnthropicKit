import Foundation
import AnthropicKit

@main
struct SmartAssistant {
    static func main() async throws {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        guard !apiKey.isEmpty else {
            print("Error: ANTHROPIC_API_KEY environment variable not set")
            print("Please set it with: export ANTHROPIC_API_KEY='your-api-key'")
            exit(1)
        }
        
        let client = AnthropicClient(apiKey: apiKey)
        var messages: [Message] = []
        
        let systemPrompt = """
        You are a helpful, friendly, and knowledgeable assistant called "SmartBot". 
        You provide clear, concise answers and always try to be helpful.
        If you're not sure about something, you say so honestly.
        You have a warm personality and occasionally use appropriate emojis.
        You can help with:
        - Answering questions
        - Writing and editing text
        - Basic coding help
        - General advice and recommendations
        - Creative tasks like storytelling
        """
        
        print("╭─────────────────────────────────────╮")
        print("│  Welcome to Smart Assistant! 🤖     │")
        print("│  I'm here to help you with          │")
        print("│  anything you need.                 │")
        print("│                                     │")
        print("│  Type 'quit' to exit                │")
        print("│  Type 'clear' to start fresh        │")
        print("╰─────────────────────────────────────╯")
        print("")
        
        while true {
            print("You: ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !input.isEmpty else { continue }
            
            switch input.lowercased() {
            case "quit", "exit", "bye":
                print("\nGoodbye! Thanks for chatting! 👋")
                break
            case "clear", "reset":
                messages.removeAll()
                print("\n🧹 Conversation cleared! Starting fresh.\n")
                continue
            default:
                break
            }
            
            if input.lowercased() == "quit" { break }
            
            messages.append(Message(role: .user, content: input))
            
            print("\nAssistant: ", terminator: "")
            var fullResponse = ""
            
            do {
                let stream = try await client.messages.createStream(
                    model: .claude3Sonnet,
                    messages: messages,
                    maxTokens: 1024,
                    system: systemPrompt,
                    temperature: 0.7
                )
                
                for try await chunk in stream {
                    if let text = chunk.delta?.text {
                        print(text, terminator: "")
                        fflush(stdout)
                        fullResponse += text
                    }
                }
                
                print("\n")
                messages.append(Message(role: .assistant, content: fullResponse))
                
            } catch {
                print("\n❌ Error: \(error.localizedDescription)\n")
            }
        }
    }
}