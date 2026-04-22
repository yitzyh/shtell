import Foundation

class NewsAPIService {

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

        // Stub: saving to backend is deferred
        print("✅ NewsAPIService: Fetched \(allURLs.count) URLs (save to backend deferred)")
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
}

// MARK: - Errors

enum NewsAPIError: Error {
    case invalidURL
    case invalidResponse
    case apiKeyMissing
}

// NOTE: @main entry point removed — this struct is for GitHub Actions use only, not compiled into the iOS app target.
