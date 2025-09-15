import Foundation

class ContentMappingService {
    static let shared = ContentMappingService()
    
    private init() {}
    
    func mapSourceToCategory(_ source: String) -> String {
        switch source.lowercased() {
        case "wikipedia-technology", "wikipedia-featured":
            return "technology"
        case "wikipedia-science", "wikipedia-good":
            return "science"
        case "wikipedia-history", "wikipedia-philosophy", "wikipedia-art", 
             "wikipedia-health", "wikipedia-geography", "wikipedia-politics":
            return "general"
            
        case "internet-archive-tech", "internet-archive-science", 
             "internet-archive-books", "internet-archive-history":
            return "internetarchive"
            
        case "reddit-technology":
            return "technology"
        case "reddit-science":
            return "science"
        case "reddit-business", "reddit-economics", "reddit-investing":
            return "business"
        case "reddit-politics", "reddit-worldnews", "reddit-news", 
             "reddit-history", "reddit-philosophy", "reddit-art", "reddit-medicine":
            return "general"
        case "reddit-webgames":
            return "games"
            
        default:
            return "general"
        }
    }
    
    func mapTagsToCategory(_ tags: [String]) -> String {
        let tagSet = Set(tags.map { $0.lowercased() })
        
        let techTags: Set<String> = ["technology", "tech", "ai", "software", "hardware", 
                                   "programming", "computer", "digital", "internet", "coding",
                                   "apple", "gadgets", "computermagazines"]
        
        let scienceTags: Set<String> = ["science", "physics", "chemistry", "biology", 
                                      "research", "study", "academic", "space", "astronomy",
                                      "nasa", "medical", "medicine", "health"]
        
        let businessTags: Set<String> = ["business", "economics", "finance", "investing", 
                                       "money", "market", "economy", "trade", "corporate"]
        
        let archiveTags: Set<String> = ["gutenberg", "nasa", "computermagazines", 
                                      "opensource", "magazine_rack", "folkscanomy", 
                                      "americana", "toronto", "archive"]
        
        let gamesTags: Set<String> = ["games", "gaming", "webgames", "entertainment"]
        
        let techScore = tagSet.intersection(techTags).count
        let scienceScore = tagSet.intersection(scienceTags).count  
        let businessScore = tagSet.intersection(businessTags).count
        let archiveScore = tagSet.intersection(archiveTags).count
        let gamesScore = tagSet.intersection(gamesTags).count
        
        let scores = [
            ("technology", techScore),
            ("science", scienceScore), 
            ("business", businessScore),
            ("internetarchive", archiveScore),
            ("games", gamesScore)
        ]
        
        let bestMatch = scores.max { $0.1 < $1.1 }
        return bestMatch?.1 > 0 ? bestMatch!.0 : "general"
    }
    
    func mapContentToCategory(source: String, tags: [String], category: String? = nil) -> String {
        if let category = category, isValidBrowseForwardCategory(category) {
            return mapCategoryToBrowseForward(category)
        }
        
        let sourceCategory = mapSourceToCategory(source)
        if sourceCategory != "general" {
            return sourceCategory
        }
        
        let tagCategory = mapTagsToCategory(tags)
        return tagCategory
    }
    
    private func isValidBrowseForwardCategory(_ category: String) -> Bool {
        let validCategories: Set<String> = [
            "technology", "business", "science", "general", "games",
            "hackernews", "wikipedia", "internetarchive", "saved", "trending"
        ]
        return validCategories.contains(category.lowercased())
    }
    
    private func mapCategoryToBrowseForward(_ category: String) -> String {
        switch category.lowercased() {
        case "technology", "tech":
            return "technology"
        case "business", "economics", "finance":
            return "business"
        case "science", "research", "academic":
            return "science"
        case "news", "politics", "world", "history", "art", "philosophy", "health", "medicine":
            return "general"
        case "games", "gaming", "entertainment":
            return "games"
        case "books", "documents", "archive", "historical":
            return "internetarchive"
        default:
            return "general"
        }
    }
    
    func getSourceFiltersForCategory(_ category: String) -> [String] {
        switch category.lowercased() {
        case "technology":
            return [
                "wikipedia-technology", "wikipedia-featured",
                "reddit-technology", "reddit-apple", "reddit-gadgets", "reddit-hardware",
                "internet-archive-tech"
            ]
            
        case "science":
            return [
                "wikipedia-science", "wikipedia-good", 
                "reddit-science", "reddit-space", "reddit-astronomy",
                "internet-archive-science"
            ]
            
        case "business":
            return [
                "reddit-business", "reddit-economics", "reddit-investing"
            ]
            
        case "general":
            return [
                "wikipedia-history", "wikipedia-philosophy", "wikipedia-art", 
                "wikipedia-health", "wikipedia-geography", "wikipedia-politics",
                "reddit-politics", "reddit-worldnews", "reddit-news", 
                "reddit-history", "reddit-philosophy", "reddit-art", "reddit-medicine"
            ]
            
        case "games":
            return [
                "reddit-webgames"
            ]
            
        case "internetarchive":
            return [
                "internet-archive-tech", "internet-archive-science",
                "internet-archive-books", "internet-archive-history"
            ]
            
        default:
            return []
        }
    }
    
    func getTagFiltersForCategory(_ category: String) -> [String] {
        switch category.lowercased() {
        case "technology":
            return ["technology", "tech", "ai", "software", "hardware", "programming", 
                   "computer", "digital", "apple", "gadgets", "computermagazines"]
            
        case "science":
            return ["science", "physics", "chemistry", "biology", "research", "space", 
                   "astronomy", "nasa", "medical", "medicine", "hackernews"]
            
        case "business":
            return ["business", "economics", "finance", "investing", "money", "market", "economy", 
                   "startup", "hackernews"]
            
        case "internetarchive":
            return ["gutenberg", "nasa", "computermagazines", "opensource", "archive", 
                   "historical", "documents", "books"]
            
        case "games":
            return ["games", "gaming", "webgames", "entertainment"]
            
        default:
            return []
        }
    }
    
    func generateQueryForCategory(_ category: String, limit: Int = 50) -> DynamoDBQuery {
        let sources = getSourceFiltersForCategory(category)
        let tags = getTagFiltersForCategory(category)
        
        return DynamoDBQuery(
            category: category,
            sources: sources,
            tags: tags,
            limit: limit
        )
    }
    
    func getContentPriority(source: String, upvotes: Int, interactions: Int) -> Int {
        var priority = 0
        
        switch source.lowercased() {
        case let s where s.contains("featured"):
            priority += 100
        case let s where s.contains("good"):
            priority += 80
        case let s where s.hasPrefix("reddit"):
            priority += 60
        case let s where s.hasPrefix("internet-archive"):
            priority += 40
        default:
            priority += 20
        }
        
        priority += min(upvotes / 100, 50)
        priority += min(interactions / 10, 30)
        
        return priority
    }
    
    func getContentFreshness(createdDate: String?, postDate: String?, fetchedAt: String) -> Double {
        let now = Date()
        
        let relevantDate: Date
        if let postDate = postDate, let date = ISO8601DateFormatter().date(from: postDate) {
            relevantDate = date
        } else if let createdDate = createdDate, let date = ISO8601DateFormatter().date(from: createdDate) {
            relevantDate = date
        } else if let fetchedDate = ISO8601DateFormatter().date(from: fetchedAt) {
            relevantDate = fetchedDate
        } else {
            return 0.0
        }
        
        let daysSinceRelevant = now.timeIntervalSince(relevantDate) / 86400
        return max(0.0, 1.0 - (daysSinceRelevant / 365.0))
    }
}

struct DynamoDBQuery {
    let category: String
    let sources: [String]
    let tags: [String]
    let limit: Int
    
    var filterExpression: String {
        var expressions: [String] = []
        
        if !sources.isEmpty {
            let sourceConditions = sources.map { "source = :source_\($0.replacingOccurrences(of: "-", with: "_"))" }
            expressions.append("(\(sourceConditions.joined(separator: " OR ")))")
        }
        
        if !tags.isEmpty {
            let tagConditions = tags.map { "contains(tags, :tag_\($0))" }
            expressions.append("(\(tagConditions.joined(separator: " OR ")))")
        }
        
        return expressions.joined(separator: " AND ")
    }
    
    var expressionAttributeValues: [String: Any] {
        var values: [String: Any] = [:]
        
        for source in sources {
            values[":source_\(source.replacingOccurrences(of: "-", with: "_"))"] = ["S": source]
        }
        
        for tag in tags {
            values[":tag_\(tag)"] = ["S": tag]
        }
        
        return values
    }
}