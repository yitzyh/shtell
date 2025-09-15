////
////  ExpandableCommentRowView.swift
////  DumFlow
////
////  Created by Isaac Herskowitz on 12/27/24.
////
//
//import SwiftUI
//import CloudKit
//
//struct ExpandableCommentRowView: View {
//    @EnvironmentObject var webPageViewModel: WebPageViewModel
//    @EnvironmentObject var authViewModel: AuthViewModel
//    @Environment(\.colorScheme) var colorScheme
//    
//    let comment: Comment
//    @State private var isExpanded: Bool = false
//    @State private var isTextExpanded: Bool = false
//    @Binding var replyComment: Comment?
//    let depth: Int
//    let onQuoteTap: ((Comment) -> Void)?
//    
//    // Maximum nesting depth - only show 1 level of replies
//    private let maxDepth = 1
//    
//    // Get direct replies to this comment
//    var replies: [Comment] {
//        webPageViewModel.contentState.comments
//            .filter { $0.parentCommentID == comment.commentID }
//            .sorted { $0.dateCreated < $1.dateCreated }
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            // Main comment with indentation
//            HStack(spacing: 0) {
//                // Visual hierarchy - vertical line for nested comments
//                if depth > 0 {
//                    Rectangle()
//                        .fill(Color.orange.opacity(0.3))
//                        .frame(width: 2)
//                        .padding(.leading, CGFloat((depth - 1) * 24))
//                        .padding(.trailing, 12)
//                }
//                
//                VStack(alignment: .leading, spacing: 0) {
//                    // Use existing CommentRowView but modify the text display
//                    VStack(alignment: .leading, spacing: 0) {
//                        // Copy the user info section from CommentRowView
//                        HStack {
//                            Image(systemName: "person.circle")
//                                .foregroundStyle(Color.secondary)
//                            
//                            Text(comment.username)
//                                .font(.caption)
//                                .bold()
//                            
//                            Text(comment.dateCreated.timeAgoShort())
//                                .font(.footnote)
//                                .foregroundColor(.secondary)
//                                .padding(.leading, 10)
//                            
//                            Spacer()
//                        }
//                        .padding(.bottom, 4)
//                        
//                        // Comment text with Read More functionality
//                        VStack(alignment: .leading, spacing: 6) {
//                            // Show quoted text if available
//                            if let quotedText = comment.quotedText {
//                                Text("\"\(quotedText)\"")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                    .italic()
//                                    .padding(.leading, 12)
//                                    .padding(.vertical, 6)
//                                    .background(Color.secondary.opacity(0.1))
//                                    .cornerRadius(6)
//                                    .overlay(
//                                        Rectangle()
//                                            .frame(width: 3)
//                                            .foregroundColor(.orange.opacity(0.6))
//                                            .cornerRadius(1.5),
//                                        alignment: .leading
//                                    )
//                                    .onTapGesture {
//                                        onQuoteTap?(comment)
//                                    }
//                            }
//                            
//                            // Comment text with line limit
//                            Text(comment.text)
//                                .font(.callout)
//                                .lineLimit(isTextExpanded ? nil : 8)
//                                .animation(.easeInOut(duration: 0.2), value: isTextExpanded)
//                            
//                            // Read more/less button
//                            if comment.text.components(separatedBy: .newlines).count > 8 ||
//                               (comment.text.count > 400 && !isTextExpanded) {
//                                Button {
//                                    withAnimation {
//                                        isTextExpanded.toggle()
//                                    }
//                                } label: {
//                                    Text(isTextExpanded ? "Read less" : "Read more")
//                                        .font(.caption)
//                                        .foregroundColor(.orange)
//                                }
//                                .buttonStyle(.plain)
//                            }
//                        }
//                        .padding(.bottom, 8)
//                        
//                        // Like/Reply buttons only (no save button in UI)
//                        HStack(alignment: .center, spacing: 20) {
//                            // Like button
//                            Button {
//                                guard authViewModel.signedInUser != nil else { return }
//                                webPageViewModel.toggleLike(on: comment, isCurrentlyLiked: webPageViewModel.hasLiked(comment)) { }
//                            } label: {
//                                HStack(spacing: 4) {
//                                    Image(systemName: webPageViewModel.hasLiked(comment) ? "heart.fill" : "heart")
//                                        .foregroundColor(webPageViewModel.hasLiked(comment) ? .red : .secondary)
//                                        .font(.system(size: 14))
//                                    
//                                    if webPageViewModel.getLikeCount(for: comment) > 0 {
//                                        Text("\(webPageViewModel.getLikeCount(for: comment))")
//                                            .font(.caption)
//                                            .foregroundColor(.secondary)
//                                    }
//                                }
//                            }
//                            .buttonStyle(.plain)
//                            
//                            // Reply button
//                            Button {
//                                replyComment = comment
//                            } label: {
//                                HStack(spacing: 4) {
//                                    Image(systemName: "bubble")
//                                        .font(.system(size: 14))
//                                        .foregroundColor(.secondary)
//                                    
//                                    if replies.count > 0 {
//                                        Text("\(replies.count)")
//                                            .font(.caption)
//                                            .foregroundColor(.secondary)
//                                    }
//                                }
//                            }
//                            .buttonStyle(.plain)
//                            
//                            Spacer()
//                        }
//                        .font(.callout)
//                    }
//                }
//            }
//            
//            // Expand/collapse button for replies (only if not at max depth)
//            if !replies.isEmpty && depth < maxDepth {
//                HStack {
//                    // Indent to align with comment
//                    if depth > 0 {
//                        Spacer()
//                            .frame(width: CGFloat(depth * 24) + 14)
//                    }
//                    
//                    Button {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            isExpanded.toggle()
//                        }
//                    } label: {
//                        HStack(spacing: 4) {
//                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
//                                .font(.caption2)
//                            Text(isExpanded ? "Hide" : "View")
//                            Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
//                        }
//                        .font(.caption)
//                        .foregroundColor(.orange)
//                        .padding(.vertical, 2)
//                    }
//                    .buttonStyle(.plain)
//                    
//                    Spacer()
//                }
//            }
//            
//            // Show replies when expanded
//            if isExpanded && depth < maxDepth {
//                VStack(spacing: 12) {
//                    ForEach(replies) { reply in
//                        ExpandableCommentRowView(
//                            comment: reply,
//                            replyComment: $replyComment,
//                            depth: depth + 1,
//                            onQuoteTap: onQuoteTap
//                        )
//                        .transition(.asymmetric(
//                            insertion: .move(edge: .top).combined(with: .opacity),
//                            removal: .opacity
//                        ))
//                    }
//                }
//                .animation(.easeInOut(duration: 0.3), value: replies.count)
//            }
//            
//            // No deeper nesting - removed @mention style since maxDepth is now 1
//        }
//        .padding(.vertical, 4)
//        // Only add swipe actions for parent comments (depth 0)
//        .swipeActions {
//            if depth == 0 {
//                Button {
//                    guard authViewModel.signedInUser != nil else { return }
//                    webPageViewModel.toggleSave(on: comment) { }
//                } label: {
//                    Image(systemName: webPageViewModel.hasSaved(comment) ? "bookmark.fill" : "bookmark")
//                }
//                .tint(webPageViewModel.hasSaved(comment) ? .orange : .gray)
//            }
//        }
//    }
//}
//
//// MARK: - Preview
//
//#Preview("Comment Thread Example") {
//    struct PreviewWrapper: View {
//        @StateObject private var authViewModel = AuthViewModel()
//        @StateObject private var webPageViewModel: WebPageViewModel
//        @State private var replyComment: Comment?
//        
//        init() {
//            let auth = AuthViewModel()
//            _webPageViewModel = StateObject(wrappedValue: WebPageViewModel(authViewModel: auth))
//        }
//        
//        var body: some View {
//            NavigationStack {
//                ScrollView {
//                    VStack(spacing: 16) {
//                        // Create sample comments for preview
//                        ForEach(sampleComments) { comment in
//                            ExpandableCommentRowView(
//                                comment: comment,
//                                replyComment: $replyComment,
//                                depth: 0,
//                                onQuoteTap: { comment in
//                                    print("Quote tapped: \(comment.text)")
//                                }
//                            )
//                            .padding(.horizontal)
//                            
//                            Divider()
//                        }
//                    }
//                    .padding(.vertical)
//                }
//                .background(Color(UIColor.systemBackground))
//                .navigationTitle("Comments")
//                .navigationBarTitleDisplayMode(.inline)
//                .onAppear {
//                    // Add sample comments to the view model
//                    webPageViewModel.contentState.comments = allSampleComments
//                }
//            }
//            .environmentObject(authViewModel)
//            .environmentObject(webPageViewModel)
//        }
//    }
//    
//    return PreviewWrapper()
//}
//
//// Sample data for preview
//private let sampleComments: [Comment] = [
//    Comment(
//        id: CKRecord.ID(recordName: "comment1"),
//        commentID: "1",
//        text: "Great article! The points about sustainable development really resonated with me.",
//        dateCreated: Date().addingTimeInterval(-3600),
//        userID: "user1",
//        username: "ArticleReader",
//        urlString: "https://example.com",
//        parentCommentID: nil,
//        quotedText: nil,
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 5,
//        saveCount: 2,
//        isReported: 0,
//        reportCount: 0
//    ),
//    Comment(
//        id: CKRecord.ID(recordName: "comment2"),
//        commentID: "2",
//        text: """
//        This is a really long comment that demonstrates the Read More functionality.
//        Line 2: I'm going to discuss many different aspects of this article.
//        Line 3: First, let me talk about the introduction which was compelling.
//        Line 4: The author really knows how to grab the reader's attention.
//        Line 5: Moving on to the main arguments presented in the piece.
//        Line 6: I found the statistics particularly convincing and well-researched.
//        Line 7: The examples from Nordic countries were especially relevant.
//        Line 8: This line should be the last one visible before "Read more".
//        Line 9: This line should only appear after clicking "Read more".
//        Line 10: And this is the final line of my lengthy commentary on this excellent article!
//        """,
//        dateCreated: Date().addingTimeInterval(-7200),
//        userID: "user2",
//        username: "LongCommenter",
//        urlString: "https://example.com",
//        parentCommentID: nil,
//        quotedText: "sustainable development is not just an option",
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 12,
//        saveCount: 8,
//        isReported: 0,
//        reportCount: 0
//    ),
//    Comment(
//        id: CKRecord.ID(recordName: "comment3"),
//        commentID: "3",
//        text: "Has anyone tried implementing these strategies in their workplace?",
//        dateCreated: Date().addingTimeInterval(-1800),
//        userID: "user3",
//        username: "CuriousReader",
//        urlString: "https://example.com",
//        parentCommentID: nil,
//        quotedText: nil,
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 3,
//        saveCount: 1,
//        isReported: 0,
//        reportCount: 0
//    )
//]
//
//// Replies for the sample comments
//private let sampleReplies: [Comment] = [
//    // Replies to comment 1
//    Comment(
//        id: CKRecord.ID(recordName: "comment1_1"),
//        commentID: "1.1",
//        text: "Totally agree! The sustainability angle is crucial for our future.",
//        dateCreated: Date().addingTimeInterval(-2400),
//        userID: "user4",
//        username: "EcoWarrior",
//        urlString: "https://example.com",
//        parentCommentID: "1",
//        quotedText: nil,
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 2,
//        saveCount: 0,
//        isReported: 0,
//        reportCount: 0
//    ),
//    Comment(
//        id: CKRecord.ID(recordName: "comment1_2"),
//        commentID: "1.2",
//        text: "I'm not entirely convinced. What about the economic implications?",
//        dateCreated: Date().addingTimeInterval(-1200),
//        userID: "user5",
//        username: "Skeptic123",
//        urlString: "https://example.com",
//        parentCommentID: "1",
//        quotedText: nil,
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 1,
//        saveCount: 0,
//        isReported: 0,
//        reportCount: 0
//    ),
//    
//    // Nested reply (reply to a reply)
//    Comment(
//        id: CKRecord.ID(recordName: "comment1_1_1"),
//        commentID: "1.1.1",
//        text: "Good question! The article addresses this in the third section.",
//        dateCreated: Date().addingTimeInterval(-600),
//        userID: "user1",
//        username: "ArticleReader",
//        urlString: "https://example.com",
//        parentCommentID: "1.1",
//        quotedText: "What about the economic implications?",
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 4,
//        saveCount: 1,
//        isReported: 0,
//        reportCount: 0
//    ),
//    
//    // Replies to comment 3
//    Comment(
//        id: CKRecord.ID(recordName: "comment3_1"),
//        commentID: "3.1",
//        text: "Yes! We started a pilot program last month. Happy to share our experience.",
//        dateCreated: Date().addingTimeInterval(-900),
//        userID: "user6",
//        username: "OfficeManager",
//        urlString: "https://example.com",
//        parentCommentID: "3",
//        quotedText: nil,
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 7,
//        saveCount: 3,
//        isReported: 0,
//        reportCount: 0
//    ),
//    Comment(
//        id: CKRecord.ID(recordName: "comment3_2"),
//        commentID: "3.2",
//        text: "We've been doing this for 2 years now. The ROI has been fantastic!",
//        dateCreated: Date().addingTimeInterval(-300),
//        userID: "user7",
//        username: "StartupFounder",
//        urlString: "https://example.com",
//        parentCommentID: "3",
//        quotedText: nil,
//        quotedTextSelector: nil,
//        quotedTextOffset: nil,
//        likeCount: 9,
//        saveCount: 4,
//        isReported: 0,
//        reportCount: 0
//    )
//]
//
//// Combine all comments for the view model
//private let allSampleComments = sampleComments + sampleReplies
