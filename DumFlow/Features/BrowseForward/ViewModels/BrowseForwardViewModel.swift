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
// Note: Using CachedCategory from Models/CachedCategory.swift

@available(iOS 13.0, *)
@MainActor
class BrowseForwardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isCacheReady = false
    @Published var browseForwardPreferences: [String] = []

    // SINGLE SOURCE OF TRUTH: Filtered items displayed in both grid and slide-through
    @Published var displayedItems: [BrowseForwardItem] = []

    // Track current filters for reapplying after cache refresh
    private var activeFilters: (categories: Set<String>, tags: [String: Set<String>]) = ([], [:])

    // Slide-through navigation index (replaces currentIndex)
    private var slideIndex = 0

    // Category-based cache with 30-min TTL
    private var categoryCache: [String: CachedCategory] = [:]
    private let cacheLock = NSLock()

    // Duplicate tracking
    @Published private var recentlyShownURLs: Set<String> = []
    private let maxRecentlyShown = 50 // Remember last 50 URLs
    private weak var webPageViewModel: WebPageViewModel?
    private weak var webBrowser: WebBrowser?
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

    init(webPageViewModel: WebPageViewModel? = nil, webBrowser: WebBrowser? = nil) {
        self.webPageViewModel = webPageViewModel
        self.webBrowser = webBrowser
        isCacheReady = true

        // No more NotificationCenter - preferences will be applied directly via method calls
        browseForwardLog("🎯 BrowseForwardViewModel initialized")
    }

    func setWebPageViewModel(_ webPageViewModel: WebPageViewModel) {
        self.webPageViewModel = webPageViewModel
    }

    // MARK: - New Unified Filtering System

    /// Apply category and tag filters - Single method for all filtering
    func applyFilters(selectedCategories: Set<String>, selectedTags: [String: Set<String>]) async {
        browseForwardLog("🎯 Applying filters - Categories: \(selectedCategories), Tags: \(selectedTags)")

        // Store active filters for refresh/reload
        activeFilters = (selectedCategories, selectedTags)

        // Cancel any pending operations
        debounceTask?.cancel()

        // Start loading
        isLoading = true

        do {
            // Step 1: Load all items for selected categories (uses cache when available)
            var allItems: [BrowseForwardItem] = []

            for category in selectedCategories {
                // Check cache first
                if let cached = categoryCache[category], cached.isValid {
                    browseForwardLog("✅ Using cached \(category): \(cached.items.count) items")
                    allItems.append(contentsOf: cached.items)
                } else {
                    // Fetch from API
                    browseForwardLog("📡 Fetching \(category) from API")
                    let items = try await apiService.fetchBFQueueItems(
                        category: category,
                        isActiveOnly: true,
                        limit: 250
                    )
                    // Store in cache with category name
                    categoryCache[category] = CachedCategory(category: category, items: items)
                    allItems.append(contentsOf: items)
                    browseForwardLog("💾 Cached \(category): \(items.count) items")
                }
            }

            browseForwardLog("📊 Total items from \(selectedCategories.count) categories: \(allItems.count)")

            // Step 2: Apply tag filters CLIENT-SIDE (instant!)
            if selectedTags.isEmpty || selectedTags.values.allSatisfy({ $0.isEmpty }) {
                // No tags selected - show all items from categories
                displayedItems = allItems
                browseForwardLog("📊 No tag filters - displaying all \(allItems.count) items")
            } else {
                // Filter by selected tags
                displayedItems = allItems.filter { item in
                    guard let category = item.bfCategory,
                          let subcategory = item.bfSubcategory else { return false }

                    // Check if this category has tag filters
                    if let tags = selectedTags[category], !tags.isEmpty {
                        return tags.contains(subcategory)
                    }
                    // No tag filter for this category = include all items from it
                    return true
                }
                browseForwardLog("🏷️ Tag filtered: \(allItems.count) → \(displayedItems.count) items")
            }

            // Step 3: Reset slide index for BrowseForward
            slideIndex = 0

            // Trigger preloading if available
            if let poolManager = webBrowser?.poolManager {
                let urls = Array(displayedItems.prefix(3).map { $0.url })
                poolManager.preloadNextURLs(urls)
            }

        } catch {
            browseForwardLog("❌ Failed to apply filters: \(error)")
            // Keep existing items on error
        }

        isLoading = false
    }

    /// Invalidate cache and refresh with current filters - Used by pull-to-refresh
    func invalidateAndRefresh() async {
        browseForwardLog("🔄 Invalidating cache and refreshing")

        // Clear cache for active categories
        for category in activeFilters.categories {
            categoryCache.removeValue(forKey: category)
            browseForwardLog("🗑️ Cleared cache for \(category)")
        }

        // Reapply filters (will fetch fresh data)
        await applyFilters(selectedCategories: activeFilters.categories, selectedTags: activeFilters.tags)
    }

    /// Get next URL for slide-through navigation (replaces getNextURLFromQueue)
    func getNextSlideURL() -> String? {
        guard !displayedItems.isEmpty else {
            browseForwardLog("⚠️ No items to slide through")
            return nil
        }

        let item = displayedItems[slideIndex]
        slideIndex = (slideIndex + 1) % displayedItems.count

        // Smart refill when running low (but maintains filters!)
        let remainingItems = displayedItems.count - slideIndex
        if remainingItems <= 10 && !isLoading {
            browseForwardLog("📈 Running low on items (\(remainingItems) left), loading more...")
            Task {
                await loadMoreWithCurrentFilters()
            }
        }

        browseForwardLog("📄 Slide URL: \(item.url) (\(slideIndex)/\(displayedItems.count))")
        return item.url
    }

    /// Load more items while maintaining current filters
    private func loadMoreWithCurrentFilters() async {
        // This maintains the same filters, just loads more content
        // In future, could implement pagination here
        await applyFilters(selectedCategories: activeFilters.categories, selectedTags: activeFilters.tags)
    }

    /// Get all cached items (unfiltered) for tag extraction
    func getAllCachedItems() -> [BrowseForwardItem] {
        var allItems: [BrowseForwardItem] = []
        for (_, cache) in categoryCache {
            allItems.append(contentsOf: cache.items)
        }
        return allItems
    }

    func setWebBrowser(_ webBrowser: WebBrowser) {
        self.webBrowser = webBrowser
    }

    // MARK: - Cache Management

    /// Check if category cache is valid
    private func isCacheValid(for category: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = categoryCache[category] else {
            return false
        }

        let valid = cached.isValid
        if !valid {
            browseForwardLog("⏰ Cache expired for \(category) (age: \(cached.cacheAge))")
        } else {
            browseForwardLog("✅ Cache valid for \(category) (age: \(cached.cacheAge))")
        }

        return valid
    }

    /// Get cached items if valid, nil otherwise
    private func getCachedItems(for category: String) -> [BrowseForwardItem]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = categoryCache[category], cached.isValid else {
            return nil
        }

        browseForwardLog("💾 Using cached items for \(category): \(cached.items.count) items (age: \(cached.cacheAge))")
        return cached.items
    }

    /// Store items in cache with timestamp
    private func setCachedItems(_ items: [BrowseForwardItem], for category: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let cached = CachedCategory(category: category, items: items)
        categoryCache[category] = cached
        browseForwardLog("💾 Cached \(items.count) items for \(category) (expires in \(String(format: "%.1f", cached.timeUntilExpiration / 3600))h)")
    }

    /// Clear all expired caches (call periodically)
    private func clearExpiredCaches() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let before = categoryCache.count
        categoryCache = categoryCache.filter { $0.value.isValid }
        let after = categoryCache.count

        if before != after {
            browseForwardLog("🧹 Cleared \(before - after) expired cache(s)")
        }
    }

    /// Clear all caches (for testing/debugging)
    func clearAllCaches() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let count = categoryCache.count
        categoryCache.removeAll()
        browseForwardLog("🧹 Cleared all caches (\(count) categories)")
    }

    /// Preload categories on app launch based on user preferences
    /// Falls back to defaults if no preferences are saved
    func preloadPopularCategories() async {
        // Try to load user's saved preferences
        let categoriesToPreload: [String]

        if let data = UserDefaults.standard.data(forKey: "BrowseForwardPreferences"),
           let preferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: data),
           !preferences.selectedCategories.isEmpty {
            // Use saved preferences
            categoriesToPreload = Array(preferences.selectedCategories)
            browseForwardLog("🎯 Preloading from user preferences: \(categoriesToPreload.joined(separator: ", "))")
        } else {
            // No preferences - use smart defaults (Short Reads, youtube, webgames, wikipedia, news)
            categoriesToPreload = ["Short Reads", "youtube", "webgames", "wikipedia", "news"]
            browseForwardLog("🎯 Preloading defaults (no preferences): \(categoriesToPreload.joined(separator: ", "))")
        }

        browseForwardLog("🚀 Starting preload for \(categoriesToPreload.count) categories")

        await withTaskGroup(of: (String, [BrowseForwardItem]?).self) { group in
            for category in categoriesToPreload {
                group.addTask { @MainActor in
                    // Check cache first - might be valid from previous session
                    if let cachedItems = self.getCachedItems(for: category) {
                        browseForwardLog("✅ \(category) already cached with \(cachedItems.count) items")
                        return (category, cachedItems)
                    }

                    // Fetch if not cached or expired
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

            // Collect results and store in cache with timestamps
            for await (category, items) in group {
                if let items = items {
                    self.setCachedItems(items, for: category)
                    browseForwardLog("💾 Cached \(category) with \(items.count) items")
                }
            }
        }

        browseForwardLog("✅ Preloading complete. Cache size: \(categoryCache.keys.count) categories")
    }

    /// Get a random saved page URL from user's saved content
    private func getRandomSavedPageURL() -> String? {
        browseForwardLog("📚 Looking for saved pages")
        // This would integrate with your saved pages system
        // For now, return nil to fall back to regular content
        return nil
    }
    
    func getRandomURL(category: String? = nil, userID: String? = nil) async throws -> String? {
        browseForwardLog("🎯 getRandomURL: Using new unified system")

        // Handle saved pages category specially
        if let category = category, category == "saved" {
            browseForwardLog("🎯 getRandomURL: Handling 'saved' category")
            if let savedURL = getRandomSavedPageURL() {
                browseForwardLog("📚 getRandomURL: Using saved pages, found URL: \(savedURL)")
                return savedURL
            }
        }

        // Initialize displayedItems if empty
        if displayedItems.isEmpty {
            browseForwardLog("📋 No items displayed, loading defaults...")
            // Load default categories if no filters are set
            if activeFilters.categories.isEmpty {
                let defaultCategories: Set<String> = ["webgames", "youtube", "wikipedia"]
                await applyFilters(selectedCategories: defaultCategories, selectedTags: [:])
            }

            if displayedItems.isEmpty {
                browseForwardLog("❌ No items available after loading")
                return "https://en.wikipedia.org/wiki/Special:Random"
            }
        }

        // Get next URL from slide system
        return getNextSlideURL()
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

    /// Load category items using smart caching with TTL
    private func loadCategoryIfNeeded(_ category: String) async throws -> [BrowseForwardItem] {
        browseForwardLog("📂 Loading category: \(category)")

        // Check cache first - use new TTL-aware cache
        if let cachedItems = getCachedItems(for: category) {
            browseForwardLog("💾 Using cached items for category: \(category)")
            return cachedItems
        }

        // Cache miss or expired - fetch from AWS
        browseForwardLog("🔄 Fetching fresh items for category: \(category) (cache miss or expired)")
        let awsItems = try await apiService.fetchBFQueueItems(
            category: category,
            isActiveOnly: true,
            limit: 1000
        )

        // Store in cache with timestamp
        setCachedItems(awsItems, for: category)
        browseForwardLog("💾 Cached \(awsItems.count) items for category: \(category)")

        // Cleanup expired caches while we're here
        clearExpiredCaches()

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
    
    // MARK: - DEPRECATED METHODS (will be removed after testing)

    // Old filtering method - replaced by applyFilters
    /*
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
    */

    /// Refresh content queue based on new preferences - REDIRECTS TO NEW SYSTEM
    func refreshWithPreferences(selectedCategories: [String], selectedSubcategories: [String: Set<String>]) async {
        // Convert to Set and use new unified method
        let categoriesSet = Set(selectedCategories)
        await applyFilters(selectedCategories: categoriesSet, selectedTags: selectedSubcategories)
    }

    // Rest of old methods are commented out below
    /*
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

            // Trigger preloading after queue ready
            if let poolManager = webBrowser?.poolManager {
                let urls = getNextURLsForPreloading(count: 2)
                poolManager.preloadNextURLs(urls)
                browseForwardLog("🔄 Started preloading \(urls.count) URLs")
            }
        } catch {
            browseForwardLog("❌ Failed to initialize queue: \(error)")
            // Fallback to default content
            do {
                let defaultItems = try await fetchDefaultContent(limit: 200)
                browseQueue = defaultItems
                currentIndex = 0
                browseForwardLog("✅ Queue initialized with \(browseQueue.count) default items")

                // Trigger preloading for fallback content too
                if let poolManager = webBrowser?.poolManager {
                    let urls = getNextURLsForPreloading(count: 2)
                    poolManager.preloadNextURLs(urls)
                    browseForwardLog("🔄 Started preloading \(urls.count) URLs (fallback)")
                }
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

    // MARK: - Preloading Support

    /// Get next URLs for preloading
    func getNextURLsForPreloading(count: Int = 3) -> [String] {
        guard !browseQueue.isEmpty else {
            browseForwardLog("⚠️ Cannot preload: queue is empty")
            return []
        }

        // Get URLs starting from current index
        var urls: [String] = []
        for i in 0..<count {
            let index = (currentIndex + i) % browseQueue.count
            urls.append(browseQueue[index].url)
        }

        browseForwardLog("📋 Returning \(urls.count) URLs for preloading")
        return urls
    }
    */
}
