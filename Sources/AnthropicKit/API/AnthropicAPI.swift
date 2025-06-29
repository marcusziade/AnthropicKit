import Foundation
#if os(Linux)
@preconcurrency import FoundationNetworking
#endif

/// The main Anthropic API client.
public final class AnthropicAPI: AnthropicAPIProtocol {
    private let configuration: APIConfiguration
    private let httpClient: HTTPClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    /// Creates a new Anthropic API client.
    /// - Parameter configuration: The API configuration.
    public init(configuration: APIConfiguration) {
        self.configuration = configuration
        self.httpClient = createHTTPClient()
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        
        // Custom date decoding strategy to handle fractional seconds
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try different date formats
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try standard ISO8601
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Could not decode date from: \(dateString)"
                )
            )
        }
    }
    
    /// Creates a new API client with the given API key.
    /// - Parameter apiKey: The API key for authentication.
    public convenience init(apiKey: String) {
        self.init(configuration: APIConfiguration(apiKey: apiKey))
    }
    
    /// Creates a new API client from environment variables.
    /// - Returns: An API client if the required environment variables are set.
    public static func fromEnvironment() -> AnthropicAPI? {
        guard let config = APIConfiguration.fromEnvironment() else {
            return nil
        }
        return AnthropicAPI(configuration: config)
    }
    
    // MARK: - Messages API
    
    public func createMessage(_ request: MessageRequest) async throws -> MessageResponse {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages")
        var modifiedRequest = request
        
        // Ensure stream is false for non-streaming requests
        modifiedRequest = MessageRequest(
            model: request.model,
            maxTokens: request.maxTokens,
            messages: request.messages,
            system: request.system,
            metadata: request.metadata,
            stopSequences: request.stopSequences,
            temperature: request.temperature,
            topP: request.topP,
            topK: request.topK,
            stream: false,
            tools: request.tools,
            toolChoice: request.toolChoice
        )
        
        let requestData = try encoder.encode(modifiedRequest)
        let urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(MessageResponse.self, from: data)
    }
    
    public func createStreamingMessage(_ request: MessageRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages")
        var modifiedRequest = request
        
        // Ensure stream is true for streaming requests
        modifiedRequest = MessageRequest(
            model: request.model,
            maxTokens: request.maxTokens,
            messages: request.messages,
            system: request.system,
            metadata: request.metadata,
            stopSequences: request.stopSequences,
            temperature: request.temperature,
            topP: request.topP,
            topK: request.topK,
            stream: true,
            tools: request.tools,
            toolChoice: request.toolChoice
        )
        
        let requestData = try encoder.encode(modifiedRequest)
        var urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let stream = try await httpClient.performStreaming(urlRequest)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = Data()
                    
                    for try await chunk in stream {
                        buffer.append(chunk)
                        
                        // Process complete SSE events (ending with double newline)
                        while let doubleNewlineRange = buffer.range(of: Data("\n\n".utf8)) {
                            let eventData = buffer[..<doubleNewlineRange.upperBound]
                            buffer.removeSubrange(..<doubleNewlineRange.upperBound)
                            
                            // Parse the SSE event
                            do {
                                let events = try StreamEventParser.parse(eventData)
                                for event in events {
                                    continuation.yield(event)
                                }
                            } catch {
                                // Ignore parsing errors and continue
                            }
                        }
                    }
                    
                    // Process any remaining data
                    if !buffer.isEmpty {
                        do {
                            let events = try StreamEventParser.parse(buffer)
                            for event in events {
                                continuation.yield(event)
                            }
                        } catch {
                            // Ignore final parsing errors
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func countTokens(_ request: TokenCountRequest) async throws -> TokenCountResponse {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages/count_tokens")
        let requestData = try encoder.encode(request)
        let urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(TokenCountResponse.self, from: data)
    }
    
    // MARK: - Batch API
    
    public func createBatch(_ request: BatchRequest) async throws -> Batch {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages/batches")
        let requestData = try encoder.encode(request)
        let urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(Batch.self, from: data)
    }
    
    public func listBatches(_ request: ListBatchesRequest? = nil) async throws -> ListBatchesResponse {
        var url = configuration.baseURL.appendingPathComponent("/v1/messages/batches")
        
        if let request = request {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems: [URLQueryItem] = []
            
            if let limit = request.limit {
                queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            if let afterId = request.afterId {
                queryItems.append(URLQueryItem(name: "after_id", value: afterId))
            }
            if let beforeId = request.beforeId {
                queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
            }
            
            if !queryItems.isEmpty {
                components.queryItems = queryItems
                url = components.url!
            }
        }
        
        let urlRequest = createURLRequest(url: url, method: .get)
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(ListBatchesResponse.self, from: data)
    }
    
    public func getBatch(id batchId: String) async throws -> Batch {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages/batches/\(batchId)")
        let urlRequest = createURLRequest(url: url, method: .get)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(Batch.self, from: data)
    }
    
    public func getBatchResults(id batchId: String) async throws -> AsyncThrowingStream<BatchResult, Error> {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages/batches/\(batchId)/results")
        let urlRequest = createURLRequest(url: url, method: .get)
        
        let stream = try await httpClient.performStreaming(urlRequest)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in stream {
                        // JSONL format - each line is a separate result
                        let lines = String(data: chunk, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
                        for line in lines where !line.isEmpty {
                            if let data = line.data(using: .utf8) {
                                let result = try self.decoder.decode(BatchResult.self, from: data)
                                continuation.yield(result)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func cancelBatch(id batchId: String) async throws -> Batch {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages/batches/\(batchId)/cancel")
        let urlRequest = createURLRequest(url: url, method: .post)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(Batch.self, from: data)
    }
    
    public func deleteBatch(id batchId: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages/batches/\(batchId)")
        let urlRequest = createURLRequest(url: url, method: .delete)
        
        _ = try await performRequest(urlRequest)
    }
    
    // MARK: - Files API
    
    public func uploadFile(data: Data, filename: String, mimeType: String) async throws -> File {
        let url = configuration.baseURL.appendingPathComponent("/v1/files")
        var urlRequest = createURLRequest(url: url, method: .post)
        
        // Add beta header for files API
        urlRequest.setValue("files-api-2025-04-14", forHTTPHeaderField: "anthropic-beta")
        
        let (responseData, response) = try await httpClient.uploadFile(urlRequest, fileData: data, filename: filename, mimeType: mimeType)
        
        guard (200...299).contains(response.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: responseData) {
                throw AnthropicError.apiError(errorResponse.error)
            }
            throw AnthropicError.networkError("HTTP \(response.statusCode)")
        }
        
        return try decoder.decode(File.self, from: responseData)
    }
    
    public func listFiles(_ request: ListFilesRequest? = nil) async throws -> ListFilesResponse {
        var url = configuration.baseURL.appendingPathComponent("/v1/files")
        
        if let request = request {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems: [URLQueryItem] = []
            
            if let limit = request.limit {
                queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            if let afterId = request.afterId {
                queryItems.append(URLQueryItem(name: "after_id", value: afterId))
            }
            if let beforeId = request.beforeId {
                queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
            }
            
            if !queryItems.isEmpty {
                components.queryItems = queryItems
                url = components.url!
            }
        }
        
        var urlRequest = createURLRequest(url: url, method: .get)
        urlRequest.setValue("files-api-2025-04-14", forHTTPHeaderField: "anthropic-beta")
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(ListFilesResponse.self, from: data)
    }
    
    public func getFile(id fileId: String) async throws -> File {
        let url = configuration.baseURL.appendingPathComponent("/v1/files/\(fileId)")
        var urlRequest = createURLRequest(url: url, method: .get)
        urlRequest.setValue("files-api-2025-04-14", forHTTPHeaderField: "anthropic-beta")
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(File.self, from: data)
    }
    
    public func downloadFile(id fileId: String) async throws -> Data {
        let url = configuration.baseURL.appendingPathComponent("/v1/files/\(fileId)/content")
        var urlRequest = createURLRequest(url: url, method: .get)
        urlRequest.setValue("files-api-2025-04-14", forHTTPHeaderField: "anthropic-beta")
        
        let (data, _) = try await performRequest(urlRequest)
        return data
    }
    
    public func deleteFile(id fileId: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("/v1/files/\(fileId)")
        var urlRequest = createURLRequest(url: url, method: .delete)
        urlRequest.setValue("files-api-2025-04-14", forHTTPHeaderField: "anthropic-beta")
        
        _ = try await performRequest(urlRequest)
    }
    
    // MARK: - Models API
    
    public func listModels() async throws -> ListModelsResponse {
        let url = configuration.baseURL.appendingPathComponent("/v1/models")
        let urlRequest = createURLRequest(url: url, method: .get)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(ListModelsResponse.self, from: data)
    }
    
    public func getModel(id modelId: String) async throws -> Model {
        let url = configuration.baseURL.appendingPathComponent("/v1/models/\(modelId)")
        let urlRequest = createURLRequest(url: url, method: .get)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(Model.self, from: data)
    }
    
    // MARK: - Organizations API
    
    public func listWorkspaceMembers(workspaceId: String, request: ListWorkspaceMembersRequest? = nil) async throws -> ListWorkspaceMembersResponse {
        var url = configuration.baseURL.appendingPathComponent("/v1/organizations/workspaces/\(workspaceId)/members")
        
        if let request = request {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems: [URLQueryItem] = []
            
            if let limit = request.limit {
                queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            if let afterId = request.afterId {
                queryItems.append(URLQueryItem(name: "after_id", value: afterId))
            }
            if let beforeId = request.beforeId {
                queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
            }
            
            if !queryItems.isEmpty {
                components.queryItems = queryItems
                url = components.url!
            }
        }
        
        let urlRequest = createURLRequest(url: url, method: .get)
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(ListWorkspaceMembersResponse.self, from: data)
    }
    
    public func getWorkspaceMember(workspaceId: String, userId: String) async throws -> WorkspaceMember {
        let url = configuration.baseURL.appendingPathComponent("/v1/organizations/workspaces/\(workspaceId)/members/\(userId)")
        let urlRequest = createURLRequest(url: url, method: .get)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(WorkspaceMember.self, from: data)
    }
    
    public func addWorkspaceMember(workspaceId: String, request: AddWorkspaceMemberRequest) async throws -> WorkspaceMember {
        let url = configuration.baseURL.appendingPathComponent("/v1/organizations/workspaces/\(workspaceId)/members")
        let requestData = try encoder.encode(request)
        let urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(WorkspaceMember.self, from: data)
    }
    
    public func updateWorkspaceMember(workspaceId: String, userId: String, request: UpdateWorkspaceMemberRequest) async throws -> WorkspaceMember {
        let url = configuration.baseURL.appendingPathComponent("/v1/organizations/workspaces/\(workspaceId)/members/\(userId)")
        let requestData = try encoder.encode(request)
        let urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(WorkspaceMember.self, from: data)
    }
    
    public func removeWorkspaceMember(workspaceId: String, userId: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("/v1/organizations/workspaces/\(workspaceId)/members/\(userId)")
        let urlRequest = createURLRequest(url: url, method: .delete)
        
        _ = try await performRequest(urlRequest)
    }
    
    public func listAPIKeys(_ request: ListAPIKeysRequest? = nil) async throws -> ListAPIKeysResponse {
        var url = configuration.baseURL.appendingPathComponent("/v1/organizations/api_keys")
        
        if let request = request {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems: [URLQueryItem] = []
            
            if let limit = request.limit {
                queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            if let afterId = request.afterId {
                queryItems.append(URLQueryItem(name: "after_id", value: afterId))
            }
            if let beforeId = request.beforeId {
                queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
            }
            
            if !queryItems.isEmpty {
                components.queryItems = queryItems
                url = components.url!
            }
        }
        
        let urlRequest = createURLRequest(url: url, method: .get)
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(ListAPIKeysResponse.self, from: data)
    }
    
    public func getAPIKey(id keyId: String) async throws -> APIKey {
        let url = configuration.baseURL.appendingPathComponent("/v1/organizations/api_keys/\(keyId)")
        let urlRequest = createURLRequest(url: url, method: .get)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(APIKey.self, from: data)
    }
    
    public func updateAPIKey(id keyId: String, request: UpdateAPIKeyRequest) async throws -> APIKey {
        let url = configuration.baseURL.appendingPathComponent("/v1/organizations/api_keys/\(keyId)")
        let requestData = try encoder.encode(request)
        let urlRequest = createURLRequest(url: url, method: .post, body: requestData)
        
        let (data, _) = try await performRequest(urlRequest)
        return try decoder.decode(APIKey.self, from: data)
    }
    
    // MARK: - Private Helpers
    
    private func createURLRequest(url: URL, method: HTTPMethod, body: Data? = nil) -> URLRequest {
        var headers: [String: String] = [
            "x-api-key": configuration.apiKey,
            "anthropic-version": configuration.apiVersion,
            "content-type": "application/json"
        ]
        
        // Add beta features
        if !configuration.betaFeatures.isEmpty {
            let betaString = configuration.betaFeatures.map { $0.rawValue }.joined(separator: ",")
            headers["anthropic-beta"] = betaString
        }
        
        // Add custom headers
        for (key, value) in configuration.customHeaders {
            headers[key] = value
        }
        
        return URLRequest.create(
            url: url,
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: configuration.timeoutInterval
        )
    }
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxRetries {
            do {
                let (data, response) = try await httpClient.perform(request, streaming: false)
                
                // Check for rate limiting
                if response.statusCode == 429 {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt)) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                // Check for errors
                if !(200...299).contains(response.statusCode) {
                    if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                        throw AnthropicError.apiError(errorResponse.error)
                    }
                    throw AnthropicError.networkError("HTTP \(response.statusCode)")
                }
                
                return (data, response)
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if case AnthropicError.apiError(let apiError) = error {
                    switch apiError.type {
                    case .invalidRequestError, .authenticationError, .permissionError, .notFoundError:
                        throw error
                    default:
                        break
                    }
                }
                
                // Exponential backoff for retries
                if attempt < configuration.maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AnthropicError.unknown("Request failed")
    }
}