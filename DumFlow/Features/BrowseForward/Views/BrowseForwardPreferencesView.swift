//
//  BrowseForwardPreferencesView.swift
//  DumFlow
//
//  Stub implementation for compatibility
//

import SwiftUI

struct BrowseForwardPreferencesView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack {
                Text("BrowseForward Preferences")
                    .font(.headline)
                    .padding()

                Text("Settings coming in next update")
                    .foregroundColor(.gray)

                Spacer()
            }
            .navigationTitle("Preferences")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

struct BrowseForwardPreferences: Codable {
    var enabled: Bool = true
    var autoPlay: Bool = false
    var preloadCount: Int = 3
    var selectedCategories: Set<String> = ["All"]
    var selectedSubcategories: [String: Set<String>] = [:]
}