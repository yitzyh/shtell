import Foundation
import Combine
import SwiftUI

// MARK: - Debug Logging Configuration
#if DEBUG
private let enableBrowseForwardLogs = ProcessInfo.processInfo.environment["BROWSE_FORWARD_LOGS"] == "1"

private func browseForwardLog(_ message: String) {
    if enableBrowseForwardLogs { print(message) }
}
#else
private func browseForwardLog(_ message: String) {}
#endif

// MARK: - Error Types
enum BrowseForwardError: Error {
    case noItemsAvailable
    case noCategoriesAvailable
    case queueInitializationFailed
}

// MARK: - BrowseForwardItem Model (DEPRECATED - Use AWSWebPageItem directly)

@available(iOS 13.0, *)
@MainActor
class BrowseForwardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isCacheReady = false
    @Published var browseForwardPreferences: [String] = []
    
    // Shared content queue for both card carousel and forward button
    @Published var browseQueue: [BrowseForwardItem] = []
    private var currentIndex = 0

    // Store full unfiltered items for client-side tag filtering
    // Published so CategorySelectionView can extract subcategories from full set
    @Published var fullUnfilteredItems: [BrowseForwardItem] = []

    // Simple cache - no persistence needed
    private var simpleCache: [String: [BrowseForwardItem]] = [:]

    // Duplicate tracking
    @Published private var recentlyShownURLs: Set<String> = []
    private let maxRecentlyShown = 50 // Remember last 50 URLs
    private weak var webPageViewModel: WebPageViewModel?
    private let apiService: BrowseForwardAPIService = BrowseForwardAPIService.shared
    
    // Debouncing for category changes
    private var debounceTask: Task<Void, Never>?
    
    private let paywalledDomains: Set<String> = [
        "wsj.com", "nytimes.com", "nymag.com", "ft.com", "economist.com",
        "bloomberg.com", "washingtonpost.com", "theathlantic.com",
        "telegraph.co.uk", "bostonglobe.com", "latimes.com"
    ]

    /// Select item avoiding recent duplicates
    private func selectItemAvoidingDuplicates(from items: [BrowseForwardItem]) throws -> BrowseForwardItem {
        // Filter out recently shown items
        let availableItems = items.filter { !recentlyShownURLs.contains($0.url) }

        // If we've shown everything, clear history and start fresh
        let finalItems = availableItems.isEmpty ? items : availableItems

        // Pick random from filtered pool
        guard let randomItem = finalItems.randomElement() else {
            // This should never happen given the filtering logic above, but provide a safe fallback
            browseForwardLog("⚠️ No items available after filtering - this should not happen")
            // Return a default item or handle gracefully
            throw BrowseForwardError.noItemsAvailable
        }

        // Track this selection
        recentlyShownURLs.insert(randomItem.url)

        // Maintain reasonable history size
        if recentlyShownURLs.count > maxRecentlyShown {
            let urlArray = Array(recentlyShownURLs)
            recentlyShownURLs = Set(urlArray.suffix(maxRecentlyShown - 10)) // Keep most recent 40
        }

        browseForwardLog("🔄 Selected avoiding duplicates: \(randomItem.url) (recently shown: \(recentlyShownURLs.count))")
        return randomItem
    }

    init(webPageViewModel: WebPageViewModel? = nil) {
        self.webPageViewModel = webPageViewModel
        isCacheReady = true

        // Listen for preference changes to refilter without API calls
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BrowseForwardPreferencesChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refilterFromFullItems()
            }
        }
        browseForwardLog("🎯 BrowseForwardViewModel initialized")
    }
    
    func setWebPageViewModel(_ webPageViewModel: WebPageViewModel) {
        self.webPageViewModel = webPageViewModel
    }

    /// Preload popular categories on app launch for instant first-tap experience
    func preloadPopularCategories() async {
        let popularCategories = ["webgames", "youtube", "wikipedia", "art"]

        browseForwardLog("🚀 Preloading popular categories: \(popularCategories.joined(separator: ", "))")

        await withTaskGroup(of: (String, [BrowseForwardItem]?).self) { group in
            for category in popularCategories {
                group.addTask {
                    do {
                        let items = try await self.apiService.fetchBFQueueItems(
                            category: category,
                            isActiveOnly: true,
                            limit: 100  // Smaller limit for preloading
                        )
                        browseForwardLog("✅ Preloaded \(category): \(items.count) items")
                        return (category, items)
                    } catch {
                        browseForwardLog("❌ Failed to preload \(category): \(error)")
                        return (category, nil)
                    }
                }
            }

            // Collect results and store in cache
            for await (category, items) in group {
                if let items = items {
                    self.simpleCache[category] = items
                    browseForwardLog("💾 Cached \(category) with \(items.count) items")
                }
            }
        }

        browseForwardLog("✅ Preloading complete. Cache size: \(simpleCache.keys.count) categories")
    }

    /// Get a random saved page URL from user's saved content
    private func getRandomSavedPageURL() -> String? {
        browseForwardLog("📚 Looking for saved pages")
        // This would integrate with your saved pages system
        // For now, return nil to fall back to regular content
        return nil
    }
    
    func getRandomURL(category: String? = nil, userID: String? = nil) async throws -> String? {
        browseForwardLog("🎯 getRandomURL: Using synchronized queue system")
        
        // Handle saved pages category specially
        if let category = category, category == "saved" {
            browseForwardLog("🎯 getRandomURL: Handling 'saved' category")
            if let savedURL = getRandomSavedPageURL() {
                browseForwardLog("📚 getRandomURL: Using saved pages, found URL: \(savedURL)")
                return savedURL
            }
        }
        
        // Initialize queue if empty
        if browseQueue.isEmpty {
            do {
                await initializeBrowseQueue()
                if browseQueue.isEmpty {
                    throw BrowseForwardError.queueInitializationFailed
                }
            } catch {
                browseForwardLog("❌ Queue initialization failed in getRandomURL: \(error)")
                // Return fallback URL instead of crashing
                return "https://en.wikipedia.org/wiki/Special:Random"
            }
        }
        
        // Get next URL from synchronized queue
        return await getNextURLFromQueue()
    }
    
    /// Get a random URL from a specific category using smart caching
    private func getRandomURLFromCategory(_ category: String) async throws -> String? {
        browseForwardLog("📱 Getting random URL from category: \(category)")
        
        do {
            // Load category items (uses cache if available, fetches if not)
            let items = try await loadCategoryIfNeeded(category)
            
            if items.isEmpty {
                print("⚠️ No items found for category \(category)")
                return "https://en.wikipedia.org/wiki/Special:Random"
            }
            
            // COMBINED POOL APPROACH: Get random item from entire category (avoiding recent duplicates)
            let randomItem = try selectItemAvoidingDuplicates(from: items)
            print("✅ Selected random item: \(randomItem.title) from \(randomItem.domain)")
            return randomItem.url
            
        } catch {
            print("🚨 Error loading category \(category): \(error)")
            return "https://en.wikipedia.org/wiki/Special:Random"
        }
    }
    
    /// Load category items using smart caching
    private func loadCategoryIfNeeded(_ category: String) async throws -> [BrowseForwardItem] {
        browseForwardLog("📂 Loading category: \(category)")
        
        // Check cache first
        if let cachedItems = simpleCache[category], !cachedItems.isEmpty {
            browseForwardLog("💾 Using cached items for category: \(category)")
            return cachedItems
        }
        
        // Fetch from AWS and cache
        browseForwardLog("🔄 Fetching fresh items for category: \(category)")
        let awsItems = try await apiService.fetchBFQueueItems(category: category, isActiveOnly: true, limit: 1000)
        
        // Cache the results
        simpleCache[category] = awsItems
        browseForwardLog("💾 Cached \(awsItems.count) items for category: \(category)")
        
        return awsItems
    }
    
    /// Get active categories from user preferences
    func getActiveCategoriesFromUserPreferences() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: "BrowseForwardPreferences"),
              let preferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: data) else {
            print("📱 No user preferences found, using defaults")
            return []
        }
        
        let activeCategories = Array(preferences.selectedCategories)
        browseForwardLog("📱 Active categories: \(activeCategories)")
        return activeCategories
    }
    
    /// Get content based on user preferences from the new BrowseForwardPreferencesView
    func fetchByUserPreferences(limit: Int = 500) async throws -> [BrowseForwardItem] {
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: === STARTING fetchByUserPreferences ===")
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: limit: \(limit)")
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: apiService ready")
        
        // Load user preferences from UserDefaults
        let userDefaultsData = UserDefaults.standard.data(forKey: "BrowseForwardPreferences")
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: UserDefaults data exists: \(userDefaultsData != nil)")

        guard let data = userDefaultsData,
              let preferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: data) else {
            browseForwardLog("🔍 DEBUG fetchByUserPreferences: No preferences found, using all active content")
            // No preferences set, use ALL active content as default
            let result = try await apiService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
            browseForwardLog("🔍 DEBUG fetchByUserPreferences: All active content returned \(result.count) items")
            return result
        }

        // Add detailed logging of the loaded preferences
        print("💾 DEBUG fetchByUserPreferences: Loaded preferences from UserDefaults:")
        print("💾 DEBUG fetchByUserPreferences: selectedCategories: \(preferences.selectedCategories)")
        print("💾 DEBUG fetchByUserPreferences: selectedSubcategories: \(preferences.selectedSubcategories)")
        print("💾 DEBUG fetchByUserPreferences: isDefaultMode: \(preferences.isDefaultMode)")
        print("💾 DEBUG fetchByUserPreferences: lastUpdated: \(preferences.lastUpdated)")

        browseForwardLog("🔍 DEBUG fetchByUserPreferences: Preferences loaded successfully")
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: isDefaultMode: \(preferences.isDefaultMode)")
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: selectedCategories: \(preferences.selectedCategories)")
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: selectedSubcategories: \(preferences.selectedSubcategories)")
        
        // If no selections, return all active content
        if preferences.isDefaultMode {
            browseForwardLog("🔍 DEBUG fetchByUserPreferences: Using default mode - calling fetchBFQueueItems with isActive=true")
            let result = try await apiService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
            browseForwardLog("🔍 DEBUG fetchByUserPreferences: Default mode returned \(result.count) items")
            return result
        }

        // Handle category-based filtering with intelligent batching
        if !preferences.selectedCategories.isEmpty {
            browseForwardLog("🔍 DEBUG fetchByUserPreferences: Using selected categories: \(preferences.selectedCategories)")

            // Batch fetch from multiple categories for better content diversity
            var allItems: [BrowseForwardItem] = []
            let maxCategories = min(3, preferences.selectedCategories.count) // Limit to prevent too many queries
            let itemsPerCategory = limit / maxCategories

            browseForwardLog("🔍 DEBUG fetchByUserPreferences: Batching \(maxCategories) categories, \(itemsPerCategory) items each")

            let selectedCategories = Array(preferences.selectedCategories.shuffled().prefix(maxCategories))

            for category in selectedCategories {
                browseForwardLog("🔍 DEBUG fetchByUserPreferences: Fetching from category: '\(category)'")

                // Fetch entire category (no subcategory filtering - we'll filter after storing)
                do {
                    let categoryItems = try await apiService.fetchBFQueueItems(
                        category: category,
                        subcategory: nil,  // Always nil - Vercel API doesn't support subcategory filtering
                        isActiveOnly: true,
                        limit: itemsPerCategory
                    )

                    // DON'T filter by subcategories here - we'll filter later in refreshWithPreferences
                    // This way we can store full items for client-side refiltering
                    allItems.append(contentsOf: categoryItems)
                    browseForwardLog("🔍 DEBUG fetchByUserPreferences: Category '\(category)' added \(categoryItems.count) items (unfiltered)")
                } catch {
                    browseForwardLog("⚠️ Failed to fetch from category '\(category)': \(error)")
                    // Continue with other categories
                }
            }

            // Shuffle for content diversity across categories
            let shuffledItems = allItems.shuffled()
            browseForwardLog("🔍 DEBUG fetchByUserPreferences: Batched \(shuffledItems.count) items from \(maxCategories) categories")
            return shuffledItems
        }

        // Fallback: return all active content
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: Fallback: fetching all active content")
        let result = try await apiService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
        browseForwardLog("🔍 DEBUG fetchByUserPreferences: Fallback returned \(result.count) items")
        return result
    }
    
    /// Refilter existing items based on current preferences (no API call)
    private func refilterFromFullItems() async {
        browseForwardLog("🔄 Refiltering from full items...")

        guard !fullUnfilteredItems.isEmpty else {
            browseForwardLog("⚠️  No full items to refilter from")
            return
        }

        // Load current preferences
        guard let data = UserDefaults.standard.data(forKey: "BrowseForwardPreferences"),
              let preferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: data) else {
            browseForwardLog("⚠️ No preferences found for refiltering")
            return
        }

        // Apply subcategory filtering if needed
        var filteredItems = fullUnfilteredItems

        if !preferences.selectedSubcategories.isEmpty {
            filteredItems = fullUnfilteredItems.filter { item in
                guard let itemCategory = item.bfCategory,
                      let itemSubcategory = item.bfSubcategory else {
                    return false
                }

                // Check if this item's subcategory is selected for its category
                if let selectedSubs = preferences.selectedSubcategories[itemCategory] {
                    return selectedSubs.contains(itemSubcategory)
                }

                return true // No subcategory filter for this category
            }
        }

        browseQueue = filteredItems
        currentIndex = 0
        browseForwardLog("✅ Refiltered: \(fullUnfilteredItems.count) → \(filteredItems.count) items")
    }

    /// Refresh content queue based on new preferences - used by preferences view
    func refreshWithPreferences(selectedCategories: [String], selectedSubcategories: [String: Set<String>]) async {
        // Cancel previous debounce task
        debounceTask?.cancel()
        
        // Create new debounced task
        debounceTask = Task {
            browseForwardLog("⏱️ Debouncing category change for 500ms...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            guard !Task.isCancelled else {
                browseForwardLog("⏹️ Debounced refresh cancelled")
                return
            }
            
            browseForwardLog("🔄 Refreshing content with new preferences")
            browseForwardLog("🔄 Categories: \(selectedCategories)")
            browseForwardLog("🔄 Subcategories: \(selectedSubcategories)")
            
            isLoading = true
            
            do {
                // Clear current queue
                browseQueue.removeAll()
                currentIndex = 0

                // Fetch new content based on preferences (unfiltered by subcategories)
                let newItems = try await fetchByUserPreferences(limit: 250)

                // Store full unfiltered items for client-side refiltering
                fullUnfilteredItems = newItems
                browseForwardLog("🔄 Stored \(fullUnfilteredItems.count) full unfiltered items")

                // Apply subcategory filtering if needed
                if !selectedSubcategories.isEmpty {
                    let filteredItems = newItems.filter { item in
                        guard let itemCategory = item.bfCategory,
                              let itemSubcategory = item.bfSubcategory else {
                            return false
                        }

                        // Check if this item's subcategory is selected for its category
                        if let selectedSubs = selectedSubcategories[itemCategory] {
                            return selectedSubs.contains(itemSubcategory)
                        }

                        return true // No subcategory filter for this category
                    }
                    browseQueue = filteredItems
                    browseForwardLog("🔄 Queue filtered: \(newItems.count) → \(filteredItems.count) items")
                } else {
                    // No subcategory filtering, use all items
                    browseQueue = newItems
                    browseForwardLog("🔄 Queue refreshed with \(browseQueue.count) items (unfiltered)")
                }

            } catch {
                browseForwardLog("❌ Failed to refresh queue: \(error)")
            }
            
            isLoading = false
        }
        
        await debounceTask?.value
    }
    
    private func fetchDefaultContent(limit: Int) async throws -> [BrowseForwardItem] {
        browseForwardLog("🎲 === STARTING fetchDefaultContent ===")
        browseForwardLog("🎲 limit: \(limit)")
        
        // Use the new category-based system - fetch all active content
        browseForwardLog("🎲 Fetching all active content as default")
        let result = try await apiService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
        
        browseForwardLog("🎲 Default content result count: \(result.count)")
        browseForwardLog("🎲 === ENDING fetchDefaultContent ===")
        return result
    }
    
    // MARK: - Queue Management Methods
    
    func initializeBrowseQueue() async {
        browseForwardLog("🔄 Initializing browse queue")
        isLoading = true
        
        do {
            let items = try await fetchByUserPreferences(limit: 250)
            browseQueue = items
            currentIndex = 0
            browseForwardLog("✅ Queue initialized with \(browseQueue.count) items")
        } catch {
            browseForwardLog("❌ Failed to initialize queue: \(error)")
            // Fallback to default content
            do {
                let defaultItems = try await fetchDefaultContent(limit: 200)
                browseQueue = defaultItems
                currentIndex = 0
                browseForwardLog("✅ Queue initialized with \(browseQueue.count) default items")
            } catch {
                browseForwardLog("❌ Failed to load default content: \(error)")
            }
        }
        
        isLoading = false
    }
    
    private func getNextURLFromQueue() async -> String? {
        guard !browseQueue.isEmpty else {
            browseForwardLog("⚠️ Queue is empty")
            return nil
        }
        
        // Get current item and advance index
        let item = browseQueue[currentIndex]
        currentIndex = (currentIndex + 1) % browseQueue.count
        
        // Smart queue management: Refill when 5 items remaining
        let remainingItems = browseQueue.count - currentIndex
        if remainingItems <= 5 && !isLoading {
            browseForwardLog("📈 Smart refill: Only \(remainingItems) items remaining, loading more...")
            Task {
                await loadMoreToQueue()
            }
        }
        
        browseForwardLog("📄 Returning URL: \(item.url) (Queue: \(currentIndex)/\(browseQueue.count))")
        return item.url
    }
    
    func refreshBrowseQueue() async {
        browseForwardLog("🔄 Refreshing browse queue")
        await initializeBrowseQueue()
    }
    
    func loadMoreToQueue() async {
        browseForwardLog("📈 Loading more content to queue")
        isLoading = true
        
        do {
            let moreItems = try await fetchByUserPreferences(limit: 200)
            browseQueue.append(contentsOf: moreItems)
            browseForwardLog("✅ Added \(moreItems.count) more items to queue. Total: \(browseQueue.count)")
        } catch {
            browseForwardLog("❌ Failed to load more items: \(error)")
            // Fallback to default content
            do {
                let fallbackItems = try await fetchDefaultContent(limit: 200)
                browseQueue.append(contentsOf: fallbackItems)
                browseForwardLog("✅ Added \(fallbackItems.count) fallback items to queue. Total: \(browseQueue.count)")
            } catch {
                browseForwardLog("❌ Even fallback load more failed: \(error)")
            }
        }
        
        isLoading = false
    }
}
