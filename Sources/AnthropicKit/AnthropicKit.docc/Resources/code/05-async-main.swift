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
    }
}