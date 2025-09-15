import Foundation

class HackerNewsService {
    
    // MARK: - HackerNews Models
    
    struct HNStory: Codable {
        let id: Int
        let title: String?
        let url: String?
        let by: String?
        let time: Int // Unix timestamp
        let score: Int?
        let descendants: Int? // Number of comments
    }
    
    // MARK: - Main Functions
    
    func fetchTop500URLsFromYear(_ year: Int) async throws -> [String] {
        print("📰 HackerNewsService: Starting fetch for top 500 stories from \(year)")
        
        // Get top story IDs
        let topStoryIDs = try await fetchTopStoryIDs()
        print("📊 HackerNewsService: Got \(topStoryIDs.count) top story IDs")
        
        // Calculate year boundaries
        let calendar = Calendar(identifier: .gregorian)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let startOfNextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        
        let yearStartTimestamp = startOfYear.timeIntervalSince1970
        let yearEndTimestamp = startOfNextYear.timeIntervalSince1970
        
        var urls: [String] = []
        var processedCount = 0
        
        print("🗓️ Looking for stories between \(startOfYear) and \(startOfNextYear)")
        
        // Process stories in batches to avoid overwhelming the API
        for storyID in topStoryIDs {
            if urls.count >= 500 {
                break // We have enough URLs
            }
            
            do {
                if let story = try await fetchStory(id: storyID) {
                    let storyTimestamp = Double(story.time)
                    
                    // Check if story is from the specified year
                    if storyTimestamp >= yearStartTimestamp && storyTimestamp < yearEndTimestamp {
                        // Extract external URL if it exists
                        if let url = story.url, !url.isEmpty {
                            urls.append(url)
                            let storyDate = Date(timeIntervalSince1970: storyTimestamp)
                            print("✅ Added URL from \(storyDate): \(story.title ?? "No title")")
                        }
                    }
                }
                
                processedCount += 1
                if processedCount % 50 == 0 {
                    print("📈 Processed \(processedCount) stories, found \(urls.count) URLs from \(year)")
                }
                
                // Add small delay to be respectful to the API
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
            } catch {
                print("⚠️ Error fetching story \(storyID): \(error)")
                continue
            }
        }
        
        print("🎉 HackerNewsService: Found \(urls.count) external URLs from \(year)")
        return Array(urls.prefix(500)) // Ensure we don't exceed 500
    }
    
    private func fetchTopStoryIDs() async throws -> [Int] {
        let urlString = "https://hacker-news.firebaseio.com/v0/topstories.json"
        
        guard let url = URL(string: urlString) else {
            throw HNError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let storyIDs = try JSONDecoder().decode([Int].self, from: data)
        
        return storyIDs
    }
    
    private func fetchStory(id: Int) async throws -> HNStory? {
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
    
    // MARK: - Utility Functions
    
    func printURLsForYear(_ year: Int) async {
        do {
            let urls = try await fetchTop500URLsFromYear(year)
            
            let separator = String(repeating: "=", count: 60)
            print("\n" + separator)
            print("🔗 TOP 500 HACKER NEWS URLS FROM \(year)")
            print(separator + "\n")
            
            for (index, url) in urls.enumerated() {
                print("\(index + 1). \(url)")
            }
            
            print("\n" + separator)
            print("📊 Total URLs from \(year): \(urls.count)")
            print(separator)
            
        } catch {
            print("❌ Error fetching URLs for \(year): \(error)")
        }
    }
    
    func printURLsForBothYears() async {
        print("🚀 Starting HackerNews URL fetch for 2024 and 2025...")
        
        await printURLsForYear(2024)
        await printURLsForYear(2025)
        
        print("\n🎉 HackerNews URL fetch completed for both years!")
    }
}

// MARK: - Errors

enum HNError: Error {
    case invalidURL
    case invalidResponse
    case storyNotFound
}

