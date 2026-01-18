//
//  CategorySelectionView.swift
//  DumFlow
//
//  Stub implementation for category selection
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

    let categories = ["All", "Science", "Culture", "Entertainment", "News", "Classics"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        viewModel.selectCategory(category)
                    }) {
                        Text(category)
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