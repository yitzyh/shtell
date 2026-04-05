//
//  BrowseForwardAPIService.swift
//  DumFlow
//
//  Live API service for BrowseForward feature
//

import Foundation

class BrowseForwardAPIService {
    static let shared = BrowseForwardAPIService()

    private let baseURL = "https://vercel-backend-azure-three.vercel.app/api/browse-content"

    private init() {}

    // MARK: - Blocked Domains

    private static let blockedDomains: Set<String> = [
        "wsj.com", "nytimes.com", "ft.com", "economist.com",
        "bloomberg.com", "washingtonpost.com", "theatlantic.com"
    ]

    private func isBlocked(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return Self.blockedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    // MARK: - Response Models

    private struct ContentResponse: Codable {
        let items: [APIItem]
    }

    private struct CategoriesResponse: Codable {
        let categories: [String]
    }

    private struct APIItem: Codable {
        let url: String
        let title: String?
        let aiSummary: String?
        let bfCategory: String?
        let bfSubcategory: String?
        let domain: String?
        let qualityScore: Int?
        let tags: [String]?
    }

    // MARK: - Public Methods

    /// Fetch content for a given category. Passing nil or "All" fetches all categories in parallel.
    func fetchContent(category: String? = nil) async throws -> [BrowseForwardItem] {
        let cat = category == "All" ? nil : category

        if let cat {
            return try await fetchSingleCategory(cat)
        } else {
            // No "all" endpoint — fetch every known category in parallel and merge
            let allCategories = try await fetchRawCategories()
            return try await fetchAllInParallel(allCategories)
        }
    }

    func fetchCategories() async throws -> [String] {
        return ["All"] + (try await fetchRawCategories())
    }

    func searchContent(query: String, limit: Int = 20) async throws -> [BrowseForwardItem] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(ContentResponse.self, from: data)
        return response.items.compactMap { mapItem($0) }
    }

    func refreshContent() async throws {
        _ = try await fetchContent()
    }

    func getAvailableCategories() async throws -> [String] {
        return try await fetchCategories()
    }

    // MARK: - Private

    private func fetchSingleCategory(_ category: String) async throws -> [BrowseForwardItem] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "isActiveOnly", value: "true"),
            URLQueryItem(name: "limit", value: "50")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(ContentResponse.self, from: data)
        return response.items.compactMap { mapItem($0) }
    }

    private func fetchRawCategories() async throws -> [String] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "endpoint", value: "categories")]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(CategoriesResponse.self, from: data)
        return response.categories
    }

    private func fetchAllInParallel(_ categories: [String]) async throws -> [BrowseForwardItem] {
        return try await withThrowingTaskGroup(of: [BrowseForwardItem].self) { group in
            for cat in categories {
                group.addTask { try await self.fetchSingleCategory(cat) }
            }
            var all: [BrowseForwardItem] = []
            for try await items in group {
                all.append(contentsOf: items)
            }
            // Sort by score descending so best content appears first
            return all.sorted { $0.score > $1.score }
        }
    }

    private func mapItem(_ item: APIItem) -> BrowseForwardItem? {
        guard !isBlocked(item.url), let url = URL(string: item.url) else { return nil }
        return BrowseForwardItem(
            url: url,
            title: item.title ?? item.domain ?? item.url,
            category: item.bfCategory ?? "All",
            description: item.aiSummary,
            score: Double(item.qualityScore ?? 0)
        )
    }
}
