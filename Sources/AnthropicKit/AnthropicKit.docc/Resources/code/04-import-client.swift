import Foundation
import AnthropicKit

let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
let client = AnthropicClient(apiKey: apiKey)

print("Welcome to Smart Assistant!")