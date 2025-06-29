import Foundation

/// An error returned by the Anthropic API.
public struct APIError: Error, Codable, Equatable, Sendable {
    /// The type of error.
    public let type: ErrorType
    
    /// A human-readable error message.
    public let message: String
    
    /// Creates a new API error.
    public init(type: ErrorType, message: String) {
        self.type = type
        self.message = message
    }
}

/// Types of errors that can be returned by the API.
public enum ErrorType: String, Codable, Equatable, Sendable {
    case invalidRequestError = "invalid_request_error"
    case authenticationError = "authentication_error"
    case permissionError = "permission_error"
    case notFoundError = "not_found_error"
    case requestTooLarge = "request_too_large"
    case rateLimitError = "rate_limit_error"
    case apiError = "api_error"
    case overloadedError = "overloaded_error"
}

/// An error response from the API.
public struct APIErrorResponse: Codable, Equatable, Sendable {
    /// The error details.
    public let error: APIError
}

/// Errors that can occur when using AnthropicKit.
public enum AnthropicError: Error, Equatable, Sendable {
    /// An API error was returned.
    case apiError(APIError)
    
    /// A network error occurred.
    case networkError(String)
    
    /// Failed to decode the response.
    case decodingError(String)
    
    /// Failed to encode the request.
    case encodingError(String)
    
    /// Invalid configuration.
    case invalidConfiguration(String)
    
    /// Stream parsing error.
    case streamParsingError(String)
    
    /// Unknown error.
    case unknown(String)
}

extension AnthropicError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .apiError(let error):
            return "API Error (\(error.type.rawValue)): \(error.message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .decodingError(let message):
            return "Decoding Error: \(message)"
        case .encodingError(let message):
            return "Encoding Error: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid Configuration: \(message)"
        case .streamParsingError(let message):
            return "Stream Parsing Error: \(message)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
}