//
//  CategorySelectionView.swift
//  DumFlow
//

import SwiftUI

struct EnhancedBrowseForwardCategorySelector: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var viewModel: BrowseForwardViewModel

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    init() {
        self._isPresented = .constant(false)
    }

    /// Maps raw API category keys → human-readable labels.
    private static let displayName: [String: String] = [
        "All": "All",
        "technology": "Tech",
        "webgames": "Games",
        "news": "News",
        "movies": "Movies",
        "food": "Food",
        "wikipedia": "Wiki",
        "youtube": "Video",
        "Short Reads": "Short Reads"
    ]

    private func label(for category: String) -> String {
        Self.displayName[category] ?? category.capitalized
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.availableCategories, id: \.self) { category in
                    Button(action: {
                        viewModel.selectCategory(category)
                    }) {
                        Text(label(for: category))
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// Legacy name support
typealias CategorySelectionView = EnhancedBrowseForwardCategorySelector
