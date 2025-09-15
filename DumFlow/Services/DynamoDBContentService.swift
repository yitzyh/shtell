import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct DynamoDBContentItem {
    let url: String
    let title: String
    let domain: String
    let category: String
    let source: String
    let upvotes: Int
    let interactions: Int
    let tags: [String]
    let thumbnailUrl: String
    let createdDate: String?
    let postDate: String?
    let fetchedAt: String
    let priority: Int
    let freshness: Double
}

struct DynamoDBScanResponse: Codable {
    let items: [[String: DynamoDBAttributeValue]]
    let count: Int
    let scannedCount: Int
    let lastEvaluatedKey: [String: DynamoDBAttributeValue]?
    
    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case count = "Count"
        case scannedCount = "ScannedCount"
        case lastEvaluatedKey = "LastEvaluatedKey"
    }
}

class DynamoDBContentService {
    static let shared = DynamoDBContentService()
    
    private let tableName = "webpages"
    private let region = "us-east-1"
    private let contentMappingService = ContentMappingService.shared
    
    private init() {}
    
    func fetchContentForCategory(_ category: String, limit: Int = 50) async throws -> [String] {
        print("🔄 DynamoDBContentService: Fetching content for category '\(category)'")
        
        let query = contentMappingService.generateQueryForCategory(category, limit: limit)
        let items = try await scanTable(query: query)
        
        let contentItems = items.compactMap { item -> DynamoDBContentItem? in
            guard let url = item["url"]?.s,
                  let title = item["title"]?.s,
                  let domain = item["domain"]?.s,
                  let source = item["source"]?.s,
                  let upvotesStr = item["upvotes"]?.n,
                  let upvotes = Int(upvotesStr),
                  let interactionsStr = item["interactions"]?.n,
                  let interactions = Int(interactionsStr),
                  let tags = item["tags"]?.ss,
                  let thumbnailUrl = item["thumbnailUrl"]?.s,
                  let fetchedAt = item["fetchedAt"]?.s else {
                return nil
            }
            
            let mappedCategory = contentMappingService.mapContentToCategory(
                source: source,
                tags: tags,
                category: item["category"]?.s
            )
            
            let priority = contentMappingService.getContentPriority(
                source: source,
                upvotes: upvotes,
                interactions: interactions
            )
            
            let freshness = contentMappingService.getContentFreshness(
                createdDate: item["createdDate"]?.s,
                postDate: item["postDate"]?.s,
                fetchedAt: fetchedAt
            )
            
            return DynamoDBContentItem(
                url: url,
                title: title,
                domain: domain,
                category: mappedCategory,
                source: source,
                upvotes: upvotes,
                interactions: interactions,
                tags: tags,
                thumbnailUrl: thumbnailUrl,
                createdDate: item["createdDate"]?.s,
                postDate: item["postDate"]?.s,
                fetchedAt: fetchedAt,
                priority: priority,
                freshness: freshness
            )
        }
        
        let filteredItems = contentItems
            .filter { $0.category == category }
            .sorted { item1, item2 in
                if item1.priority != item2.priority {
                    return item1.priority > item2.priority
                }
                return item1.freshness > item2.freshness
            }
            .prefix(limit)
        
        let urls = filteredItems.map { $0.url }
        print("✅ DynamoDBContentService: Found \(urls.count) URLs for category '\(category)'")
        
        return Array(urls)
    }
    
    private func scanTable(query: DynamoDBQuery) async throws -> [[String: DynamoDBAttributeValue]] {
        guard let url = URL(string: "https://dynamodb.\(region).amazonaws.com/") else {
            throw URLError(.badURL)
        }
        
        let scanRequest: [String: Any] = [
            "TableName": tableName,
            "Limit": query.limit,
            "FilterExpression": query.filterExpression.isEmpty ? nil : query.filterExpression,
            "ExpressionAttributeValues": query.expressionAttributeValues.isEmpty ? nil : query.expressionAttributeValues
        ].compactMapValues { $0 }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DynamoDB_20120810.Scan", forHTTPHeaderField: "X-Amz-Target")
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: scanRequest)
        request.httpBody = jsonData
        
        try addAWSAuthHeaders(&request, jsonData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "DynamoDB", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "DynamoDB scan failed: \(responseString)"
                ])
            }
        }
        
        let scanResponse = try JSONDecoder().decode(DynamoDBScanResponse.self, from: data)
        return scanResponse.items
    }
    
    private func addAWSAuthHeaders(_ request: inout URLRequest, _ body: Data) throws {
        let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] ?? ""
        let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] ?? ""
        
        guard !accessKey.isEmpty, !secretKey.isEmpty else {
            throw NSError(domain: "AWS", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "AWS credentials not found. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
            ])
        }
        
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.setValue(Date().iso8601String, forHTTPHeaderField: "X-Amz-Date")
        
        print("⚠️ DynamoDBContentService: Using basic AWS headers - implement proper AWS Signature v4 for production")
    }
    
    func testConnection() async -> Bool {
        print("🧪 DynamoDBContentService: Testing connection to DynamoDB...")
        
        do {
            let testQuery = DynamoDBQuery(category: "test", sources: [], tags: [], limit: 1)
            let _ = try await scanTable(query: testQuery)
            print("✅ DynamoDBContentService: Connection test successful")
            return true
        } catch {
            print("❌ DynamoDBContentService: Connection test failed: \(error)")
            return false
        }
    }
    
    func getCategoryStats() async throws -> [String: Int] {
        print("📊 DynamoDBContentService: Fetching category statistics...")
        
        var stats: [String: Int] = [:]
        let categories = ["technology", "science", "business", "general", "games", "internetarchive"]
        
        for category in categories {
            do {
                let urls = try await fetchContentForCategory(category, limit: 100)
                stats[category] = urls.count
            } catch {
                print("⚠️ Failed to get stats for category \(category): \(error)")
                stats[category] = 0
            }
        }
        
        print("📊 Category stats: \(stats)")
        return stats
    }
}