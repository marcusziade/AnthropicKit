# Batch Processing Guide

Learn how to efficiently process multiple messages in parallel using AnthropicKit's batch processing capabilities.

## Overview

Batch processing allows you to send multiple message requests concurrently, significantly improving throughput and reducing total processing time. This is ideal for scenarios like:

- Processing large datasets
- Generating multiple variations
- Analyzing numerous documents
- Running parallel conversations
- A/B testing different prompts

## Basic Batch Processing

### Concurrent Requests

```swift
import AnthropicKit

func processBatch(_ prompts: [String]) async throws -> [MessageResponse] {
    // Create requests from prompts
    let requests = prompts.map { prompt in
        MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 1024,
            messages: [Message.text(prompt, role: .user)]
        )
    }
    
    // Process all requests concurrently
    let responses = try await withThrowingTaskGroup(of: MessageResponse.self) { group in
        for request in requests {
            group.addTask {
                try await client.createMessage(request)
            }
        }
        
        var results: [MessageResponse] = []
        for try await response in group {
            results.append(response)
        }
        return results
    }
    
    return responses
}

// Usage
let prompts = [
    "Explain quantum computing",
    "What is machine learning?",
    "How does blockchain work?"
]

let responses = try await processBatch(prompts)
```

### Ordered Batch Processing

Maintain the order of responses to match input order:

```swift
func processOrderedBatch(_ prompts: [String]) async throws -> [MessageResponse] {
    let requests = prompts.enumerated().map { index, prompt in
        (index, MessageRequest(
            model: "claude-opus-4-20250514",
            maxTokens: 1024,
            messages: [Message.text(prompt, role: .user)]
        ))
    }
    
    let responses = try await withThrowingTaskGroup(
        of: (Int, MessageResponse).self
    ) { group in
        for (index, request) in requests {
            group.addTask {
                let response = try await client.createMessage(request)
                return (index, response)
            }
        }
        
        var results = Array<MessageResponse?>(repeating: nil, count: prompts.count)
        for try await (index, response) in group {
            results[index] = response
        }
        
        return results.compactMap { $0 }
    }
    
    return responses
}
```

## Advanced Batch Patterns

### Batch with Error Handling

Handle partial failures gracefully:

```swift
struct BatchResult {
    let successful: [(index: Int, response: MessageResponse)]
    let failed: [(index: Int, error: Error)]
    
    var successRate: Double {
        Double(successful.count) / Double(successful.count + failed.count)
    }
}

func processWithErrorHandling(_ requests: [MessageRequest]) async -> BatchResult {
    await withTaskGroup(of: (Int, Result<MessageResponse, Error>).self) { group in
        for (index, request) in requests.enumerated() {
            group.addTask {
                do {
                    let response = try await client.createMessage(request)
                    return (index, .success(response))
                } catch {
                    return (index, .failure(error))
                }
            }
        }
        
        var successful: [(Int, MessageResponse)] = []
        var failed: [(Int, Error)] = []
        
        for await (index, result) in group {
            switch result {
            case .success(let response):
                successful.append((index, response))
            case .failure(let error):
                failed.append((index, error))
            }
        }
        
        return BatchResult(successful: successful, failed: failed)
    }
}

// Usage with retry for failed items
func processWithRetry(_ requests: [MessageRequest], maxRetries: Int = 3) async -> BatchResult {
    var remainingRequests = requests.enumerated().map { ($0, $1) }
    var allSuccessful: [(Int, MessageResponse)] = []
    var allFailed: [(Int, Error)] = []
    
    for attempt in 1...maxRetries {
        let result = await processWithErrorHandling(remainingRequests.map { $0.1 })
        
        // Collect successful responses
        allSuccessful.append(contentsOf: result.successful)
        
        // Prepare failed requests for retry
        if attempt < maxRetries {
            remainingRequests = result.failed.map { failedIndex, _ in
                remainingRequests[failedIndex]
            }
            
            if !remainingRequests.isEmpty {
                // Exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        } else {
            allFailed = result.failed
        }
        
        if remainingRequests.isEmpty {
            break
        }
    }
    
    return BatchResult(successful: allSuccessful, failed: allFailed)
}
```

### Rate-Limited Batch Processing

Respect API rate limits with controlled concurrency:

```swift
actor RateLimitedBatchProcessor {
    private let maxConcurrent: Int
    private let requestsPerMinute: Int
    private var activeRequests = 0
    private var requestTimes: [Date] = []
    
    init(maxConcurrent: Int = 5, requestsPerMinute: Int = 60) {
        self.maxConcurrent = maxConcurrent
        self.requestsPerMinute = requestsPerMinute
    }
    
    func process(_ requests: [MessageRequest]) async throws -> [MessageResponse] {
        var results: [MessageResponse] = []
        
        for request in requests {
            await waitForSlot()
            
            Task {
                defer { Task { await releaseSlot() } }
                let response = try await client.createMessage(request)
                results.append(response)
            }
        }
        
        return results
    }
    
    private func waitForSlot() async {
        while activeRequests >= maxConcurrent {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Rate limiting check
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        requestTimes = requestTimes.filter { $0 > oneMinuteAgo }
        
        if requestTimes.count >= requestsPerMinute {
            let oldestRequest = requestTimes.first!
            let waitTime = oldestRequest.addingTimeInterval(60).timeIntervalSince(now)
            if waitTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        activeRequests += 1
        requestTimes.append(now)
    }
    
    private func releaseSlot() {
        activeRequests -= 1
    }
}
```

### Batch Document Analysis

Process multiple documents with context:

```swift
struct DocumentBatch {
    let documents: [Document]
    let analysisType: AnalysisType
    
    struct Document {
        let id: String
        let content: String
        let metadata: [String: Any]
    }
    
    enum AnalysisType {
        case summary
        case sentiment
        case extraction(fields: [String])
        case classification(categories: [String])
    }
}

class DocumentAnalyzer {
    private let client: AnthropicAPIProtocol
    
    func analyzeBatch(_ batch: DocumentBatch) async throws -> [DocumentAnalysis] {
        let systemPrompt = createSystemPrompt(for: batch.analysisType)
        
        let analyses = try await withThrowingTaskGroup(
            of: (String, DocumentAnalysis).self
        ) { group in
            for document in batch.documents {
                group.addTask {
                    let request = MessageRequest(
                        model: "claude-opus-4-20250514",
                        maxTokens: 2048,
                        messages: [
                            Message(role: .system, content: systemPrompt),
                            Message.text(document.content, role: .user)
                        ],
                        temperature: 0.3 // Lower temperature for consistency
                    )
                    
                    let response = try await self.client.createMessage(request)
                    let analysis = try self.parseAnalysis(
                        response,
                        type: batch.analysisType,
                        document: document
                    )
                    
                    return (document.id, analysis)
                }
            }
            
            var results: [String: DocumentAnalysis] = [:]
            for try await (id, analysis) in group {
                results[id] = analysis
            }
            
            // Return in original order
            return batch.documents.compactMap { results[$0.id] }
        }
        
        return analyses
    }
    
    private func createSystemPrompt(for type: DocumentBatch.AnalysisType) -> String {
        switch type {
        case .summary:
            return "Provide a concise summary of the document in 2-3 sentences."
        case .sentiment:
            return "Analyze the sentiment of this document. Response format: {sentiment: positive|negative|neutral, confidence: 0-1}"
        case .extraction(let fields):
            return "Extract the following information: \(fields.joined(separator: ", ")). Return as JSON."
        case .classification(let categories):
            return "Classify this document into one of: \(categories.joined(separator: ", ")). Return only the category name."
        }
    }
}
```

## Streaming Batch Processing

Process multiple streams concurrently:

```swift
struct StreamBatch {
    let prompts: [String]
    let onUpdate: (Int, String) -> Void // (index, partialText)
    
    func process() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for (index, prompt) in prompts.enumerated() {
                group.addTask {
                    let request = MessageRequest(
                        model: "claude-opus-4-20250514",
                        maxTokens: 1024,
                        messages: [Message.text(prompt, role: .user)]
                    )
                    
                    let stream = try await client.streamMessage(request)
                    var fullText = ""
                    
                    for await event in stream {
                        if case .delta(let delta) = event,
                           let text = delta.text {
                            fullText += text
                            self.onUpdate(index, fullText)
                        }
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
}

// Usage with UI updates
@MainActor
class BatchStreamViewModel: ObservableObject {
    @Published var responses: [String] = []
    
    func processBatch(_ prompts: [String]) {
        responses = Array(repeating: "", count: prompts.count)
        
        Task {
            let batch = StreamBatch(prompts: prompts) { [weak self] index, text in
                Task { @MainActor in
                    self?.responses[index] = text
                }
            }
            
            try await batch.process()
        }
    }
}
```

## Optimization Strategies

### Dynamic Batching

Automatically batch requests based on load:

```swift
actor DynamicBatcher {
    private var pendingRequests: [(MessageRequest, CheckedContinuation<MessageResponse, Error>)] = []
    private var batchTimer: Task<Void, Never>?
    private let batchSize: Int
    private let maxWaitTime: TimeInterval
    
    init(batchSize: Int = 10, maxWaitTime: TimeInterval = 0.1) {
        self.batchSize = batchSize
        self.maxWaitTime = maxWaitTime
    }
    
    func request(_ request: MessageRequest) async throws -> MessageResponse {
        await withCheckedThrowingContinuation { continuation in
            pendingRequests.append((request, continuation))
            
            if pendingRequests.count >= batchSize {
                Task { await processBatch() }
            } else if batchTimer == nil {
                batchTimer = Task {
                    try? await Task.sleep(nanoseconds: UInt64(maxWaitTime * 1_000_000_000))
                    await processBatch()
                }
            }
        }
    }
    
    private func processBatch() async {
        batchTimer?.cancel()
        batchTimer = nil
        
        let batch = pendingRequests
        pendingRequests.removeAll()
        
        await withTaskGroup(of: Void.self) { group in
            for (request, continuation) in batch {
                group.addTask {
                    do {
                        let response = try await client.createMessage(request)
                        continuation.resume(returning: response)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
```

### Cost-Optimized Batching

Optimize for token usage and costs:

```swift
struct CostOptimizedBatcher {
    struct BatchConfig {
        let maxTokensPerBatch: Int
        let maxRequestsPerBatch: Int
        let preferredModel: String
        let fallbackModel: String
    }
    
    func optimizeBatch(
        _ requests: [MessageRequest],
        config: BatchConfig
    ) -> [[MessageRequest]] {
        var batches: [[MessageRequest]] = []
        var currentBatch: [MessageRequest] = []
        var currentTokens = 0
        
        for request in requests {
            let estimatedTokens = estimateTokens(request)
            
            if currentBatch.count >= config.maxRequestsPerBatch ||
               currentTokens + estimatedTokens > config.maxTokensPerBatch {
                if !currentBatch.isEmpty {
                    batches.append(currentBatch)
                }
                currentBatch = [request]
                currentTokens = estimatedTokens
            } else {
                currentBatch.append(request)
                currentTokens += estimatedTokens
            }
        }
        
        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }
        
        return batches
    }
    
    private func estimateTokens(_ request: MessageRequest) -> Int {
        // Rough estimation: 1 token ≈ 4 characters
        let messageTokens = request.messages.reduce(0) { total, message in
            total + (message.content.compactMap { content in
                if case .text(let text) = content {
                    return text.count / 4
                }
                return nil
            }.reduce(0, +))
        }
        
        return messageTokens + request.maxTokens
    }
}
```

## Monitoring and Analytics

### Batch Performance Tracking

```swift
struct BatchMetrics {
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let totalDuration: TimeInterval
    let averageResponseTime: TimeInterval
    let totalTokensUsed: Int
    let estimatedCost: Double
    
    var successRate: Double {
        Double(successfulRequests) / Double(totalRequests)
    }
    
    var requestsPerSecond: Double {
        Double(totalRequests) / totalDuration
    }
}

class BatchMonitor {
    func processBatchWithMetrics(
        _ requests: [MessageRequest]
    ) async -> (responses: [MessageResponse?], metrics: BatchMetrics) {
        let startTime = Date()
        var successful = 0
        var failed = 0
        var totalTokens = 0
        var responseTimes: [TimeInterval] = []
        
        let responses = await withTaskGroup(
            of: (Int, MessageResponse?, TimeInterval, Int).self
        ) { group in
            for (index, request) in requests.enumerated() {
                group.addTask {
                    let requestStart = Date()
                    
                    do {
                        let response = try await client.createMessage(request)
                        let duration = Date().timeIntervalSince(requestStart)
                        let tokens = response.usage.inputTokens + response.usage.outputTokens
                        return (index, response, duration, tokens)
                    } catch {
                        let duration = Date().timeIntervalSince(requestStart)
                        return (index, nil, duration, 0)
                    }
                }
            }
            
            var results = Array<MessageResponse?>(
                repeating: nil,
                count: requests.count
            )
            
            for await (index, response, duration, tokens) in group {
                results[index] = response
                responseTimes.append(duration)
                totalTokens += tokens
                
                if response != nil {
                    successful += 1
                } else {
                    failed += 1
                }
            }
            
            return results
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        let metrics = BatchMetrics(
            totalRequests: requests.count,
            successfulRequests: successful,
            failedRequests: failed,
            totalDuration: totalDuration,
            averageResponseTime: averageResponseTime,
            totalTokensUsed: totalTokens,
            estimatedCost: calculateCost(tokens: totalTokens, model: requests.first?.model ?? "")
        )
        
        return (responses, metrics)
    }
    
    private func calculateCost(tokens: Int, model: String) -> Double {
        // Approximate costs per 1M tokens (adjust based on actual pricing)
        let costPerMillion: Double = switch model {
        case "claude-opus-4-20250514": 15.0
        case "claude-3-5-sonnet-20241022": 3.0
        case "claude-3-5-haiku-20241022": 0.25
        default: 3.0
        }
        
        return (Double(tokens) / 1_000_000) * costPerMillion
    }
}
```

## Best Practices

### 1. Implement Proper Concurrency Control

```swift
// ❌ Bad: Unbounded concurrency
let responses = try await requests.map { request in
    try await client.createMessage(request)
}

// ✅ Good: Controlled concurrency
let responses = try await withThrowingTaskGroup(of: MessageResponse.self) { group in
    // Limit concurrent requests
    let maxConcurrent = 10
    var activeCount = 0
    
    for request in requests {
        while activeCount >= maxConcurrent {
            if let response = try await group.next() {
                results.append(response)
                activeCount -= 1
            }
        }
        
        group.addTask {
            try await client.createMessage(request)
        }
        activeCount += 1
    }
    
    // Collect remaining responses
    var results: [MessageResponse] = []
    for try await response in group {
        results.append(response)
    }
    return results
}
```

### 2. Handle Partial Failures Gracefully

```swift
func processBatchWithFallback(_ requests: [MessageRequest]) async -> [String] {
    let result = await processWithErrorHandling(requests)
    
    return requests.enumerated().map { index, request in
        if let success = result.successful.first(where: { $0.0 == index }) {
            return success.1.content.first?.text ?? "No response"
        } else if let failure = result.failed.first(where: { $0.0 == index }) {
            // Provide meaningful fallback based on error
            return "Unable to process: \(failure.1.localizedDescription)"
        } else {
            return "Unknown error occurred"
        }
    }
}
```

### 3. Monitor Resource Usage

```swift
class ResourceAwareBatcher {
    @available(iOS 13.0, macOS 10.15, *)
    func processBatchWithMemoryLimit(_ requests: [MessageRequest]) async throws {
        let memoryLimit = ProcessInfo.processInfo.physicalMemory / 4 // Use 25% of memory
        var currentMemoryUsage: UInt64 = 0
        
        var batches: [[MessageRequest]] = []
        var currentBatch: [MessageRequest] = []
        
        for request in requests {
            let estimatedMemory = estimateMemoryUsage(request)
            
            if currentMemoryUsage + estimatedMemory > memoryLimit {
                if !currentBatch.isEmpty {
                    batches.append(currentBatch)
                    // Process batch and free memory
                    _ = try await processBatch(currentBatch)
                }
                currentBatch = [request]
                currentMemoryUsage = estimatedMemory
            } else {
                currentBatch.append(request)
                currentMemoryUsage += estimatedMemory
            }
        }
        
        if !currentBatch.isEmpty {
            _ = try await processBatch(currentBatch)
        }
    }
}
```

## Summary

Batch processing with AnthropicKit enables efficient handling of multiple requests, significantly improving throughput and reducing processing time. By implementing proper error handling, rate limiting, and monitoring, you can build robust applications that scale effectively while managing costs and resources.

Key takeaways:
- Use Swift's concurrency features for efficient parallel processing
- Implement proper error handling for partial failures
- Monitor performance and optimize based on metrics
- Control concurrency to respect rate limits
- Design for fault tolerance and graceful degradation

For more information, see:
- <doc:ErrorHandling> for advanced error handling strategies
- <doc:StreamingResponses> for batch streaming patterns
- ``MessageRequest`` for request configuration options