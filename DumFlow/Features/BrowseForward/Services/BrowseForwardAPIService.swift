//
//  BrowseForwardAPIService.swift
//  Shtell
//
//  Created by Claude Code on 9/19/25.
//

import Foundation

// MARK: - Response Models

struct BrowseContentResponse: Codable {
    let items: [BrowseForwardItem]
    let count: Int
    let scannedCount: Int?
    let lastEvaluatedKey: String?
}

struct CategoriesResponse: Codable {
    let categories: [String]
}

struct SubcategoriesResponse: Codable {
    let subcategories: [String]
}

// MARK: - API Service

@MainActor
class BrowseForwardAPIService: ObservableObject {
    static let shared = BrowseForwardAPIService()

    // Using Vercel API for both debug and release modes
    #if DEBUG
    private let baseURL = "https://vercel-backend-k6iizy48w-yitzyhs-projects.vercel.app/api"  // GSI query fixed
    #else
    private let baseURL = "https://vercel-backend-k6iizy48w-yitzyhs-projects.vercel.app/api"  // GSI query fixed
    #endif

    @Published var isLoading = false
    @Published var lastError: Error?

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Main Query Methods

    /// Fetch browse queue items
    func fetchBFQueueItems(
        category: String? = nil,
        subcategory: String? = nil,
        isActiveOnly: Bool = true,
        limit: Int = 500
    ) async throws -> [BrowseForwardItem] {
        var components = URLComponents(string: "\(baseURL)/browse-content")!
        var queryItems: [URLQueryItem] = []

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let subcategory = subcategory {
            queryItems.append(URLQueryItem(name: "subcategory", value: subcategory))
        }
        queryItems.append(URLQueryItem(name: "isActiveOnly", value: String(isActiveOnly)))
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))

        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("📱 BrowseForward API: Fetching items from \(url)")

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode != 200 {
                print("❌ BrowseForward API: HTTP error \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }

            let contentResponse = try JSONDecoder().decode(BrowseContentResponse.self, from: data)
            print("✅ BrowseForward API: Retrieved \(contentResponse.items.count) items")

            return contentResponse.items

        } catch {
            print("❌ BrowseForward API: Error - \(error)")
            lastError = error
            throw error
        }
    }

    /// Get available categories
    func getAvailableCategories() async throws -> [String] {
        var components = URLComponents(string: "\(baseURL)/browse-content")!
        components.queryItems = [URLQueryItem(name: "endpoint", value: "categories")]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("📱 BrowseForward API: Fetching categories from \(url)")

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let categoriesResponse = try JSONDecoder().decode(CategoriesResponse.self, from: data)
            print("✅ BrowseForward API: Retrieved \(categoriesResponse.categories.count) categories")

            return categoriesResponse.categories

        } catch {
            print("❌ BrowseForward API: Error - \(error)")
            lastError = error
            throw error
        }
    }

    /// Get subcategories for a category
    func getSubcategories(for category: String) async throws -> [String] {
        var components = URLComponents(string: "\(baseURL)/browse-content")!
        components.queryItems = [
            URLQueryItem(name: "endpoint", value: "subcategories"),
            URLQueryItem(name: "category", value: category)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("📱 BrowseForward API: Fetching subcategories for \(category) from \(url)")

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let subcategoriesResponse = try JSONDecoder().decode(SubcategoriesResponse.self, from: data)
            print("✅ BrowseForward API: Retrieved \(subcategoriesResponse.subcategories.count) subcategories")

            return subcategoriesResponse.subcategories

        } catch {
            print("❌ BrowseForward API: Error - \(error)")
            lastError = error
            throw error
        }
    }

    /// Fetch by source
    func fetchBySource(_ source: String, limit: Int = 50) async throws -> [BrowseForwardItem] {
        var components = URLComponents(string: "\(baseURL)/browse-content")!
        components.queryItems = [
            URLQueryItem(name: "source", value: source),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        isLoading = true
        defer { isLoading = false }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(BrowseContentResponse.self, from: data)

        return response.items
    }

    /// Fetch popular articles
    func fetchPopular(limit: Int = 50) async throws -> [BrowseForwardItem] {
        return try await fetchBFQueueItems(isActiveOnly: true, limit: limit)
    }
}

// MARK: - Migration Helper

extension BrowseForwardAPIService {
    /// Helper method to migrate from DynamoDBWebPageService
    /// This maintains compatibility during the transition
    func migrationHelper_fetchBFQueueItems(
        category: String?,
        subcategory: String? = nil,
        isActiveOnly: Bool = true,
        limit: Int = 500
    ) async throws -> [BrowseForwardItem] {
        // This matches the old DynamoDBWebPageService method signature exactly
        return try await fetchBFQueueItems(
            category: category,
            subcategory: subcategory,
            isActiveOnly: isActiveOnly,
            limit: limit
        )
    }
}