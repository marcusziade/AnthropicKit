#!/usr/bin/env swift

import Foundation
import AnthropicKit

// This example demonstrates basic usage of AnthropicKit
// Set your API key: export ANTHROPIC_API_KEY="your-api-key"

@main
struct SimpleExample {
    static func main() async throws {
        // Create client from environment
        guard let client = AnthropicAPI.fromEnvironment() else {
            print("Error: ANTHROPIC_API_KEY environment variable not set")
            exit(1)
        }
        
        print("AnthropicKit Simple Example")
        print("==========================\n")
        
        // 1. Simple message
        print("1. Sending a simple message...")
        do {
            let request = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 100,
                messages: [.text("Hello! Can you tell me a fun fact about Swift programming?", role: .user)]
            )
            
            let response = try await client.createMessage(request)
            print("Response: \(response.content.first?.text ?? "")")
            print("Tokens used: \(response.usage.inputTokens) input, \(response.usage.outputTokens) output\n")
        } catch {
            print("Error: \(error)\n")
        }
        
        // 2. Streaming example
        print("2. Streaming a response...")
        do {
            let request = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 150,
                messages: [.text("Write a haiku about Swift programming", role: .user)]
            )
            
            print("Response: ", terminator: "")
            let stream = try await client.createStreamingMessage(request)
            for try await event in stream {
                if case .contentBlockDelta(let delta) = event {
                    if let text = delta.delta.text {
                        print(text, terminator: "")
                        fflush(stdout)
                    }
                }
            }
            print("\n")
        } catch {
            print("\nError: \(error)\n")
        }
        
        // 3. Token counting
        print("3. Counting tokens...")
        do {
            let request = TokenCountRequest(
                model: "claude-opus-4-20250514",
                messages: [.text("This is a test message to count tokens.", role: .user)]
            )
            
            let count = try await client.countTokens(request)
            print("Token count: \(count.inputTokens)\n")
        } catch {
            print("Error: \(error)\n")
        }
        
        print("Example complete!")
    }
}