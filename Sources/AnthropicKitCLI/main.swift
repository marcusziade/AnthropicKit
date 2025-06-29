import Foundation
import ArgumentParser
import AnthropicKit

@main
struct AnthropicCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "anthropic-cli",
        abstract: "Test CLI for AnthropicKit SDK",
        version: "1.0.0",
        subcommands: [
            Message.self,
            Stream.self,
            CountTokens.self,
            Batch.self,
            Files.self,
            Models.self,
            Organization.self,
            Test.self
        ]
    )
}

// MARK: - Message Command

struct Message: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a message to Claude"
    )
    
    @Option(name: .shortAndLong, help: "The model to use")
    var model: String = "claude-3-5-haiku-20241022"
    
    @Option(name: .shortAndLong, help: "Maximum tokens to generate")
    var maxTokens: Int = 1024
    
    @Option(name: .shortAndLong, help: "System prompt")
    var system: String?
    
    @Option(name: .shortAndLong, help: "Temperature (0.0-1.0)")
    var temperature: Double?
    
    @Argument(help: "The message to send")
    var message: String
    
    func run() async throws {
        let client = try createClient()
        
        let request = MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [.text(message, role: .user)],
            system: system,
            temperature: temperature
        )
        
        print("Sending message...")
        let response = try await client.createMessage(request)
        
        print("\nResponse:")
        for block in response.content {
            if let text = block.text {
                print(text)
            }
        }
        
        print("\nUsage:")
        print("  Input tokens: \(response.usage.inputTokens)")
        print("  Output tokens: \(response.usage.outputTokens)")
        if let stopReason = response.stopReason {
            print("  Stop reason: \(stopReason.rawValue)")
        }
    }
}

// MARK: - Stream Command

struct Stream: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stream a message response from Claude"
    )
    
    @Option(name: .shortAndLong, help: "The model to use")
    var model: String = "claude-3-5-haiku-20241022"
    
    @Option(name: .shortAndLong, help: "Maximum tokens to generate")
    var maxTokens: Int = 1024
    
    @Argument(help: "The message to send")
    var message: String
    
    func run() async throws {
        let client = try createClient()
        
        let request = MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [.text(message, role: .user)]
        )
        
        print("Streaming response...")
        let stream = try await client.createStreamingMessage(request)
        
        var hasContent = false
        for try await event in stream {
            switch event {
            case .contentBlockDelta(let delta):
                if let text = delta.delta.text {
                    print(text, terminator: "")
                    fflush(stdout)
                    hasContent = true
                }
            case .messageDelta(let delta):
                if let usage = delta.usage {
                    if hasContent {
                        print("\n\nOutput tokens: \(usage.outputTokens)")
                    }
                }
            case .messageStop:
                if hasContent {
                    print("\n\nStream complete.")
                } else {
                    print("No content received in stream.")
                }
            case .error(let error):
                print("\n\nError: \(error.error.message)")
            case .ping:
                // Ignore ping events
                break
            case .messageStart, .contentBlockStart, .contentBlockStop:
                // Ignore these events for cleaner output
                break
            default:
                // Ignore other events
                break
            }
        }
    }
}

// MARK: - Count Tokens Command

struct CountTokens: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Count tokens in a message"
    )
    
    @Option(name: .shortAndLong, help: "The model to use")
    var model: String = "claude-3-5-haiku-20241022"
    
    @Option(name: .shortAndLong, help: "System prompt")
    var system: String?
    
    @Argument(help: "The message to count tokens for")
    var message: String
    
    func run() async throws {
        let client = try createClient()
        
        let request = TokenCountRequest(
            model: model,
            messages: [.text(message, role: .user)],
            system: system
        )
        
        print("Counting tokens...")
        let response = try await client.countTokens(request)
        
        print("\nToken count: \(response.inputTokens)")
    }
}

// MARK: - Batch Command

struct Batch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Batch operations",
        subcommands: [Create.self, List.self, Get.self, Results.self, Cancel.self]
    )
    
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a batch request"
        )
        
        @Option(name: .shortAndLong, help: "The model to use")
        var model: String = "claude-opus-4-20250514"
        
        @Option(name: .shortAndLong, help: "Number of requests to create")
        var count: Int = 3
        
        func run() async throws {
            let client = try createClient()
            
            var requests: [BatchRequestItem] = []
            for i in 1...count {
                let messageRequest = MessageRequest(
                    model: model,
                    maxTokens: 100,
                    messages: [.text("What is \(i) + \(i)?", role: .user)]
                )
                requests.append(BatchRequestItem(customId: "request-\(i)", params: messageRequest))
            }
            
            let batchRequest = BatchRequest(requests: requests)
            
            print("Creating batch...")
            let batch = try await client.createBatch(batchRequest)
            
            print("\nBatch created:")
            print("  ID: \(batch.id)")
            print("  Status: \(batch.processingStatus.rawValue)")
            print("  Total requests: \(batch.requestCounts.total)")
        }
    }
    
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List batches"
        )
        
        @Option(name: .shortAndLong, help: "Maximum items to return")
        var limit: Int?
        
        func run() async throws {
            let client = try createClient()
            
            let request = limit.map { ListBatchesRequest(limit: $0) }
            
            print("Listing batches...")
            let response = try await client.listBatches(request)
            
            print("\nBatches:")
            for batch in response.data {
                print("  \(batch.id): \(batch.processingStatus.rawValue) - \(batch.requestCounts.total) requests")
            }
            
            if response.hasMore {
                print("\nMore batches available.")
            }
        }
    }
    
    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get batch details"
        )
        
        @Argument(help: "The batch ID")
        var batchId: String
        
        func run() async throws {
            let client = try createClient()
            
            print("Getting batch...")
            let batch = try await client.getBatch(id: batchId)
            
            print("\nBatch details:")
            print("  ID: \(batch.id)")
            print("  Status: \(batch.processingStatus.rawValue)")
            print("  Requests:")
            print("    Total: \(batch.requestCounts.total)")
            print("    Processing: \(batch.requestCounts.processing)")
            print("    Succeeded: \(batch.requestCounts.succeeded)")
            print("    Errored: \(batch.requestCounts.errored)")
            
            if let resultsUrl = batch.resultsUrl {
                print("  Results URL: \(resultsUrl)")
            }
        }
    }
    
    struct Results: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get batch results"
        )
        
        @Argument(help: "The batch ID")
        var batchId: String
        
        func run() async throws {
            let client = try createClient()
            
            print("Getting batch results...")
            let results = try await client.getBatchResults(id: batchId)
            
            print("\nResults:")
            for try await result in results {
                print("\n  Custom ID: \(result.customId)")
                switch result.result {
                case .success(let response):
                    if let text = response.content.first?.text {
                        print("  Response: \(text)")
                    }
                case .error(let error):
                    print("  Error: \(error.message)")
                }
            }
        }
    }
    
    struct Cancel: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Cancel a batch"
        )
        
        @Argument(help: "The batch ID")
        var batchId: String
        
        func run() async throws {
            let client = try createClient()
            
            print("Canceling batch...")
            let batch = try await client.cancelBatch(id: batchId)
            
            print("\nBatch canceled:")
            print("  ID: \(batch.id)")
            print("  Status: \(batch.processingStatus.rawValue)")
        }
    }
}

// MARK: - Files Command

struct Files: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "File operations",
        subcommands: [Upload.self, List.self, Get.self, Download.self, Delete.self]
    )
    
    struct Upload: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Upload a file"
        )
        
        @Argument(help: "Path to the file to upload")
        var filePath: String
        
        func run() async throws {
            let client = try createClient()
            
            let fileURL = URL(fileURLWithPath: filePath)
            let fileData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent
            
            // Determine MIME type
            let mimeType: String
            switch fileURL.pathExtension.lowercased() {
            case "txt": mimeType = "text/plain"
            case "pdf": mimeType = "application/pdf"
            case "json": mimeType = "application/json"
            case "csv": mimeType = "text/csv"
            default: mimeType = "application/octet-stream"
            }
            
            print("Uploading file...")
            let file = try await client.uploadFile(data: fileData, filename: filename, mimeType: mimeType)
            
            print("\nFile uploaded:")
            print("  ID: \(file.id)")
            print("  Filename: \(file.filename)")
            print("  Size: \(file.sizeBytes) bytes")
            print("  MIME type: \(file.mimeType)")
        }
    }
    
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List files"
        )
        
        @Option(name: .shortAndLong, help: "Maximum items to return")
        var limit: Int?
        
        func run() async throws {
            let client = try createClient()
            
            let request = limit.map { ListFilesRequest(limit: $0) }
            
            print("Listing files...")
            let response = try await client.listFiles(request)
            
            print("\nFiles:")
            for file in response.data {
                print("  \(file.id): \(file.filename) (\(file.sizeBytes) bytes)")
            }
            
            if response.hasMore {
                print("\nMore files available.")
            }
        }
    }
    
    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get file details"
        )
        
        @Argument(help: "The file ID")
        var fileId: String
        
        func run() async throws {
            let client = try createClient()
            
            print("Getting file...")
            let file = try await client.getFile(id: fileId)
            
            print("\nFile details:")
            print("  ID: \(file.id)")
            print("  Filename: \(file.filename)")
            print("  Size: \(file.sizeBytes) bytes")
            print("  MIME type: \(file.mimeType)")
            print("  Created: \(file.createdAt)")
            print("  Downloadable: \(file.downloadable)")
        }
    }
    
    struct Download: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Download a file"
        )
        
        @Argument(help: "The file ID")
        var fileId: String
        
        @Option(name: .shortAndLong, help: "Output filename")
        var output: String?
        
        func run() async throws {
            let client = try createClient()
            
            // Get file metadata first
            let file = try await client.getFile(id: fileId)
            let outputPath = output ?? file.filename
            
            print("Downloading file...")
            let data = try await client.downloadFile(id: fileId)
            
            try data.write(to: URL(fileURLWithPath: outputPath))
            
            print("\nFile downloaded to: \(outputPath)")
            print("  Size: \(data.count) bytes")
        }
    }
    
    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a file"
        )
        
        @Argument(help: "The file ID")
        var fileId: String
        
        func run() async throws {
            let client = try createClient()
            
            print("Deleting file...")
            try await client.deleteFile(id: fileId)
            
            print("\nFile deleted successfully.")
        }
    }
}

// MARK: - Models Command

struct Models: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Model operations",
        subcommands: [List.self, Get.self]
    )
    
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available models"
        )
        
        func run() async throws {
            let client = try createClient()
            
            print("Listing models...")
            let response = try await client.listModels()
            
            print("\nAvailable models:")
            for model in response.data {
                print("  \(model.id): \(model.displayName)")
                print("    Created: \(model.createdAt)")
            }
        }
    }
    
    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get model details"
        )
        
        @Argument(help: "The model ID")
        var modelId: String
        
        func run() async throws {
            let client = try createClient()
            
            print("Getting model...")
            let model = try await client.getModel(id: modelId)
            
            print("\nModel details:")
            print("  ID: \(model.id)")
            print("  Display name: \(model.displayName)")
            print("  Created: \(model.createdAt)")
        }
    }
}

// MARK: - Organization Command

struct Organization: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Organization operations",
        subcommands: [Members.self, APIKeys.self]
    )
    
    struct Members: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Workspace member operations",
            subcommands: [List.self, Get.self, Add.self, Update.self, Remove.self]
        )
        
        struct List: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "List workspace members"
            )
            
            @Argument(help: "The workspace ID")
            var workspaceId: String
            
            @Option(name: .shortAndLong, help: "Maximum items to return")
            var limit: Int?
            
            func run() async throws {
                let client = try createClient()
                
                let request = limit.map { ListWorkspaceMembersRequest(limit: $0) }
                
                print("Listing workspace members...")
                let response = try await client.listWorkspaceMembers(workspaceId: workspaceId, request: request)
                
                print("\nMembers:")
                for member in response.data {
                    print("  \(member.email) (\(member.role.rawValue))")
                    if let name = member.name {
                        print("    Name: \(name)")
                    }
                }
            }
        }
        
        struct Get: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Get workspace member details"
            )
            
            @Argument(help: "The workspace ID")
            var workspaceId: String
            
            @Argument(help: "The user ID")
            var userId: String
            
            func run() async throws {
                let client = try createClient()
                
                print("Getting member...")
                let member = try await client.getWorkspaceMember(workspaceId: workspaceId, userId: userId)
                
                print("\nMember details:")
                print("  ID: \(member.id)")
                print("  Email: \(member.email)")
                if let name = member.name {
                    print("  Name: \(name)")
                }
                print("  Role: \(member.role.rawValue)")
                print("  Added: \(member.addedAt)")
            }
        }
        
        struct Add: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Add a workspace member"
            )
            
            @Argument(help: "The workspace ID")
            var workspaceId: String
            
            @Argument(help: "The email address")
            var email: String
            
            @Option(name: .shortAndLong, help: "The role (workspace_user, workspace_developer, workspace_admin, workspace_billing)")
            var role: String = "workspace_user"
            
            func run() async throws {
                let client = try createClient()
                
                guard let workspaceRole = WorkspaceRole(rawValue: role) else {
                    throw ValidationError("Invalid role: \(role)")
                }
                
                let request = AddWorkspaceMemberRequest(email: email, role: workspaceRole)
                
                print("Adding member...")
                let member = try await client.addWorkspaceMember(workspaceId: workspaceId, request: request)
                
                print("\nMember added:")
                print("  ID: \(member.id)")
                print("  Email: \(member.email)")
                print("  Role: \(member.role.rawValue)")
            }
        }
        
        struct Update: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Update a workspace member's role"
            )
            
            @Argument(help: "The workspace ID")
            var workspaceId: String
            
            @Argument(help: "The user ID")
            var userId: String
            
            @Argument(help: "The new role")
            var role: String
            
            func run() async throws {
                let client = try createClient()
                
                guard let workspaceRole = WorkspaceRole(rawValue: role) else {
                    throw ValidationError("Invalid role: \(role)")
                }
                
                let request = UpdateWorkspaceMemberRequest(role: workspaceRole)
                
                print("Updating member...")
                let member = try await client.updateWorkspaceMember(workspaceId: workspaceId, userId: userId, request: request)
                
                print("\nMember updated:")
                print("  ID: \(member.id)")
                print("  Email: \(member.email)")
                print("  Role: \(member.role.rawValue)")
            }
        }
        
        struct Remove: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Remove a workspace member"
            )
            
            @Argument(help: "The workspace ID")
            var workspaceId: String
            
            @Argument(help: "The user ID")
            var userId: String
            
            func run() async throws {
                let client = try createClient()
                
                print("Removing member...")
                try await client.removeWorkspaceMember(workspaceId: workspaceId, userId: userId)
                
                print("\nMember removed successfully.")
            }
        }
    }
    
    struct APIKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "API key operations",
            subcommands: [List.self, Get.self, Update.self]
        )
        
        struct List: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "List API keys"
            )
            
            @Option(name: .shortAndLong, help: "Maximum items to return")
            var limit: Int?
            
            func run() async throws {
                let client = try createClient()
                
                let request = limit.map { ListAPIKeysRequest(limit: $0) }
                
                print("Listing API keys...")
                let response = try await client.listAPIKeys(request)
                
                print("\nAPI Keys:")
                for key in response.data {
                    print("  \(key.id): \(key.name)")
                    print("    Partial key: \(key.partialKey)")
                    if let lastUsed = key.lastUsedAt {
                        print("    Last used: \(lastUsed)")
                    }
                }
            }
        }
        
        struct Get: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Get API key details"
            )
            
            @Argument(help: "The API key ID")
            var keyId: String
            
            func run() async throws {
                let client = try createClient()
                
                print("Getting API key...")
                let key = try await client.getAPIKey(id: keyId)
                
                print("\nAPI Key details:")
                print("  ID: \(key.id)")
                print("  Name: \(key.name)")
                print("  Partial key: \(key.partialKey)")
                print("  Created: \(key.createdAt)")
                if let lastUsed = key.lastUsedAt {
                    print("  Last used: \(lastUsed)")
                }
            }
        }
        
        struct Update: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Update an API key"
            )
            
            @Argument(help: "The API key ID")
            var keyId: String
            
            @Argument(help: "The new name")
            var name: String
            
            func run() async throws {
                let client = try createClient()
                
                let request = UpdateAPIKeyRequest(name: name)
                
                print("Updating API key...")
                let key = try await client.updateAPIKey(id: keyId, request: request)
                
                print("\nAPI Key updated:")
                print("  ID: \(key.id)")
                print("  Name: \(key.name)")
            }
        }
    }
}

// MARK: - Test Command

struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run comprehensive API tests"
    )
    
    func run() async throws {
        let client = try createClient()
        
        print("Running comprehensive API tests...\n")
        
        // Test 1: Basic message
        print("Test 1: Basic message")
        do {
            let request = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 50,
                messages: [.text("Say 'Hello, AnthropicKit!'", role: .user)]
            )
            let response = try await client.createMessage(request)
            print("✓ Success: \(response.content.first?.text ?? "")")
        } catch {
            print("✗ Failed: \(error)")
        }
        
        // Test 2: Token counting
        print("\nTest 2: Token counting")
        do {
            let request = TokenCountRequest(
                model: "claude-opus-4-20250514",
                messages: [.text("Count the tokens in this message.", role: .user)]
            )
            let response = try await client.countTokens(request)
            print("✓ Success: \(response.inputTokens) tokens")
        } catch {
            print("✗ Failed: \(error)")
        }
        
        // Test 3: Streaming
        print("\nTest 3: Streaming message")
        do {
            let request = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 30,
                messages: [.text("Count from 1 to 5", role: .user)]
            )
            let stream = try await client.createStreamingMessage(request)
            print("✓ Success: Streaming...")
            
            var receivedContent = ""
            for try await event in stream {
                if case .contentBlockDelta(let delta) = event {
                    if let text = delta.delta.text {
                        receivedContent += text
                    }
                }
            }
            print("  Content: \(receivedContent)")
        } catch {
            print("✗ Failed: \(error)")
        }
        
        // Test 4: System prompt
        print("\nTest 4: System prompt")
        do {
            let request = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 50,
                messages: [.text("Who are you?", role: .user)],
                system: "You are a pirate. Always speak like a pirate."
            )
            let response = try await client.createMessage(request)
            print("✓ Success: \(response.content.first?.text ?? "")")
        } catch {
            print("✗ Failed: \(error)")
        }
        
        // Test 5: Temperature
        print("\nTest 5: Temperature control")
        do {
            let request = MessageRequest(
                model: "claude-opus-4-20250514",
                maxTokens: 20,
                messages: [.text("Generate a random number", role: .user)],
                temperature: 0.0
            )
            let response = try await client.createMessage(request)
            print("✓ Success: \(response.content.first?.text ?? "")")
        } catch {
            print("✗ Failed: \(error)")
        }
        
        // Test 6: List models
        print("\nTest 6: List models")
        do {
            let response = try await client.listModels()
            print("✓ Success: Found \(response.data.count) models")
            for model in response.data.prefix(3) {
                print("  - \(model.id)")
            }
        } catch {
            print("✗ Failed: \(error)")
        }
        
        print("\n\nTests complete!")
    }
}

// MARK: - Helper Functions

func createClient() throws -> AnthropicAPI {
    guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
        throw ValidationError("ANTHROPIC_API_KEY environment variable not set")
    }
    
    return AnthropicAPI(apiKey: apiKey)
}

struct ValidationError: Error, CustomStringConvertible {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        message
    }
}