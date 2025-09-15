import Foundation

// MARK: - AWS DynamoDB WebPage Item Model
struct AWSWebPageItem: Codable, Identifiable {
    let url: String
    let id: String
    let title: String
    let domain: String
    let category: String
    let bfCategory: String?
    let bfSubcategory: String?
    let source: String
    let upvotes: Int
    let interactions: Int
    let tags: [String]
    let thumbnailUrl: String
    let createdDate: String?
    let postDate: String?
    let fetchedAt: String
    let updatedAt: String
    
    // Enhanced fields for better content display
    let textContent: String?
    let aiSummary: String?
    let readingTimeMinutes: Int?
    let wordCount: Int?
    let aiTopics: [String]?
    let contentType: String?
    let qualityScore: Int?
    let aiKeywords: [String]?
    let relatedCategories: [String]?
    let difficulty: String?
    let thumbnailDescription: String?
    let alternativeHeadline: [String]
    let internalLinks: [String]
    let paragraphCount: Int
    
    // CloudKit compatibility fields
    let commentCount: Int?
    let likeCount: Int?
    let saveCount: Int?
    let isReported: Int?
    let reportCount: Int?
    let isActive: Bool
    
    // Computed properties for UI
    var formattedUpvotes: String {
        if upvotes >= 1000 {
            return String(format: "%.1fK", Double(upvotes) / 1000.0)
        }
        return "\(upvotes)"
    }
    
    var displayCategory: String {
        switch category.lowercased() {
        case "technology": return "Tech"
        case "science": return "Science"
        case "business": return "Business"
        case "general": return "News"
        case "internetarchive": return "Archive"
        default: return category.capitalized
        }
    }
    
    var sourceIcon: String {
        switch source {
        case let s where s.contains("reddit"): return "text.bubble"
        case let s where s.contains("wikipedia"): return "book"
        case let s where s.contains("internet-archive"): return "archivebox"
        case let s where s.contains("nasa"): return "sparkles"
        default: return "doc.text"
        }
    }
    
    var isHighQuality: Bool {
        return (qualityScore ?? 0) >= 7 || upvotes >= 100 || interactions >= 50
    }
}

// MARK: - Category Mapping Extension
extension AWSWebPageItem {
    
    /// Maps to BrowseForward category keys
    var browseForwardCategory: String {
        switch category.lowercased() {
        case "technology": return "technology"
        case "science": return "science"
        case "business": return "business"
        case "general": return "general"
        case "games": return "games"
        case "internetarchive": return "internetarchive"
        case "wikipedia": return "wikipedia"
        default: return category.lowercased()
        }
    }
    
    /// Determines if item should appear in specific subcategories
    func matchesSubcategory(_ subcategory: String) -> Bool {
        let lowercaseSubcategory = subcategory.lowercased()
        let lowercaseTags = tags.map { $0.lowercased() }
        
        switch lowercaseSubcategory {
        case "nasa":
            return lowercaseTags.contains("nasa") || source.contains("nasa")
        case "computer magazines", "computermagazines":
            return lowercaseTags.contains("computermagazines") || lowercaseTags.contains("computer")
        case "classic books", "books":
            return lowercaseTags.contains("gutenberg") || lowercaseTags.contains("books")
        case "museum art", "art":
            return lowercaseTags.contains("art") || lowercaseTags.contains("museum")
        case "historical documents", "documents":
            return lowercaseTags.contains("historical") || lowercaseTags.contains("documents")
        case "radio shows", "radio":
            return lowercaseTags.contains("radio") || lowercaseTags.contains("oldtimeradio")
        default:
            return lowercaseTags.contains(lowercaseSubcategory)
        }
    }
}

// MARK: - Sample Data for Previews
extension AWSWebPageItem {
    static let sampleData = [
        AWSWebPageItem(
            url: "https://en.wikipedia.org/wiki/Artificial_intelligence",
            id: "wiki_ai_001",
            title: "Artificial Intelligence - Wikipedia",
            domain: "en.wikipedia.org",
            category: "Technology",
            bfCategory: "technology",
            bfSubcategory: nil,
            source: "wikipedia-technology",
            upvotes: 0,
            interactions: 245,
            tags: ["AI", "Technology", "Computer Science"],
            thumbnailUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Artificial_intelligence_prompt_completion_by_dalle_mini.jpg/300px-Artificial_intelligence_prompt_completion_by_dalle_mini.jpg",
            createdDate: "2024-01-15T10:30:00Z",
            postDate: nil,
            fetchedAt: "2025-01-17T15:20:00Z",
            updatedAt: "2025-01-17T15:20:00Z",
            textContent: "Artificial intelligence (AI) is intelligence demonstrated by machines...",
            aiSummary: "Comprehensive overview of AI technologies and applications",
            readingTimeMinutes: 15,
            wordCount: 2500,
            aiTopics: ["Machine Learning", "Neural Networks", "Computer Vision"],
            contentType: "article",
            qualityScore: 9,
            aiKeywords: ["artificial intelligence", "machine learning", "technology"],
            relatedCategories: ["Science", "Technology"],
            difficulty: "intermediate",
            thumbnailDescription: "AI generated art showing artificial intelligence concepts",
            alternativeHeadline: ["AI Overview", "Machine Intelligence"],
            internalLinks: ["https://en.wikipedia.org/wiki/Machine_learning"],
            paragraphCount: 42,
            commentCount: 5,
            likeCount: 23,
            saveCount: 8,
            isReported: 0,
            reportCount: 0,
            isActive: true
        ),
        AWSWebPageItem(
            url: "https://archive.org/details/nasa-apollo-missions",
            id: "archive_nasa_001",
            title: "NASA Apollo Mission Archives",
            domain: "archive.org",
            category: "Science",
            bfCategory: "science",
            bfSubcategory: nil,
            source: "internet-archive-science",
            upvotes: 1250,
            interactions: 89,
            tags: ["NASA", "Space", "Apollo", "History"],
            thumbnailUrl: "https://archive.org/services/img/nasa-apollo-missions",
            createdDate: "1969-07-20T20:17:00Z",
            postDate: nil,
            fetchedAt: "2025-01-17T15:20:00Z",
            updatedAt: "2025-01-17T15:20:00Z",
            textContent: "Complete archive of NASA Apollo mission documentation...",
            aiSummary: "Historical archive of the Apollo space program",
            readingTimeMinutes: 45,
            wordCount: 8500,
            aiTopics: ["Space Exploration", "History", "Engineering"],
            contentType: "archive",
            qualityScore: 10,
            aiKeywords: ["nasa", "apollo", "space", "moon landing"],
            relatedCategories: ["History", "Science"],
            difficulty: "beginner",
            thumbnailDescription: "NASA Apollo spacecraft and mission documentation",
            alternativeHeadline: ["Apollo Archives", "Moon Mission Records"],
            internalLinks: [],
            paragraphCount: 156,
            commentCount: 12,
            likeCount: 67,
            saveCount: 34,
            isReported: 0,
            reportCount: 0,
            isActive: true
        )
    ]
}