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
    
    // Simple cache - no persistence needed
    private var simpleCache: [String: [BrowseForwardItem]] = [:]
    private weak var webPageViewModel: WebPageViewModel?
    private let dynamoDBService: DynamoDBWebPageService = DynamoDBWebPageService.shared
    
    // Debouncing for category changes
    private var debounceTask: Task<Void, Never>?
    
    private let paywalledDomains: Set<String> = [
        "wsj.com", "nytimes.com", "ft.com", "economist.com",
        "bloomberg.com", "washingtonpost.com", "theathlantic.com",
        "telegraph.co.uk", "bostonglobe.com", "latimes.com"
    ]
    
    init(webPageViewModel: WebPageViewModel? = nil) {
        self.webPageViewModel = webPageViewModel
        isCacheReady = true
        browseForwardLog("🎯 BrowseForwardViewModel initialized")
    }
    
    func setWebPageViewModel(_ webPageViewModel: WebPageViewModel) {
        self.webPageViewModel = webPageViewModel
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
            await initializeBrowseQueue()
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
            
            // COMBINED POOL APPROACH: Get random item from entire category
            let randomItem = items.randomElement()!
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
        let awsItems = try await dynamoDBService.fetchBFQueueItems(category: category, isActiveOnly: true, limit: 100)
        
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
    func fetchByUserPreferences(limit: Int = 20) async throws -> [BrowseForwardItem] {
        print("🔍 DEBUG fetchByUserPreferences: === STARTING fetchByUserPreferences ===")
        print("🔍 DEBUG fetchByUserPreferences: limit: \(limit)")
        print("🔍 DEBUG fetchByUserPreferences: dynamoDBService ready")
        
        // Load user preferences from UserDefaults
        let userDefaultsData = UserDefaults.standard.data(forKey: "BrowseForwardPreferences")
        print("🔍 DEBUG fetchByUserPreferences: UserDefaults data exists: \(userDefaultsData != nil)")
        
        guard let data = userDefaultsData,
              let preferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: data) else {
            print("🔍 DEBUG fetchByUserPreferences: No preferences found, using fetchDefaultContent")
            // No preferences set, use ALL active content as default
            return try await dynamoDBService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
        }
        
        print("🔍 DEBUG fetchByUserPreferences: Preferences loaded successfully")
        print("🔍 DEBUG fetchByUserPreferences: isDefaultMode: \(preferences.isDefaultMode)")
        print("🔍 DEBUG fetchByUserPreferences: selectedCategories: \(preferences.selectedCategories)")
        print("🔍 DEBUG fetchByUserPreferences: selectedSubcategories: \(preferences.selectedSubcategories)")
        
        // If no selections, return all active content
        if preferences.isDefaultMode {
            print("🔍 DEBUG fetchByUserPreferences: Using default mode - calling fetchBFQueueItems with isActive=true")
            return try await dynamoDBService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
        }
        
        // Handle category-based filtering
        if !preferences.selectedCategories.isEmpty {
            print("🔍 DEBUG fetchByUserPreferences: Using selected categories: \(preferences.selectedCategories)")
            
            // Pick one random category from user's selections
            let randomCategory = preferences.selectedCategories.randomElement()!
            print("🔍 DEBUG fetchByUserPreferences: Selected random category: '\(randomCategory)'")
            
            // Check if user has subcategory selections for this category
            var selectedSubcategory: String? = nil
            if let subcategories = preferences.selectedSubcategories[randomCategory],
               !subcategories.isEmpty {
                selectedSubcategory = subcategories.randomElement()
                print("🔍 DEBUG fetchByUserPreferences: Selected random subcategory: '\(selectedSubcategory ?? "nil")'")
            }
            
            let result = try await dynamoDBService.fetchBFQueueItems(
                category: randomCategory, 
                subcategory: selectedSubcategory, 
                isActiveOnly: true, 
                limit: limit
            )
            
            print("🔍 DEBUG fetchByUserPreferences: Category result count: \(result.count)")
            return result
        }
        
        // Fallback: return all active content
        print("🔍 DEBUG fetchByUserPreferences: Fallback: fetching all active content")
        return try await dynamoDBService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
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
                
                // Fetch new content based on preferences
                let newItems = try await fetchByUserPreferences(limit: 20)
                browseQueue = newItems
                
                browseForwardLog("🔄 Queue refreshed with \(browseQueue.count) items")
                
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
        let result = try await dynamoDBService.fetchBFQueueItems(category: nil, subcategory: nil, isActiveOnly: true, limit: limit)
        
        browseForwardLog("🎲 Default content result count: \(result.count)")
        browseForwardLog("🎲 === ENDING fetchDefaultContent ===")
        return result
    }
    
    // MARK: - Queue Management Methods
    
    func initializeBrowseQueue() async {
        browseForwardLog("🔄 Initializing browse queue")
        isLoading = true
        
        do {
            let items = try await fetchByUserPreferences(limit: 20)
            browseQueue = items
            currentIndex = 0
            browseForwardLog("✅ Queue initialized with \(browseQueue.count) items")
        } catch {
            browseForwardLog("❌ Failed to initialize queue: \(error)")
            // Fallback to default content
            do {
                let defaultItems = try await fetchDefaultContent(limit: 15)
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
            let moreItems = try await fetchByUserPreferences(limit: 15)
            browseQueue.append(contentsOf: moreItems)
            browseForwardLog("✅ Added \(moreItems.count) more items to queue. Total: \(browseQueue.count)")
        } catch {
            browseForwardLog("❌ Failed to load more items: \(error)")
            // Fallback to default content
            do {
                let fallbackItems = try await fetchDefaultContent(limit: 15)
                browseQueue.append(contentsOf: fallbackItems)
                browseForwardLog("✅ Added \(fallbackItems.count) fallback items to queue. Total: \(browseQueue.count)")
            } catch {
                browseForwardLog("❌ Even fallback load more failed: \(error)")
            }
        }
        
        isLoading = false
    }
}
