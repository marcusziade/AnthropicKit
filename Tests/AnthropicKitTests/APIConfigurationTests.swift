import XCTest
@testable import AnthropicKit

final class APIConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = APIConfiguration(apiKey: "test-key")
        
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.baseURL.absoluteString, "https://api.anthropic.com")
        XCTAssertEqual(config.apiVersion, "2023-06-01")
        XCTAssertTrue(config.betaFeatures.isEmpty)
        XCTAssertEqual(config.timeoutInterval, 600)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertTrue(config.customHeaders.isEmpty)
    }
    
    func testCustomConfiguration() {
        let customURL = URL(string: "https://custom.api.com")!
        let betaFeatures: Set<BetaFeature> = [.filesAPI]
        let customHeaders = ["X-Custom": "Value"]
        
        let config = APIConfiguration(
            apiKey: "custom-key",
            baseURL: customURL,
            apiVersion: "2024-01-01",
            betaFeatures: betaFeatures,
            timeoutInterval: 30,
            maxRetries: 5,
            customHeaders: customHeaders
        )
        
        XCTAssertEqual(config.apiKey, "custom-key")
        XCTAssertEqual(config.baseURL, customURL)
        XCTAssertEqual(config.apiVersion, "2024-01-01")
        XCTAssertEqual(config.betaFeatures, betaFeatures)
        XCTAssertEqual(config.timeoutInterval, 30)
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.customHeaders, customHeaders)
    }
    
    func testBetaFeatures() {
        XCTAssertEqual(BetaFeature.filesAPI.rawValue, "files-api-2025-04-14")
    }
    
    func testConfigurationEquality() {
        let config1 = APIConfiguration(apiKey: "key1")
        let config2 = APIConfiguration(apiKey: "key1")
        let config3 = APIConfiguration(apiKey: "key2")
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
}