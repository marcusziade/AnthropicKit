import Foundation

/// A file object returned by the Files API.
public struct File: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the file.
    public let id: String
    
    /// The type of object (always "file").
    public let type: String
    
    /// The filename.
    public let filename: String
    
    /// The MIME type of the file.
    public let mimeType: String
    
    /// The size of the file in bytes.
    public let sizeBytes: Int
    
    /// When the file was created.
    public let createdAt: Date
    
    /// Whether the file can be downloaded.
    public let downloadable: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, type, filename
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
        case downloadable
    }
}

/// Request to list files.
public struct ListFilesRequest: Equatable, Sendable {
    /// Maximum number of items to return.
    public let limit: Int?
    
    /// Return items after this ID.
    public let afterId: String?
    
    /// Return items before this ID.
    public let beforeId: String?
    
    /// Creates a new list files request.
    public init(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) {
        self.limit = limit
        self.afterId = afterId
        self.beforeId = beforeId
    }
}

/// Response from listing files.
public struct ListFilesResponse: Codable, Equatable, Sendable {
    /// The list of files.
    public let data: [File]
    
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