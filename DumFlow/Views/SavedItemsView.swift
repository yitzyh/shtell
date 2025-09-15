//
//  LikedCommentsView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/9/25.
//
import SwiftUI
import CloudKit

struct SavedItemsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var webPageViewModel: WebPageViewModel
    @EnvironmentObject private var webBrowser: WebBrowser
    @State private var commentsUrlString: String?
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var followedUsers: [User] = []
    @State private var isLoadingFollowedUsers = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            // Following Tab - Comments from followed users
            Group {
                if webPageViewModel.contentState.followedUserComments.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No comments from followed users")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Follow users to see their comments here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(webPageViewModel.contentState.followedUserComments, id: \.id.recordName) { comment in
                        WebPageCommentRowView(
                            comment: comment,
                            commentsUrlString: $commentsUrlString,
                            onDismiss: {
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .tabItem {
                Image(systemName: "person.2")
                    .environment(\.symbolVariants, .none)
            }
            .tag(0)
            
            // User Comments Tab
            Group {
                if webPageViewModel.contentState.userComments.isEmpty {
                    Text("You haven't made any comments yet.")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(webPageViewModel.contentState.userComments.sorted { comment1, comment2 in
                        return comment1.dateCreated > comment2.dateCreated
                    }, id: \.id.recordName) { comment in
                        WebPageCommentRowView(
                            comment: comment,
                            commentsUrlString: $commentsUrlString,
                            onDismiss: {
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .tabItem {
                Image(systemName: "person.bubble")
                    .environment(\.symbolVariants, .none)
            }
            .tag(1)
            
            // Saved Comments Tab
            Group {
                if webPageViewModel.contentState.savedComments.isEmpty {
                    Text("You haven't saved any comments yet.")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(webPageViewModel.contentState.savedComments.sorted { comment1, comment2 in
                        let date1 = webPageViewModel.contentState.commentSaveDates[comment1.commentID] ?? Date.distantPast
                        let date2 = webPageViewModel.contentState.commentSaveDates[comment2.commentID] ?? Date.distantPast
                        return date1 > date2
                    }, id: \.id.recordName) { comment in
                        WebPageCommentRowView(
                            comment: comment,
                            commentsUrlString: $commentsUrlString,
                            onDismiss: {
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .tabItem {
                Image(systemName: "star.circle")
                    .environment(\.symbolVariants, .none)
            }
            .tag(2)
        }
        .accentColor(.orange)
        .navigationTitle("Comments")
        .toolbarBackground(.regularMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetToRoot"))) { _ in
            presentationMode.wrappedValue.dismiss()
        }
        .onAppear {
            if let user = authViewModel.signedInUser {
                webPageViewModel.fetchUserComments(for: user)
                webPageViewModel.fetchFollowedUsersComments(for: user) { _ in }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
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
                NavigationLink(destination: SignInView()) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: .constant(commentsUrlString != nil), onDismiss: {
            commentsUrlString = nil
            webPageViewModel.urlString = nil
            webPageViewModel.contentState.webPage = nil
            webPageViewModel.contentState.comments = []
        }) { if let urlString = commentsUrlString{
                NavigationStack {
                    CommentView(urlString: urlString)
                        .environmentObject(webPageViewModel)
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.fraction(0.75), .large])
                        .presentationContentInteraction(.scrolls)
                        .presentationCornerRadius(20)
                }
            }
        }
    }
    
}

// Wrapper to make WebPage work with sheet(item:)
struct WebPageWrapper: Identifiable {
    let id = UUID()
    let webPage: WebPage
}

// Updated WebPageCommentRowView

struct WebPageCommentRowView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var webBrowser: WebBrowser
    @EnvironmentObject private var webPageViewModel: WebPageViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var commentsUrlString: String?
    let comment: Comment
    let onDismiss: () -> Void
    
    @State private var webPage: WebPage?
    
    private var currentWebPage: WebPage? {
        webPageViewModel.contentState.webPages.first(where: { $0.urlString == comment.urlString }) ??
        webPageViewModel.contentState.savedWebPages.first(where: { $0.urlString == comment.urlString }) ??
        webPage  // Fallback to cached version during transitions
    }
    
    private var cachedImages: (favicon: Data?, thumbnail: Data?) {
        guard let webPage = currentWebPage else { return (nil, nil) }
        return webPageViewModel.contentState.imageCache[webPage.urlString] ?? (nil, nil)
    }

    init(comment: Comment, commentsUrlString: Binding<String?>, onDismiss: @escaping () -> Void) {
        self.comment = comment
        self._commentsUrlString = commentsUrlString
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // Show WebPage context above comment with connecting line
            if let webPage = currentWebPage {
                // Parent webpage with connecting line layout
                HStack(alignment: .top, spacing: 5) {
                    // Left side: Favicon + connecting line (aligned with user profile)
                    VStack(spacing: 3) {
                        // Favicon (exactly same as WebPageRowView)
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorScheme == .dark ? Color(uiColor: .systemGray4) : .white)
                                .frame(width: 25, height: 25)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(lineWidth: 1)
                                .frame(width: 25, height: 25)
                            
                            FaviconView(faviconData: cachedImages.favicon)
                                .frame(width: 15, height: 15)
                        }
                        
                        // Fixed spacing between webpage and comment
                        Rectangle()
                            .frame(width: 1, height: 65)
                            .foregroundColor(.primary)
                    }
                    
                    // Right side: Content layout similar to WebPageRowView
                    HStack(alignment: .top, spacing: 8) {
                        // Left side: Text content
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .bottom, spacing: 8) {
                                Text(webPage.domain.shortURL())
                                    .padding(.leading, 7)
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.blue)
                                
                                Spacer()
                                
                                
                                Text(webPage.dateCreated.timeAgoShort())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Title (smaller font)
                            Text(webPage.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Action buttons (same style as WebPageRowView but smaller)
                            HStack(spacing: 15) {
                            // Like button
                            Button {
                                guard authViewModel.signedInUser != nil else { return }
                                webPageViewModel.toggleLike(on: webPage, isCurrentlyLiked: webPageViewModel.uiState.likedWebPages.contains(webPage.urlString))
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: webPageViewModel.uiState.likedWebPages.contains(webPage.urlString) ? "heart.fill" : "heart")
                                        .font(.system(size: 12))
                                        .foregroundColor(webPageViewModel.uiState.likedWebPages.contains(webPage.urlString) ? .red : .primary)
                                    
                                    if webPageViewModel.uiState.webPageLikeCounts[webPage.urlString] ?? 0 > 0 {
                                        Text("\(webPageViewModel.uiState.webPageLikeCounts[webPage.urlString] ?? 0)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)
                                            .contentTransition(.numericText())
                                            .animation(.smooth(duration: 0.2), value: webPageViewModel.uiState.webPageLikeCounts[webPage.urlString] ?? 0)
                                    }
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary, lineWidth: 0.4)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Comments button
                            Button {
                                commentsUrlString = webPage.urlString
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble")
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                    
                                    if webPage.commentCount > 0 {
                                        Text("\(webPage.commentCount)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)
                                            .contentTransition(.numericText())
                                            .animation(.smooth(duration: 0.4), value: webPage.commentCount)
                                    }
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary, lineWidth: 0.4)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Save button
                            Button {
                                guard authViewModel.signedInUser != nil else { return }
                                webPageViewModel.toggleSave(on: webPage)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: webPageViewModel.uiState.savedWebPageStates.contains(webPage.urlString) ? "star.fill" : "star")
                                        .scaleEffect(x: 1.3, y: 0.9)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                    
                                    if webPageViewModel.uiState.webPageSaveCounts[webPage.urlString] ?? 0 > 0 {
                                        Text("\(webPageViewModel.uiState.webPageSaveCounts[webPage.urlString] ?? 0)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)
                                            .contentTransition(.numericText())
                                            .animation(.smooth(duration: 0.2), value: webPageViewModel.uiState.webPageSaveCounts[webPage.urlString] ?? 0)
                                    }
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary, lineWidth: 0.4)
                                )
                            }
                            .buttonStyle(.plain)
                                
                                Spacer()
                            }
                        }
                        
                        // Right side: Thumbnail spanning from top of text to bottom of buttons (same aspect ratio as WebPageRowView)
                        // VStack{
                        //     if let thumbnailData = cachedImages.thumbnail, let uiImage = UIImage(data: thumbnailData) {
                        //         Image(uiImage: uiImage)
                        //             .resizable()
                        //             .aspectRatio(contentMode: .fill)
                        //             .frame(width: 80, height: 60)
                        //             .clipped()
                        //             .cornerRadius(5)
                        //             .overlay(RoundedRectangle(cornerRadius: 5)
                        //             .stroke(Color.secondary, lineWidth: 0.5))
                        //     }
                        // }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        webBrowser.urlString = webPage.urlString
                        webBrowser.isUserInitiatedNavigation = true
                        onDismiss()
                    }
//                    .padding(.top, 0)
                }
                .padding(.leading, 12)
                .padding(.trailing, 15)
                .padding(.top, 15)
                
            } else {
                // Loading placeholder
                HStack(alignment: .top, spacing: 5) {
                    VStack(spacing: 3) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 25, height: 25)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(lineWidth: 1)
                                .frame(width: 25, height: 25)
                        }
                        
                        Rectangle()
                            .frame(width: 1, height: 120)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // RoundedRectangle(cornerRadius: 6)
                            //     .fill(Color.gray.opacity(0.3))
                            //     .frame(width: 60, height: 45)
                        }
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 16)
                        
                        HStack(spacing: 20) {
                            ForEach(0..<3) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 14)
                            }
                            Spacer()
                        }
                    }
                    .padding(.top, 1.4)
                }
                .padding(.leading, 11)
                .padding(.trailing, 15)
                .padding(.top, 15)
                .padding(.bottom, 0)
            }
            
            
            // Show comment below webpage (aligned with connecting line) - closer to buttons
            CommentRowView(comment: comment, isShowingSwipeAction: false)
                .padding(.horizontal, 15)
                .padding(.top, 0)
                .padding(.bottom, 15)
        }
        .listRowSeparator(.hidden)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray6), lineWidth: 1.5)
        )
        .onAppear {
            // Cache the initial webPage and ensure it exists in ViewModel data
            if let foundWebPage = currentWebPage {
                webPage = foundWebPage
                webPageViewModel.loadAndCacheImages(for: foundWebPage)
            } else {
                webPageViewModel.fetchExistingWebPage(for: comment.urlString) { fetchedPage in
                    DispatchQueue.main.async {
                        self.webPage = fetchedPage
                        if let page = fetchedPage {
                            webPageViewModel.loadAndCacheImages(for: page)
                        }
                    }
                }
            }
        }
    }
}

#Preview("WebPageCommentRowView") {
    
    @Previewable @State var commentsUrlString: String? = nil

    let comment = Comment(
        id: CKRecord.ID(recordName: "comment1"),
        commentID: "comment1-uuid",
        text: "This is a great article! I really enjoyed reading about the new SwiftUI features and how they can improve our development workflow.",
        dateCreated: Date().addingTimeInterval(-3600), // 1 hour ago
        userID: "user1-uuid",
        username: "alexdev",
        urlString: "https://developer.apple.com/documentation/swiftui",
        likeCount: 15,
        saveCount: 3,
        isReported: 0,
        reportCount: 0
    )
    
    // WebPage will be fetched internally by WebPageCommentRowView
    
    let authViewModel = AuthViewModel()
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    let webBrowser = WebBrowser(urlString: "https://developer.apple.com")
    
    
    VStack(spacing: 20) {
        Text("WebPageCommentRowView Preview")
            .font(.title2)
            .fontWeight(.bold)
            .padding(.top)
        
        WebPageCommentRowView(
            comment: comment,
            commentsUrlString: .constant(commentsUrlString),
            onDismiss: {}
        )
        // WebPage will be automatically fetched based on comment.urlString
        
        Spacer()
    }
    .padding()
    .environmentObject(authViewModel)
    .environmentObject(webPageViewModel)
    .environmentObject(webBrowser)
    .background(Color(.systemBackground))
}
