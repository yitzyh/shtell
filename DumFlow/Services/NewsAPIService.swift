import Foundation
import CloudKit

class NewsAPIService {
    
    private let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - NewsAPI Models
    
    struct NewsAPIResponse: Codable {
        let status: String
        let totalResults: Int
        let articles: [NewsArticle]
    }
    
    struct NewsArticle: Codable {
        let url: String
    }
    
    // MARK: - Fetch and Save URLs
    
    func fetchAndSaveURLs(for categories: [String]) async throws {
        print("🗞️ NewsAPIService: Starting fetch for categories: \(categories)")
        
        var allURLs: [String] = []
        
        for category in categories {
            let urls = try await fetchCategoryURLs(category)
            allURLs.append(contentsOf: urls)
            // Add delay between requests
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Save all URLs to CloudKit as a single record
        try await saveURLsToCloudKit(allURLs)
        
        print("✅ NewsAPIService: Saved \(allURLs.count) URLs to CloudKit")
    }
    
    private func fetchCategoryURLs(_ category: String) async throws -> [String] {
        let urlString = "https://newsapi.org/v2/top-headlines?category=\(category)&pageSize=30&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw NewsAPIError.invalidURL
        }
        
        print("📡 NewsAPIService: Fetching \(category) URLs...")
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
        
        let urls = response.articles.map { $0.url }
        print("📰 NewsAPIService: Got \(urls.count) \(category) URLs")
        
        return urls
    }
    
    private func saveURLsToCloudKit(_ urls: [String]) async throws {
        let recordID = CKRecord.ID(recordName: "newsapi_urls")
        
        // Try to fetch existing record or create new one
        let record: CKRecord
        do {
            record = try await publicDatabase.record(for: recordID)
            print("📝 Updating existing URLs record")
        } catch {
            record = CKRecord(recordType: "NewsURLs", recordID: recordID)
            print("📝 Creating new URLs record")
        }
        
        // Save URLs as array
        record["urls"] = urls as [NSString]
        record["lastUpdated"] = Date() as NSDate
        
        try await publicDatabase.save(record)
        print("✅ Saved \(urls.count) URLs to CloudKit")
    }
}

// MARK: - Errors

enum NewsAPIError: Error {
    case invalidURL
    case invalidResponse
    case apiKeyMissing
}

// MARK: - Main Function for GitHub Actions

@main
struct NewsAPIFetcher {
    static func main() async {
        print("🚀 Starting NewsAPI URL fetch...")
        
        guard let apiKey = ProcessInfo.processInfo.environment["NEWSAPI_KEY"] else {
            print("❌ NEWSAPI_KEY environment variable not found")
            exit(1)
        }
        
        let service = NewsAPIService(apiKey: apiKey)
        let categories = ["technology", "business", "science", "general"]
        
        do {
            try await service.fetchAndSaveURLs(for: categories)
            print("🎉 NewsAPI URL fetch completed successfully!")
        } catch {
            print("❌ NewsAPI URL fetch failed: \(error)")
            exit(1)
        }
    }
}