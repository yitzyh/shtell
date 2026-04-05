//
//  BrowseForwardViewModel.swift
//  DumFlow
//
//  ViewModel for BrowseForward feature - temporary placeholder
//

import SwiftUI
import Combine

@MainActor
class BrowseForwardViewModel: ObservableObject {
    @Published var items: [BrowseForwardItem] = []
    @Published var isLoading = false
    @Published var selectedCategory: String = "All"
    @Published var currentItemIndex: Int = 0
    @Published var isCacheReady = false
    @Published var availableCategories: [String] = ["All"]

    var displayedItems: [BrowseForwardItem] {
        return items
    }

    init() {
        items = []
        isLoading = true
        Task {
            async let cats: () = loadCategories()
            async let content: () = loadContent()
            _ = await (cats, content)
        }
    }

    func loadCategories() async {
        do {
            availableCategories = try await BrowseForwardAPIService.shared.fetchCategories()
        } catch {
            print("❌ BrowseForwardViewModel: Categories fetch failed (\(error))")
        }
    }

    func loadContent() async {
        isLoading = true
        do {
            let fetched = try await BrowseForwardAPIService.shared.fetchContent(category: selectedCategory)
            // Reset index before items so both @Published changes are batched
            // into a single ContentView re-render, preventing FocusState disruption.
            currentItemIndex = 0
            items = fetched
            print("✅ BrowseForwardViewModel: Loaded \(fetched.count) items from API")
        } catch {
            print("❌ BrowseForwardViewModel: API failed (\(error)), using fallback items")
            currentItemIndex = 0
            items = [
                BrowseForwardItem(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News", category: "News"),
                BrowseForwardItem(url: URL(string: "https://arstechnica.com")!, title: "Ars Technica", category: "Science"),
                BrowseForwardItem(url: URL(string: "https://kottke.org")!, title: "Kottke.org", category: "Culture")
            ]
        }
        isLoading = false
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
        Task { await loadContent() }
    }

    func navigateToNext() {
        if currentItemIndex < items.count - 1 {
            currentItemIndex += 1
        } else {
            // Loop back to beginning
            currentItemIndex = 0
        }
    }

    func navigateToPrevious() {
        if currentItemIndex > 0 {
            currentItemIndex -= 1
        }
    }

    func getNextSlideURL() -> URL? {
        guard !items.isEmpty, currentItemIndex < items.count - 1 else { return nil }
        return items[currentItemIndex + 1].url
    }

    func setWebPageViewModel(_ viewModel: Any) {
        // Placeholder for web page view model connection
    }

    func setWebBrowser(_ browser: Any) {
        // Placeholder for web browser connection
    }

    func refreshWithPreferences(selectedCategories: Set<String> = [], selectedSubcategories: [String: Set<String>] = [:]) {
        Task { await loadContent() }
    }

    func refreshWithPreferences() {
        Task { await loadContent() }
    }

    func preloadPopularCategories() async {
        // Preload popular categories for instant access
        isLoading = true
        try? await Task.sleep(nanoseconds: 100_000_000)
        isLoading = false
    }
}

// MARK: - BrowseForwardItem Model
struct BrowseForwardItem: Identifiable, Codable, Equatable {
    var id: UUID
    var url: URL
    var title: String
    var description: String?
    var category: String
    var imageURL: URL?
    var thumbnailUrl: String?
    var domain: String?
    var score: Double

    init(id: UUID = UUID(), url: URL, title: String, category: String, description: String? = nil, imageURL: URL? = nil, thumbnailUrl: String? = nil, score: Double = 0.0) {
        self.id = id
        self.url = url
        self.title = title
        self.category = category
        self.description = description
        self.imageURL = imageURL
        self.thumbnailUrl = thumbnailUrl
        self.domain = url.host
        self.score = score
    }
}