import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Internet Archive Response Models
struct InternetArchiveSearchResponse: Codable {
    let response: InternetArchiveSearchData
}

struct InternetArchiveSearchData: Codable {
    let docs: [InternetArchiveSearchItem]
    let numFound: Int
}

struct InternetArchiveSearchItem: Codable {
    let identifier: String
    let title: String?
    let description: String?
    let creator: String?
    let date: String?
    let downloads: Int?
    let subject: [String]?
    let collection: [String]?
    let language: String?
    let mediatype: String?
    let addeddate: String?
    let publicdate: String?
}

// MARK: - Collection Configuration
struct CollectionConfig {
    let name: String
    let category: String
    let source: String
    let targetCount: Int
    
    static let allCollections = [
        CollectionConfig(name: "nasa", category: "Science", source: "internet-archive-science", targetCount: 5000),
        CollectionConfig(name: "computermagazines", category: "Technology", source: "internet-archive-tech", targetCount: 5000),
        CollectionConfig(name: "gutenberg", category: "Books", source: "internet-archive-books", targetCount: 5000),
        CollectionConfig(name: "library_of_congress", category: "History", source: "internet-archive-history", targetCount: 5000),
        CollectionConfig(name: "metropolitanmuseumofart-gallery", category: "Art", source: "internet-archive-art", targetCount: 5000),
        CollectionConfig(name: "oldtimeradio", category: "Culture", source: "internet-archive-culture", targetCount: 5000)
    ]
}

// MARK: - Internet Archive Collection Service
class InternetArchiveCollectionService {
    static let shared = InternetArchiveCollectionService()
    
    private let baseURL = "https://archive.org/advancedsearch.php"
    private let requestsPerSecond = 10.0
    private let itemsPerRequest = 1000
    private let minDownloads = 100 // Quality threshold
    
    private init() {}
    
    // MARK: - Collect All Collections
    func collectAllCollections() async throws -> [AWSWebPageItem] {
        print("🚀 Starting Internet Archive collection from all 6 collections...")
        print("📊 Target: ~30K items (5K from each collection)")
        
        var allItems: [AWSWebPageItem] = []
        let startTime = Date()
        
        for config in CollectionConfig.allCollections {
            print("\n🔄 Processing collection: \(config.name) (target: \(config.targetCount) items)")
            
            do {
                let items = try await collectFromSingleCollection(config)
                allItems.append(contentsOf: items)
                print("✅ Collected \(items.count) items from \(config.name)")
                
            } catch {
                print("❌ Failed to collect from \(config.name): \(error)")
                throw error
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("\n🎉 Collection complete!")
        print("📊 Total collected: \(allItems.count) items")
        print("⏱️  Duration: \(Int(duration/60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s")
        
        return allItems
    }
    
    // MARK: - Collect From Single Collection
    private func collectFromSingleCollection(_ config: CollectionConfig) async throws -> [AWSWebPageItem] {
        var allItems: [AWSWebPageItem] = []
        var page = 1
        let maxPages = (config.targetCount / itemsPerRequest) + 1
        
        while allItems.count < config.targetCount && page <= maxPages {
            print("  📄 Fetching page \(page) from \(config.name)...")
            
            let items = try await fetchPage(collection: config.name, page: page, config: config)
            allItems.append(contentsOf: items)
            
            print("  ✅ Page \(page): got \(items.count) items (total: \(allItems.count))")
            
            // Rate limiting
            let delay = 1.0 / requestsPerSecond
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            page += 1
            
            // If we got fewer items than requested, we've reached the end
            if items.count < itemsPerRequest {
                break
            }
        }
        
        // Limit to target count
        return Array(allItems.prefix(config.targetCount))
    }
    
    // MARK: - Fetch Single Page
    private func fetchPage(collection: String, page: Int, config: CollectionConfig) async throws -> [AWSWebPageItem] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "collection:\(collection)"),
            URLQueryItem(name: "fl", value: "identifier,title,description,creator,date,downloads,subject,collection,language,mediatype,addeddate,publicdate"),
            URLQueryItem(name: "rows", value: String(itemsPerRequest)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "sort", value: "downloads desc") // Most popular first
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "InternetArchive", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"
                ])
            }
        }
        
        let searchResponse = try JSONDecoder().decode(InternetArchiveSearchResponse.self, from: data)
        
        // Filter by download count and transform
        let filteredItems = searchResponse.response.docs.filter { item in
            (item.downloads ?? 0) >= minDownloads
        }
        
        return filteredItems.map { item in
            transformToAWSWebPage(item, config: config)
        }
    }
    
    // MARK: - Transform to AWS WebPage
    private func transformToAWSWebPage(_ item: InternetArchiveSearchItem, config: CollectionConfig) -> AWSWebPageItem {
        let now = Date()
        let url = "https://archive.org/details/\(item.identifier)"
        let thumbnailUrl = "https://archive.org/services/img/\(item.identifier)"
        
        // Generate rich tags
        var tags: [String] = []
        
        // Add collection tags
        if let collections = item.collection {
            tags.append(contentsOf: collections)
        }
        
        // Add subject tags
        if let subjects = item.subject {
            tags.append(contentsOf: subjects.prefix(5)) // Limit to avoid too many tags
        }
        
        // Add creator tag
        if let creator = item.creator, !creator.isEmpty {
            tags.append(creator)
        }
        
        // Add era tag from date
        if let dateString = item.date {
            if let era = extractEra(from: dateString) {
                tags.append(era)
            }
        }
        
        // Add language tag
        if let language = item.language, !language.isEmpty && language != "eng" {
            tags.append(language)
        }
        
        // Add category tag
        tags.append(config.category.lowercased())
        
        // Remove duplicates and empty strings
        tags = Array(Set(tags)).filter { !$0.isEmpty }
        
        // Parse created date
        let createdDate = parseDate(item.date ?? item.publicdate ?? item.addeddate)
        
        return AWSWebPageItem(
            url: url,
            id: "archive_\(item.identifier)_\(Int(now.timeIntervalSince1970))",
            title: item.title ?? "Untitled",
            domain: "archive.org",
            category: config.category,
            source: config.source,
            upvotes: item.downloads ?? 0,
            interactions: 0,
            tags: tags,
            thumbnailUrl: thumbnailUrl,
            createdDate: createdDate,
            postDate: nil,
            fetchedAt: now.iso8601String,
            updatedAt: now.iso8601String
        )
    }
    
    // MARK: - Helper Functions
    private func parseDate(_ dateString: String?) -> String? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }
        
        let formatters = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date.iso8601String
            }
        }
        
        return nil
    }
    
    private func extractEra(from dateString: String) -> String? {
        // Extract year and create era tags
        if let year = Int(dateString.prefix(4)) {
            switch year {
            case 1800..<1900: return "19th century"
            case 1900..<1950: return "early 20th century"
            case 1950..<1980: return "mid 20th century"
            case 1980..<2000: return "late 20th century"
            case 2000..<2010: return "2000s"
            case 2010..<2020: return "2010s"
            case 2020...: return "2020s"
            default: return nil
            }
        }
        return nil
    }
    
    // MARK: - Test Collection
    func testCollection(collection: String = "computermagazines", limit: Int = 10) async {
        print("🧪 Testing collection from \(collection) (limit: \(limit))...")
        
        let config = CollectionConfig.allCollections.first { $0.name == collection } ?? 
                     CollectionConfig(name: collection, category: "Test", source: "test", targetCount: limit)
        
        do {
            let items = try await fetchPage(collection: collection, page: 1, config: config)
            let limitedItems = Array(items.prefix(limit))
            
            print("✅ Test successful: collected \(limitedItems.count) items")
            
            // Print sample
            if let first = limitedItems.first {
                print("\n📝 Sample item:")
                print("  Title: \(first.title)")
                print("  URL: \(first.url)")
                print("  Thumbnail: \(first.thumbnailUrl)")
                print("  Category: \(first.category)")
                print("  Tags: \(first.tags.prefix(5).joined(separator: ", "))")
                print("  Upvotes: \(first.upvotes)")
            }
            
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
}