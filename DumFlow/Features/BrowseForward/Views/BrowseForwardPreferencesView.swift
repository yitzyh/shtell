import SwiftUI
import Foundation

// MARK: - User Preferences Model
struct BrowseForwardPreferences: Codable {
    var selectedCategories: Set<String> = []
    var selectedSubcategories: [String: Set<String>] = [:]
    var lastUpdated: Date = Date()
    
    var isDefaultMode: Bool {
        selectedCategories.isEmpty
    }
}

// MARK: - Main View
struct BrowseForwardPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var browseForwardViewModel: BrowseForwardViewModel
    @State private var preferences = BrowseForwardPreferences()
    @State private var selectedCategoryForSubcategories: String?
    
    // Dynamic content from database
    @State private var availableCategories: [String] = []
    @State private var categorySubcategories: [String: [String]] = [:]
    @State private var isLoadingContent = false
    
    private let userDefaultsKey = "BrowseForwardPreferences"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoadingContent {
                        ProgressView("Loading categories...")
                            .frame(height: 100)
                    } else {
                        // Default mode info
                        if preferences.isDefaultMode {
                            defaultModeSection
                        }
                        
                        // Categories section
                        categoriesSection
                        
                        // Subcategories section (if category selected)
                        if let selectedCategory = selectedCategoryForSubcategories,
                           let subcategories = categorySubcategories[selectedCategory],
                           !subcategories.isEmpty {
                            subcategoriesSection(for: selectedCategory, subcategories: subcategories)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        clearAllSelections()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("Browse Categories")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadPreferences()
            loadDynamicContent()
        }
    }
    
    // MARK: - View Sections
    
    private var defaultModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "infinity.circle.fill")
                    .foregroundColor(.green)
                Text("All Active Content")
                    .font(.headline)
                Spacer()
            }
            
            Text("Currently showing all active content from the database. Select categories below to filter your browsing experience.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.green.opacity(0.05))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                Text("Categories")
                    .font(.headline)
                Spacer()
                Text("\(availableCategories.count) available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !availableCategories.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Categories with subcategories
                    let categoriesWithSubs = availableCategories.filter { categorySubcategories[$0]?.isEmpty == false }.sorted()
                    let categoriesWithoutSubs = availableCategories.filter { categorySubcategories[$0]?.isEmpty != false }.sorted()
                    
                    if !categoriesWithSubs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("With Subcategories")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                ForEach(categoriesWithSubs, id: \.self) { category in
                                    HierarchicalCategoryButton(
                                        title: category,
                                        subcategoryCount: categorySubcategories[category]?.count ?? 0,
                                        isSelected: preferences.selectedCategories.contains(category),
                                        hasSubcategories: true
                                    ) {
                                        toggleCategory(category)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !categoriesWithoutSubs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Direct Categories")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(categoriesWithoutSubs, id: \.self) { category in
                                    CategoryButton(
                                        title: category,
                                        isSelected: preferences.selectedCategories.contains(category),
                                        hasSubcategories: false
                                    ) {
                                        toggleCategory(category)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Text("No categories found in database")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.blue.opacity(0.05))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
    }
    
    private func subcategoriesSection(for category: String, subcategories: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.orange)
                Text("\(category) Subcategories")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    selectedCategoryForSubcategories = nil
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(subcategories.sorted(), id: \.self) { subcategory in
                    CategoryButton(
                        title: subcategory,
                        isSelected: preferences.selectedSubcategories[category]?.contains(subcategory) ?? false,
                        hasSubcategories: false
                    ) {
                        toggleSubcategory(subcategory, for: category)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.orange.opacity(0.05))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: selectedCategoryForSubcategories)
    }
    
    
    
    
    // MARK: - Helper Views
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.headline)
    }
    
    // MARK: - Toggle Methods
    
    private func toggleCategory(_ category: String) {
        if preferences.selectedCategories.contains(category) {
            preferences.selectedCategories.remove(category)
            preferences.selectedSubcategories[category] = nil
            selectedCategoryForSubcategories = nil
        } else {
            preferences.selectedCategories.insert(category)
            preferences.selectedSubcategories[category] = []
            // Show subcategories if available
            if let subcategories = categorySubcategories[category], !subcategories.isEmpty {
                selectedCategoryForSubcategories = category
            }
        }
        
        // Auto-refresh content when category changes
        Task {
            await refreshBrowseForwardContent()
        }
    }
    
    private func toggleSubcategory(_ subcategory: String, for category: String) {
        if preferences.selectedSubcategories[category] == nil {
            preferences.selectedSubcategories[category] = []
        }
        
        if preferences.selectedSubcategories[category]!.contains(subcategory) {
            preferences.selectedSubcategories[category]!.remove(subcategory)
        } else {
            preferences.selectedSubcategories[category]!.insert(subcategory)
        }
        
        // Auto-refresh content when subcategory changes
        Task {
            await refreshBrowseForwardContent()
        }
    }
    
    private func clearAllSelections() {
        preferences.selectedCategories.removeAll()
        preferences.selectedSubcategories.removeAll()
        selectedCategoryForSubcategories = nil
        
        // Auto-refresh content to show all active content
        Task {
            await refreshBrowseForwardContent()
        }
    }
    
    @MainActor
    private func refreshBrowseForwardContent() async {
        // Refresh the BrowseForward content queue with new preferences
        await browseForwardViewModel.refreshWithPreferences(
            selectedCategories: Array(preferences.selectedCategories),
            selectedSubcategories: preferences.selectedSubcategories
        )
    }
    
    // MARK: - Dynamic Content Loading
    
    private func loadDynamicContent() {
        print("🔄 DEBUG loadDynamicContent: Starting to load categories")
        Task { @MainActor in
            isLoadingContent = true
            
            do {
                print("🔄 DEBUG loadDynamicContent: About to call getAvailableCategories")
                // Load categories
                availableCategories = try await DynamoDBWebPageService.shared.getAvailableCategories()
                print("✅ Categories loaded: \(availableCategories.count)")
                print("✅ Categories: \(availableCategories)")
                
                // Load subcategories for each category
                for category in availableCategories {
                    print("🔄 DEBUG loadDynamicContent: Loading subcategories for: \(category)")
                    do {
                        let subcategories = try await DynamoDBWebPageService.shared.getSubcategories(for: category)
                        print("✅ Subcategories for \(category): \(subcategories.count) - \(subcategories)")
                        if !subcategories.isEmpty {
                            categorySubcategories[category] = subcategories
                        }
                    } catch {
                        print("⚠️ Failed to load subcategories for \(category): \(error)")
                    }
                }
                
                print("✅ Dynamic content loaded: \(availableCategories.count) categories, \(categorySubcategories.count) with subcategories")
                
            } catch {
                print("❌ Failed to load dynamic content: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Error description: \(error.localizedDescription)")
                // Keep empty arrays as fallback
            }
            
            print("🔄 DEBUG loadDynamicContent: Setting isLoadingContent = false")
            isLoadingContent = false
        }
    }
    
    // MARK: - Persistence
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let loadedPreferences = try? JSONDecoder().decode(BrowseForwardPreferences.self, from: data) {
            self.preferences = loadedPreferences
        }
    }
    
    private func savePreferences() {
        preferences.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // Post notification that preferences have changed
            NotificationCenter.default.post(name: Notification.Name("BrowseForwardPreferencesChanged"), object: nil)
        }
    }
}

// MARK: - Category Button Components

struct HierarchicalCategoryButton: View {
    let title: String
    let subcategoryCount: Int
    let isSelected: Bool
    let hasSubcategories: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    Spacer()
                    
                    if hasSubcategories {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }
                
                HStack {
                    Text("\(subcategoryCount) subcategories")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? .blue : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let hasSubcategories: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                if hasSubcategories {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? .blue : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}


// MARK: - Preview
struct BrowseForwardPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        BrowseForwardPreferencesView()
    }
}
