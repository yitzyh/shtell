//
//  BrowseForwardAPIService.swift
//  DumFlow
//
//  Stub API service for BrowseForward feature
//

import Foundation
import Combine

class BrowseForwardAPIService {
    static let shared = BrowseForwardAPIService()

    private init() {}

    func fetchContent(category: String? = nil) async throws -> [BrowseForwardItem] {
        // Stub implementation - returns sample data
        return [
            BrowseForwardItem(
                url: URL(string: "https://example.com")!,
                title: "Sample Item",
                category: category ?? "All"
            )
        ]
    }

    func fetchCategories() async throws -> [String] {
        return ["All", "Science", "Culture", "Entertainment", "News", "Classics"]
    }

    func refreshContent() async throws {
        // Stub refresh
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}