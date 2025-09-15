//
//  CommentThreadView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 12/27/24.
//

import SwiftUI
import CloudKit

struct CommentThreadView: View {
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    let parentComment: Comment
    @State private var isExpanded = false
    @State private var visibleReplyCount = 3
    @Binding var replyComment: Comment?
    let onQuoteTap: ((Comment) -> Void)?
    
    // Get direct replies to this comment
    var replies: [Comment] {
        webPageViewModel.contentState.comments
            .filter { $0.parentCommentID == parentComment.commentID }
            .sorted { $0.dateCreated < $1.dateCreated }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent comment using existing CommentRowView
            CommentRowView(
                comment: parentComment,
                replyComment: $replyComment,
                onQuoteTap: onQuoteTap
            )
            
            // Replies section
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Show expand button only when collapsed - aligned with comment text
                    if !isExpanded {
                        HStack {
                            Button {
                                isExpanded.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                    Text("View all \(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 8)
                                .padding(.bottom, 0)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.leading, 42) // 36 (profile) + 6 (spacing)
                    }
                    
                    // Replies container - no animation, instant show/hide like Reddit
                    if isExpanded {
                        VStack(spacing: 8) {
                            // Show limited number of replies
                            ForEach(replies.prefix(visibleReplyCount)) { reply in
                                ReplyRowView(
                                    reply: reply,
                                    replyComment: $replyComment,
                                    onQuoteTap: onQuoteTap
                                )
                            }
                            
                            // Show more button - aligned with comment text left edge
                            if replies.count > visibleReplyCount {
                                HStack {
                                    Button {
                                        visibleReplyCount = replies.count
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                            Text("View all \(replies.count) replies")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                }
                                .padding(.leading, 42) // 36 (profile) + 6 (spacing)
                            }
                            
                            // Hide replies button - aligned with comment text
                            if visibleReplyCount >= replies.count {
                                HStack {
                                    Button {
                                        isExpanded.toggle()
                                        if !isExpanded {
                                            visibleReplyCount = 3 // Reset when collapsing
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.up")
                                                .font(.caption2)
                                            Text("Hide replies")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                }
                                .padding(.leading, 42) // 36 (profile) + 6 (spacing)
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.top, 12)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
    }
}

// MARK: - ReplyRowView

struct ReplyRowView: View {
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    let reply: Comment
    @State private var isTextExpanded: Bool = false
    @State private var isLiking: Bool = false
    @State private var likeAnimationTrigger: Bool = false
    @Binding var replyComment: Comment?
    let onQuoteTap: ((Comment) -> Void)?
    
    private var isLiked: Bool {
        webPageViewModel.hasLiked(reply)
    }
    
    var body: some View {
        let isSaved = webPageViewModel.hasSaved(reply)
        
        HStack(alignment: .top, spacing: 5) {
            // Profile image on left - smaller
            Image(systemName: "person.circle")
                .font(.title3)
                .foregroundStyle(Color.secondary)
                .frame(width: 28, height: 28)
                .padding(.top, -1)
            
            // All content on right
            VStack(alignment: .leading, spacing: 3) {
                // User info row
                HStack(alignment: .center) {
                    Text(reply.username)
                        .font(.caption2)
                        .bold()
                    
                    Text(reply.dateCreated.timeAgoShort())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)

                    Spacer()
                    
                    // Save indicator
                    if isSaved {
                        Image(systemName: "star.fill")
                            .scaleEffect(x: 1.3, y: 0.9)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            
                // Comment content
                VStack(alignment: .leading, spacing: 6) {
                    // Show quoted text if available
                    if let quotedText = reply.quotedText {
                        Text("\"\(quotedText)\"")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.leading, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                            .overlay(
                                Rectangle()
                                    .frame(width: 2)
                                    .foregroundColor(.orange.opacity(0.6))
                                    .cornerRadius(1),
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onQuoteTap?(reply)
                            }
                    }
                    
                    Text(reply.text)
                        .font(.callout)
                        .lineLimit(isTextExpanded ? nil : 6)
                        .animation(.easeInOut(duration: 0.2), value: isTextExpanded)
                    
                    // Read more/less button for long replies
                    if reply.text.components(separatedBy: .newlines).count > 6 ||
                       (reply.text.count > 300 && !isTextExpanded) {
                        Button {
                            withAnimation {
                                isTextExpanded.toggle()
                            }
                        } label: {
                            Text(isTextExpanded ? "Read less" : "Read more")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    replyComment = reply
                }
            
                // Action buttons - smaller
                HStack(alignment: .center, spacing: 10) {
                    // Like
                    Button {
                        guard authViewModel.signedInUser != nil else { return }
                        guard !isLiking else { return }
                        
                        isLiking = true
                        if !isLiked {
                            likeAnimationTrigger.toggle()
                        }
                        webPageViewModel.toggleLike(on: reply, isCurrentlyLiked: isLiked) {
                            isLiking = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .primary)
                                .opacity(isLiking ? 0.6 : 1.0)
                                .font(.callout)
                                .frame(width: 18, height: 18)
                                .symbolEffect(.bounce, value: likeAnimationTrigger)
                            
                            Text(webPageViewModel.getLikeCount(for: reply) > 0 ? "\(webPageViewModel.getLikeCount(for: reply))" : "")
                                .font(.caption2)
                                .frame(minWidth: 8, alignment: .leading)
                                .contentTransition(.numericText())
                                .animation(.smooth(duration: 0.4), value: webPageViewModel.getLikeCount(for: reply))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLiking)
                    
                    // Reply
                    Button {
                        replyComment = reply
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble")
                                .font(.callout)
                                .frame(width: 18, height: 18)
                            
                            if webPageViewModel.getReplyCount(for: reply) > 0 {
                                Text("\(webPageViewModel.getReplyCount(for: reply))")
                                    .font(.caption2)
                                    .frame(minWidth: 8, alignment: .leading)
                            } else {
                                Text("")
                                    .font(.caption2)
                                    .frame(minWidth: 8, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .frame(height: 16)
                .font(.caption2)
            }
        }
    }
}

// MARK: - Preview

#Preview("Comment Thread") {
    struct PreviewWrapper: View {
        @StateObject private var authViewModel = AuthViewModel()
        @StateObject private var webPageViewModel: WebPageViewModel
        @State private var replyComment: Comment?
        
        init() {
            let auth = AuthViewModel()
            _webPageViewModel = StateObject(wrappedValue: WebPageViewModel(authViewModel: auth))
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        CommentThreadView(
                            parentComment: sampleParentComment,
                            replyComment: $replyComment,
                            onQuoteTap: { comment in
                                print("Quote tapped: \(comment.text)")
                            }
                        )
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Long comment example
                        CommentThreadView(
                            parentComment: sampleLongComment,
                            replyComment: $replyComment,
                            onQuoteTap: { comment in
                                print("Quote tapped: \(comment.text)")
                            }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .background(Color(UIColor.systemBackground))
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    // Add all sample data to view model
                    webPageViewModel.contentState.comments = [
                        sampleParentComment,
                        sampleLongComment
                    ] + sampleReplies
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(webPageViewModel)
            .environmentObject(BrowseForwardViewModel())
        }
    }
    
    return PreviewWrapper()
}

// Sample data
private let sampleParentComment = Comment(
    id: CKRecord.ID(recordName: "parent1"),
    commentID: "parent1",
    text: "This article really opened my eyes to sustainable development. The renewable energy section was particularly insightful!",
    dateCreated: Date().addingTimeInterval(-3600),
    userID: "user1",
    username: "GreenEnthusiast",
    urlString: "https://example.com",
    parentCommentID: nil,
    quotedText: "renewable energy is the future",
    quotedTextSelector: nil,
    quotedTextOffset: nil,
    likeCount: 24,
    saveCount: 5,
    isReported: 0,
    reportCount: 0
)

private let sampleLongComment = Comment(
    id: CKRecord.ID(recordName: "parent2"),
    commentID: "parent2",
    text: """
    This is a comprehensive comment that demonstrates the Read More functionality.
    Line 2: I want to discuss several key points from this article.
    Line 3: First, the introduction was incredibly compelling and well-written.
    Line 4: The statistics about climate change were eye-opening.
    Line 5: I particularly appreciated the focus on actionable solutions.
    Line 6: The case studies from Nordic countries were fascinating.
    Line 7: It's encouraging to see real-world implementations working.
    Line 8: This line should be the last visible before "Read more".
    Line 9: This additional content appears after expanding.
    Line 10: Thanks for sharing this important article with the community!
    """,
    dateCreated: Date().addingTimeInterval(-7200),
    userID: "user2",
    username: "ThoughtfulReader",
    urlString: "https://example.com",
    parentCommentID: nil,
    quotedText: nil,
    quotedTextSelector: nil,
    quotedTextOffset: nil,
    likeCount: 42,
    saveCount: 12,
    isReported: 0,
    reportCount: 0
)

private let sampleReplies: [Comment] = [
    // Replies to parent1
    Comment(
        id: CKRecord.ID(recordName: "reply1"),
        commentID: "reply1",
        text: "Totally agree! The renewable energy stats were mind-blowing.",
        dateCreated: Date().addingTimeInterval(-2400),
        userID: "user3",
        username: "EcoWarrior",
        urlString: "https://example.com",
        parentCommentID: "parent1",
        quotedText: nil,
        quotedTextSelector: nil,
        quotedTextOffset: nil,
        likeCount: 8,
        saveCount: 0,
        isReported: 0,
        reportCount: 0
    ),
    Comment(
        id: CKRecord.ID(recordName: "reply2"),
        commentID: "reply2",
        text: "What about the economic implications? I'm curious about the cost-benefit analysis.",
        dateCreated: Date().addingTimeInterval(-1800),
        userID: "user4",
        username: "Economist101",
        urlString: "https://example.com",
        parentCommentID: "parent1",
        quotedText: nil,
        quotedTextSelector: nil,
        quotedTextOffset: nil,
        likeCount: 5,
        saveCount: 1,
        isReported: 0,
        reportCount: 0
    ),
    Comment(
        id: CKRecord.ID(recordName: "reply3"),
        commentID: "reply3",
        text: "The article actually covers economics in section 3. Worth a read!",
        dateCreated: Date().addingTimeInterval(-1200),
        userID: "user1",
        username: "GreenEnthusiast",
        urlString: "https://example.com",
        parentCommentID: "parent1",
        quotedText: "economic implications",
        quotedTextSelector: nil,
        quotedTextOffset: nil,
        likeCount: 3,
        saveCount: 0,
        isReported: 0,
        reportCount: 0
    ),
    Comment(
        id: CKRecord.ID(recordName: "reply4"),
        commentID: "reply4",
        text: "Has anyone tried implementing these strategies at their workplace?",
        dateCreated: Date().addingTimeInterval(-900),
        userID: "user5",
        username: "CorporateGreen",
        urlString: "https://example.com",
        parentCommentID: "parent1",
        quotedText: nil,
        quotedTextSelector: nil,
        quotedTextOffset: nil,
        likeCount: 6,
        saveCount: 2,
        isReported: 0,
        reportCount: 0
    ),
    Comment(
        id: CKRecord.ID(recordName: "reply5"),
        commentID: "reply5",
        text: "We started a pilot program last month. Happy to share our experience if anyone's interested!",
        dateCreated: Date().addingTimeInterval(-600),
        userID: "user6",
        username: "StartupFounder",
        urlString: "https://example.com",
        parentCommentID: "parent1",
        quotedText: nil,
        quotedTextSelector: nil,
        quotedTextOffset: nil,
        likeCount: 12,
        saveCount: 4,
        isReported: 0,
        reportCount: 0
    ),
    
    // Replies to parent2
    Comment(
        id: CKRecord.ID(recordName: "reply6"),
        commentID: "reply6",
        text: "Your analysis is spot on! The Nordic case studies were my favorite part too.",
        dateCreated: Date().addingTimeInterval(-3000),
        userID: "user7",
        username: "PolicyWonk",
        urlString: "https://example.com",
        parentCommentID: "parent2",
        quotedText: nil,
        quotedTextSelector: nil,
        quotedTextOffset: nil,
        likeCount: 15,
        saveCount: 3,
        isReported: 0,
        reportCount: 0
    )
]
