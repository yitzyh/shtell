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
    @EnvironmentObject private var webBrowser: WebBrowser

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Use the same category/tag selector as the search overlay
                ScrollView {
                    VStack(spacing: 16) {
                        EnhancedBrowseForwardCategorySelector()
                            .environmentObject(browseForwardViewModel)
                            .environmentObject(webBrowser)
                            .padding(.top, 20)
                            .padding(.bottom, 20)

                        Spacer(minLength: 40)
                    }
                }
                .background(Color(UIColor.systemBackground))
            }
            .background(Color(UIColor.systemBackground))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Browse Preferences")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
