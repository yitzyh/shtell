//
//  ContentView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 4/28/24.
//
import SwiftData
import SwiftUI
import UIKit
import WebKit

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    
    @FocusState private var searchIsFocused: Bool
    @Namespace private var toolbarNamespace
    @Namespace private var bottomToolbarNamespace
    
    @State private var isShowingComments = false
    @State private var isShowingWelcome = false
    @State private var isShowingTrending = false
    @State private var isShowingSafariView = false
    @State private var isShowingBrowseForwardPreferences = false
    @State private var isSafariReaderMode = false
    @State private var scrollProgress: CGFloat = 0.0 // 0.0 = full toolbar, 1.0 = compact
    @State private var searchBarText: String = ""
    @State private var numComments: Int = 0
    @State private var isShowingHistory = false
    @State private var isShowingMenu = false
    @State private var isShowingSaved = false
    @State private var isShowingProfile = false
    @State private var isShowingSignIn = false
    @State private var searchResults: [BrowseForwardItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var showNoResults = false  // Explicit flag to prevent flash

    private let topToolbarHeight: CGFloat = 44
    private let toolbarHeight: CGFloat = 44
    
    var body: some View {
        NavigationStack{
            //WebView()
            ZStack{
                WebView(
                    scrollProgress: $scrollProgress,
                    onQuoteText: { quotedText, selector, offset in
                        handleQuoteText(quotedText, selector, offset)
                    },
                    onCommentTap: { commentID in
                        handleCommentTap(commentID)
                    }
                )
                .ignoresSafeArea()
                .environmentObject(webBrowser)
                .environmentObject(browseForwardViewModel)
                .environmentObject(webPageViewModel)
                .onAppear {
                    webBrowser.webPageViewModel = webPageViewModel
                    webBrowser.browseForwardViewModel = browseForwardViewModel
                    // webPageViewModel.fetchNewsAPIURLs() // Commented out due to rate limits
                }
                .onChange(of: webBrowser.urlString){ _, newURL in
//                    webPageViewModel.webBrowserFetch(for: webBrowser.urlString.normalizedURL ?? "poop")
                    webPageViewModel.urlString = newURL   // triggers didSet → loadWebPageCK → fetchCommentsCK
                    searchBarText = webBrowser.urlString
                }
                
                // Card list overlay - always present but hidden when not needed
                VStack(spacing: 0) {
                    // Minimal top spacing
                    Spacer()
                        .frame(height: 60)

                    // 1. Cards at top (results/content) - fixed position
                    // Priority: Searching spinner → Search results/empty → Default browse queue
                    if isSearching {
                        // Show spinner while searching
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Searching...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .frame(height: 158)
                        .frame(maxWidth: .infinity)
                    } else if !searchBarText.isEmpty && searchBarText != webBrowser.urlString {
                        // User has typed a search query (not a URL)
                        if !searchResults.isEmpty {
                            // Show search results
                            WebPageCardListView(
                                commentsUrlString: .constant(nil),
                                onURLTap: { urlString in
                                    searchIsFocused = false
                                    normalizeAndLoads(urlString)
                                },
                                items: searchResults
                            )
                            .environmentObject(webBrowser)
                            .environmentObject(browseForwardViewModel)
                            .environmentObject(webPageViewModel)
                            .frame(height: 158)
                        } else if showNoResults {
                            // Only show "No results" when explicitly told to
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("No results for '\(searchBarText)'")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(height: 158)
                            .frame(maxWidth: .infinity)
                        } else {
                            // Transitioning - show default queue
                            WebPageCardListView(
                                commentsUrlString: .constant(nil),
                                onURLTap: { urlString in
                                    searchIsFocused = false
                                    normalizeAndLoads(urlString)
                                },
                                items: nil
                            )
                            .environmentObject(webBrowser)
                            .environmentObject(browseForwardViewModel)
                            .environmentObject(webPageViewModel)
                            .frame(height: 158)
                        }
                    } else {
                        // Show default browse queue
                        WebPageCardListView(
                            commentsUrlString: .constant(nil),
                            onURLTap: { urlString in
                                searchIsFocused = false
                                normalizeAndLoads(urlString)
                            },
                            items: nil
                        )
                        .environmentObject(webBrowser)
                        .environmentObject(browseForwardViewModel)
                        .environmentObject(webPageViewModel)
                        .frame(height: 158)
                    }
                    Spacer()
                        .frame(height: 12)

                    // 2. Categories/Tags below cards (filters/input)
                    EnhancedBrowseForwardCategorySelector()
                        .environmentObject(browseForwardViewModel)
                        .environmentObject(webBrowser)
                        .padding(.vertical, 12)
                        .padding(.bottom, 12)

                    Spacer()

                    // 3. Bangs at bottom (actions) - only show when user has typed, closer to keyboard
//                    if searchBarText != webBrowser.urlString && !searchBarText.isEmpty {
//                        SearchBangsView(searchText: searchBarText) { selectedBang in
//                            // Check if searchBarText is a URL or a search query
//                            let isURL = searchBarText.hasPrefix("http://") ||
//                                       searchBarText.hasPrefix("https://") ||
//                                       (searchBarText.contains(".") && !searchBarText.contains(" "))
//
//                            let finalURL: String
//                            if isURL {
//                                // If it's a URL, just go to the bang's homepage
//                                finalURL = selectedBang.homepage
//                            } else {
//                                // If it's a search query, search on that site
//                                let query = searchBarText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchBarText
//                                finalURL = selectedBang.searchPrefix + query
//                            }
//
//                            webBrowser.urlString = finalURL
//                            webBrowser.isUserInitiatedNavigation = true
//                            searchBarText = finalURL
//                            searchIsFocused = false
//                        }
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .ignoresSafeArea()
                )
                .opacity(searchIsFocused ? 1 : 0)
                .allowsHitTesting(searchIsFocused)
                
                VStack{
                    
                    // TOP TOOLBAR - Safari-style morphing animation
                    FullToolbar(
                        namespace: toolbarNamespace,
                        searchIsFocused: $searchIsFocused,
                        searchBarText: $searchBarText,
                        isShowingComments: $isShowingComments,
                        scrollProgress: scrollProgress,
                        isShowingSafariView: $isShowingSafariView,
                        isSafariReaderMode: $isSafariReaderMode,
                        isShowingTrending: $isShowingTrending,
                        isShowingProfile: $isShowingProfile,
                        onSubmit: {
                            searchIsFocused = false
                            normalizeAndLoads(searchBarText)
                        },
                        onSearchBarTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollProgress = 0.0
                                searchIsFocused = true
                            }
                        }
                    )
                    // Removed intercepting tap gesture that blocked focus

                    Spacer()
                    
                    // BOTTOM TOOLBAR - Single morphing toolbar
                    if !searchIsFocused {
                        bottomToolbar
                    }
                }
            }
        }
        .onAppear {
            webPageViewModel.refreshCommentCounts()
        }
//        .onChange(of: webPageViewModel.allWebPages) { _, _ in
//            updateWebBrowserURLs()
//        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetToRoot"))) { _ in
            // Reset ContentView state
            isShowingComments = false
            isShowingTrending = false
            isShowingSafariView = false
            searchIsFocused = false
        }
        .alert(isPresented: $webPageViewModel.loadingState.showErrorAlert, error: webPageViewModel.loadingState.error) { error in
            Button("OK") {
                webPageViewModel.loadingState.showErrorAlert = false
            }
            
            //etry button for specific errors
            if case .loadingFailed = error {
                Button("loadingFailed") {
//                    Task {
//                        webPageViewModel.makeWebPage(for: webBrowser.urlString)
//                    }
                }
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Please try again")
        }
        .sheet(isPresented: $isShowingComments, onDismiss: {
            // Reset the WebPageViewModel state when the sheet closes
            webPageViewModel.urlString = nil
            webPageViewModel.contentState.webPage = nil
            webPageViewModel.contentState.comments = []
            webPageViewModel.uiState.pendingQuote = nil
        }) {
            NavigationStack {
                CommentView(urlString: webBrowser.urlString, onQuoteTap: { comment in
                    handleQuoteTap(comment)
                })
                    .environmentObject(webPageViewModel)
                    .environmentObject(webBrowser)
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationContentInteraction(.scrolls)
                    .presentationCornerRadius(20)
            }
        }
        .sheet(isPresented: $isShowingWelcome) {
            WelcomeView()
        }
        .sheet(isPresented: $isShowingSafariView) {
            if let url = URL(string: webBrowser.urlString) {
                SafariView(url: url, readerMode: isSafariReaderMode)
            } else {
                Text("Invalid URL")
                    .font(.headline)
                    .padding()
            }
        }
        .sheet(isPresented: $isShowingBrowseForwardPreferences) {
            BrowseForwardPreferencesView()
                .environmentObject(browseForwardViewModel)
                .environmentObject(webBrowser)
                .presentationDetents([.height(400), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingHistory) {
            HistoryView()
                .environmentObject(webPageViewModel)
                .environmentObject(authViewModel)
                .environmentObject(webBrowser)
        }
        .sheet(isPresented: $isShowingMenu) {
            ContentViewMenuView(
                isShowingHistory: $isShowingHistory,
                isShowingSafariView: $isShowingSafariView,
                isShowingBrowseForwardPreferences: $isShowingBrowseForwardPreferences,
                isSafariReaderMode: $isSafariReaderMode,
                isShowingSaved: $isShowingSaved
            )
            .environmentObject(authViewModel)
            .environmentObject(webBrowser)
            .environmentObject(webPageViewModel)
            .presentationDetents([.fraction(0.5)])
        }
        .sheet(isPresented: $isShowingSaved) {
            SavedWebPagesView()
                .environmentObject(authViewModel)
                .environmentObject(webPageViewModel)
                .environmentObject(webBrowser)
        }
        .sheet(isPresented: $isShowingSignIn) {
            VStack(spacing: 20) {
                Text("Sign in to save webpages")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                authViewModel.signInButton()
                    .frame(height: 50)
            }
            .padding()
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
            .onReceive(authViewModel.$signedInUser) { user in
                if user != nil {
                    // User signed in, dismiss sheet
                    isShowingSignIn = false
                }
            }
        }
        .onAppear{
            initViewModel()
            searchBarText = webBrowser.urlString

            // Preload popular categories for instant first-tap experience
            Task {
                await browseForwardViewModel.preloadPopularCategories()
            }
        }
        .onChange(of: searchBarText) { oldValue, newValue in
            // Only search when search is focused
            guard searchIsFocused else {
                searchResults = []
                return
            }

            // Don't search if text is a URL
            if newValue == webBrowser.urlString ||
               newValue.hasPrefix("http://") ||
               newValue.hasPrefix("https://") {
                searchResults = []
                return
            }

            // Cancel previous search task
            searchTask?.cancel()

            // Clear results if search is empty
            if newValue.isEmpty {
                searchResults = []
                isSearching = false
                showNoResults = false
                return
            }

            // Debounce search by 300ms
            searchTask = Task {
                await MainActor.run {
                    isSearching = true
                    showNoResults = false  // Clear flag when starting new search
                }

                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

                // Check if task was cancelled
                guard !Task.isCancelled else {
                    await MainActor.run { isSearching = false }
                    return
                }

                // Perform search
                do {
                    let results = try await BrowseForwardAPIService.shared.searchContent(query: newValue, limit: 20)

                    // Check again if task was cancelled before updating UI
                    guard !Task.isCancelled else {
                        await MainActor.run { isSearching = false }
                        return
                    }

                    await MainActor.run {
                        searchResults = results
                        isSearching = false
                        showNoResults = results.isEmpty  // Only set true if actually empty
                    }
                } catch {
                    print("❌ Search error: \(error)")
                    await MainActor.run {
                        searchResults = []
                        isSearching = false
                        showNoResults = true  // Show "No results" on error
                    }
                }
            }
        }
        .onChange(of: searchIsFocused) { oldValue, newValue in
            print("🔍 DEBUG: searchIsFocused changed from \(oldValue) to \(newValue)")
            print("🔍 DEBUG: displayedItems count = \(browseForwardViewModel.displayedItems.count)")

            if newValue {
                // Search overlay opened - load items if empty
                if browseForwardViewModel.displayedItems.isEmpty {
                    print("🔍 DEBUG: displayedItems is empty, loading content...")
                    Task {
                        await browseForwardViewModel.refreshWithPreferences(selectedCategories: [], selectedSubcategories: [:])
                    }
                }
            } else {
                // Search overlay closed - clear search state
                searchResults = []
                searchTask?.cancel()
                isSearching = false
                showNoResults = false
            }
        }
    }
    
    // MARK: - Bottom Toolbar States
    
    private var bottomToolbar: some View {
        VStack {
            Spacer()
            
            HStack {                                    // Layer 1: Centered container
                HStack {                                // Layer 2: Right-aligned container  
                    HStack(spacing: 0) {                     // Layer 3: Manual spacing system
                        // 4pt persistent left padding
                        Spacer().frame(width: 4)
                        // LEFT GROUP - Disappearing buttons with manual spacing
                        HStack(spacing: 0) {
                            // Back button - disappears first (0.0 to 0.33)
                            if scrollProgress < 0.33 {
                                Button { 
                                    webBrowser.goBack()
                                } label: {
                                    Image(systemName: "arrow.left")
                                        .foregroundColor(webBrowser.canGoBack ? (webBrowser.pageBackgroundIsDark ? .white : .black) : .gray)
                                        .font(.system(size: 22, weight: .medium))
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .disabled(!webBrowser.canGoBack)
                                .opacity(max(0, 1.0 - (scrollProgress * CGFloat(3))))
                                .scaleEffect(max(0.5, 1.0 - (scrollProgress * CGFloat(1.5))))
                            }
                            
                            // Spacer 1: Back → Menu (20pt → 0pt, disappears with Back)
                            if scrollProgress < 0.33 {
                                Spacer()
                                    .frame(width: max(0, 20 - (scrollProgress * 20)))
                            }
                            
                            // Menu button - disappears second (0.33 to 0.66)
                            if scrollProgress < 0.66 {
                                Button {
                                    isShowingMenu = true
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                        .font(.system(size: 22, weight: .medium))
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .opacity(scrollProgress < 0.33 ? 1.0 : max(0, 1.0 - (CGFloat((scrollProgress - 0.33) / 0.33))))
                                .scaleEffect(scrollProgress < 0.33 ? 1.0 : max(0.5, 1.0 - (CGFloat((scrollProgress - 0.33) / 0.33) * 0.5)))
                            }
                            
                            // Spacer 2: Menu → Save (20pt → 0pt, disappears with Menu)
                            if scrollProgress < 0.66 {
                                Spacer()
                                    .frame(width: max(0, 20 - (scrollProgress * 20)))
                            }
                            
                            // Save button - disappears last (0.66 to 1.0)
                            if scrollProgress < 1.0 {
                                let isSaved = webPageViewModel.uiState.savedWebPageStates.contains(webBrowser.urlString.normalizedURL ?? webBrowser.urlString)
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                    .font(.system(size: 22, weight: .medium))
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .onLongPressGesture {
                                        isShowingSaved = true
                                    }
                                    .onTapGesture {
                                        handleSaveButtonTap()
                                    }
                                    .opacity(scrollProgress < 0.66 ? 1.0 : max(0, 1.0 - (CGFloat((scrollProgress - 0.66) / 0.34))))
                                    .scaleEffect(scrollProgress < 0.66 ? 1.0 : max(0.5, 1.0 - (CGFloat((scrollProgress - 0.66) / 0.34) * 0.5)))
                            }
                            
                            // Spacer 3: Save → Comment (20pt → 0pt, disappears with Save)
                            if scrollProgress < 1.0 {
                                Spacer()
                                    .frame(width: max(0, 20 - (scrollProgress * 20)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: scrollProgress)
                        
                        // RIGHT GROUP - Always visible, no animations
                        HStack(spacing: 20) {
                            // Comment button (always visible, with count to right)
                            let normalized = webBrowser.urlString.normalizedURL ?? webBrowser.urlString
                            let count = webPageViewModel.contentState.commentCountLookup[normalized] ?? webPageViewModel.contentState.webPage?.commentCount ?? 0
                            
                            Image(systemName: "bubble.right")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if webBrowser.urlString.normalizedURL != nil {
                                        isShowingComments.toggle()
                                    } else {
                                        isShowingWelcome.toggle()
                                    }
                                }
                            .overlay(alignment: .leading) {
                                if count > 0 {
                                    Text(formatCommentCount(count))
                                        .contentTransition(.numericText())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                        .offset(x: 41, y: 0)  // Positioned right at the edge of the button
                                        .animation(.easeInOut(duration: 0.5), value: count)
                                }
                            }
                            .matchedGeometryEffect(id: "commentButton", in: bottomToolbarNamespace)
                            
                            // Forward/BrowseForward button with smart rotation
                            BrowseForwardButton(
                                webBrowser: webBrowser,
                                isShowingBrowseForwardPreferences: $isShowingBrowseForwardPreferences
                            )
                            .matchedGeometryEffect(id: "forwardButton", in: bottomToolbarNamespace)
                        }
                        
                        // 4pt persistent right padding
                        Spacer().frame(width: 4)
                    }
                    .background(                        // Background ONLY on button layer
                        Group {
                            if #available(iOS 26.0, *) {
                                RoundedRectangle(cornerRadius: 22)
                                    .glassEffect(.clear)
                            } else {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .animation(.easeInOut(duration: 0.3), value: scrollProgress)
                }
                .frame(width: 320, alignment: .center)  // Layer 2: Always center
            }
            .frame(maxWidth: .infinity, alignment: .center)        // Layer 1: Always center
            .offset(x: {
                // Calculate how much space the left buttons took up and shift right by that amount
                var offset: CGFloat = 0

                // Back button (44pt) + spacer (20pt) disappears from 0.0 to 0.33
                if scrollProgress > 0.0 {
                    let backProgress = min(scrollProgress / 0.33, 1.0)
                    offset += (44 + 20) * backProgress
                }

                // Menu button (44pt) + spacer (20pt) disappears from 0.33 to 0.66
                if scrollProgress > 0.33 {
                    let menuProgress = min((scrollProgress - 0.33) / 0.33, 1.0)
                    offset += (44 + 20) * menuProgress
                }

                // Save button (44pt) + spacer (20pt) disappears from 0.66 to 1.0
                if scrollProgress > 0.66 {
                    let saveProgress = min((scrollProgress - 0.66) / 0.34, 1.0)
                    offset += (44 + 20) * saveProgress
                }

                return offset / 2  // Divide by 2 because we're centering
            }())
            .padding(.horizontal, 20)
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    // Comment count formatter
    private func formatCommentCount(_ count: Int) -> String {
        switch count {
        case 0..<1000:
            return "\(count)"
        case 1000..<10000:
            return "\(count/1000)k"
        case 10000..<1000000:
            let rounded = (count + 500) / 1000
            return "\(rounded)k"
        default:
            let rounded = (count + 500000) / 1000000
            return "\(rounded)m"
        }
    }
    
    
    // Commented out - replaced with ContentViewMenuView sheet
    // private var menuButton: some View {
    //     Menu{
    //         // ... menu content moved to ContentViewMenuView
    //     } label: {
    //         Image(systemName: "ellipsis")
    //             .foregroundColor(.primary)
    //             .font(.system(size: 18, weight: .semibold))
    //     }
    // }
    
    private func initViewModel() {
//        if webPageViewModel.modelContext == nil {
//            webPageViewModel.modelContext = modelContext
//        }
        webPageViewModel.urlString = webBrowser.urlString
    }
    
    private func updateWebBrowserURLs() {
//        let urls = webPageViewModel.allWebPages
//            .filter { $0.commentCount > 0 }
//            .sorted { $0.dateCreated > $1.dateCreated }
//            .map { $0.urlString }
//        webBrowser.allWebPagesURLs = urls
    }
    
    private func normalizeAndLoads(_ input: String) {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate  = input.hasPrefix("http://") || input.hasPrefix("https://") ? input : "https://\(input)"
//        if let url = URL(string: candidate), url.host != nil {
        if let url = URL(string: candidate), let host = url.host, host.contains(".") {
            webBrowser.urlString = candidate
        } else {
            let query = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            webBrowser.urlString = "https://www.google.com/search?hl=en&q=\(query)"
        }
        webBrowser.isUserInitiatedNavigation = true
        searchBarText = webBrowser.urlString

    }
    
    // MARK: - Save Handler
    private func handleSaveButtonTap() {
        guard authViewModel.signedInUser != nil else {
            isShowingSignIn = true
            return
        }
        guard let normalizedURL = webBrowser.urlString.normalizedURL else { return }

        // Check if currently saved (for immediate UI feedback)
        let currentlySaved = webPageViewModel.uiState.savedWebPageStates.contains(normalizedURL)

        // Check if we have a current webpage for this URL
        if let currentWebPage = webPageViewModel.contentState.webPage,
           currentWebPage.urlString == normalizedURL {
            // We have the webpage, just toggle save
            webPageViewModel.toggleSave(on: currentWebPage)
        } else if currentlySaved {
            // It's saved but we don't have the WebPage object, need to unsave
            // Remove from saved state immediately for instant UI feedback
            webPageViewModel.uiState.savedWebPageStates.remove(normalizedURL)
            // TODO: Also need to handle the CloudKit unsave operation
        } else {
            // Not saved and no WebPage exists, need to create and save
            // Mark as saved immediately to prevent duplicate operations from multiple taps
            webPageViewModel.uiState.savedWebPageStates.insert(normalizedURL)

            // Create webpage and save it with current page title
            webPageViewModel.createWebPageForSave(for: normalizedURL, title: webBrowser.pageTitle) { newWebPage in
                if let webPage = newWebPage {
                    // WebPage is created - now perform direct save operation
                    // Don't use toggleSave since we already updated the state above
                    webPageViewModel.performDirectSave(on: webPage)
                }
            }
        }
    }

    // MARK: - Quote Handlers
    private func handleQuoteText(_ quotedText: String, _ selector: String, _ offset: Int) {
        // Store quote data for when comment sheet opens
        print("🔍 DEBUG ContentView: Storing quote: '\(quotedText)'")
        webPageViewModel.uiState.pendingQuote = (quotedText, selector, offset)
        print("🔍 DEBUG ContentView: pendingQuote is now: \(webPageViewModel.uiState.pendingQuote != nil ? "SET" : "NIL")")
        
        // Open comment sheet
        isShowingComments = true
    }
    
    private func handleCommentTap(_ commentID: String) {
        // Find comment and scroll to it
        if let comment = webPageViewModel.contentState.comments.first(where: { $0.commentID == commentID }) {
            webPageViewModel.uiState.selectedComment = comment
            isShowingComments = true
        }
    }
    
private func handleQuoteTap(_ comment: Comment) {
    // Navigate to the webpage URL
    webBrowser.urlString = comment.urlString
    webBrowser.isUserInitiatedNavigation = true
    
    // Store the comment for potential focused highlighting after page loads
    webPageViewModel.uiState.selectedComment = comment
}


// MARK: - Full Toolbar
struct FullToolbar: View {
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @Environment(\.colorScheme) var colorScheme
    let namespace: Namespace.ID

    @FocusState.Binding var searchIsFocused: Bool
    @Binding var searchBarText: String
    @Binding var isShowingComments: Bool
    let scrollProgress: CGFloat
    @Binding var isShowingSafariView: Bool
    @Binding var isSafariReaderMode: Bool
    @Binding var isShowingTrending: Bool
    @Binding var isShowingProfile: Bool
    var onSubmit: (() -> Void)?
    var onSearchBarTap: (() -> Void)?
    
    let topToolbarHeight: CGFloat = 44
    
    var body: some View {
        HStack(spacing: 0) {
            trendingButton

            Spacer()

            searchBarSection

            Spacer()

            profileButton
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 10)
        .frame(height: topToolbarHeight)
    }
    
    // MARK: - Subviews
    private var trendingButton: some View {
        NavigationLink(destination: TrendPageView()) {
            ZStack {
                if #available(iOS 26.0, *) {
                    Circle()
                        .glassEffect(.clear)
                        .frame(width: 44, height: 44)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                }

                Image(systemName: "network")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
            }
        }
        .buttonStyle(.plain)
        .opacity(searchIsFocused ? 0 : 1)
        .offset(y: searchIsFocused ? -20 : -(scrollProgress * 100))
        .animation(.easeInOut(duration: 0.15), value: searchIsFocused)
        .animation(.easeInOut(duration: 0.3), value: scrollProgress)
        .frame(width: searchIsFocused ? 0 : 44, height: 44, alignment: .leading)
    }
    
    private var searchBarSection: some View {
        ZStack {
            SearchTextFieldView(
                searchBarText: $searchBarText,
                searchIsFocused: $searchIsFocused,
                scrollProgress: scrollProgress,
                pageBackgroundIsDark: webBrowser.pageBackgroundIsDark,
                onSubmit: onSubmit
            )

            if !searchIsFocused {
                URLDisplayView(
                    urlString: webBrowser.urlString,
                    scrollProgress: scrollProgress,
                    pageBackgroundIsDark: webBrowser.pageBackgroundIsDark,
                    onSearchBarTap: onSearchBarTap,
                    searchIsFocused: $searchIsFocused,
                    isSafariReaderMode: $isSafariReaderMode,
                    isShowingSafariView: $isShowingSafariView,
                    webBrowser: webBrowser
                )
            }
        }
        .frame(height: 44)
        .frame(maxWidth: searchIsFocused ? .infinity : max(140, 400 - (scrollProgress * 260)))
        .background(SearchBarBackground())
        .overlay(SearchBarBorder(searchIsFocused: searchIsFocused, colorScheme: colorScheme))
        .overlay(
            // Progress bar at bottom of search capsule
            VStack {
                Spacer()
                if webBrowser.loadingProgress > 0 && webBrowser.loadingProgress < 1.0 {
                    Rectangle()
                        .fill(webBrowser.isForwardNavigation ? .orange : .blue)
                        .frame(height: 2)
                        .scaleEffect(x: webBrowser.loadingProgress * 1.2, y: 1, anchor: .leading)
                        .animation(.easeInOut(duration: 0.25), value: webBrowser.loadingProgress)
                        .onAppear {
                            print("🔄 DEBUG: Search capsule progress bar appeared!")
                        }
                }
            }
            .clipShape(Capsule()) // Clip to search capsule shape
        )
        .contextMenu {
            Button {
                if let clipboardString = UIPasteboard.general.string {
                    searchBarText = clipboardString
                    onSubmit?()
                }
            } label: {
                Label("Paste and Go", systemImage: "doc.on.clipboard")
            }

            Button {
                UIPasteboard.general.string = webBrowser.urlString
            } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }

            Button {
                searchBarText = ""
                withAnimation(.easeInOut(duration: 0.15)) {
                    searchIsFocused = true
                }
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }

            Divider()

            Button {
                isSafariReaderMode = true
                isShowingSafariView = true
            } label: {
                Label("Reader Mode", systemImage: "doc.text")
            }

            Button {
                webBrowser.reload()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: scrollProgress)
        .animation(.easeInOut(duration: 0.15), value: searchIsFocused)
    }
    
    
    private var profileButton: some View {
        Group {
            if searchIsFocused {
                // X button when searching
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        searchIsFocused = false
                    }
                    searchBarText = webBrowser.urlString
                } label: {
                    ZStack {
                        if #available(iOS 26.0, *) {
                            Circle()
                                .glassEffect(.clear)
                                .frame(width: 44, height: 44)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                        }

                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Profile button when not searching
                NavigationLink(destination: SavedItemsView()) {
                    ZStack {
                        if #available(iOS 26.0, *) {
                            Circle()
                                .glassEffect(.clear)
                                .frame(width: 44, height: 44)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                        }

                        Image(systemName: "person")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                    }
                }
                .buttonStyle(.plain)
                .offset(y: -(scrollProgress * 100)) // Move up and out of view
                .animation(.easeInOut(duration: 0.3), value: scrollProgress)
            }
        }
    }
    
}
}

struct VisualEffectView: UIViewRepresentable {

    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

public struct SelectTextOnEditingModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
    }
}

extension View {
    public func selectAllTextOnEditing() -> some View {
        modifier(SelectTextOnEditingModifier())
    }
}



// MARK: - Preview

#Preview {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    let browseForwardViewModel = BrowseForwardViewModel()
    
    // Setup tab service connection
    webBrowser.webPageViewModel = webPageViewModel
    webBrowser.browseForwardViewModel = browseForwardViewModel
    
    return ContentView()
        .environmentObject(authViewModel)
        .environmentObject(webBrowser)
        .environmentObject(webPageViewModel)
        .environmentObject(browseForwardViewModel)
}

#Preview("Focused Search") {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    let browseForwardViewModel = BrowseForwardViewModel()
    
    // Setup tab service connection
    webBrowser.webPageViewModel = webPageViewModel
    webBrowser.browseForwardViewModel = browseForwardViewModel
    
    return ContentViewFocusedPreview()
        .environmentObject(authViewModel)
        .environmentObject(webBrowser)
        .environmentObject(webPageViewModel)
        .environmentObject(browseForwardViewModel)
}

#Preview("Top Toolbar Test") {
    TopToolbarTestView()
}

#Preview("WebPageCardListView Overlay") {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    let browseForwardViewModel = BrowseForwardViewModel()
    
    // Setup connections
    webBrowser.webPageViewModel = webPageViewModel
    webBrowser.browseForwardViewModel = browseForwardViewModel
    
    return ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
                .frame(height: 100)
            
            WebPageCardListView(
                commentsUrlString: .constant(nil)
            ) { urlString in
                print("Tapped URL: \(urlString)")
            }
            
            Spacer()
        }
        .opacity(1.0)
    }
    .environmentObject(authViewModel)
    .environmentObject(webBrowser)
    .environmentObject(webPageViewModel)
    .environmentObject(browseForwardViewModel)
}


struct ContentViewFocusedPreview: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    
    @FocusState private var searchIsFocused: Bool
    
    @State private var isShowingComments = false
    @State private var isShowingWelcome = false
    @State private var isShowingTrending = false
    @State private var isShowingSafariView = false
    @State private var isShowingBrowseForwardPreferences = false
    @State private var isSafariReaderMode = false
    @State private var scrollProgress: CGFloat = 0.0 // 0.0 = full toolbar, 1.0 = compact
    @State private var searchBarText: String = "Enter a website or search term"
    @State private var numComments: Int = 0
    @State private var isShowingHistory = false
    @State private var isShowingTabOverview = false
    
    private let topToolbarHeight: CGFloat = 44
    private let toolbarHeight: CGFloat = 44
    
    var body: some View {
        NavigationStack{
            ZStack{
                WebView(
                    scrollProgress: $scrollProgress,
                    onQuoteText: { quotedText, selector, offset in
                        // Preview handler
                    },
                    onCommentTap: { commentID in
                        // Preview handler
                    }
                )
                .ignoresSafeArea()
                .environmentObject(webBrowser)
                
                // Card list overlay - visible when search is focused
                VStack {
                    Spacer()
                        .frame(height: 100)
                    
                    WebPageCardListView(
                        commentsUrlString: .constant(nil)
                    ) { urlString in
                        searchIsFocused = false
                    }
                    
                    Spacer()
                }
                .opacity(searchIsFocused ? 1 : 0)
                .allowsHitTesting(searchIsFocused)
                
                VStack{
                    // TOP TOOLBAR - Search Focused State
                    HStack(spacing: 0){
                        HStack {
                            // Trending button hidden when focused
                        }
                        .frame(width: 0, height: 36, alignment: .leading)
                        .animation(.easeInOut(duration: 0.15), value: searchIsFocused)
                        
                        Spacer()
                        
                        // SearchBar - Focused State
                        HStack(spacing: 4) {
                            ZStack(alignment: .trailing){
                                TextField("Search or enter website name", text: $searchBarText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .font(.system(size: 17, weight: .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.trailing, 32)
                                    .selectAllTextOnEditing()
                                    .focused($searchIsFocused)
                                    .frame(height: 36)
                                    .background(
                                        Capsule().fill(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.6))
                                    )
                                    .overlay(
                                        Capsule().stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 0.5)
                                    )
                                    .foregroundStyle(Color.primary)
                                    .scaleEffect(x: 1.05, y: 1.0)
                                
                                // Clear button
                                if !searchBarText.isEmpty {
                                    Button {
                                        searchBarText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                            .padding(.trailing, 2)
                                    }
                                }
                            }
                            
                            // X button - visible when focused
                            Button {
                                searchIsFocused = false
                                searchBarText = webBrowser.urlString
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                            }
                            .padding(.leading, 4)
                            .offset(x: 10)
                        }
                        
                        Spacer()
                        
                        // Profile button hidden when focused
                        HStack {
                        }
                        .frame(width: 0)
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 10)
                    .frame(height: topToolbarHeight)
                        
                    Spacer()
                }
            }
        }
        .onAppear {
            // Set search to focused for preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchIsFocused = true
            }
        }
    }
}

// MARK: - SearchBar Component Views

struct SearchTextFieldView: View {
    @Binding var searchBarText: String
    let searchIsFocused: FocusState<Bool>.Binding
    let scrollProgress: CGFloat
    let pageBackgroundIsDark: Bool
    let onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 15)

            TextField(
                "Search or enter website name",
                text: $searchBarText,
                prompt: Text("Search or enter website name").foregroundColor(.gray)
            )
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.system(size: max(14, 20 - (scrollProgress * 6)), weight: .medium))
                .foregroundColor(pageBackgroundIsDark ? .white : .black)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                .selectAllTextOnEditing()
                .focused(searchIsFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !searchBarText.isEmpty {
                Button {
                    searchBarText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
            }

            Spacer().frame(width: 15)
        }
        .frame(height: 44)
        .opacity(searchIsFocused.wrappedValue ? 1 : 0)
    }
}

struct URLDisplayView: View {
    let urlString: String
    let scrollProgress: CGFloat
    let pageBackgroundIsDark: Bool
    let onSearchBarTap: (() -> Void)?
    let searchIsFocused: FocusState<Bool>.Binding
    @Binding var isSafariReaderMode: Bool
    @Binding var isShowingSafariView: Bool
    let webBrowser: WebBrowser

    var body: some View {
        URLTextView(
            urlString: urlString,
            scrollProgress: scrollProgress,
            pageBackgroundIsDark: pageBackgroundIsDark,
            onSearchBarTap: onSearchBarTap,
            searchIsFocused: searchIsFocused
        )
    }
}

struct URLTextView: View {
    let urlString: String
    let scrollProgress: CGFloat
    let pageBackgroundIsDark: Bool
    let onSearchBarTap: (() -> Void)?
    let searchIsFocused: FocusState<Bool>.Binding

    var body: some View {
        Text(urlString.shortURL())
            .font(.system(size: max(14, 20 - (scrollProgress * 6)), weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundColor(pageBackgroundIsDark ? .white : .black)
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
            .contentShape(Rectangle())
            .onTapGesture {
                if scrollProgress > 0.1 {
                    onSearchBarTap?()
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        searchIsFocused.wrappedValue = true
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, max(0, 12 - (scrollProgress * 12)))
    }
}

struct SearchBarBackground: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Capsule().glassEffect(.clear)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
    }
}

struct SearchBarBorder: View {
    let searchIsFocused: Bool
    let colorScheme: ColorScheme

    var body: some View {
        Capsule()
            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 0.5)
            .opacity(searchIsFocused ? 1 : 0)
    }
}

struct LoadingProgressBar: View {
    let webBrowser: WebBrowser

    var body: some View {
        VStack {
            Spacer()
            if webBrowser.loadingProgress > 0 && webBrowser.loadingProgress < 1.0 {
                Rectangle()
                    .fill(webBrowser.isForwardNavigation ? .orange : .blue)
                    .frame(height: 8) // Made thicker for debugging
                    .scaleEffect(x: webBrowser.loadingProgress * 1.2, y: 1, anchor: .leading)
                    .animation(.easeInOut(duration: 0.25), value: webBrowser.loadingProgress)
            }
        }
        .clipShape(Capsule())
        .onAppear {
            print("🔄 DEBUG: LoadingProgressBar appeared")
        }
        .onChange(of: webBrowser.loadingProgress) { _, progress in
            print("🔄 DEBUG: Progress changed to \(progress)")
        }
    }
}

// MARK: - BrowseForward Category Selector
struct BrowseForwardCategorySelector: View {
    @EnvironmentObject private var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject private var webBrowser: WebBrowser
    @AppStorage("BrowseForwardPreferences") private var preferencesData: Data = Data()

    @State private var selectedCategories: Set<String> = []
    @State private var availableCategories: [String] = []
    @State private var isLoadingCategories = false

    var body: some View {
        VStack(spacing: 12) {
            if isLoadingCategories {
                ProgressView("Loading categories...")
                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                    .frame(height: 80)
            } else if !availableCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(availableCategories.sorted(), id: \.self) { category in
                            LiquidGlassCategoryButton(
                                title: category,
                                isSelected: selectedCategories.contains(category),
                                pageBackgroundIsDark: webBrowser.pageBackgroundIsDark
                            ) {
                                toggleCategory(category)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 60)
            }
        }
        .onAppear {
            loadPreferences()
            loadCategories()

            // Initialize items if empty
            if browseForwardViewModel.displayedItems.isEmpty {
                Task {
                    await browseForwardViewModel.refreshWithPreferences(
                        selectedCategories: Array(selectedCategories),
                        selectedSubcategories: [:]
                    )
                }
            }
        }
    }

    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }

        savePreferences()

        // Auto-refresh content when category changes
        Task {
            await browseForwardViewModel.refreshWithPreferences(
                selectedCategories: Array(selectedCategories),
                selectedSubcategories: [:]
            )
        }
    }

    private func loadCategories() {
        Task { @MainActor in
            isLoadingCategories = true

            do {
                availableCategories = try await BrowseForwardAPIService.shared.getAvailableCategories()
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
        }
    }

    private func savePreferences() {
        let preferences = BrowseForwardPreferences(
            selectedCategories: selectedCategories,
            lastUpdated: Date()
        )
        if let data = try? JSONEncoder().encode(preferences) {
            preferencesData = data
            NotificationCenter.default.post(name: Notification.Name("BrowseForwardPreferencesChanged"), object: nil)
        }
    }
}

// MARK: - Liquid Glass Category Button (Pill Style)
struct LiquidGlassCategoryButton: View {
    let title: String
    let isSelected: Bool
    let pageBackgroundIsDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(pageBackgroundIsDark ? .white : .black)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                .frame(minWidth: 60)
                .frame(height: 36)
                .padding(.horizontal, 16)
                .background(
                    ZStack {
                        // Base contrast layer for readability
                        Capsule()
                            .fill(pageBackgroundIsDark ? .black.opacity(0.5) : .white.opacity(0.7))

                        // Glass effect on top
                        Group {
                            if #available(iOS 26.0, *) {
                                Capsule()
                                    .fill(.clear)
                                    .glassEffect(.clear, in: Capsule())
                            } else {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            }
                        }

                        // Brighter fill when selected
                        if isSelected {
                            Capsule()
                                .fill(pageBackgroundIsDark ? .white.opacity(0.25) : .black.opacity(0.2))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - BrowseForward Button
struct BrowseForwardButton: View {
    @ObservedObject var webBrowser: WebBrowser
    @Binding var isShowingBrowseForwardPreferences: Bool

    @State private var rotationAngle: Double = 0
    @State private var targetRotation: Double = 0

    private var arrowIcon: String {
        webBrowser.canGoForward ? "arrow.right" : "arrow.up"
    }

    private var arrowColor: Color {
        // Use final color based on current state
        return webBrowser.canGoForward ?
            (webBrowser.pageBackgroundIsDark ? .white : .black) : .orange
    }

    var body: some View {
        Image(systemName: arrowIcon)
            .foregroundColor(arrowColor)
            .font(.system(size: 22, weight: webBrowser.canGoForward ? .medium : .bold))
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
            .rotationEffect(.degrees(rotationAngle))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity) {
                handleLongPress()
            }
            .onChange(of: webBrowser.canGoForward) { _, newValue in
                animateRotation(to: newValue)
            }
            .onAppear {
                // Set initial rotation without animation
                rotationAngle = webBrowser.canGoForward ? 0 : 0
                targetRotation = rotationAngle
            }
    }

    private func handleTap() {
        if webBrowser.canGoForward {
            // Standard forward navigation - no haptics
            webBrowser.goForward()
        } else {
            // BrowseForward - vibrate for special action
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            webBrowser.browseForward()
        }
    }

    private func handleLongPress() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if webBrowser.canGoForward {
            // Jump to last page in forward history
            webBrowser.jumpToLastForwardPage()
        } else {
            // Show preferences
            isShowingBrowseForwardPreferences = true
        }
    }

    private func animateRotation(to canGoForward: Bool) {
        let newRotation = 0.0
        targetRotation = newRotation

        if canGoForward {
            // Rotating to right arrow (standard spring)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                rotationAngle = newRotation
            }
        } else {
            // Rotating to up arrow (bounce effect for BrowseForward mode)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                rotationAngle = newRotation
            }
        }
    }
}

// MARK: - Search Bangs
struct SearchBang: Identifiable {
    let id = UUID()
    let name: String
    let faviconURL: String
    let searchPrefix: String
    let homepage: String
}

struct SearchBangsView: View {
    let searchText: String
    let onBangSelected: (SearchBang) -> Void

    // Static array to prevent re-creation on text changes
    private static let bangs: [SearchBang] = [
        SearchBang(name: "Google", faviconURL: "https://www.google.com/s2/favicons?domain=google.com&sz=128", searchPrefix: "https://www.google.com/search?q=", homepage: "https://www.google.com"),
        SearchBang(name: "YouTube", faviconURL: "https://www.google.com/s2/favicons?domain=youtube.com&sz=128", searchPrefix: "https://www.youtube.com/results?search_query=", homepage: "https://www.youtube.com"),
        SearchBang(name: "Reddit", faviconURL: "https://www.google.com/s2/favicons?domain=reddit.com&sz=128", searchPrefix: "https://www.reddit.com/search/?q=", homepage: "https://www.reddit.com"),
        SearchBang(name: "Wikipedia", faviconURL: "https://www.google.com/s2/favicons?domain=wikipedia.org&sz=128", searchPrefix: "https://en.wikipedia.org/wiki/Special:Search?search=", homepage: "https://en.wikipedia.org"),
        SearchBang(name: "Perplexity", faviconURL: "https://www.google.com/s2/favicons?domain=perplexity.ai&sz=128", searchPrefix: "https://www.perplexity.ai/search?q=", homepage: "https://www.perplexity.ai")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Self.bangs) { bang in
                    BangButton(bang: bang) {
                        onBangSelected(bang)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 80)
        .opacity(searchText.isEmpty ? 0 : 1)
    }
}

struct BangButton: View {
    let bang: SearchBang
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Liquid glass background with readability layer
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.3))
                        .frame(width: 52, height: 52)

                    if #available(iOS 26.0, *) {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.clear, in: Circle())
                            .frame(width: 52, height: 52)
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 52, height: 52)
                    }
                }

                // Favicon with liquid glass overlay
                ZStack {
                    AsyncImage(url: URL(string: bang.faviconURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.6)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 27, height: 27)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        case .failure:
                            Image(systemName: "globe")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }

                    // Subtle glass overlay on favicon
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.clear)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 4))
                            .frame(width: 24, height: 24)
                            .opacity(0.2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
    }
}

