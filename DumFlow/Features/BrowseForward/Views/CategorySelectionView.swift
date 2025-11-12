import SwiftUI

// MARK: - Enhanced Category Selector with Subcategories
struct EnhancedBrowseForwardCategorySelector: View {
    @EnvironmentObject private var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject private var webBrowser: WebBrowser
    @AppStorage("BrowseForwardPreferences") private var preferencesData: Data = Data()

    @State private var selectedCategories: Set<String> = []
    @State private var selectedSubcategories: [String: Set<String>] = [:] // category -> selected subcategories
    @State private var availableCategories: [String] = []
    @State private var availableSubcategories: [String: [String]] = [:] // category -> [subcategories]
    @State private var isLoadingCategories = false
    @State private var cachedCombinedTags: [String] = [] // Cached to prevent excessive recomputation

    // Dynamically determine which categories have subcategories
    private var categoriesWithSubs: Set<String> {
        Set(availableSubcategories.keys.filter { !availableSubcategories[$0]!.isEmpty })
    }

    var body: some View {
        VStack(spacing: 8) {
            if isLoadingCategories {
                ProgressView("Loading categories...")
                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                    .frame(height: 120)
            } else if !availableCategories.isEmpty {
                // Main categories (2 rows, scroll together)
                let sortedCategories = availableCategories.sorted()
                let halfCount = (sortedCategories.count + 1) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        // First row
                        HStack(spacing: 8) {
                            ForEach(sortedCategories.prefix(halfCount), id: \.self) { category in
                                EnhancedCategoryButton(
                                    title: category,
                                    isSelected: selectedCategories.contains(category),
                                    pageBackgroundIsDark: webBrowser.pageBackgroundIsDark
                                ) {
                                    toggleCategory(category)
                                }
                            }
                        }
                        .frame(height: 44)

                        // Second row
                        HStack(spacing: 8) {
                            ForEach(sortedCategories.dropFirst(halfCount), id: \.self) { category in
                                EnhancedCategoryButton(
                                    title: category,
                                    isSelected: selectedCategories.contains(category),
                                    pageBackgroundIsDark: webBrowser.pageBackgroundIsDark
                                ) {
                                    toggleCategory(category)
                                }
                            }
                        }
                        .frame(height: 44)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 96)
                }
                .frame(height: 96)

                // Show loading indicator when fetching category content
                if browseForwardViewModel.isLoading && !selectedCategories.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading \(selectedCategories.sorted().joined(separator: ", "))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(height: 20)
                    .padding(.vertical, 4)
                }

                // Tags (2 rows, scroll together, combined from all selected categories)
                if !cachedCombinedTags.isEmpty {
                    let halfCount = (cachedCombinedTags.count + 1) / 2

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            // First row
                            HStack(spacing: 8) {
                                ForEach(cachedCombinedTags.prefix(halfCount), id: \.self) { tag in
                                    SubcategoryTag(
                                        title: tag,
                                        isSelected: isTagSelected(tag),
                                        pageBackgroundIsDark: webBrowser.pageBackgroundIsDark
                                    ) {
                                        toggleTag(tag)
                                    }
                                }
                            }
                            .frame(height: 32)

                            // Second row
                            HStack(spacing: 8) {
                                ForEach(cachedCombinedTags.dropFirst(halfCount), id: \.self) { tag in
                                    SubcategoryTag(
                                        title: tag,
                                        isSelected: isTagSelected(tag),
                                        pageBackgroundIsDark: webBrowser.pageBackgroundIsDark
                                    ) {
                                        toggleTag(tag)
                                    }
                                }
                            }
                            .frame(height: 32)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 72)
                    }
                    .frame(height: 72)
                } else {
                    Text("Select categories to see tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 40)
                }
            }
        }
        .onAppear {
            loadPreferences()
            loadCategories()

            // Initialize browse queue if empty
            if browseForwardViewModel.browseQueue.isEmpty {
                Task {
                    await browseForwardViewModel.refreshWithPreferences(
                        selectedCategories: Array(selectedCategories),
                        selectedSubcategories: selectedSubcategories
                    )
                }
            } else {
                // Items already loaded, extract subcategories immediately
                extractSubcategoriesFromLoadedItems()
            }
        }
        .onChange(of: browseForwardViewModel.fullUnfilteredItems) {
            // Extract subcategories whenever new full items are loaded from API
            extractSubcategoriesFromLoadedItems()
        }
    }

    // Extract unique subcategories from FULL unfiltered items (not filtered browseQueue!)
    private func extractSubcategoriesFromLoadedItems() {
        print("🏷️ Extracting subcategories from FULL unfiltered items")

        var subcategoriesByCategory: [String: Set<String>] = [:]

        // Extract from FULL unfiltered items, not from filtered browseQueue
        for item in browseForwardViewModel.fullUnfilteredItems {
            guard let category = item.bfCategory,
                  let subcategory = item.bfSubcategory,
                  !subcategory.isEmpty else {
                continue
            }

            if subcategoriesByCategory[category] == nil {
                subcategoriesByCategory[category] = []
            }
            subcategoriesByCategory[category]?.insert(subcategory)
        }

        // Convert to sorted arrays
        var updatedAvailableSubcategories: [String: [String]] = [:]
        for (category, subcatSet) in subcategoriesByCategory {
            updatedAvailableSubcategories[category] = Array(subcatSet).sorted()
        }

        availableSubcategories = updatedAvailableSubcategories

        print("✅ Extracted subcategories from \(browseForwardViewModel.fullUnfilteredItems.count) full items: \(availableSubcategories)")

        // Update cached combined tags
        updateCachedCombinedTags()
    }

    // Update the cached combined tags from availableSubcategories
    private func updateCachedCombinedTags() {
        var allTags = Set<String>()

        for category in selectedCategories {
            if let categorySubs = availableSubcategories[category], !categorySubs.isEmpty {
                allTags.formUnion(categorySubs)
            }
        }

        cachedCombinedTags = Array(allTags).sorted()
        print("🏷️ Updated cachedCombinedTags: \(cachedCombinedTags.count) tags")
    }

    // Check if a tag is selected in any category
    private func isTagSelected(_ tag: String) -> Bool {
        for category in selectedCategories where categoriesWithSubs.contains(category) {
            if selectedSubcategories[category]?.contains(tag) == true {
                return true
            }
        }
        return false
    }

    // Toggle tag across all selected categories that have this tag
    private func toggleTag(_ tag: String) {
        let isCurrentlySelected = isTagSelected(tag)

        // Toggle the tag in all selected categories that have this subcategory
        for category in selectedCategories where categoriesWithSubs.contains(category) {
            if let categorySubs = availableSubcategories[category], categorySubs.contains(tag) {
                if selectedSubcategories[category] == nil {
                    selectedSubcategories[category] = []
                }

                if isCurrentlySelected {
                    selectedSubcategories[category]!.remove(tag)
                } else {
                    selectedSubcategories[category]!.insert(tag)
                }
            }
        }

        savePreferences()

        // NOTE: Don't refresh here! ViewModel will filter client-side based on preferences
        // Making a new API call causes tags to disappear and wastes 10+ seconds
        print("🏷️ Tag toggled, preferences saved. ViewModel will filter existing items.")
    }

    private func toggleCategory(_ category: String) {
        print("🔘 toggleCategory called for: \(category)")

        if selectedCategories.contains(category) {
            print("🔘 DESELECTING \(category)")
            selectedCategories.remove(category)
            // Clean up stale subcategory data
            selectedSubcategories.removeValue(forKey: category)
        } else {
            print("🔘 SELECTING \(category)")
            selectedCategories.insert(category)
        }

        // Update cached tags based on new selection
        updateCachedCombinedTags()

        savePreferences()

        // Auto-refresh content when category changes
        // Note: extractSubcategoriesFromLoadedItems() will be called automatically
        // via .onChange(of: browseQueue) when items finish loading
        Task {
            await browseForwardViewModel.refreshWithPreferences(
                selectedCategories: Array(selectedCategories),
                selectedSubcategories: selectedSubcategories
            )
        }
    }

    private func loadCategories() {
        Task { @MainActor in
            isLoadingCategories = true

            do {
                availableCategories = try await BrowseForwardAPIService.shared.getAvailableCategories()
                print("✅ Loaded \(availableCategories.count) categories")

                // Note: extractSubcategoriesFromLoadedItems() will be called automatically
                // via .onChange(of: browseQueue) when items are available
            } catch {
                print("❌ Failed to load categories: \(error)")
                availableCategories = []
            }

            isLoadingCategories = false
        }
    }

    private func loadPreferences() {
        if let preferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: preferencesData) {
            selectedCategories = preferences.selectedCategories
            selectedSubcategories = preferences.selectedSubcategories
        }
    }

    private func savePreferences() {
        let preferences = BrowseForwardPreferences(
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            lastUpdated: Date()
        )
        if let data = try? JSONEncoder().encode(preferences) {
            preferencesData = data
            NotificationCenter.default.post(name: Notification.Name("BrowseForwardPreferencesChanged"), object: nil)
        }
    }
}

// MARK: - Enhanced Category Button with Better Selected State
struct EnhancedCategoryButton: View {
    let title: String
    let isSelected: Bool
    let pageBackgroundIsDark: Bool
    let action: () -> Void

    // Display friendly name for categories
    private var displayTitle: String {
        title == "webgames" ? "games" : title
    }

    var body: some View {
        Button(action: action) {
            Text(displayTitle)
                .font(.footnote)
                .fontWeight(isSelected ? .bold : .medium)
                // Always white text for readability on dark tinted background
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(minWidth: 60)
                .frame(height: 44)
                .padding(.horizontal, 16)
                .background(
                    ZStack {
                        if isSelected {
                            // Selected: Solid blue fill
                            Capsule()
                                .fill(Color.blue)
                        } else {
                            // Unselected: More opaque white for readability
                            Capsule()
                                .fill(.white.opacity(0.25))

                            // Glass effect on top
                            Group {
                                if #available(iOS 26.0, *) {
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.clear, in: Capsule())
                                } else {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.5)
                                }
                            }
                        }
                    }
                )
                // Border for selected state
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 2)
                )
                // Scale slightly larger when selected
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Subcategory Tag (Smaller version of category button)
struct SubcategoryTag: View {
    let title: String
    let isSelected: Bool
    let pageBackgroundIsDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                // Always white text for readability on dark tinted background
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(minWidth: 50)
                .frame(height: 32)
                .padding(.horizontal, 12)
                .background(
                    ZStack {
                        if isSelected {
                            // Selected: Solid blue fill (same as category)
                            Capsule()
                                .fill(Color.blue)
                        } else {
                            // Unselected: More opaque white for readability
                            Capsule()
                                .fill(.white.opacity(0.25))

                            // Glass effect on top
                            Group {
                                if #available(iOS 26.0, *) {
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.clear, in: Capsule())
                                } else {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.5)
                                }
                            }
                        }
                    }
                )
                // Border for selected state
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1.5)
                )
                // Scale slightly larger when selected
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
