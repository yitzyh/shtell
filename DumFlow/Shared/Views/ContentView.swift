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
                VStack {
                    Spacer()
                        .frame(height: 100) // Space for top toolbar
                    
                    WebPageCardListView(
                        commentsUrlString: .constant(nil)
                    ) { urlString in
                        // Handle URL tap
                        searchIsFocused = false
                        normalizeAndLoads(urlString)
                    }
                    
                    Spacer()
                }
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            Rectangle()
                                .glassEffect(.regular)
                        } else {
                            Rectangle()
                                .fill(.thinMaterial)
                        }
                    }
                )
                .opacity(searchIsFocused ? 1 : 0)
                .allowsHitTesting(searchIsFocused)
                
                VStack{
                    
                    // TOP TOOLBAR - Safari-style morphing animation
                    FullToolbar(
                        namespace: toolbarNamespace,
                        searchIsFocused: _searchIsFocused,
                        searchBarText: $searchBarText,
                        isShowingComments: $isShowingComments,
                        scrollProgress: scrollProgress,
                        isShowingSafariView: $isShowingSafariView,
                        isSafariReaderMode: $isSafariReaderMode,
                        isShowingTrending: $isShowingTrending,
                        isShowingProfile: $isShowingProfile,
                        onSubmit: {
                            normalizeAndLoads(searchBarText)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
        }
        .sheet(isPresented: $isShowingHistory) {
            HistoryView()
                .environmentObject(webPageViewModel)
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
        .sheet(isPresented: $isShowingTrending) {
            TrendPageView()
                .environmentObject(webPageViewModel)
                .environmentObject(webBrowser)
                .environmentObject(authViewModel)
                .environmentObject(browseForwardViewModel)
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileView()
                .environmentObject(authViewModel)
        }
        .onAppear{
            initViewModel()
            searchBarText = webBrowser.urlString
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
                                Button {
                                    print("Toggle save for: \(webBrowser.urlString)")
                                } label: {
                                    Image(systemName: "bookmark")
                                        .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                        .font(.system(size: 22, weight: .medium))
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
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
                            
                            Button {
                                if webBrowser.urlString.normalizedURL != nil {
                                    isShowingComments.toggle()
                                } else {
                                    isShowingWelcome.toggle()
                                }
                            } label: {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .overlay(alignment: .trailing) {
                                if count > 0 {
                                    Text(formatCommentCount(count))
                                        .contentTransition(.numericText())
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                                        .offset(x: 12, y: 0)  // 12pt to the right of button
                                        .animation(.easeInOut(duration: 0.5), value: count)
                                }
                            }
                            .matchedGeometryEffect(id: "commentButton", in: bottomToolbarNamespace)
                            
                            // Forward button (always visible)
                            Button {
                                if webBrowser.canGoForward {
                                    webBrowser.goForward()
                                } else {
                                    webBrowser.browseForward()
                                }
                            } label: {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(webBrowser.canGoForward ? (webBrowser.pageBackgroundIsDark ? .white : .black) : .orange)
                                    .font(.system(size: 22, weight: webBrowser.canGoForward ? .medium : .bold))
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        
                                        if webBrowser.canGoForward {
                                            webBrowser.goForward()
                                        } else {
                                            isShowingBrowseForwardPreferences = true
                                        }
                                    }
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
                                    .glassEffect(.regular.interactive())
                            } else {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .animation(.easeInOut(duration: 0.3), value: scrollProgress)
                }
                .frame(width: 320, alignment: .trailing)  // Layer 2: Right-align, 320pt width
            }
            .frame(maxWidth: .infinity, alignment: .center)        // Layer 1: Center
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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
    @Environment(\.colorScheme) var colorScheme
    let namespace: Namespace.ID

    var searchIsFocused: FocusState<Bool>.Binding
    @Binding var searchBarText: String
    @Binding var isShowingComments: Bool
    let scrollProgress: CGFloat
    @Binding var isShowingSafariView: Bool
    @Binding var isSafariReaderMode: Bool
    @Binding var isShowingTrending: Bool
    @Binding var isShowingProfile: Bool
    var onSubmit: (() -> Void)?
    
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
        Button {
            isShowingTrending = true
        } label: {
            ZStack {
                if #available(iOS 26.0, *) {
                    Circle()
                        .glassEffect(.regular)
                        .frame(width: 44, height: 44)
                } else {
                    Circle()
                        .fill(.thinMaterial)
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
        // Search capsule with same background as top buttons
            HStack(spacing: 0) {
                if searchIsFocused {
                    // TextField when focused
                    TextField("Search or enter website name", text: $searchBarText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                        .selectAllTextOnEditing()
                        .focused($searchIsFocused)
                        .onSubmit {
                            onSubmit?()
                        }
                    
                    // Clear button when focused and has text
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
                } else {
                    // ZStack layout for better text centering without spacer constraints
                    ZStack {
                        // Centered text with maximum available space
                        Text(webBrowser.urlString.shortURL())
                            .font(.system(size: max(14, 20 - (scrollProgress * 6)), weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                print("🔥 URL TEXT TAPPED!")
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    searchIsFocused = true
                                }
                            }
                            .padding(.horizontal, max(2, 44 - (scrollProgress * 42)))
                            .padding(.vertical, max(2, 12 - (scrollProgress * 10)))
                        
                        // Reader mode button positioned on left
                        HStack {
                            Button {
                                isSafariReaderMode = true
                                isShowingSafariView = true
                            } label: {
                                Image(systemName: "doc.text")
                                    .font(.system(size: max(0, 18 - (scrollProgress * 18)), weight: .medium))
                                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                            }
                            .frame(width: max(0, 40 - (scrollProgress * 40)), height: max(0, 40 - (scrollProgress * 40)))
                            .opacity(max(0, 1.0 - (scrollProgress * 1.25)))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 2)
                            .allowsHitTesting(scrollProgress < 0.8)
                            
                            Spacer()
                        }
                        
                        // Reload button positioned on right
                        HStack {
                            Spacer()
                            
                            Button {
                                webBrowser.reload()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: max(0, 18 - (scrollProgress * 18)), weight: .medium))
                                    .foregroundColor(webBrowser.pageBackgroundIsDark ? .white : .black)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                            }
                            .frame(width: max(0, 40 - (scrollProgress * 40)), height: max(0, 40 - (scrollProgress * 40)))
                            .opacity(max(0, 1.0 - (scrollProgress * 1.25)))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 2)
                            .allowsHitTesting(scrollProgress < 0.8)
                        }
                    }
                }
            }
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .glassEffect(.regular)
                    } else {
                        Capsule().fill(.thinMaterial)
                    }
                }
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 0.5)
                    .opacity(searchIsFocused ? 1 : 0)
            )
            .overlay(
                // Loading progress bar
                VStack {
                    Spacer()
                    if webBrowser.loadingProgress > 0 && webBrowser.loadingProgress < 1.0 {
                        Rectangle()
                            .fill(webBrowser.isForwardNavigation ? .orange : .blue)
                            .frame(height: 2)
                            .scaleEffect(x: webBrowser.loadingProgress * 1.2, y: 1, anchor: .leading)
                            .animation(.easeInOut(duration: 0.25), value: webBrowser.loadingProgress)
                    }
                }
                .clipShape(Capsule())
            )
            .scaleEffect(searchIsFocused ? 1.05 : 1.0)
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
                                .glassEffect(.regular)
                                .frame(width: 44, height: 44)
                        } else {
                            Circle()
                                .fill(.thinMaterial)
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
                Button {
                    isShowingProfile = true
                } label: {
                    ZStack {
                        if #available(iOS 26.0, *) {
                            Circle()
                                .glassEffect(.regular)
                                .frame(width: 44, height: 44)
                        } else {
                            Circle()
                                .fill(.thinMaterial)
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

