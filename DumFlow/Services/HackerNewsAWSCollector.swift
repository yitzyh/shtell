import Foundation

class HackerNewsAWSCollector {
    private let hackerNewsService = HackerNewsService()
    
    // MARK: - Category Configuration
    
    private let categoryTargets: [String: Int] = [
        "technology": 400,
        "ai": 240,
        "programming": 240,
        "startup": 200,
        "business": 200,
        "finance": 120
    ]
    
    // MARK: - Domain Mapping
    
    private let domainToCategory: [String: String] = [
        // Technology
        "techcrunch.com": "technology",
        "theverge.com": "technology", 
        "arstechnica.com": "technology",
        "wired.com": "technology",
        "engadget.com": "technology",
        
        // AI/ML
        "openai.com": "ai",
        "anthropic.com": "ai",
        "deepmind.com": "ai",
        "huggingface.co": "ai",
        "nvidia.com": "ai",
        
        // Programming
        "github.com": "programming",
        "stackoverflow.com": "programming",
        "dev.to": "programming",
        "medium.com": "programming",
        "hackernoon.com": "programming",
        
        // Startup/Business
        "ycombinator.com": "startup",
        "forbes.com": "business",
        "bloomberg.com": "business",
        "wsj.com": "business",
        "ft.com": "business",
        
        // Finance/Crypto
        "coinbase.com": "finance",
        "binance.com": "finance",
        "coindesk.com": "finance",
        "reuters.com": "finance"
    ]
    
    // MARK: - Keyword Mapping
    
    private let keywordToCategory: [String: String] = [
        // AI Keywords
        "artificial intelligence": "ai",
        "machine learning": "ai",
        "chatgpt": "ai",
        "openai": "ai",
        "claude": "ai",
        "neural": "ai",
        "transformer": "ai",
        
        // Programming Keywords
        "javascript": "programming",
        "python": "programming",
        "react": "programming",
        "github": "programming",
        "api": "programming",
        "database": "programming",
        "framework": "programming",
        
        // Startup Keywords
        "funding": "startup",
        "series a": "startup",
        "venture": "startup",
        "y combinator": "startup",
        "silicon valley": "startup",
        
        // Finance Keywords
        "bitcoin": "finance",
        "cryptocurrency": "finance",
        "blockchain": "finance",
        "stock": "finance",
        "investment": "finance"
    ]
    
    // MARK: - Main Collection Function
    
    func collectBalancedHackerNewsToAWS() async throws {
        print("🚀 Starting balanced HackerNews collection for 2025...")
        print("📊 Target distribution: \(categoryTargets)")
        
        // Get all 2025 stories with metadata
        let stories = try await fetchHackerNewsStories(year: 2025, limit: 1400) // Get extra to ensure we hit targets
        print("📰 Fetched \(stories.count) stories from 2025")
        
        // Categorize stories
        let categorizedStories = categorizeStories(stories)
        
        // Balance to targets
        let balancedStories = balanceToTargets(categorizedStories)
        
        print("📊 Final balanced distribution:")
        for (category, items) in balancedStories {
            print("  - \(category): \(items.count) items")
        }
        
        // Save to JSON for Python upload
        let totalItems = balancedStories.values.flatMap { $0 }
        print("📤 Saving \(totalItems.count) items to JSON for Python upload...")
        
        try saveStoriesToJSON(Array(totalItems))
        
        print("✅ HackerNews collection completed! Run Python upload script next.")
    }
    
    // MARK: - Story Fetching
    
    private func fetchHackerNewsStories(year: Int, limit: Int) async throws -> [CategorizedHNStory] {
        print("📡 Fetching top stories from HackerNews API...")
        
        let topStoryIDs = try await hackerNewsService.fetchTopStoryIDs()
        print("📊 Got \(topStoryIDs.count) top story IDs")
        
        // Calculate year boundaries
        let calendar = Calendar(identifier: .gregorian)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let startOfNextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        
        let yearStartTimestamp = startOfYear.timeIntervalSince1970
        let yearEndTimestamp = startOfNextYear.timeIntervalSince1970
        
        var stories: [CategorizedHNStory] = []
        var processedCount = 0
        
        for storyID in topStoryIDs {
            if stories.count >= limit {
                break
            }
            
            do {
                if let story = try await hackerNewsService.fetchStory(id: storyID) {
                    let storyTimestamp = Double(story.time)
                    
                    // Check if story is from the specified year and has external URL
                    if storyTimestamp >= yearStartTimestamp && storyTimestamp < yearEndTimestamp,
                       let url = story.url, !url.isEmpty, !url.contains("news.ycombinator.com") {
                        
                        let categorizedStory = CategorizedHNStory(
                            id: story.id,
                            title: story.title ?? "",
                            url: url,
                            author: story.by ?? "",
                            timestamp: story.time,
                            score: story.score ?? 0,
                            commentCount: story.descendants ?? 0
                        )
                        
                        stories.append(categorizedStory)
                        
                        if stories.count % 50 == 0 {
                            print("📈 Processed \(stories.count) valid stories")
                        }
                    }
                }
                
                processedCount += 1
                
                // Rate limiting
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
            } catch {
                print("⚠️ Error fetching story \(storyID): \(error)")
                continue
            }
        }
        
        print("✅ Collected \(stories.count) stories from \(year)")
        return stories
    }
    
    // MARK: - Categorization
    
    private func categorizeStories(_ stories: [CategorizedHNStory]) -> [String: [CategorizedHNStory]] {
        print("🏷️ Categorizing \(stories.count) stories...")
        
        var categorized: [String: [CategorizedHNStory]] = [:]
        for category in categoryTargets.keys {
            categorized[category] = []
        }
        
        for story in stories {
            let category = determineCategory(for: story)
            categorized[category, default: []].append(story)
        }
        
        print("📊 Initial categorization:")
        for (category, items) in categorized {
            print("  - \(category): \(items.count) items")
        }
        
        return categorized
    }
    
    private func determineCategory(for story: CategorizedHNStory) -> String {
        let title = story.title.lowercased()
        let url = story.url.lowercased()
        
        // 1. Domain-based categorization
        if let domain = extractDomain(from: story.url),
           let category = domainToCategory[domain] {
            return category
        }
        
        // 2. Keyword-based categorization
        for (keyword, category) in keywordToCategory {
            if title.contains(keyword) || url.contains(keyword) {
                return category
            }
        }
        
        // 3. Fallback to technology
        return "technology"
    }
    
    private func extractDomain(from url: String) -> String? {
        guard let urlObj = URL(string: url) else { return nil }
        return urlObj.host?.lowercased()
    }
    
    // MARK: - Balancing
    
    private func balanceToTargets(_ categorized: [String: [CategorizedHNStory]]) -> [String: [CategorizedHNStory]] {
        print("⚖️ Balancing categories to targets...")
        
        var balanced: [String: [CategorizedHNStory]] = [:]
        
        for (category, target) in categoryTargets {
            let available = categorized[category] ?? []
            let selected = Array(available.shuffled().prefix(target))
            balanced[category] = selected
            
            if selected.count < target {
                print("⚠️ \(category): Only \(selected.count)/\(target) items available")
            }
        }
        
        return balanced
    }
    
    // MARK: - JSON Export
    
    private func saveStoriesToJSON(_ stories: [CategorizedHNStory]) throws {
        let jsonData = stories.map { story in
            createJSONItem(from: story)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(jsonData)
        
        let fileURL = URL(fileURLWithPath: "hackernews_collection.json")
        try data.write(to: fileURL)
        
        print("💾 Saved \(stories.count) items to: \(fileURL.path)")
    }
    
    private func createJSONItem(from story: CategorizedHNStory) -> [String: Any] {
        let category = determineCategory(for: story)
        let domain = extractDomain(from: story.url) ?? "unknown"
        
        // Create comprehensive tags
        var tags = ["hackernews", "2025", category]
        
        // Add domain-based tags
        if let domainCategory = domainToCategory[domain] {
            tags.append(domainCategory)
        }
        
        // Add keyword-based tags
        let title = story.title.lowercased()
        for (keyword, _) in keywordToCategory {
            if title.contains(keyword) {
                tags.append(keyword.replacingOccurrences(of: " ", with: ""))
            }
        }
        
        // Add domain tag
        tags.append(domain.replacingOccurrences(of: ".", with: ""))
        
        return [
            "id": "hackernews_\(story.id)_2025",
            "url": story.url,
            "title": story.title,
            "source": "hackernews",
            "author": story.author,
            "timestamp": story.timestamp,
            "score": story.score,
            "commentCount": story.commentCount,
            "tags": Array(Set(tags)), // Remove duplicates
            "category": category,
            "domain": domain,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
    }
}

// MARK: - Supporting Types

struct CategorizedHNStory {
    let id: Int
    let title: String
    let url: String
    let author: String
    let timestamp: Int
    let score: Int
    let commentCount: Int
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - HackerNewsService Extension

extension HackerNewsService {
    func fetchTopStoryIDs() async throws -> [Int] {
        let urlString = "https://hacker-news.firebaseio.com/v0/topstories.json"
        
        guard let url = URL(string: urlString) else {
            throw HNError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let storyIDs = try JSONDecoder().decode([Int].self, from: data)
        
        return storyIDs
    }
    
    func fetchStory(id: Int) async throws -> HNStory? {
        let urlString = "https://hacker-news.firebaseio.com/v0/item/\(id).json"
        
        guard let url = URL(string: urlString) else {
            throw HNError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Handle null responses (deleted stories)
        if data.count <= 4 { // "null" response
            return nil
        }
        
        let story = try JSONDecoder().decode(HNStory.self, from: data)
        return story
    }
}