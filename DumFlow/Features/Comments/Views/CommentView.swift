//
//  CommentView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 4/28/24.
//
//import SwiftData
import SwiftUI
import Foundation
import CloudKit

// to fix comment/reply issue: make temporary commentoreply that is set in button and passed into sheet once

// make it so that sheet not triggereed for each for each

enum CommentSortOrder: String, CaseIterable {
    case oldest = "oldest"
    case newest = "newest"
    
    var displayName: String {
        switch self {
        case .oldest: return "Oldest"
        case .newest: return "Newest"
        }
    }
}

struct CommentView: View {
    
//    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var authViewModel: AuthViewModel
        
    @FocusState private var textFieldIsFocused: Bool

    @State private var newComment = ""
    @State private var replyComment: Comment?
    private var navToComment: Comment? = nil
    @State private var hasAppeared = false
    @State private var showLoadingIndicator = false
    @State private var sortOrder: CommentSortOrder = .newest
    @State private var isScrolling = false
    
    let urlString: String
    let onQuoteTap: ((Comment) -> Void)?
    
    init(urlString: String, navToComment: Comment? = nil, onQuoteTap: ((Comment) -> Void)? = nil) {
        self.urlString = urlString
        self.navToComment = navToComment
        self.onQuoteTap = onQuoteTap
    }
    
    private var shouldShowError: Bool {
        webPageViewModel.loadingState.error != nil && webPageViewModel.loadingState.showErrorAlert
    }

    private var shouldShowLoading: Bool {
        showLoadingIndicator && webPageViewModel.loadingState.isLoadingComments
    }

    private var shouldShowEmptyState: Bool {
        webPageViewModel.contentState.comments.isEmpty && !webPageViewModel.loadingState.isLoadingComments && webPageViewModel.loadingState.error == nil
    }
    
//    @State private var commentCount = 0
    
    @State private var showSignInAlert = false
    @State private var showSignInSheet = false
    @State private var keyboardHeight: CGFloat = 0
    
//    init(urlString: String = "https://www.google.com", navToComment: Comment? = nil) {
////        _viewModel = StateObject(wrappedValue: WebPageViewModel(urlString: urlString, modelContext: modelContext))
//        self.urlString = urlString
//        self.navToComment = navToComment
//    }
    
    var body: some View {
        NavigationStack{
            ZStack(alignment: .bottom) {
                // Main content
                VStack(spacing: 0){
                // Custom header with X button
                ZStack {
                    Text("Comments")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                
                // Sort buttons
                HStack(spacing: 8) {
                    ForEach(CommentSortOrder.allCases, id: \.self) { order in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sortOrder = order
                            }
                        } label: {
                            Text(order.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(sortOrder == order ? (colorScheme == .dark ? .black : .white) : .primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(sortOrder == order ? (colorScheme == .dark ? Color.white : Color.black) : Color.secondary.opacity(0.15))
                                )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 0.5)
                
//                if shouldShowError, let error = webPageViewModel.error {
//                    ErrorView(error: error) {
                if shouldShowError, let error = webPageViewModel.loadingState.error {
                    ErrorView(error: error) {

                        
                        // ✅ REVERTED: Use ViewModel methods
//                        webPageViewModel.fetchExistingWebPage(urlString: urlString)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shouldShowLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // LoadingIndicatorView()
                    //     .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shouldShowEmptyState {
                    if webPageViewModel.contentState.webPage == nil {
                        NoWebPageCommentsView()
                    } else {
                        NoCommentsView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    commentsListView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, 47)
                }
                }
                
                // Floating comment input overlay
                VStack(spacing: 0) {
                    // Show quoted text if available
                    if let pendingQuote = webPageViewModel.uiState.pendingQuote {
                        HStack {
                            Text("Quoting: \"\(pendingQuote.text)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            Button {
                                webPageViewModel.uiState.pendingQuote = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 8) {
                            TextField("Add a comment...", text: $newComment, axis: .vertical)
                                .lineLimit(5)
                                .focused($textFieldIsFocused)
                                .submitLabel(.next)
                                .onSubmit(createNewLine)
                                .textFieldStyle(.plain)
                                .padding(.vertical, 10)
                                .padding(.leading, 16)
                                .padding(.trailing, !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 8 : 16)
                            
                            if !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button { postComment() } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.orange)
                                }
                                .padding(.trailing, 4)
                                .padding(.vertical, 4)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(colorScheme == .dark ? Color(white: 0.07) : .white)
                                .stroke(.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 15)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .navigationBarHidden(true)
        .onAppear{
            print("🔍 CommentView.onAppear: urlString = \(urlString)")
            webPageViewModel.loadingState.error = nil
            webPageViewModel.loadingState.showErrorAlert = false
            
            // Reset loading indicator state
            showLoadingIndicator = false
            
            // Set loading state immediately to prevent NoCommentsView flash
            webPageViewModel.loadingState.isLoadingComments = true
            
            // Delay showing loading indicator to avoid jarring flash for quick loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if webPageViewModel.loadingState.isLoadingComments {
                    showLoadingIndicator = true
                }
            }

            print("🔍 CommentView: Setting webPageViewModel.urlString")
            webPageViewModel.urlString = urlString
            print("🔍 CommentView: webPageViewModel.urlString is now = \(String(describing: webPageViewModel.urlString))")
            
            // Auto-focus text field if there's a pending quote
            if webPageViewModel.uiState.pendingQuote != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    textFieldIsFocused = true
                }
            }
            
        }
        .alert(isPresented: $webPageViewModel.loadingState.showErrorAlert, error: webPageViewModel.loadingState.error) { error in
            Button("OK") {
                webPageViewModel.loadingState.showErrorAlert = false
                webPageViewModel.loadingState.error = nil
            }
            
            Button("Retry") {
//                webPageViewModel.fetchExistingWebPage(urlString: urlString)
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Please try again")
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .presentationDetents([.large])
        }
    }
    
    private var sortedComments: [Comment] {
        let parentComments = webPageViewModel.contentState.comments.filter { $0.parentCommentID == nil }
        switch sortOrder {
        case .oldest:
            return parentComments.sorted { $0.dateCreated < $1.dateCreated }
        case .newest:
            return parentComments.sorted { $0.dateCreated > $1.dateCreated }
        }
    }
    
    @State private var scrollProxy: ScrollViewProxy?
    
    private var commentsListView: some View {
        VStack{
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(sortedComments.enumerated()), id: \.element.commentID) { index, comment in
                        CommentThreadView(
                            parentComment: comment,
                            replyComment: $replyComment,
                            onQuoteTap: { comment in
                                handleQuoteTap(comment)
                            }
                        )
                            .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                            .listRowBackground(colorScheme == .dark ? Color(white: 0.07) : .white)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .padding(.top, index == 0 ? 16 : 0)
                            .id(comment.commentID)
                    }
                }
                .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                .listStyle(.plain)
                .listRowSeparator(.visible)
                .scrollContentBackground(.hidden)
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: sortOrder) {
                    scrollToAppropriatePosition(proxy: proxy)
                }
            }
            
            .navigationDestination(item: $replyComment) { comment in
                ReplyView(parentComment: comment)
                    .environmentObject(webPageViewModel)
                    .environmentObject(authViewModel)
            }
        }
        .background(colorScheme == .dark ? Color(white: 0.07) : .white)
        .listRowSpacing(0)
        .ignoresSafeArea(.keyboard)
    }
    
    private func postComment() {
        guard authViewModel.signedInUser != nil else {
          showSignInSheet = true
          return
        }
        
        guard !newComment.isEmpty else { return }
        
        let commentText = newComment
        
        // Clear text first, then dismiss keyboard for smoother animation
        newComment = ""
        
        // Dismiss keyboard with slight delay to avoid UI jump
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textFieldIsFocused = false
        }
        
        // Post comment immediately (no delay needed for this)
        webPageViewModel.addComment(text: commentText)
        
        // Scroll to appropriate position after comment is posted with staggered timing
        if let proxy = scrollProxy {
            // First, briefly highlight the text field area
            withAnimation(.easeOut(duration: 0.2)) {
                // Text field animation is handled by the UI state change above
            }
            
            // Then scroll after a short delay for better UX flow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📜 Scrolling after post - sortOrder: \(sortOrder)")
                if sortOrder == .oldest {
                    scrollToBottomIfNeeded(proxy: proxy)
                } else {
                    scrollToTopIfNeeded(proxy: proxy)
                }
            }
        } else {
            print("⚠️ scrollProxy is nil!")
        }
    }
    
    func createNewLine(){
        newComment = newComment + "\n"
        textFieldIsFocused = true
    }
    
    private func scrollToBottomIfNeeded(proxy: ScrollViewProxy) {
        guard let lastComment = sortedComments.last else { return }
        
        isScrolling = true
        
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: 0)) {
            proxy.scrollTo(lastComment.commentID, anchor: .bottom)
        }
        
        // Reset scrolling state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isScrolling = false
        }
    }
    
    private func scrollToTopIfNeeded(proxy: ScrollViewProxy) {
        guard let firstComment = sortedComments.first else { return }
        
        isScrolling = true
        
        withAnimation(.interpolatingSpring(stiffness: 280, damping: 28, initialVelocity: 0)) {
            proxy.scrollTo(firstComment.commentID, anchor: .top)
        }
        
        // Reset scrolling state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isScrolling = false
        }
    }
    
    private func scrollToAppropriatePosition(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Always scroll to top when changing sort order to see the beginning of the sorted list
            scrollToTopIfNeeded(proxy: proxy)
        }
    }
    
    // MARK: - Quote Navigation
    private func handleQuoteTap(_ comment: Comment) {
        // Dismiss the comment sheet
        dismiss()
        
        // Pass the comment back to ContentView for navigation
        onQuoteTap?(comment)
    }
    
}

// MARK: - Preview

#Preview {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    
    // Create mock parent comment 1
    let parentComment1 = Comment(
        id: CKRecord.ID(recordName: "parent-comment-1"),
        commentID: "parent-comment-1-id",
        text: "This is a great article about Apple's latest innovations!",
        dateCreated: Date().addingTimeInterval(-3600), // 1 hour ago
        userID: "user1",
        username: "techenthusiast",
        urlString: "https://www.apple.com",
        likeCount: 12,
        saveCount: 3,
        isReported: 0,
        reportCount: 0
    )
    
    // Create replies for parent comment 1
    let reply1_1 = Comment(
        id: CKRecord.ID(recordName: "reply-1-1"),
        commentID: "reply-1-1-id",
        text: "I completely agree! The new features are game-changing.",
        dateCreated: Date().addingTimeInterval(-2400), // 40 minutes ago
        userID: "user2",
        username: "applefan",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-1-id",
        likeCount: 5,
        saveCount: 1,
        isReported: 0,
        reportCount: 0
    )
    
    let reply1_2 = Comment(
        id: CKRecord.ID(recordName: "reply-1-2"),
        commentID: "reply-1-2-id",
        text: "Has anyone tried the beta version yet? Would love to hear your thoughts.",
        dateCreated: Date().addingTimeInterval(-1800), // 30 minutes ago
        userID: "user3",
        username: "betatester",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-1-id",
        likeCount: 8,
        saveCount: 2,
        isReported: 0,
        reportCount: 0
    )
    
    let reply1_3 = Comment(
        id: CKRecord.ID(recordName: "reply-1-3"),
        commentID: "reply-1-3-id",
        text: "Thanks for sharing this! Really helpful insights 👍",
        dateCreated: Date().addingTimeInterval(-1200), // 20 minutes ago
        userID: "user4",
        username: "devcommunity",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-1-id",
        likeCount: 3,
        saveCount: 0,
        isReported: 0,
        reportCount: 0
    )
    
    // Create mock parent comment 2
    let parentComment2 = Comment(
        id: CKRecord.ID(recordName: "parent-comment-2"),
        commentID: "parent-comment-2-id",
        text: "This is a great article about Apple's latest innovations!",
        dateCreated: Date().addingTimeInterval(-5400), // 1.5 hours ago
        userID: "user5",
        username: "techenthusiast2",
        urlString: "https://www.apple.com",
        likeCount: 15,
        saveCount: 4,
        isReported: 0,
        reportCount: 0
    )
    
    // Create replies for parent comment 2
    let reply2_1 = Comment(
        id: CKRecord.ID(recordName: "reply-2-1"),
        commentID: "reply-2-1-id",
        text: "I completely agree! The new features are game-changing.",
        dateCreated: Date().addingTimeInterval(-4800), // 80 minutes ago
        userID: "user6",
        username: "applefan2",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-2-id",
        likeCount: 7,
        saveCount: 2,
        isReported: 0,
        reportCount: 0
    )
    
    let reply2_2 = Comment(
        id: CKRecord.ID(recordName: "reply-2-2"),
        commentID: "reply-2-2-id",
        text: "Has anyone tried the beta version yet? Would love to hear your thoughts.",
        dateCreated: Date().addingTimeInterval(-4200), // 70 minutes ago
        userID: "user7",
        username: "betatester2",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-2-id",
        likeCount: 6,
        saveCount: 1,
        isReported: 0,
        reportCount: 0
    )
    
    let reply2_3 = Comment(
        id: CKRecord.ID(recordName: "reply-2-3"),
        commentID: "reply-2-3-id",
        text: "Thanks for sharing this! Really helpful insights 👍",
        dateCreated: Date().addingTimeInterval(-3600), // 60 minutes ago
        userID: "user8",
        username: "devcommunity2",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-2-id",
        likeCount: 4,
        saveCount: 1,
        isReported: 0,
        reportCount: 0
    )
    
    // Create mock parent comment 3
    let parentComment3 = Comment(
        id: CKRecord.ID(recordName: "parent-comment-3"),
        commentID: "parent-comment-3-id",
        text: "This is a great article about Apple's latest innovations!",
        dateCreated: Date().addingTimeInterval(-7200), // 2 hours ago
        userID: "user9",
        username: "techenthusiast3",
        urlString: "https://www.apple.com",
        likeCount: 20,
        saveCount: 6,
        isReported: 0,
        reportCount: 0
    )
    
    // Create replies for parent comment 3
    let reply3_1 = Comment(
        id: CKRecord.ID(recordName: "reply-3-1"),
        commentID: "reply-3-1-id",
        text: "I completely agree! The new features are game-changing.",
        dateCreated: Date().addingTimeInterval(-6600), // 110 minutes ago
        userID: "user10",
        username: "applefan3",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-3-id",
        likeCount: 9,
        saveCount: 3,
        isReported: 0,
        reportCount: 0
    )
    
    let reply3_2 = Comment(
        id: CKRecord.ID(recordName: "reply-3-2"),
        commentID: "reply-3-2-id",
        text: "Has anyone tried the beta version yet? Would love to hear your thoughts.",
        dateCreated: Date().addingTimeInterval(-6000), // 100 minutes ago
        userID: "user11",
        username: "betatester3",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-3-id",
        likeCount: 11,
        saveCount: 4,
        isReported: 0,
        reportCount: 0
    )
    
    let reply3_3 = Comment(
        id: CKRecord.ID(recordName: "reply-3-3"),
        commentID: "reply-3-3-id",
        text: "Thanks for sharing this! Really helpful insights 👍",
        dateCreated: Date().addingTimeInterval(-5400), // 90 minutes ago
        userID: "user12",
        username: "devcommunity3",
        urlString: "https://www.apple.com",
        parentCommentID: "parent-comment-3-id",
        likeCount: 5,
        saveCount: 2,
        isReported: 0,
        reportCount: 0
    )
    
    // Set up the mock data
    webPageViewModel.contentState.comments = [
        parentComment1, reply1_1, reply1_2, reply1_3,
        parentComment2, reply2_1, reply2_2, reply2_3,
        parentComment3, reply3_1, reply3_2, reply3_3
    ]
    
    // Create a mock CKRecord for WebPage
    let mockRecord = CKRecord(recordType: "WebPage", recordID: CKRecord.ID(recordName: "mock-webpage"))
    mockRecord["urlString"] = "https://www.apple.com"
    mockRecord["title"] = "Apple - Official Site"
    mockRecord["domain"] = "apple.com"
    mockRecord["dateCreated"] = Date()
    mockRecord["commentCount"] = 4 // Parent + 3 replies
    mockRecord["likeCount"] = 0
    mockRecord["saveCount"] = 0
    mockRecord["isReported"] = 0
    mockRecord["reportCount"] = 0
    
    // Create WebPage from the mock record
    let mockWebPage = try! WebPage(record: mockRecord)
    webPageViewModel.contentState.webPage = mockWebPage
    
    struct PreviewCommentView: View {
        let webPageViewModel: WebPageViewModel
        
        var body: some View {
            NavigationStack{
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0){
                        // Header
                        ZStack {
                            Text("Comments")
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack {
                                Spacer()
                                Button("✕") { }
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        // Comments list with expanded replies
                        List {
                            ForEach(webPageViewModel.contentState.comments.filter { $0.parentCommentID == nil }) { comment in
                                VStack(alignment: .leading, spacing: 0) {
                                    CommentRowView(
                                        comment: comment,
                                        replyComment: .constant(nil),
                                        onQuoteTap: nil
                                    )
                                    
                                    let replies = webPageViewModel.contentState.comments
                                        .filter { $0.parentCommentID == comment.commentID }
                                        .sorted { $0.dateCreated < $1.dateCreated }
                                    
                                    if !replies.isEmpty {
                                        VStack(spacing: 8) {
                                            ForEach(replies) { reply in
                                                ReplyRowView(
                                                    reply: reply,
                                                    replyComment: .constant(nil),
                                                    onQuoteTap: nil
                                                )
                                            }
                                        }
                                        .padding(.leading, 20)
                                        .padding(.top, 12)
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                webPageViewModel.loadingState.isLoadingComments = false
                webPageViewModel.loadingState.error = nil
                webPageViewModel.loadingState.showErrorAlert = false
            }
        }
    }
    
    return PreviewCommentView(webPageViewModel: webPageViewModel)
        .environmentObject(authViewModel)
        .environmentObject(webBrowser)
        .environmentObject(webPageViewModel)
}
