import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftUI
import CommonCrypto
import Darwin.Mach

// MARK: - Debug Logging Configuration
#if DEBUG
private let enableDynamoLogs = ProcessInfo.processInfo.environment["DYNAMO_LOGS"] == "1"
private let enableNetworkLogs = ProcessInfo.processInfo.environment["NETWORK_LOGS"] == "1"
private let enableAWSLogs = ProcessInfo.processInfo.environment["AWS_LOGS"] == "1"
private let enableMemoryLogs = ProcessInfo.processInfo.environment["MEMORY_LOGS"] == "1"

private func dynamoLog(_ message: String) {
    if enableDynamoLogs { print(message) }
}

private func networkLog(_ message: String) {
    if enableNetworkLogs { print(message) }
}

private func awsLog(_ message: String) {
    if enableAWSLogs { print(message) }
}

private func memoryLog(_ message: String) {
    if enableMemoryLogs { print(message) }
}
#else
private func dynamoLog(_ message: String) {}
private func networkLog(_ message: String) {}
private func awsLog(_ message: String) {}
private func memoryLog(_ message: String) {}
#endif

// MARK: - Lightweight BrowseForward Item Model
struct BrowseForwardItem: Codable, Identifiable, Hashable {
    let url: String
    let title: String
    let thumbnailUrl: String
    let domain: String
    let category: String
    let bfCategory: String?
    let isActive: Bool
    let wordCount: Int?
    
    // Computed property for Identifiable - based on URL
    var id: String { url }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: BrowseForwardItem, rhs: BrowseForwardItem) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: - DynamoDB Query Response Models
struct DynamoDBQueryResponse: Codable {
    let items: [DynamoDBItemResponse]?
    let count: Int?
    let scannedCount: Int?
    let lastEvaluatedKey: [String: DynamoDBAttributeValue]?
    
    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case count = "Count"
        case scannedCount = "ScannedCount"
        case lastEvaluatedKey = "LastEvaluatedKey"
    }
}

struct DynamoDBItemResponse: Codable {
    let attributes: [String: DynamoDBAttributeValue]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.attributes = try container.decode([String: DynamoDBAttributeValue].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(attributes)
    }
}

// MARK: - Enhanced DynamoDB Attribute Value (supports mixed formats)
struct DynamoDBAttributeValue: Codable {
    let s: String?
    let n: String?
    let ss: [String]?
    let l: [DynamoDBAttributeValue]?
    let null: Bool?
    let bool: Bool?
    
    enum CodingKeys: String, CodingKey {
        case s = "S"
        case n = "N"
        case ss = "SS"
        case l = "L"
        case null = "NULL"
        case bool = "BOOL"
    }
    
    // Helper to extract string array from either SS or L format
    var stringArray: [String] {
        if let ss = ss {
            return ss
        } else if let l = l {
            return l.compactMap { $0.s }
        }
        return []
    }
}

// MARK: - Query Parameters
struct WebPageQueryParams {
    let bfCategory: String?
    let bfSubcategory: String?
    let isActiveOnly: Bool?
    let source: String?
    let tags: [String]?
    let limit: Int
    let sortBy: SortOption
    let lastEvaluatedKey: [String: DynamoDBAttributeValue]?
    
    enum SortOption {
        case popularity // upvotes descending
        case recent     // fetchedAt descending
        case title      // title ascending
    }
}

// MARK: - Service Errors
enum DynamoDBWebPageServiceError: Error, LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case parseError(Error)
    case awsError(Int, String)
    case invalidResponse
    case noItemsFound
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "AWS credentials not found. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .awsError(let code, let message):
            return "AWS DynamoDB error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from DynamoDB"
        case .noItemsFound:
            return "No items found matching the query criteria"
        }
    }
}

// MARK: - DynamoDB WebPage Query Service
@MainActor
class DynamoDBWebPageService: ObservableObject {
    static let shared = DynamoDBWebPageService()
    
    private let tableName = "webpages"
    private let region = "us-east-1"
    
    @Published var isLoading = false
    @Published var lastError: DynamoDBWebPageServiceError?
    
    private init() {}
    
    // MARK: - Main Query Methods
    
    /// Fetch articles by category (Science, Culture, News, Classics)
    func fetchByCategory(_ category: String, limit: Int = 50) async throws -> [AWSWebPageItem] {
        let params = WebPageQueryParams(
            bfCategory: category,
            bfSubcategory: nil,
            isActiveOnly: nil,
            source: nil,
            tags: nil,
            limit: limit,
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        return try await performQuery(with: params)
    }
    
    /// Lightweight queue items by category and subcategory with isActive filtering (only 8 fields)
    func fetchBFQueueItems(category: String?, subcategory: String? = nil, isActiveOnly: Bool = true, limit: Int = 50) async throws -> [BrowseForwardItem] {
        print("🏷️ DEBUG fetchBFQueueItems: === STARTING fetchBFQueueItems ===")
        print("🏷️ DEBUG fetchBFQueueItems: category: \(category ?? "nil")")
        print("🏷️ DEBUG fetchBFQueueItems: subcategory: \(subcategory ?? "nil")")
        print("🏷️ DEBUG fetchBFQueueItems: isActiveOnly: \(isActiveOnly)")
        print("🏷️ DEBUG fetchBFQueueItems: limit: \(limit)")
        
        let params = WebPageQueryParams(
            bfCategory: category,
            bfSubcategory: subcategory,
            isActiveOnly: isActiveOnly,
            source: nil,
            tags: nil,
            limit: limit,
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        print("🏷️ DEBUG fetchBFQueueItems: About to call performLightweightQuery")
        let result = try await performLightweightQuery(with: params)
        print("🏷️ DEBUG fetchBFQueueItems: performLightweightQuery returned \(result.count) items")
        print("🏷️ DEBUG fetchBFQueueItems: === ENDING fetchBFQueueItems ===")
        return result
    }
    
    
    /// Get all available categories from active items
    func getAvailableCategories() async throws -> [String] {
        print("📂 DEBUG getAvailableCategories: === STARTING getAvailableCategories ===")
        
        // Fetch a sample of active items to discover categories
        let params = WebPageQueryParams(
            bfCategory: nil,
            bfSubcategory: nil,
            isActiveOnly: true,
            source: nil,
            tags: nil,
            limit: 200, // Get enough to find all categories
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        let items = try await performQuery(with: params)
        let categories = Set(items.compactMap { $0.bfCategory }).sorted()
        
        print("📂 DEBUG getAvailableCategories: Found \(categories.count) categories: \(categories)")
        return categories
    }
    
    /// Get available subcategories for a specific category
    func getSubcategories(for category: String) async throws -> [String] {
        print("📂 DEBUG getSubcategories: === STARTING getSubcategories ===")
        print("📂 DEBUG getSubcategories: category: \(category)")
        
        let params = WebPageQueryParams(
            bfCategory: category,
            bfSubcategory: nil,
            isActiveOnly: true,
            source: nil,
            tags: nil,
            limit: 200, // Get enough to find all subcategories
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        let items = try await performQuery(with: params)
        let subcategories = Set(items.compactMap { $0.bfSubcategory }).sorted()
        
        print("📂 DEBUG getSubcategories: Found \(subcategories.count) subcategories: \(subcategories)")
        return subcategories
    }
    
    /// Fetch articles by source (e.g., "internet-archive-science", "reddit-worldnews")
    func fetchBySource(_ source: String, limit: Int = 50) async throws -> [AWSWebPageItem] {
        print("🔥 DEBUG fetchBySource: === STARTING fetchBySource ===")
        print("🔥 DEBUG fetchBySource: source: '\(source)'")
        print("🔥 DEBUG fetchBySource: limit: \(limit)")
        
        let params = WebPageQueryParams(
            bfCategory: nil,
            bfSubcategory: nil,
            isActiveOnly: nil,
            source: source,
            tags: nil,
            limit: limit,
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        print("🔥 DEBUG fetchBySource: About to call performQuery")
        let result = try await performQuery(with: params)
        print("🔥 DEBUG fetchBySource: performQuery returned \(result.count) items")
        print("🔥 DEBUG fetchBySource: === ENDING fetchBySource ===")
        return result
    }
    
    /// Fetch popular articles across all categories
    func fetchPopular(limit: Int = 50) async throws -> [AWSWebPageItem] {
        print("⭐ DEBUG fetchPopular: === STARTING fetchPopular ===")
        print("⭐ DEBUG fetchPopular: limit: \(limit)")
        
        let params = WebPageQueryParams(
            bfCategory: nil,
            bfSubcategory: nil,
            isActiveOnly: nil,
            source: nil,
            tags: nil,
            limit: limit,
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        print("⭐ DEBUG fetchPopular: About to call performQuery")
        let result = try await performQuery(with: params)
        print("⭐ DEBUG fetchPopular: performQuery returned \(result.count) items")
        print("⭐ DEBUG fetchPopular: === ENDING fetchPopular ===")
        return result
    }
    
    /// Fetch recent articles across all categories
    func fetchRecent(limit: Int = 50) async throws -> [AWSWebPageItem] {
        let params = WebPageQueryParams(
            bfCategory: nil,
            bfSubcategory: nil,
            isActiveOnly: nil,
            source: nil,
            tags: nil,
            limit: limit,
            sortBy: .recent,
            lastEvaluatedKey: nil
        )
        return try await performQuery(with: params)
    }
    
    /// Search articles by multiple tags with AND logic (handles both SS and L formats)
    func fetchByTags(_ tags: [String], limit: Int = 50) async throws -> [AWSWebPageItem] {
        print("🏷️ DEBUG fetchByTags: === STARTING fetchByTags ===")
        print("🏷️ DEBUG fetchByTags: tags: \(tags)")
        print("🏷️ DEBUG fetchByTags: limit: \(limit)")
        
        let params = WebPageQueryParams(
            bfCategory: nil,
            bfSubcategory: nil,
            isActiveOnly: nil,
            source: nil,
            tags: tags.map { $0.lowercased() },
            limit: limit,
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        print("🏷️ DEBUG fetchByTags: About to call performQuery")
        let result = try await performQuery(with: params)
        print("🏷️ DEBUG fetchByTags: performQuery returned \(result.count) items")
        print("🏷️ DEBUG fetchByTags: === ENDING fetchByTags ===")
        return result
    }
    
    /// Advanced query with custom parameters
    func fetchWithParams(_ params: WebPageQueryParams) async throws -> [AWSWebPageItem] {
        return try await performQuery(with: params)
    }
    
    
    
    
    // MARK: - Private Query Implementation
    
    private func performQuery(with params: WebPageQueryParams) async throws -> [AWSWebPageItem] {
        let startMemory = getMemoryUsage()
        dynamoLog("🌟 DEBUG performQuery: === STARTING performQuery ===")
        dynamoLog("🌟 DEBUG performQuery: params.bfCategory: \(params.bfCategory ?? "nil")")
        dynamoLog("🌟 DEBUG performQuery: params.source: \(params.source ?? "nil")")
        dynamoLog("🌟 DEBUG performQuery: params.tags: \(params.tags ?? [])")
        dynamoLog("🌟 DEBUG performQuery: params.limit: \(params.limit)")
        memoryLog("📊 DEBUG performQuery: Starting memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(startMemory), countStyle: .memory))")
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            dynamoLog("🌟 DEBUG performQuery: About to buildQueryExpression")
            let queryExpression = buildQueryExpression(for: params)
            dynamoLog("🌟 DEBUG performQuery: Query expression built, about to executeQuery")
            
            let response = try await executeQuery(queryExpression)
            dynamoLog("🌟 DEBUG performQuery: Query executed, about to parseResponse")
            
            var items = try parseResponse(response)
            dynamoLog("🌟 DEBUG performQuery: Response parsed, got \(items.count) items")
            
            // Sort in memory since DynamoDB scan doesn't support sorting
            items = applySorting(items, sortBy: params.sortBy)
            dynamoLog("🌟 DEBUG performQuery: Items sorted, final count: \(items.count)")
            
            print("✅ DynamoDB query successful: \(items.count) items fetched")
            
            if items.isEmpty {
                dynamoLog("🌟 DEBUG performQuery: No items found, throwing noItemsFound error")
                throw DynamoDBWebPageServiceError.noItemsFound
            }
            
            let endMemory = getMemoryUsage()
            let memoryDelta = Int64(endMemory) - Int64(startMemory)
            print("📊 DEBUG performQuery: Final memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(endMemory), countStyle: .memory)) (Δ\(memoryDelta > 0 ? "+" : "")\(ByteCountFormatter.string(fromByteCount: memoryDelta, countStyle: .memory)))")
            dynamoLog("🌟 DEBUG performQuery: === ENDING performQuery SUCCESS ===")
            return items
            
        } catch let error as DynamoDBWebPageServiceError {
            print("🚨 DEBUG performQuery: DynamoDBWebPageServiceError caught: \(error)")
            await MainActor.run {
                lastError = error
            }
            throw error
        } catch {
            print("🚨 DEBUG performQuery: Generic error caught: \(error)")
            let serviceError = DynamoDBWebPageServiceError.networkError(error)
            await MainActor.run {
                lastError = serviceError
            }
            throw serviceError
        }
    }
    
    /// Lightweight query that only parses the 8 core fields
    private func performLightweightQuery(with params: WebPageQueryParams) async throws -> [BrowseForwardItem] {
        print("🚀 DEBUG performLightweightQuery: === STARTING performLightweightQuery ===")
        print("🚀 DEBUG performLightweightQuery: params.bfCategory: \(params.bfCategory ?? "nil")")
        print("🚀 DEBUG performLightweightQuery: params.bfSubcategory: \(params.bfSubcategory ?? "nil")")
        print("🚀 DEBUG performLightweightQuery: params.isActiveOnly: \(params.isActiveOnly ?? false)")
        print("🚀 DEBUG performLightweightQuery: params.limit: \(params.limit)")
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            print("🚀 DEBUG performLightweightQuery: About to buildQueryExpression")
            let queryExpression = buildQueryExpression(for: params)
            print("🚀 DEBUG performLightweightQuery: Query expression built, calling executeQuery")
            let response = try await executeQuery(queryExpression)
            print("🚀 DEBUG performLightweightQuery: executeQuery returned \(response.count) bytes")
            let items = try parseLightweightResponse(response)
            print("🚀 DEBUG performLightweightQuery: Parsed \(items.count) items")
            
            if items.isEmpty {
                print("🚀 DEBUG performLightweightQuery: No items found, throwing error")
                throw DynamoDBWebPageServiceError.noItemsFound
            }
            
            print("🚀 DEBUG performLightweightQuery: === ENDING performLightweightQuery SUCCESS ===")
            return items
            
        } catch let error as DynamoDBWebPageServiceError {
            print("🚨 DEBUG performLightweightQuery: DynamoDBWebPageServiceError: \(error)")
            await MainActor.run {
                lastError = error
            }
            throw error
        } catch {
            print("🚨 DEBUG performLightweightQuery: Generic error: \(error)")
            let serviceError = DynamoDBWebPageServiceError.networkError(error)
            await MainActor.run {
                lastError = serviceError
            }
            throw serviceError
        }
    }
    
    /// Parse response for lightweight BrowseForwardItems
    private func parseLightweightResponse(_ data: Data) throws -> [BrowseForwardItem] {
        do {
            let response = try JSONDecoder().decode(DynamoDBQueryResponse.self, from: data)
            guard let items = response.items else { return [] }
            
            let queueItems = items.compactMap { item -> BrowseForwardItem? in
                return parseBrowseForwardItem(from: item.attributes)
            }
            
            return queueItems
            
        } catch {
            throw DynamoDBWebPageServiceError.parseError(error)
        }
    }
    
    private func buildQueryExpression(for params: WebPageQueryParams) -> [String: Any] {
        let buildStart = CFAbsoluteTimeGetCurrent()
        dynamoLog("🔧 DEBUG buildQueryExpression: === STARTING buildQueryExpression ===")
        dynamoLog("🔧 DEBUG buildQueryExpression: tableName: \(tableName)")
        dynamoLog("🔧 DEBUG buildQueryExpression: params.limit: \(params.limit)")
        dynamoLog("🔧 DEBUG buildQueryExpression: params.source: \(params.source ?? "nil")")
        dynamoLog("🔧 DEBUG buildQueryExpression: params.bfCategory: \(params.bfCategory ?? "nil")")
        dynamoLog("🔧 DEBUG buildQueryExpression: params.tags: \(params.tags ?? [])")
        
        var query: [String: Any] = [
            "TableName": tableName,
            "Limit": params.limit
        ]
        
        // Use appropriate GSI query based on parameters
        if let bfCategory = params.bfCategory {
            dynamoLog("🔧 DEBUG buildQueryExpression: Using GSI query for category: \(bfCategory)")
            query["IndexName"] = "category-status-index"
            query["KeyConditionExpression"] = "#bfCategory = :bfCategory AND #status = :status"
            query["ExpressionAttributeNames"] = ["#bfCategory": "bfCategory", "#status": "status"]
            query["ExpressionAttributeValues"] = [":bfCategory": ["S": bfCategory], ":status": ["S": "active"]]
        } else if let source = params.source {
            dynamoLog("🔧 DEBUG buildQueryExpression: Using GSI query for source: \(source)")
            query["IndexName"] = "source-index"
            query["KeyConditionExpression"] = "#source = :source"
            query["ExpressionAttributeNames"] = ["#source": "source"]
            query["ExpressionAttributeValues"] = [":source": ["S": source]]
        } else {
            // Fallback to scan only when no specific parameters are provided
            dynamoLog("🔧 DEBUG buildQueryExpression: Using Scan operation (no category or source specified)")
        }
        
        // Build filter expression for additional filters beyond the key conditions
        var filterExpressions: [String] = []
        var scanExpressionAttributeValues: [String: [String: Any]] = [:]
        var scanExpressionAttributeNames: [String: String] = [:]

        // For Scan operations, filter by isActive (GSI queries handle this in KeyConditionExpression)
        if query["IndexName"] == nil {
            filterExpressions.append("isActive = :isActive")
            scanExpressionAttributeValues[":isActive"] = ["BOOL": true]
        }
        
        // Filter by bfSubcategory
        if let bfSubcategory = params.bfSubcategory {
            filterExpressions.append("#bfSubcategory = :bfSubcategory")
            scanExpressionAttributeNames["#bfSubcategory"] = "bfSubcategory"
            scanExpressionAttributeValues[":bfSubcategory"] = ["S": bfSubcategory]
        }

        // Filter by tags (supports both SS and L formats)
        if let tags = params.tags, !tags.isEmpty {
            for (index, tag) in tags.enumerated() {
                // Check both SS (String Set) and L (List) formats
                filterExpressions.append("(contains(tags, :tag\(index)) OR contains(tags, :tagItem\(index)))")
                scanExpressionAttributeValues[":tag\(index)"] = ["S": tag]
                scanExpressionAttributeValues[":tagItem\(index)"] = ["L": [["S": tag]]]
            }
        }
        
        if !filterExpressions.isEmpty {
            query["FilterExpression"] = filterExpressions.joined(separator: " AND ")
            dynamoLog("🔧 DEBUG buildQueryExpression: FilterExpression: \(query["FilterExpression"] as? String ?? "nil")")
        } else {
            dynamoLog("🔧 DEBUG buildQueryExpression: No FilterExpression - scanning entire table")
        }
        
        if !expressionAttributeValues.isEmpty {
            query["ExpressionAttributeValues"] = expressionAttributeValues
            dynamoLog("🔧 DEBUG buildQueryExpression: ExpressionAttributeValues: \(expressionAttributeValues)")
        }
        
        if !expressionAttributeNames.isEmpty {
            query["ExpressionAttributeNames"] = expressionAttributeNames
            dynamoLog("🔧 DEBUG buildQueryExpression: ExpressionAttributeNames: \(expressionAttributeNames)")
        }
        
        // Add pagination
        if let lastKey = params.lastEvaluatedKey {
            query["ExclusiveStartKey"] = lastKey
        }
        
        dynamoLog("🔧 DEBUG buildQueryExpression: Final query: \(query)")
        print("⏱️  DEBUG buildQueryExpression: Query building completed in: \(CFAbsoluteTimeGetCurrent() - buildStart)s")
        dynamoLog("🔧 DEBUG buildQueryExpression: === ENDING buildQueryExpression ===")
        return query
    }
    
    private func executeQuery(_ queryExpression: [String: Any]) async throws -> Data {
        let credStart = CFAbsoluteTimeGetCurrent()
        print("🔑 DEBUG executeQuery: === STARTING executeQuery ===")
        print("🔑 DEBUG executeQuery: Starting credential lookup")
        
        // Get AWS credentials from Info.plist (best practice for iOS)
        guard let accessKey = Bundle.main.object(forInfoDictionaryKey: "AWS_ACCESS_KEY_ID") as? String,
              let secretKey = Bundle.main.object(forInfoDictionaryKey: "AWS_SECRET_ACCESS_KEY") as? String,
              !accessKey.isEmpty, !secretKey.isEmpty else {
            // Fallback to environment variables for development
            guard let envAccessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
                  let envSecretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"],
                  !envAccessKey.isEmpty, !envSecretKey.isEmpty else {
                print("❌ DynamoDBWebPageService: AWS credentials not found in Info.plist or environment")
                throw DynamoDBWebPageServiceError.invalidCredentials
            }
            awsLog("✅ DynamoDBWebPageService: Using AWS credentials from environment variables")
            awsLog("🔑 DEBUG executeQuery: Credential lookup took: \(CFAbsoluteTimeGetCurrent() - credStart)s")
            return try await performRequest(queryExpression: queryExpression, accessKey: envAccessKey, secretKey: envSecretKey)
        }
        
        awsLog("✅ DynamoDBWebPageService: Using AWS credentials from Info.plist")
        awsLog("🔑 DEBUG executeQuery: Credential lookup took: \(CFAbsoluteTimeGetCurrent() - credStart)s")
        print("🔑 DEBUG executeQuery: Calling performRequest with credentials")
        let result = try await performRequest(queryExpression: queryExpression, accessKey: accessKey, secretKey: secretKey)
        print("🔑 DEBUG executeQuery: === ENDING executeQuery SUCCESS ===")
        return result
    }
    
    // Add request deduplication cache
    private var pendingRequests: [String: Task<Data, Error>] = [:]
    
    private func performRequest(queryExpression: [String: Any], accessKey: String, secretKey: String) async throws -> Data {
        print("🌐 DEBUG performRequest: === STARTING performRequest ===")
        print("🌐 DEBUG performRequest: accessKey exists: \(!accessKey.isEmpty)")
        print("🌐 DEBUG performRequest: secretKey exists: \(!secretKey.isEmpty)")
        
        // Create cache key for request deduplication
        let requestKey = createRequestCacheKey(queryExpression)
        print("🌐 DEBUG performRequest: Request cache key: \(requestKey)")
        
        // Check if identical request is already in progress
        if let existingTask = pendingRequests[requestKey] {
            print("🔄 Reusing existing request for: \(requestKey)")
            return try await existingTask.value
        }
        
        // Create new task and cache it
        print("🌐 DEBUG performRequest: Creating new task for request")
        let task = Task<Data, Error> {
            defer { 
                print("🌐 DEBUG performRequest: Removing cached task for: \(requestKey)")
                pendingRequests.removeValue(forKey: requestKey) 
            }
            print("🌐 DEBUG performRequest: Calling executeRequest")
            return try await executeRequest(queryExpression: queryExpression, accessKey: accessKey, secretKey: secretKey)
        }
        
        pendingRequests[requestKey] = task
        print("🌐 DEBUG performRequest: Waiting for task to complete")
        let result = try await task.value
        print("🌐 DEBUG performRequest: === ENDING performRequest SUCCESS ===")
        return result
    }
    
    private func createRequestCacheKey(_ queryExpression: [String: Any]) -> String {
        // Create deterministic key from query parameters
        let tableName = queryExpression["TableName"] as? String ?? "unknown"
        let indexName = queryExpression["IndexName"] as? String ?? "none"
        let keyCondition = queryExpression["KeyConditionExpression"] as? String ?? "none"
        let filterExpression = queryExpression["FilterExpression"] as? String ?? "none"
        let limit = queryExpression["Limit"] as? Int ?? 0
        
        return "\(tableName)_\(indexName)_\(keyCondition)_\(filterExpression)_\(limit)".replacingOccurrences(of: " ", with: "_")
    }
    
    private func executeRequest(queryExpression: [String: Any], accessKey: String, secretKey: String) async throws -> Data {
        print("🔗 DEBUG executeRequest: === STARTING executeRequest ===")
        print("🔗 DEBUG executeRequest: Region: \(region)")
        
        // Create request
        guard let url = URL(string: "https://dynamodb.\(region).amazonaws.com/") else {
            print("🚨 DEBUG executeRequest: Failed to create URL")
            throw DynamoDBWebPageServiceError.networkError(URLError(.badURL))
        }
        print("🔗 DEBUG executeRequest: URL created: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Determine operation type based on whether IndexName is present
        let operation = queryExpression["IndexName"] != nil ? "DynamoDB_20120810.Query" : "DynamoDB_20120810.Scan"
        print("🔗 DEBUG executeRequest: Operation type: \(operation)")
        request.setValue(operation, forHTTPHeaderField: "X-Amz-Target")
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Increase timeout for DynamoDB scans
        
        // Encode request body
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: queryExpression)
            request.httpBody = jsonData
            print("🔗 DEBUG executeRequest: Request body size: \(jsonData.count) bytes")
        } catch {
            print("🚨 DEBUG executeRequest: Failed to encode request body: \(error)")
            throw DynamoDBWebPageServiceError.parseError(error)
        }
        
        // Add AWS authentication headers (basic implementation)
        print("🔗 DEBUG executeRequest: Adding AWS auth headers")
        try addAWSAuthHeaders(&request, jsonData, accessKey: accessKey, secretKey: secretKey)
        print("🔗 DEBUG executeRequest: AWS auth headers added successfully")
        
        // Execute request with retry logic
        let networkStart = CFAbsoluteTimeGetCurrent()
        networkLog("🌐 DEBUG performRequest: Starting network request")
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let requestTime = CFAbsoluteTimeGetCurrent() - networkStart
                networkLog("🌐 DEBUG performRequest: Network request completed in: \(requestTime)s")
                networkLog("📊 DEBUG performRequest: Response size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .memory))")
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        networkLog("✅ DEBUG performRequest: HTTP 200 OK received")
                        return data
                    } else {
                        let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                        let error = DynamoDBWebPageServiceError.awsError(httpResponse.statusCode, responseString)
                        
                        // Retry on certain error codes
                        if httpResponse.statusCode >= 500 && attempt < maxRetries {
                            let retryDelay = Double(attempt)
                            print("🔄 DEBUG performRequest: Retrying attempt \(attempt)/\(maxRetries) after \(retryDelay)s due to server error: \(httpResponse.statusCode)")
                            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                            continue
                        }
                        
                        print("🚨 DEBUG performRequest: HTTP error \(httpResponse.statusCode) - no retry")
                        throw error
                    }
                }
                
                print("🚨 DEBUG performRequest: Invalid response type")
                throw DynamoDBWebPageServiceError.invalidResponse
                
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let retryDelay = Double(attempt)
                    print("🔄 DEBUG performRequest: Retrying attempt \(attempt)/\(maxRetries) after \(retryDelay)s due to: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                } else {
                    print("🚨 DEBUG performRequest: All \(maxRetries) attempts failed")
                }
            }
        }
        
        throw DynamoDBWebPageServiceError.networkError(lastError ?? URLError(.unknown))
    }
    
    private func parseResponse(_ data: Data) throws -> [AWSWebPageItem] {
        let parseStart = CFAbsoluteTimeGetCurrent()
        dynamoLog("🌐 DEBUG parseResponse: Starting JSON parsing...")
        
        do {
            let jsonStart = CFAbsoluteTimeGetCurrent()
            let response = try JSONDecoder().decode(DynamoDBQueryResponse.self, from: data)
            print("⏱️  DEBUG parseResponse: JSON decoding completed in: \(CFAbsoluteTimeGetCurrent() - jsonStart)s")
            
            guard let items = response.items else {
                dynamoLog("🌐 DEBUG parseResponse: No items found in response")
                print("⏱️  DEBUG parseResponse: Total parsing completed in: \(CFAbsoluteTimeGetCurrent() - parseStart)s")
                return []
            }
            
            dynamoLog("🌐 DEBUG parseResponse: Processing \(items.count) raw items...")
            let itemStart = CFAbsoluteTimeGetCurrent()
            let webPageItems = items.compactMap { item -> AWSWebPageItem? in
                return parseWebPageItem(from: item.attributes)
            }
            print("⏱️  DEBUG parseResponse: Item parsing completed in: \(CFAbsoluteTimeGetCurrent() - itemStart)s")
            
            dynamoLog("🌐 DEBUG parseResponse: Parsed \(webPageItems.count) items successfully")
            print("⏱️  DEBUG parseResponse: Total parsing completed in: \(CFAbsoluteTimeGetCurrent() - parseStart)s")
            return webPageItems
            
        } catch {
            print("🚨 DEBUG parseResponse: JSON parsing failed in: \(CFAbsoluteTimeGetCurrent() - parseStart)s")
            throw DynamoDBWebPageServiceError.parseError(error)
        }
    }
    
    private func parseWebPageItem(from attributes: [String: DynamoDBAttributeValue]) -> AWSWebPageItem? {
        // Required fields
        guard let url = attributes["url"]?.s,
              let id = attributes["id"]?.s,
              let title = attributes["title"]?.s,
              let domain = attributes["domain"]?.s,
              let category = attributes["category"]?.s,
              let source = attributes["source"]?.s,
              let upvotesString = attributes["upvotes"]?.n,
              let upvotes = Int(upvotesString),
              let interactionsString = attributes["interactions"]?.n,
              let interactions = Int(interactionsString),
              let thumbnailUrl = attributes["thumbnailUrl"]?.s,
              let fetchedAt = attributes["fetchedAt"]?.s,
              let updatedAt = attributes["updatedAt"]?.s else {
            print("⚠️  Skipping item missing required fields: \(attributes.keys)")
            return nil
        }
        
        // Handle mixed tag formats (SS or L)
        let tags = attributes["tags"]?.stringArray ?? []
        
        // Optional fields
        let createdDate = attributes["createdDate"]?.s
        let postDate = attributes["postDate"]?.s
        
        // BrowseForward category fields
        let bfCategory = attributes["bfCategory"]?.s
        let bfSubcategory = attributes["bfSubcategory"]?.s
        let isActive = attributes["isActive"]?.bool
        
        // Enhanced fields with safe parsing
        let textContent = attributes["text"]?.s ?? attributes["textContent"]?.s
        let aiSummary = attributes["aiSummary"]?.s
        let readingTimeMinutes = attributes["readingTimeMinutes"]?.n.flatMap(Int.init)
        let wordCount = attributes["wordCount"]?.n.flatMap(Int.init)
        let aiTopics = attributes["aiTopics"]?.stringArray
        let contentType = attributes["contentType"]?.s
        let qualityScore = attributes["qualityScore"]?.n.flatMap(Int.init)
        let aiKeywords = attributes["aiKeywords"]?.stringArray
        let relatedCategories = attributes["relatedCategories"]?.stringArray
        let difficulty = attributes["difficulty"]?.s
        let thumbnailDescription = attributes["thumbnailDescription"]?.s
        let alternativeHeadline = attributes["alternativeHeadline"]?.stringArray ?? []
        let internalLinks = attributes["internalLinks"]?.stringArray ?? []
        let paragraphCount = attributes["paragraphCount"]?.n.flatMap(Int.init) ?? 0
        
        return AWSWebPageItem(
            url: url,
            id: id,
            title: title,
            domain: domain,
            category: category,
            bfCategory: bfCategory,
            bfSubcategory: bfSubcategory,
            source: source,
            upvotes: upvotes,
            interactions: interactions,
            tags: tags,
            thumbnailUrl: thumbnailUrl,
            createdDate: createdDate,
            postDate: postDate,
            fetchedAt: fetchedAt,
            updatedAt: updatedAt,
            textContent: textContent,
            aiSummary: aiSummary,
            readingTimeMinutes: readingTimeMinutes,
            wordCount: wordCount,
            aiTopics: aiTopics,
            contentType: contentType,
            qualityScore: qualityScore,
            aiKeywords: aiKeywords,
            relatedCategories: relatedCategories,
            difficulty: difficulty,
            thumbnailDescription: thumbnailDescription,
            alternativeHeadline: alternativeHeadline,
            internalLinks: internalLinks,
            paragraphCount: paragraphCount,
            commentCount: attributes["commentCount"]?.n.flatMap(Int.init),
            likeCount: attributes["likeCount"]?.n.flatMap(Int.init),
            saveCount: attributes["saveCount"]?.n.flatMap(Int.init),
            isReported: attributes["isReported"]?.n.flatMap(Int.init),
            reportCount: attributes["reportCount"]?.n.flatMap(Int.init),
            isActive: isActive ?? true
        )
    }
    
    /// Parse lightweight BrowseForwardItem from DynamoDB attributes (only 8 core fields)
    private func parseBrowseForwardItem(from attributes: [String: DynamoDBAttributeValue]) -> BrowseForwardItem? {
        // Required fields only
        guard let url = attributes["url"]?.s,
              let title = attributes["title"]?.s,
              let domain = attributes["domain"]?.s,
              let category = attributes["category"]?.s,
              let thumbnailUrl = attributes["thumbnailUrl"]?.s else {
            return nil
        }
        
        // Optional fields
        let bfCategory = attributes["bfCategory"]?.s
        let isActive = attributes["isActive"]?.bool ?? true
        let wordCount = attributes["wordCount"]?.n.flatMap(Int.init)
        
        return BrowseForwardItem(
            url: url,
            title: title,
            thumbnailUrl: thumbnailUrl,
            domain: domain,
            category: category,
            bfCategory: bfCategory,
            isActive: isActive,
            wordCount: wordCount
        )
    }
    
    private func applySorting(_ items: [AWSWebPageItem], sortBy: WebPageQueryParams.SortOption) -> [AWSWebPageItem] {
        let sortStart = CFAbsoluteTimeGetCurrent()
        print("🔄 DEBUG applySorting: Starting sorting \(items.count) items by \(sortBy)...")
        
        let sortedItems: [AWSWebPageItem]
        switch sortBy {
        case .popularity:
            sortedItems = items.sorted { $0.upvotes > $1.upvotes }
        case .recent:
            sortedItems = items.sorted { $0.fetchedAt > $1.fetchedAt }
        case .title:
            sortedItems = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        print("⏱️  DEBUG applySorting: Sorting completed in: \(CFAbsoluteTimeGetCurrent() - sortStart)s")
        return sortedItems
    }
    
    // MARK: - AWS Signature v4 Authentication
    private func addAWSAuthHeaders(_ request: inout URLRequest, _ body: Data, accessKey: String, secretKey: String) throws {
        if accessKey.isEmpty || secretKey.isEmpty {
            throw DynamoDBWebPageServiceError.invalidCredentials
        }
        
        let timestamp = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let amzDate = dateFormatter.string(from: timestamp).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        let dateStamp = String(amzDate.prefix(8))
        
        // Get the operation that was already set in performRequest
        let operation = request.value(forHTTPHeaderField: "X-Amz-Target") ?? "DynamoDB_20120810.Scan"
        
        // Set required headers (X-Amz-Target already set in performRequest)
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        
        // Create canonical request
        let httpMethod = request.httpMethod ?? "POST"
        let canonicalUri = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/x-amz-json-1.0\nhost:dynamodb.\(region).amazonaws.com\nx-amz-date:\(amzDate)\nx-amz-target:\(operation)\n"
        let signedHeaders = "content-type;host;x-amz-date;x-amz-target"
        let payloadHash = sha256Hash(data: body)
        
        let canonicalRequest = "\(httpMethod)\n\(canonicalUri)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"
        
        // Create string to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/dynamodb/aws4_request"
        let stringToSign = "\(algorithm)\n\(amzDate)\n\(credentialScope)\n\(sha256Hash(string: canonicalRequest))"
        
        // Calculate signature
        let signingKey = getSignatureKey(key: secretKey, dateStamp: dateStamp, regionName: region, serviceName: "dynamodb")
        let signature = hmacSha256(data: stringToSign.data(using: .utf8)!, key: signingKey).map { String(format: "%02hhx", $0) }.joined()
        
        // Create authorization header
        let authorizationHeader = "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        
        print("✅ DynamoDBWebPageService: AWS request signed with Signature v4")
    }
    
    private func sha256Hash(string: String) -> String {
        return sha256Hash(data: string.data(using: .utf8)!)
    }
    
    private func sha256Hash(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func hmacSha256(data: Data, key: Data) -> Data {
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        result.withUnsafeMutableBytes { resultBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, dataBytes.baseAddress, data.count, resultBytes.bindMemory(to: UInt8.self).baseAddress)
                }
            }
        }
        return result
    }
    
    private func getSignatureKey(key: String, dateStamp: String, regionName: String, serviceName: String) -> Data {
        let kDate = hmacSha256(data: dateStamp.data(using: .utf8)!, key: ("AWS4" + key).data(using: .utf8)!)
        let kRegion = hmacSha256(data: regionName.data(using: .utf8)!, key: kDate)
        let kService = hmacSha256(data: serviceName.data(using: .utf8)!, key: kRegion)
        let kSigning = hmacSha256(data: "aws4_request".data(using: .utf8)!, key: kService)
        return kSigning
    }
    
    // MARK: - Dynamic Categories
    
    /// Fetch all available bf-category tags from the database
    func fetchAvailableBFCategories() async throws -> [String] {
        print("🏷️ Fetching available bf-category tags...")
        
        // Use scan to get all items and extract unique bf-category tags
        let params = WebPageQueryParams(
            bfCategory: nil,
            bfSubcategory: nil,
            isActiveOnly: nil,
            source: nil,
            tags: nil,
            limit: 5000, // High limit to scan more items
            sortBy: .popularity,
            lastEvaluatedKey: nil
        )
        
        let items = try await performQuery(with: params)
        
        // Extract bf-category tags
        var categories = Set<String>()
        for item in items {
            for tag in item.tags {
                if tag.hasPrefix("bf-category:") {
                    let category = String(tag.dropFirst("bf-category:".count))
                    categories.insert(category.capitalized)
                }
            }
        }
        
        let sortedCategories = Array(categories).sorted()
        print("🏷️ Found bf-category tags: \(sortedCategories)")
        return sortedCategories
    }
    

    // MARK: - Memory Usage Tracking
    private func getMemoryUsage() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }
}

// MARK: - Extensions for Legacy Support
extension DynamoDBWebPageService {
    
    /// Legacy method names for backwards compatibility
    func fetchComputerMagazines(limit: Int = 50) async throws -> [AWSWebPageItem] {
        return try await fetchByTags(["computermagazines"], limit: limit)
    }
    
    func fetchClassicBooks(limit: Int = 50) async throws -> [AWSWebPageItem] {
        return try await fetchByTags(["gutenberg"], limit: limit)
    }
    
    func fetchMuseumArt(limit: Int = 50) async throws -> [AWSWebPageItem] {
        return try await fetchByTags(["art", "museum"], limit: limit)
    }
    
    func fetchHistoricalDocuments(limit: Int = 50) async throws -> [AWSWebPageItem] {
        return try await fetchByTags(["historical", "documents"], limit: limit)
    }
    
    func fetchRadioShows(limit: Int = 50) async throws -> [AWSWebPageItem] {
        return try await fetchByCultureContent(limit: limit)
    }
    
    private func fetchByCultureContent(limit: Int) async throws -> [AWSWebPageItem] {
        return try await fetchBySource("internet-archive-culture", limit: limit)
    }
}