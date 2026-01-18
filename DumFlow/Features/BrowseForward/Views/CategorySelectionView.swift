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
        NavigationView {
            List(categories, id: \.self) { category in
                Button(action: {
                    viewModel.selectCategory(category)
                    isPresented = false
                }) {
                    HStack {
                        Text(category)
                        Spacer()
                        if viewModel.selectedCategory == category {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

// Legacy name support
typealias CategorySelectionView = EnhancedBrowseForwardCategorySelector