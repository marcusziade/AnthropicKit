import Foundation

/// A batch request for processing multiple messages.
public struct BatchRequest: Codable, Equatable, Sendable {
    /// Array of individual requests in the batch.
    public let requests: [BatchRequestItem]
    
    /// Creates a new batch request.
    public init(requests: [BatchRequestItem]) {
        self.requests = requests
    }
}

/// An individual request within a batch.
public struct BatchRequestItem: Codable, Equatable, Sendable {
    /// Custom identifier for this request.
    public let customId: String
    
    /// The message request parameters.
    public let params: MessageRequest
    
    private enum CodingKeys: String, CodingKey {
        case customId = "custom_id"
        case params
    }
    
    /// Creates a new batch request item.
    public init(customId: String, params: MessageRequest) {
        self.customId = customId
        self.params = params
    }
}

/// A batch object returned by the API.
public struct Batch: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the batch.
    public let id: String
    
    /// The type of object (always "message_batch").
    public let type: String
    
    /// Processing status of the batch.
    public let processingStatus: ProcessingStatus
    
    /// Number of requests in the batch.
    public let requestCounts: RequestCounts
    
    /// When the batch was created.
    public let createdAt: Date
    
    /// When the batch expires.
    public let expiresAt: Date
    
    /// When processing started (optional).
    public let startedAt: Date?
    
    /// When processing ended (optional).
    public let endedAt: Date?
    
    /// URL to download results (when completed).
    public let resultsUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, type
        case processingStatus = "processing_status"
        case requestCounts = "request_counts"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case resultsUrl = "results_url"
    }
}

/// Processing status of a batch.
public enum ProcessingStatus: String, Codable, Equatable, Sendable {
    case inProgress = "in_progress"
    case canceling
    case ended
}

/// Request counts for a batch.
public struct RequestCounts: Codable, Equatable, Sendable {
    /// Number of processing requests.
    public let processing: Int
    
    /// Number of succeeded requests.
    public let succeeded: Int
    
    /// Number of errored requests.
    public let errored: Int
    
    /// Number of canceled requests.
    public let canceled: Int
    
    /// Number of expired requests.
    public let expired: Int
    
    /// Total number of requests (computed).
    public var total: Int {
        processing + succeeded + errored + canceled + expired
    }
}

/// Request to list batches.
public struct ListBatchesRequest: Equatable, Sendable {
    /// Maximum number of items to return.
    public let limit: Int?
    
    /// Return items after this ID.
    public let afterId: String?
    
    /// Return items before this ID.
    public let beforeId: String?
    
    /// Creates a new list batches request.
    public init(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) {
        self.limit = limit
        self.afterId = afterId
        self.beforeId = beforeId
    }
}

/// Response from listing batches.
public struct ListBatchesResponse: Codable, Equatable, Sendable {
    /// The list of batches.
    public let data: [Batch]
    
    /// Whether there are more items.
    public let hasMore: Bool
    
    /// ID of the first item in the list.
    public let firstId: String?
    
    /// ID of the last item in the list.
    public let lastId: String?
    
    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
}

/// A result from a batch request.
public struct BatchResult: Codable, Equatable, Sendable {
    /// The custom ID from the original request.
    public let customId: String
    
    /// The result of the request.
    public let result: BatchResultType
    
    private enum CodingKeys: String, CodingKey {
        case customId = "custom_id"
        case result
    }
}

/// The result type of a batch request.
public enum BatchResultType: Codable, Equatable, Sendable {
    case success(MessageResponse)
    case error(APIError)
    
    private enum CodingKeys: String, CodingKey {
        case type, message, error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "succeeded":
            let message = try container.decode(MessageResponse.self, forKey: .message)
            self = .success(message)
        case "errored":
            let error = try container.decode(APIError.self, forKey: .error)
            self = .error(error)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown result type: \(type)"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let response):
            try container.encode("succeeded", forKey: .type)
            try container.encode(response, forKey: .message)
        case .error(let error):
            try container.encode("errored", forKey: .type)
            try container.encode(error, forKey: .error)
        }
    }
}