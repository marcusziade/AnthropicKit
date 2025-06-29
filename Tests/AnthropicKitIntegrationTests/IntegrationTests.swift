import XCTest
@testable import AnthropicKit

/// Integration tests that require an API key and network access.
/// These tests are not run by default in CI.
final class IntegrationTests: XCTestCase {
    
    /// Set ANTHROPIC_RUN_INTEGRATION_TESTS=true and ANTHROPIC_API_KEY to run these tests
    override func setUp() {
        super.setUp()
        
        let runIntegration = ProcessInfo.processInfo.environment["ANTHROPIC_RUN_INTEGRATION_TESTS"] == "true"
        let hasAPIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
        
        if !runIntegration || !hasAPIKey {
            XCTSkip("Integration tests require ANTHROPIC_RUN_INTEGRATION_TESTS=true and ANTHROPIC_API_KEY")
        }
    }
    
    func testBasicMessage() async throws {
        let client = AnthropicAPI.fromEnvironment()!
        
        let request = MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 50,
            messages: [.text("Say 'Hello from AnthropicKit tests!'", role: .user)]
        )
        
        let response = try await client.createMessage(request)
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNotNil(response.content.first?.text)
        XCTAssertGreaterThan(response.usage.outputTokens, 0)
    }
}