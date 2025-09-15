import Foundation

class WikipediaService {
    static let shared = WikipediaService()
    private init() {}
    
    func fetchTrendingArticleURLs(limit: Int = 200) async throws -> [String] {
        print("🔄 WikipediaService: Starting optimized fetch for \(limit) articles")
        // 100 popular + 100 random for better content mix
        let popularCount = 100
        let randomCount = 100
        
        print("🔄 WikipediaService: Fetching \(popularCount) popular + \(randomCount) random using 2 API calls")
        
        async let popular = fetchPopular(count: popularCount)
        async let random = fetchRandom(count: randomCount)
        
        let (popularURLs, randomURLs) = await (popular, random)
        let allURLs = (popularURLs + randomURLs).shuffled()
        
        print("✅ WikipediaService: Completed - got \(allURLs.count) total URLs using 2 API calls (was 61!)")
        return allURLs
    }
    
    private func fetchTrending(count: Int) async -> [String] {
        print("🔄 WikipediaService: Fetching \(count) trending articles...")
        
        guard let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date()) else {
            print("❌ WikipediaService: Failed to calculate date")
            return []
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let dateString = formatter.string(from: fourDaysAgo)
        
        let urlString = "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/en.wikipedia/all-access/\(dateString)"
        
        guard let url = URL(string: urlString) else {
            print("❌ WikipediaService: Invalid trending URL")
            return []
        }
        
        do {
            print("🔄 WikipediaService: Fetching from \(urlString)")
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let firstItem = items.first,
                  let articles = firstItem["articles"] as? [[String: Any]] else {
                print("❌ WikipediaService: Failed to parse trending response")
                return []
            }
            
            let urls = Array(articles.prefix(count)).compactMap { (article: [String: Any]) -> String? in
                guard let title = article["article"] as? String else { return nil }
                return "https://en.wikipedia.org/wiki/\(title.replacingOccurrences(of: " ", with: "_"))"
            }
            
            print("✅ WikipediaService: Got \(urls.count) trending articles")
            return urls
        } catch {
            print("❌ WikipediaService: Trending fetch error: \(error)")
            return []
        }
    }
    
    private func fetchRandom(count: Int) async -> [String] {
        print("🔄 WikipediaService: Fetching \(count) random articles using bulk API...")
        
        guard let url = URL(string: "https://en.wikipedia.org/w/api.php?action=query&list=random&rnnamespace=0&rnlimit=\(min(count, 500))&format=json") else {
            print("❌ WikipediaService: Invalid bulk random URL")
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let randomArticles = query["random"] as? [[String: Any]] else {
                print("❌ WikipediaService: Failed to parse bulk random response")
                return []
            }
            
            let urls = randomArticles.compactMap { article -> String? in
                guard let title = article["title"] as? String else { return nil }
                let encodedTitle = title.replacingOccurrences(of: " ", with: "_")
                return "https://en.wikipedia.org/wiki/\(encodedTitle)"
            }
            
            print("✅ WikipediaService: Fetched \(urls.count) random articles using 1 API call")
            return urls
            
        } catch {
            print("❌ WikipediaService: Bulk random fetch error: \(error)")
            return []
        }
    }
    
    private func fetchPopular(count: Int) async -> [String] {
        print("🔄 WikipediaService: Fetching \(count) popular articles...")
        
        // Get yesterday's date for popular articles API
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let dateString = formatter.string(from: yesterday)
        
        guard let url = URL(string: "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/en.wikipedia/all-access/\(dateString)") else {
            print("❌ WikipediaService: Invalid popular articles URL")
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let firstItem = items.first,
                  let articles = firstItem["articles"] as? [[String: Any]] else {
                print("❌ WikipediaService: Failed to parse popular articles response")
                return []
            }
            
            let urls = Array(articles.prefix(count)).compactMap { article -> String? in
                guard let title = article["article"] as? String,
                      !title.hasPrefix("Main_Page"),
                      !title.hasPrefix("Special:") else { return nil }
                return "https://en.wikipedia.org/wiki/\(title)"
            }
            
            print("✅ WikipediaService: Fetched \(urls.count) popular articles using 1 API call")
            return urls
            
        } catch {
            print("❌ WikipediaService: Popular articles fetch error: \(error)")
            return []
        }
    }
}