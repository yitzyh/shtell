//
//  HistoryView.swift
//  DumFlow
//
//  Created by Claude on 7/19/25.
//  Browser history view with search and navigation
//

import SwiftUI
import CloudKit

struct HistoryView: View {
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    var filteredHistory: [BrowserHistory] {
        let history = webPageViewModel.browserHistoryService.recentHistory
        
        // Apply search filter only
        if !searchText.isEmpty {
            return history.filter { entry in
                entry.urlString.localizedCaseInsensitiveContains(searchText) ||
                entry.title?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.domain.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return history
    }
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter bar
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search history...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // History list
                if webPageViewModel.browserHistoryService.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading history...")
                        Spacer()
                    }
                } else if filteredHistory.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No browsing history")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "Start browsing to see your history here" : "No results for '\(searchText)'")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredHistory, id: \.id) { entry in
                            HistoryRowView(entry: entry) {
                                // Navigate to URL
                                webBrowser.urlString = entry.urlString
                                webBrowser.isUserInitiatedNavigation = true
                                dismiss()
                            }
                        }
                        
                        // Load More Section
                        if webPageViewModel.browserHistoryService.hasMoreData && searchText.isEmpty {
                            Section {
                                Button {
                                    webPageViewModel.browserHistoryService.loadMoreIfNeeded()
                                } label: {
                                    HStack {
                                        if webPageViewModel.browserHistoryService.isLoadingMore {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .padding(.trailing, 8)
                                            Text("Loading more...")
                                                .foregroundColor(.secondary)
                                        } else {
                                            Image(systemName: "arrow.down.circle")
                                                .foregroundColor(.blue)
                                            Text("Load More")
                                                .foregroundColor(.blue)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .disabled(webPageViewModel.browserHistoryService.isLoadingMore)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            webPageViewModel.browserHistoryService.fetchHistory()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(role: .destructive) {
                            webPageViewModel.browserHistoryService.clearHistory()
                        } label: {
                            Label("Clear All History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            webPageViewModel.browserHistoryService.fetchHistory()
        }
    }
}

struct HistoryRowView: View {
    let entry: BrowserHistory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Favicon placeholder
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(entry.title ?? entry.urlString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // URL and domain
                    Text(entry.domain)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    // Analytics info
                    HStack(spacing: 8) {
                        Text(formatTime(entry.dateVisited))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if entry.visitCount > 1 {
                            Text("• \(entry.visitCount) visits")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let duration = entry.viewDuration, duration > 10 {
                            Text("• \(Int(duration))s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
        .environmentObject(WebPageViewModel(authViewModel: AuthViewModel()))
        .environmentObject(WebBrowser())
}