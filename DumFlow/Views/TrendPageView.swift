//
//  TrendPageView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/26/24.
//

import SwiftUI
import CloudKit

struct TrendPageView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject private var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    
    
    @State var commentsUrlString: String?
    @State var isShowingComments = false
    @State var isSaved: Bool = false
    @State private var sortOrder: SortOrder = .dateCreated
    @State private var searchText = ""
    
    enum SortOrder: CaseIterable {
        case commentCount
        case dateCreated
        case likeCount
        case saved
        
        var title: String {
            switch self {
            case .commentCount: return "Comments"
            case .dateCreated: return "New"
            case .likeCount: return "Likes"
            case .saved: return "Saved"
            }
        }
        
        var iconName: String {
            switch self {
            case .commentCount: return "bubble.left.and.text.bubble.right"
            case .dateCreated: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
            case .likeCount: return "heart"
            case .saved: return "star"
            }
        }
    }
    
    // Pagination state
    @State private var visibleItemsCount = 20
    private let itemsPerPage = 20
    
    // Break up complex expressions to avoid compiler timeout
    private var webPagesWithComments: [WebPage] {
        return webPageViewModel.contentState.webPages.filter { $0.commentCount > 0 }
    }
    
    private var filteredWebPages: [WebPage] {
        guard !searchText.isEmpty else { return webPagesWithComments }
        
        return webPagesWithComments.filter { webPage in
            let titleMatch = webPage.title.localizedCaseInsensitiveContains(searchText)
            let urlMatch = webPage.urlString.localizedCaseInsensitiveContains(searchText)
            let hostMatch = URL(string: webPage.urlString)?.host?.localizedCaseInsensitiveContains(searchText) == true
            return titleMatch || urlMatch || hostMatch
        }
    }
    
    private var sortedWebPages: [WebPage] {
        let sorted: [WebPage]
        
        switch sortOrder {
        case .commentCount:
            sorted = filteredWebPages.sorted { $0.commentCount > $1.commentCount }
        case .dateCreated:
            sorted = filteredWebPages.sorted { $0.dateCreated > $1.dateCreated }
        case .likeCount:
            sorted = filteredWebPages.sorted { $0.likeCount > $1.likeCount }
        case .saved:
            sorted = filteredWebPages.filter { webPageViewModel.uiState.savedWebPageStates.contains($0.urlString) }
        }
        
        // Return paginated results
        return Array(sorted.prefix(visibleItemsCount))
    }
    
    private var hasMoreItems: Bool {
        return visibleItemsCount < webPagesWithComments.count
    }
    
    var body: some View {
        NavigationStack{
            VStack {
                // ✅ ADDED: Loading state handling
                if webPageViewModel.loadingState.isLoadingWebPage {
                    VStack {
                        ProgressView("Loading webpages...")
                            .padding()
                        Spacer()
                    }
                }
                else {
                    // ✅ FIXED: Only show list when data is loaded
                    List{
                        ForEach(sortedWebPages) { webPage in
                            WebPageRowView(webPage: webPage, commentsUrlString: $commentsUrlString)
                                .onAppear {
                                    // Lazy loading trigger - use index instead of object comparison
                                    if let lastIndex = sortedWebPages.indices.last,
                                       let currentIndex = sortedWebPages.firstIndex(where: { $0.id == webPage.id }),
                                       currentIndex == lastIndex,
                                       hasMoreItems {
                                        loadMoreItems()
                                    }
                                }
                        }
                        .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                        
                        // Loading indicator for pagination
                        if hasMoreItems && visibleItemsCount > 20 {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .onAppear {
                                loadMoreItems()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search webpages")
                    // ✅ ADDED: Pull to refresh
                    .refreshable {
                        await refreshData()
                    }
                }
            }
        }
        .onAppear{
            webPageViewModel.fetchAllWebPages()
        }
        .onChange(of: sortOrder) { _, _ in
            // Reset pagination when sort order changes
            visibleItemsCount = itemsPerPage
        }
        .onChange(of: searchText) { _, _ in
            // Reset pagination when search changes
            visibleItemsCount = itemsPerPage
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(colorScheme == .dark ? Color(white: 0.07) : .white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
//        .toolbarColorScheme(.dark, for: .navigationBar)
//        .accentColor(.white)
        .toolbar{
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu{
                    Picker("Sort Order", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Label(order.title, systemImage: order.iconName)
                                .tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                // ✅ ADDED: Disable menu while loading
                .disabled(webPageViewModel.loadingState.isLoadingWebPage)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink{
                    TrendingView(webPages: sortedWebPages)
                } label: {
                    Image(systemName: "newspaper")
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                // ✅ ADDED: Disable navigation while loading
                .disabled(webPageViewModel.loadingState.isLoadingWebPage || sortedWebPages.isEmpty)
            }
            
            // ✅ ADDED: Manual refresh button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        webPageViewModel.fetchAllWebPages()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .disabled(webPageViewModel.loadingState.isLoadingWebPage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetToRoot"))) { _ in
            presentationMode.wrappedValue.dismiss()
        }
        .sheet(isPresented: .constant(commentsUrlString != nil), onDismiss: {
            // Reset the WebPageViewModel state when the sheet closes
//            webPageViewModel.urlString = nil
            webPageViewModel.contentState.webPage = nil
            webPageViewModel.contentState.comments = []
            commentsUrlString = nil
        }) {
            if let urlString = commentsUrlString {
                NavigationStack {
                    CommentView(urlString: urlString)
                        .environmentObject(webPageViewModel)
                        .environmentObject(webBrowser)
                        .environmentObject(authViewModel)
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.fraction(0.75), .large])
                        .presentationContentInteraction(.scrolls)
                        .presentationCornerRadius(20)
                }
            }
        }
        .alert("Error Loading Webpages", isPresented: $webPageViewModel.loadingState.showErrorAlert) {
            Button("Retry") {
                Task {
                    webPageViewModel.fetchAllWebPages()
                }
            }
            Button("OK") { }
        } message: {
            Text(webPageViewModel.loadingState.error?.localizedDescription ?? "Failed to load webpages")
        }
    }
    
    // MARK: - Pagination Functions
    
    private func loadMoreItems() {
        guard hasMoreItems else { return }
        
        // Load more items on background thread to avoid blocking UI
        Task {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    visibleItemsCount += itemsPerPage
                }
            }
        }
    }
    
    private func refreshData() async {
        // Reset pagination and refresh data
        visibleItemsCount = itemsPerPage
        webPageViewModel.fetchAllWebPages()
        
        // Also refresh Wikipedia articles
        // Wikipedia fetching moved to BrowseForwardViewModel
    }
}
