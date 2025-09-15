import Foundation

// MARK: - YouTube API Models
struct YouTubeSearchResponse: Codable {
    let items: [YouTubeVideo]
    let nextPageToken: String?
}

struct YouTubeVideo: Codable {
    let id: YouTubeVideoId
    let snippet: YouTubeSnippet
    let statistics: YouTubeStatistics?
    let contentDetails: YouTubeContentDetails?
}

struct YouTubeVideoId: Codable {
    let videoId: String
}

struct YouTubeSnippet: Codable {
    let publishedAt: String
    let channelId: String
    let title: String
    let description: String
    let thumbnails: YouTubeThumbnails
    let channelTitle: String
    let tags: [String]?
    let categoryId: String
}

struct YouTubeThumbnails: Codable {
    let maxres: YouTubeThumbnail?
    let high: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let `default`: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
    let width: Int?
    let height: Int?
}

struct YouTubeStatistics: Codable {
    let viewCount: String?
    let likeCount: String?
    let commentCount: String?
}

struct YouTubeContentDetails: Codable {
    let duration: String
    let definition: String?
    let caption: String?
}

// MARK: - YouTube API Service
class YouTubeAPIService {
    static let shared = YouTubeAPIService()
    
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let apiKey: String
    
    private init() {
        // Get API key from environment or plist
        self.apiKey = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? ""
        
        if apiKey.isEmpty {
            print("⚠️ YouTube API key not found. Set YOUTUBE_API_KEY environment variable.")
        }
    }
    
    // MARK: - Search Videos by Category
    func searchCategoryVideos(
        categoryId: String,
        maxResults: Int = 50,
        pageToken: String? = nil
    ) async throws -> YouTubeSearchResponse {
        
        let searchQuery = getSearchQuery(for: categoryId)
        
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: categoryId),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "order", value: "relevance"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        if let pageToken = pageToken {
            components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "YouTubeAPI", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "YouTube API error: \(errorMessage)"
            ])
        }
        
        return try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
    }
    
    // MARK: - Search Music Videos by Genre (Legacy)
    func searchMusicVideos(
        genre: String,
        maxResults: Int = 50,
        pageToken: String? = nil
    ) async throws -> YouTubeSearchResponse {
        
        let searchQuery = "\(genre) music official video"
        
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: "10"), // Music category
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "order", value: "relevance"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        if let pageToken = pageToken {
            components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "YouTubeAPI", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "YouTube API error: \(errorMessage)"
            ])
        }
        
        return try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
    }
    
    // MARK: - Get Video Details with Statistics
    func getVideoDetails(videoIds: [String]) async throws -> [YouTubeVideo] {
        let idsString = videoIds.joined(separator: ",")
        
        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,statistics,contentDetails"),
            URLQueryItem(name: "id", value: idsString),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let response = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        return response.items
    }
    
    // MARK: - Collect Category Videos
    func collectCategoryVideos(
        categoryId: String,
        targetCount: Int,
        minDuration: Int? = nil,
        maxDuration: Int? = nil
    ) async throws -> [AWSWebPageItem] {
        
        let categoryName = getCategoryName(categoryId)
        print("🎬 Collecting \(targetCount) \(categoryName) videos from YouTube...")
        
        // Check with tracker
        let tracker = YouTubeCollectionTracker.shared
        let sourceKey = "youtube-\(categoryName.lowercased().replacingOccurrences(of: " ", with: "-"))-\(categoryId)"
        
        if tracker.hasCollectedGenre(sourceKey) {
            print("⚠️ Already collected \(categoryName) videos. Skipping...")
            return []
        }
        
        guard let session = tracker.startCollectionSession(genre: sourceKey, targetCount: targetCount) else {
            print("❌ Cannot start collection session for \(categoryName)")
            return []
        }
        
        var allVideos: [YouTubeVideo] = []
        var nextPageToken: String? = nil
        let batchSize = 50 // YouTube API max per request
        var apiCallsUsed = 0
        
        // Collect videos in batches
        while allVideos.count < targetCount {
            print("📥 Fetching batch \(allVideos.count/batchSize + 1)...")
            
            let response = try await searchCategoryVideos(
                categoryId: categoryId,
                maxResults: batchSize,
                pageToken: nextPageToken
            )
            apiCallsUsed += 1
            
            allVideos.append(contentsOf: response.items)
            nextPageToken = response.nextPageToken
            
            // Break if no more videos available
            if nextPageToken == nil || response.items.isEmpty {
                break
            }
            
            // Rate limiting - YouTube API has quotas
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        // Get detailed statistics for all videos
        print("📊 Fetching detailed statistics...")
        let videoIds = allVideos.map { $0.id.videoId }
        let chunkedIds = videoIds.chunked(into: 50) // API limit per request
        
        var detailedVideos: [YouTubeVideo] = []
        for chunk in chunkedIds {
            let detailed = try await getVideoDetails(videoIds: chunk)
            detailedVideos.append(contentsOf: detailed)
            apiCallsUsed += 1
            
            // Update progress
            tracker.updateSession(
                sessionId: session.id,
                videosCollected: detailedVideos.count,
                apiCallsUsed: apiCallsUsed
            )
            
            // Rate limiting
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Filter by duration if specified
        var filteredVideos = detailedVideos
        if let minDur = minDuration, let maxDur = maxDuration {
            filteredVideos = detailedVideos.filter { video in
                guard let durationStr = video.contentDetails?.duration else { return false }
                let durationSeconds = parseDurationToSeconds(durationStr)
                return durationSeconds >= minDur && durationSeconds <= maxDur
            }
            print("🔍 Filtered to \(filteredVideos.count) videos within \(minDur)-\(maxDur) second range")
        }
        
        // Convert to AWS format
        let awsItems = filteredVideos.prefix(targetCount).enumerated().map { (index, video) in
            convertToAWSItem(video: video, categoryId: categoryId, index: index)
        }
        
        // Complete session
        tracker.completeSession(sessionId: session.id)
        
        print("✅ Collected \(awsItems.count) \(categoryName) videos")
        return Array(awsItems)
    }
    
    // MARK: - Convert YouTube Video to AWS Item
    private func convertToAWSItem(
        video: YouTubeVideo,
        categoryId: String,
        index: Int
    ) -> AWSWebPageItem {
        let currentDate = Date().iso8601String
        
        // Generate quality score based on engagement
        let qualityScore = calculateQualityScore(video: video)
        
        // Get duration
        let durationSeconds = parseDurationToSeconds(video.contentDetails?.duration ?? "PT0S")
        let durationFormatted = formatDuration(durationSeconds)
        
        // Generate AI-like fields based on video data
        let categoryName = getCategoryName(categoryId)
        let aiTopics = generateAITopics(video: video, categoryId: categoryId)
        let aiKeywords = generateAIKeywords(video: video, categoryId: categoryId)
        let aiSummary = generateAISummary(video: video, categoryId: categoryId)
        
        return AWSWebPageItem(
            url: "https://www.youtube.com/watch?v=\(video.id.videoId)",
            id: "youtube_\(categoryId)_\(video.id.videoId)_\(Int(Date().timeIntervalSince1970))_\(index)",
            title: video.snippet.title,
            domain: "youtube.com",
            category: categoryName,
            source: getSourceName(categoryId: categoryId),
            upvotes: Int(video.statistics?.likeCount ?? "0") ?? 0,
            interactions: Int(video.statistics?.viewCount ?? "0") ?? 0,
            tags: generateTags(video: video, categoryId: categoryId),
            thumbnailUrl: getBestThumbnailURL(video: video),
            createdDate: video.snippet.publishedAt,
            postDate: currentDate,
            fetchedAt: currentDate,
            updatedAt: currentDate,
            alternativeHeadline: [video.snippet.channelTitle, categoryName],
            internalLinks: ["https://www.youtube.com/channel/\(video.snippet.channelId)"],
            paragraphCount: 0,
            // New fields
            textContent: video.snippet.description,
            aiSummary: aiSummary,
            readingTimeMinutes: nil, // Videos don't have reading time
            aiTopics: aiTopics,
            contentType: "video", // All YouTube content is video
            qualityScore: qualityScore,
            aiKeywords: aiKeywords,
            relatedCategories: getRelatedCategories(categoryId: categoryId),
            difficulty: getDifficulty(categoryId: categoryId),
            thumbnailDescription: "\(categoryName) video thumbnail showing \(video.snippet.channelTitle)",
            durationSeconds: durationSeconds,
            videoDuration: durationFormatted
        )
    }
    
    // MARK: - Helper Functions
    private func calculateQualityScore(video: YouTubeVideo) -> Int {
        guard let viewCount = Int(video.statistics?.viewCount ?? "0"),
              let likeCount = Int(video.statistics?.likeCount ?? "0") else {
            return 5 // Default score
        }
        
        // Quality based on view count and engagement
        switch viewCount {
        case 100_000_000...: return 10 // 100M+ views
        case 10_000_000...: return 9   // 10M+ views
        case 1_000_000...: return 8    // 1M+ views
        case 100_000...: return 7      // 100K+ views
        case 10_000...: return 6       // 10K+ views
        default: return 5              // Under 10K views
        }
    }
    
    private func generateAITopics(video: YouTubeVideo, categoryId: String) -> [String] {
        let categoryName = getCategoryName(categoryId).lowercased()
        var topics = [categoryName]
        
        // Add topics based on title and description
        let text = "\(video.snippet.title) \(video.snippet.description)".lowercased()
        
        switch categoryId {
        case "25": // News & Politics
            if text.contains("election") { topics.append("election") }
            if text.contains("trump") || text.contains("biden") { topics.append("politics") }
            if text.contains("breaking") { topics.append("breaking-news") }
            
        case "27": // Education
            if text.contains("tutorial") { topics.append("tutorial") }
            if text.contains("explained") { topics.append("explanation") }
            if text.contains("lesson") { topics.append("lesson") }
            
        case "28": // Science & Technology
            if text.contains("ai") || text.contains("artificial") { topics.append("artificial-intelligence") }
            if text.contains("review") { topics.append("review") }
            if text.contains("iphone") || text.contains("apple") { topics.append("apple") }
            
        case "23": // Comedy
            if text.contains("stand") { topics.append("stand-up") }
            if text.contains("funny") { topics.append("humor") }
            if text.contains("sketch") { topics.append("sketch") }
            
        case "17": // Sports
            if text.contains("nfl") { topics.append("football") }
            if text.contains("nba") { topics.append("basketball") }
            if text.contains("highlights") { topics.append("highlights") }
            
        case "1": // Film & Animation
            if text.contains("movie") { topics.append("movie") }
            if text.contains("trailer") { topics.append("trailer") }
            if text.contains("animation") { topics.append("animation") }
            
        default:
            break
        }
        
        return Array(topics.prefix(5)) // Limit to 5 topics
    }
    
    private func generateAIKeywords(video: YouTubeVideo, categoryId: String) -> [String] {
        let categoryName = getCategoryName(categoryId).lowercased()
        var keywords = [categoryId, categoryName, "video"]
        
        // Add channel name
        keywords.append(video.snippet.channelTitle.lowercased())
        
        // Add year
        let year = String(video.snippet.publishedAt.prefix(4))
        keywords.append(year)
        
        // Add tags if available
        if let tags = video.snippet.tags {
            keywords.append(contentsOf: tags.prefix(3).map { $0.lowercased() })
        }
        
        return Array(keywords.prefix(10)) // Limit to 10 keywords
    }
    
    private func generateAISummary(video: YouTubeVideo, categoryId: String) -> String {
        let categoryName = getCategoryName(categoryId)
        let channel = video.snippet.channelTitle
        let title = video.snippet.title
        
        switch categoryId {
        case "25": // News & Politics
            return "\(categoryName) content by \(channel). \(title) provides current analysis and commentary on political developments."
        case "27": // Education
            return "\(categoryName) content by \(channel). \(title) offers educational insights and learning opportunities."
        case "28": // Science & Technology
            return "\(categoryName) content by \(channel). \(title) explores technological innovations and scientific developments."
        case "23": // Comedy
            return "\(categoryName) content by \(channel). \(title) delivers entertainment and humor for audience engagement."
        case "17": // Sports
            return "\(categoryName) content by \(channel). \(title) covers athletic competition and sports analysis."
        case "1": // Film & Animation
            return "\(categoryName) content by \(channel). \(title) showcases cinematic and animated storytelling."
        default:
            return "\(categoryName) video by \(channel). \(title) provides engaging content for viewers."
        }
    }
    
    private func generateTags(video: YouTubeVideo, categoryId: String) -> [String] {
        let categoryName = getCategoryName(categoryId).lowercased()
        var tags = [categoryId, categoryName]
        
        // Add channel tag
        let channelTag = video.snippet.channelTitle
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        tags.append(channelTag)
        
        // Add year
        let year = String(video.snippet.publishedAt.prefix(4))
        tags.append(year)
        
        // Add era
        if let yearInt = Int(year) {
            switch yearInt {
            case 2020...: tags.append("2020s")
            case 2010...: tags.append("2010s")
            case 2000...: tags.append("2000s")
            default: tags.append("classic")
            }
        }
        
        // Add quality tier based on views
        if let viewCount = Int(video.statistics?.viewCount ?? "0") {
            switch viewCount {
            case 100_000_000...: tags.append("viral")
            case 1_000_000...: tags.append("hit")
            default: tags.append("popular")
            }
        }
        
        return tags
    }
    
    private func getBestThumbnailURL(video: YouTubeVideo) -> String {
        let thumbnails = video.snippet.thumbnails
        
        if let maxres = thumbnails.maxres {
            return maxres.url
        } else if let high = thumbnails.high {
            return high.url
        } else if let medium = thumbnails.medium {
            return medium.url
        } else if let defaultThumb = thumbnails.default {
            return defaultThumb.url
        }
        
        // Fallback to standard YouTube thumbnail
        return "https://img.youtube.com/vi/\(video.id.videoId)/maxresdefault.jpg"
    }
    
    private func getRelatedCategories(categoryId: String) -> [String] {
        switch categoryId {
        case "25": return ["News", "Current Events", "Analysis"]
        case "27": return ["Learning", "Tutorial", "Knowledge"]
        case "28": return ["Innovation", "Reviews", "Tech News"]
        case "23": return ["Entertainment", "Humor", "Performance"]
        case "17": return ["Athletics", "Competition", "Analysis"]
        case "1": return ["Entertainment", "Storytelling", "Visual Arts"]
        default: return ["Entertainment", "Content"]
        }
    }
    
    // MARK: - New Helper Functions
    private func getCategoryName(_ categoryId: String) -> String {
        switch categoryId {
        case "1": return "Film & Animation"
        case "17": return "Sports"
        case "23": return "Comedy"
        case "25": return "News & Politics"
        case "27": return "Education"
        case "28": return "Science & Technology"
        default: return "Entertainment"
        }
    }
    
    private func getSourceName(categoryId: String) -> String {
        switch categoryId {
        case "1": return "youtube-film-animation"
        case "17": return "youtube-sports"
        case "23": return "youtube-comedy"
        case "25": return "youtube-news-politics"
        case "27": return "youtube-education"
        case "28": return "youtube-science-tech"
        default: return "youtube-entertainment"
        }
    }
    
    private func getSearchQuery(for categoryId: String) -> String {
        switch categoryId {
        case "25": return "news politics analysis breaking current events"
        case "27": return "education tutorial explained lesson learning"
        case "28": return "technology science tech review innovation"
        case "23": return "comedy funny humor stand-up sketch"
        case "17": return "sports highlights analysis game recap"
        case "1": return "film movie animation trailer short"
        default: return "popular trending"
        }
    }
    
    private func getDifficulty(categoryId: String) -> String {
        switch categoryId {
        case "25": return "intermediate" // News requires some context
        case "27": return "beginner" // Educational content is accessible
        case "28": return "intermediate" // Tech can be complex
        case "23": return "beginner" // Comedy is universal
        case "17": return "beginner" // Sports are accessible
        case "1": return "beginner" // Films are entertainment
        default: return "beginner"
        }
    }
    
    private func parseDurationToSeconds(_ isoDuration: String) -> Int {
        // Parse PT4M13S format
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: isoDuration, range: NSRange(isoDuration.startIndex..., in: isoDuration)) else {
            return 0
        }
        
        let hours = match.range(at: 1).location != NSNotFound ? 
            Int(String(isoDuration[Range(match.range(at: 1), in: isoDuration)!])) ?? 0 : 0
        let minutes = match.range(at: 2).location != NSNotFound ? 
            Int(String(isoDuration[Range(match.range(at: 2), in: isoDuration)!])) ?? 0 : 0
        let seconds = match.range(at: 3).location != NSNotFound ? 
            Int(String(isoDuration[Range(match.range(at: 3), in: isoDuration)!])) ?? 0 : 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Array Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}