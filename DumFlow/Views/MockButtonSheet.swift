//
//  MockButtonSheet.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 8/7/25.
//

import SwiftUI

struct MockButtonSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategories: Set<String> = []
    
    private let buttonCategories = [
        "Wikipedia", "Trending", "Internet Archive",
        "HackerNews", "Podcasts", "Games"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        // Button Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(buttonCategories, id: \.self) { category in
                                Button(action: {
                                    toggleCategory(category)
                                }) {
                                    HStack {
                                        Text(category)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        if isSelected(category) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(isSelected(category) ? .blue : Color(.systemGray6))
                                    .foregroundColor(isSelected(category) ? .white : .primary)
                                    .cornerRadius(12)
                                    .animation(.easeInOut(duration: 0.2), value: isSelected(category))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
    
    private func isSelected(_ category: String) -> Bool {
        return selectedCategories.contains(category.lowercased())
    }
    
    private func toggleCategory(_ category: String) {
        let key = category.lowercased()
        if selectedCategories.contains(key) {
            selectedCategories.remove(key)
            print("Deselected: \(category)")
        } else {
            selectedCategories.insert(key)
            print("Selected: \(category)")
        }
    }
}

#Preview {
    MockButtonSheet()
}