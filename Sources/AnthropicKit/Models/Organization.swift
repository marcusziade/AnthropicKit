import Foundation

/// A workspace member.
public struct WorkspaceMember: Codable, Equatable, Sendable, Identifiable {
    /// The user's ID.
    public let id: String
    
    /// The user's email.
    public let email: String
    
    /// The user's name.
    public let name: String?
    
    /// The user's role in the workspace.
    public let role: WorkspaceRole
    
    /// When the user was added to the workspace.
    public let addedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, email, name, role
        case addedAt = "added_at"
    }
}

/// Workspace roles.
public enum WorkspaceRole: String, Codable, Equatable, Sendable {
    case workspaceUser = "workspace_user"
    case workspaceDeveloper = "workspace_developer"
    case workspaceAdmin = "workspace_admin"
    case workspaceBilling = "workspace_billing"
}

/// Request to add a workspace member.
public struct AddWorkspaceMemberRequest: Codable, Equatable, Sendable {
    /// The email of the user to add.
    public let email: String
    
    /// The role to assign to the user.
    public let role: WorkspaceRole
    
    /// Creates a new add workspace member request.
    public init(email: String, role: WorkspaceRole) {
        self.email = email
        self.role = role
    }
}

/// Request to update a workspace member.
public struct UpdateWorkspaceMemberRequest: Codable, Equatable, Sendable {
    /// The new role for the user.
    public let role: WorkspaceRole
    
    /// Creates a new update workspace member request.
    public init(role: WorkspaceRole) {
        self.role = role
    }
}

/// Request to list workspace members.
public struct ListWorkspaceMembersRequest: Equatable, Sendable {
    /// Maximum number of items to return.
    public let limit: Int?
    
    /// Return items after this ID.
    public let afterId: String?
    
    /// Return items before this ID.
    public let beforeId: String?
    
    /// Creates a new list workspace members request.
    public init(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) {
        self.limit = limit
        self.afterId = afterId
        self.beforeId = beforeId
    }
}

/// Response from listing workspace members.
public struct ListWorkspaceMembersResponse: Codable, Equatable, Sendable {
    /// The list of members.
    public let data: [WorkspaceMember]
    
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

/// An API key.
public struct APIKey: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the API key.
    public let id: String
    
    /// The type of object (always "api_key").
    public let type: String
    
    /// Name of the API key.
    public let name: String
    
    /// When the API key was created.
    public let createdAt: Date
    
    /// When the API key was last used.
    public let lastUsedAt: Date?
    
    /// Partial API key for display.
    public let partialKey: String
    
    private enum CodingKeys: String, CodingKey {
        case id, type, name
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case partialKey = "partial_key"
    }
}

/// Request to update an API key.
public struct UpdateAPIKeyRequest: Codable, Equatable, Sendable {
    /// The new name for the API key.
    public let name: String
    
    /// Creates a new update API key request.
    public init(name: String) {
        self.name = name
    }
}

/// Request to list API keys.
public struct ListAPIKeysRequest: Equatable, Sendable {
    /// Maximum number of items to return.
    public let limit: Int?
    
    /// Return items after this ID.
    public let afterId: String?
    
    /// Return items before this ID.
    public let beforeId: String?
    
    /// Creates a new list API keys request.
    public init(limit: Int? = nil, afterId: String? = nil, beforeId: String? = nil) {
        self.limit = limit
        self.afterId = afterId
        self.beforeId = beforeId
    }
}

/// Response from listing API keys.
public struct ListAPIKeysResponse: Codable, Equatable, Sendable {
    /// The list of API keys.
    public let data: [APIKey]
    
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