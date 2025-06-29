import Foundation

/// Protocol defining the Anthropic API interface.
public protocol AnthropicAPIProtocol: Sendable {
    /// Creates a message.
    /// - Parameter request: The message request.
    /// - Returns: The message response.
    func createMessage(_ request: MessageRequest) async throws -> MessageResponse
    
    /// Creates a streaming message.
    /// - Parameter request: The message request.
    /// - Returns: An async stream of events.
    func createStreamingMessage(_ request: MessageRequest) async throws -> AsyncThrowingStream<StreamEvent, Error>
    
    /// Counts tokens in a message request.
    /// - Parameter request: The token count request.
    /// - Returns: The token count response.
    func countTokens(_ request: TokenCountRequest) async throws -> TokenCountResponse
    
    /// Creates a batch of messages.
    /// - Parameter request: The batch request.
    /// - Returns: The created batch.
    func createBatch(_ request: BatchRequest) async throws -> Batch
    
    /// Lists batches.
    /// - Parameter request: The list request.
    /// - Returns: The list response.
    func listBatches(_ request: ListBatchesRequest?) async throws -> ListBatchesResponse
    
    /// Gets a batch by ID.
    /// - Parameter batchId: The batch ID.
    /// - Returns: The batch.
    func getBatch(id batchId: String) async throws -> Batch
    
    /// Gets batch results.
    /// - Parameter batchId: The batch ID.
    /// - Returns: An async stream of batch results.
    func getBatchResults(id batchId: String) async throws -> AsyncThrowingStream<BatchResult, Error>
    
    /// Cancels a batch.
    /// - Parameter batchId: The batch ID.
    /// - Returns: The updated batch.
    func cancelBatch(id batchId: String) async throws -> Batch
    
    /// Deletes a batch.
    /// - Parameter batchId: The batch ID.
    func deleteBatch(id batchId: String) async throws
    
    /// Uploads a file.
    /// - Parameters:
    ///   - data: The file data.
    ///   - filename: The filename.
    ///   - mimeType: The MIME type.
    /// - Returns: The uploaded file.
    func uploadFile(data: Data, filename: String, mimeType: String) async throws -> File
    
    /// Lists files.
    /// - Parameter request: The list request.
    /// - Returns: The list response.
    func listFiles(_ request: ListFilesRequest?) async throws -> ListFilesResponse
    
    /// Gets a file by ID.
    /// - Parameter fileId: The file ID.
    /// - Returns: The file.
    func getFile(id fileId: String) async throws -> File
    
    /// Downloads file content.
    /// - Parameter fileId: The file ID.
    /// - Returns: The file data.
    func downloadFile(id fileId: String) async throws -> Data
    
    /// Deletes a file.
    /// - Parameter fileId: The file ID.
    func deleteFile(id fileId: String) async throws
    
    /// Lists available models.
    /// - Returns: The list response.
    func listModels() async throws -> ListModelsResponse
    
    /// Gets a model by ID.
    /// - Parameter modelId: The model ID.
    /// - Returns: The model.
    func getModel(id modelId: String) async throws -> Model
    
    /// Lists workspace members.
    /// - Parameters:
    ///   - workspaceId: The workspace ID.
    ///   - request: The list request.
    /// - Returns: The list response.
    func listWorkspaceMembers(workspaceId: String, request: ListWorkspaceMembersRequest?) async throws -> ListWorkspaceMembersResponse
    
    /// Gets a workspace member.
    /// - Parameters:
    ///   - workspaceId: The workspace ID.
    ///   - userId: The user ID.
    /// - Returns: The workspace member.
    func getWorkspaceMember(workspaceId: String, userId: String) async throws -> WorkspaceMember
    
    /// Adds a workspace member.
    /// - Parameters:
    ///   - workspaceId: The workspace ID.
    ///   - request: The add member request.
    /// - Returns: The added member.
    func addWorkspaceMember(workspaceId: String, request: AddWorkspaceMemberRequest) async throws -> WorkspaceMember
    
    /// Updates a workspace member.
    /// - Parameters:
    ///   - workspaceId: The workspace ID.
    ///   - userId: The user ID.
    ///   - request: The update request.
    /// - Returns: The updated member.
    func updateWorkspaceMember(workspaceId: String, userId: String, request: UpdateWorkspaceMemberRequest) async throws -> WorkspaceMember
    
    /// Removes a workspace member.
    /// - Parameters:
    ///   - workspaceId: The workspace ID.
    ///   - userId: The user ID.
    func removeWorkspaceMember(workspaceId: String, userId: String) async throws
    
    /// Lists API keys.
    /// - Parameter request: The list request.
    /// - Returns: The list response.
    func listAPIKeys(_ request: ListAPIKeysRequest?) async throws -> ListAPIKeysResponse
    
    /// Gets an API key.
    /// - Parameter keyId: The API key ID.
    /// - Returns: The API key.
    func getAPIKey(id keyId: String) async throws -> APIKey
    
    /// Updates an API key.
    /// - Parameters:
    ///   - keyId: The API key ID.
    ///   - request: The update request.
    /// - Returns: The updated API key.
    func updateAPIKey(id keyId: String, request: UpdateAPIKeyRequest) async throws -> APIKey
}