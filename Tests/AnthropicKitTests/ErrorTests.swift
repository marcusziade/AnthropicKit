import XCTest
@testable import AnthropicKit

final class ErrorTests: XCTestCase {
    
    func testAPIErrorCreation() {
        let error = APIError(type: .rateLimitError, message: "Too many requests")
        XCTAssertEqual(error.type, .rateLimitError)
        XCTAssertEqual(error.message, "Too many requests")
    }
    
    func testErrorTypeRawValues() {
        XCTAssertEqual(ErrorType.invalidRequestError.rawValue, "invalid_request_error")
        XCTAssertEqual(ErrorType.authenticationError.rawValue, "authentication_error")
        XCTAssertEqual(ErrorType.permissionError.rawValue, "permission_error")
        XCTAssertEqual(ErrorType.notFoundError.rawValue, "not_found_error")
        XCTAssertEqual(ErrorType.requestTooLarge.rawValue, "request_too_large")
        XCTAssertEqual(ErrorType.rateLimitError.rawValue, "rate_limit_error")
        XCTAssertEqual(ErrorType.apiError.rawValue, "api_error")
        XCTAssertEqual(ErrorType.overloadedError.rawValue, "overloaded_error")
    }
    
    func testAnthropicErrorDescriptions() {
        let apiError = AnthropicError.apiError(APIError(type: .rateLimitError, message: "Rate limited"))
        XCTAssertEqual(apiError.localizedDescription, "API Error (rate_limit_error): Rate limited")
        
        let networkError = AnthropicError.networkError("Connection failed")
        XCTAssertEqual(networkError.localizedDescription, "Network Error: Connection failed")
        
        let decodingError = AnthropicError.decodingError("Invalid JSON")
        XCTAssertEqual(decodingError.localizedDescription, "Decoding Error: Invalid JSON")
        
        let encodingError = AnthropicError.encodingError("Cannot encode")
        XCTAssertEqual(encodingError.localizedDescription, "Encoding Error: Cannot encode")
        
        let configError = AnthropicError.invalidConfiguration("Missing API key")
        XCTAssertEqual(configError.localizedDescription, "Invalid Configuration: Missing API key")
        
        let streamError = AnthropicError.streamParsingError("Invalid SSE")
        XCTAssertEqual(streamError.localizedDescription, "Stream Parsing Error: Invalid SSE")
        
        let unknownError = AnthropicError.unknown("Something went wrong")
        XCTAssertEqual(unknownError.localizedDescription, "Unknown Error: Something went wrong")
    }
    
    func testAPIErrorResponseDecoding() throws {
        let json = """
        {
            "error": {
                "type": "rate_limit_error",
                "message": "You have exceeded your rate limit"
            }
        }
        """
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(APIErrorResponse.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.error.type, .rateLimitError)
        XCTAssertEqual(response.error.message, "You have exceeded your rate limit")
    }
    
    func testErrorEquality() {
        let error1 = APIError(type: .apiError, message: "Server error")
        let error2 = APIError(type: .apiError, message: "Server error")
        let error3 = APIError(type: .apiError, message: "Different error")
        let error4 = APIError(type: .rateLimitError, message: "Server error")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }
    
    func testAnthropicErrorEquality() {
        let apiError1 = AnthropicError.apiError(APIError(type: .apiError, message: "Error"))
        let apiError2 = AnthropicError.apiError(APIError(type: .apiError, message: "Error"))
        let apiError3 = AnthropicError.apiError(APIError(type: .apiError, message: "Different"))
        
        XCTAssertEqual(apiError1, apiError2)
        XCTAssertNotEqual(apiError1, apiError3)
        
        let networkError1 = AnthropicError.networkError("Failed")
        let networkError2 = AnthropicError.networkError("Failed")
        
        XCTAssertEqual(networkError1, networkError2)
        XCTAssertNotEqual(apiError1, networkError1)
    }
}