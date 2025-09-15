//
//  CommentRowView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 4/28/24.
//

import SwiftUI
import Foundation

struct CommentRowView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    var comment: Comment  // ✅ UPDATED: No longer @ObservedObject since it's a struct
    @Binding var replyComment: Comment?
    
    var isParent: Bool = false
    var isShowingSwipeAction = true
    var isVUVNavLink = true
    var onTap: (() -> Void)?
    var onQuoteTap: ((Comment) -> Void)?
    
    @State private var foregroundColor: Color = .primary
    @State private var showDeleteConfirmation = false
    @State private var showReportSheet = false
    @State private var isSaving = false
    @State private var isLiking: Bool = false
    @State private var isProcessingSave = false
    @State private var likeAnimationTrigger: Bool = false
    @State private var showUserView = false
    
    // HYBRID LIKE SYSTEM: Use ViewModel's local cache for instant like status
    // This eliminates race conditions and provides immediate visual feedback
    // Like status persists across app sessions and syncs with CloudKit in background
    private var isLiked: Bool {
        webPageViewModel.hasLiked(comment)
    }
    
    init(
         comment: Comment,
         replyComment: Binding<Comment?> = .constant(nil),
         isParent: Bool = false,
         isShowingSwipeAction: Bool = true,
         isVUVNavlink: Bool = true,
         onTap: (() -> Void)? = nil,
         onQuoteTap: ((Comment) -> Void)? = nil
    ) {
        self.comment = comment
        self._replyComment = replyComment
        self.isParent = isParent
        self.isShowingSwipeAction = isShowingSwipeAction
        self.isVUVNavLink = isVUVNavlink
        self.onTap = onTap
        self.onQuoteTap = onQuoteTap
    }
    
    var body: some View {
        let isSaved = webPageViewModel.hasSaved(comment)
        
        HStack(alignment: .top, spacing: 6) {
            // Profile image on left
            Image(systemName: "person.circle")
                .font(.title)
                .foregroundStyle(Color.secondary)
                .frame(width: 36, height: 36)
                .padding(.top, -4)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isVUVNavLink {
                        showUserView = true
                    }
                }
            
            // All content on right
            VStack(alignment: .leading, spacing: 4) {
                // User info row
                HStack(alignment: .center) {
                    Text(comment.username)
                        .font(.caption)
                        .bold()
                    
                    Text(comment.dateCreated.timeAgoShort())
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)

                    Spacer()
                    
                    // Save indicator
                    if isSaved {
                        Image(systemName: "star.fill")
                            .scaleEffect(x: 1.3, y: 0.9)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            
                // Comment content
                VStack(alignment: .leading, spacing: 8) {
                    // Show quoted text if available
                    if let quotedText = comment.quotedText {
                        Text("\"\(quotedText)\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.leading, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                Rectangle()
                                    .frame(width: 3)
                                    .foregroundColor(.orange.opacity(0.6))
                                    .cornerRadius(1.5),
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onQuoteTap?(comment)
                            }
                    }
                    
                    Text(comment.text)
                        .font(.body)
                        .lineLimit(nil)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap?() ?? {replyComment = comment}()
                }
            
                // Action buttons
                HStack(alignment: .center, spacing: 12) {
                // Like
                Button {
                    guard authViewModel.signedInUser != nil else { return }
                    guard !isLiking else { 
                        print("🚫 COMMENT: Blocked tap - already liking")
                        return 
                    }
                    
                    // HYBRID LIKE SYSTEM: Instant UI response via local cache
                    // No need for @State management or optimistic updates
                    // ViewModel handles everything: local cache + CloudKit sync + persistence
                    
                    print("✅ COMMENT: Tap! isLiked=\(isLiked), count=\(webPageViewModel.getLikeCount(for: comment))")
                    isLiking = true
                    // Only animate when liking (not unliking)
                    if !isLiked {
                        likeAnimationTrigger.toggle()
                    }
                    webPageViewModel.toggleLike(on: comment, isCurrentlyLiked: isLiked) {
                        print("✅ COMMENT: Completion! new count=\(webPageViewModel.getLikeCount(for: comment))")
                        isLiking = false
                    }
                    
                    // UI updates automatically because isLiked computed property
                    // reads from webPageViewModel.likedComments (which is @Published)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .primary)
                            .opacity(isLiking ? 0.6 : 1.0)
                            .font(.callout)
                            .fontWeight(.light)
                            .frame(width: 16, height: 16)
                            .symbolEffect(.bounce, value: likeAnimationTrigger)
                        
                        Text(webPageViewModel.getLikeCount(for: comment) > 0 ? "\(webPageViewModel.getLikeCount(for: comment))" : "")
                            .font(.footnote)
                            .frame(minWidth: 12, alignment: .leading)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.4), value: webPageViewModel.getLikeCount(for: comment))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLiking)
                
                // Reply
                Button {
                    onTap?() ?? {replyComment = comment}()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble")
                            .font(.callout)
                            .fontWeight(.light)
                            .frame(width: 16, height: 16)
                        
                        // Show reply count if comment has replies
                        if webPageViewModel.getReplyCount(for: comment) > 0 {
                            Text("\(webPageViewModel.getReplyCount(for: comment))")
                                .font(.footnote)
                                .frame(minWidth: 12, alignment: .leading)
                        } else {
                            Text("")
                                .font(.footnote)
                                .frame(minWidth: 12, alignment: .leading)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Save - Commented out, functionality available via swipe action
                /*
                Button {
                    guard authViewModel.signedInUser != nil else { return }
                    guard !isSaving else { return }
                    guard !isProcessingSave else { return }
                    
                    isSaving = true
                    isProcessingSave = true
                    webPageViewModel.toggleSave(on: comment) {
                        isSaving = false
                        isProcessingSave = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "star.fill" : "star")
                            .scaleEffect(x: 1.3, y: 0.9)
                            .font(.title3)
                            .foregroundColor(.primary)
                            .opacity(isSaving ? 0.6 : 1.0)
                            .frame(width: 24, height: 24)
                        
                        Text(webPageViewModel.getSaveCount(for: comment) > 0 ? "\(webPageViewModel.getSaveCount(for: comment))" : "")
                            .font(.footnote)
                            .frame(minWidth: 5, alignment: .leading)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.4), value: webPageViewModel.getSaveCount(for: comment))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                */
                
                    Spacer()
                }
                .font(.callout)
                .padding(.bottom, 4)
            }
        }
        .transition(.slide)
        .listRowSeparator(.hidden)
        .swipeActions() {
            if isShowingSwipeAction{
                // Reply action (rightmost)
                Button {
                    replyComment = comment
                } label: {
                    Image(systemName: "arrow.turn.up.left")
                }
                .tint(.blue)
                
                // Save action (middle)
                Button{
                    guard authViewModel.signedInUser != nil else { return }
                    guard !isProcessingSave else { return }
                    isProcessingSave = true
                    webPageViewModel.toggleSave(on: comment) {
                        isProcessingSave = false
                    }
                } label: {
                    Image(systemName: isSaved ? "star.fill" : "star")
                }
                .tint(isSaved ? .orange : .gray)
                
                // Delete action (leftmost - only for comment owner)
                if let currentUser = authViewModel.signedInUser, comment.userID == currentUser.userID {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
                
                // Report action (leftmost - only for other users' comments)
                if let currentUser = authViewModel.signedInUser, comment.userID != currentUser.userID {
                    Button{
                        showReportSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                    .tint(.orange)
                }
            }
        }
        .confirmationDialog(
            "Delete Comment",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                webPageViewModel.removeComment(comment)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(comment: comment)
                .environmentObject(webPageViewModel)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showUserView) {
            ViewUserView(userID: comment.userID, authViewModel: authViewModel)
                .environmentObject(webPageViewModel)
                .environmentObject(authViewModel)
        }
        // HYBRID LIKE SYSTEM: No onAppear needed!
        // Like status loads instantly from local cache (UserDefaults)
        // Background CloudKit sync happens automatically when app launches
    }
}
