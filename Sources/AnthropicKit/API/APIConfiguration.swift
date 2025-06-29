import Foundation

/// Configuration for the Anthropic API.
public struct APIConfiguration: Equatable, Sendable {
    /// The API key for authentication.
    public let apiKey: String
    
    /// The base URL for the API.
    public let baseURL: URL
    
    /// The API version.
    public let apiVersion: String
    
    /// Beta features to enable.
    public let betaFeatures: Set<BetaFeature>
    
    /// Request timeout in seconds.
    public let timeoutInterval: TimeInterval
    
    /// Maximum retry attempts.
    public let maxRetries: Int
    
    /// Custom headers to include in all requests.
    public let customHeaders: [String: String]
    
    /// Creates a new API configuration.
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - baseURL: The base URL for the API (defaults to Anthropic's API).
    ///   - apiVersion: The API version (defaults to "2023-06-01").
    ///   - betaFeatures: Beta features to enable.
    ///   - timeoutInterval: Request timeout in seconds (defaults to 600).
    ///   - maxRetries: Maximum retry attempts (defaults to 3).
    ///   - customHeaders: Custom headers to include in all requests.
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        apiVersion: String = "2023-06-01",
        betaFeatures: Set<BetaFeature> = [],
        timeoutInterval: TimeInterval = 600,
        maxRetries: Int = 3,
        customHeaders: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.apiVersion = apiVersion
        self.betaFeatures = betaFeatures
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.customHeaders = customHeaders
    }
    
    /// Creates a configuration from environment variables.
    /// - Returns: A configuration if the required environment variables are set.
    public static func fromEnvironment() -> APIConfiguration? {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            return nil
        }
        
        var config = APIConfiguration(apiKey: apiKey)
        
        if let baseURL = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"],
           let url = URL(string: baseURL) {
            config = APIConfiguration(
                apiKey: apiKey,
                baseURL: url,
                apiVersion: config.apiVersion,
                betaFeatures: config.betaFeatures,
                timeoutInterval: config.timeoutInterval,
                maxRetries: config.maxRetries,
                customHeaders: config.customHeaders
            )
        }
        
        return config
    }
}

/// Beta features that can be enabled.
public enum BetaFeature: String, Equatable, Sendable {
    /// Files API beta.
    case filesAPI = "files-api-2025-04-14"
}

/// Rate limit information.
public struct RateLimitInfo: Equatable, Sendable {
    /// Requests per minute limit.
    public let requestsPerMinute: Int
    
    /// Requests per day limit.
    public let requestsPerDay: Int?
    
    /// Tokens per minute limit.
    public let tokensPerMinute: Int?
    
    /// Tokens per day limit.
    public let tokensPerDay: Int?
    
    /// Current requests remaining.
    public let requestsRemaining: Int?
    
    /// Current tokens remaining.
    public let tokensRemaining: Int?
    
    /// When the rate limit resets.
    public let resetAt: Date?
}