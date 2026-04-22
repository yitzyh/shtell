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
    @State private var showUserView = false

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

                    Text(comment.timeAgoShort)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)

                    Spacer()
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
            ViewUserView(userID: comment.userID)
                .environmentObject(webPageViewModel)
                .environmentObject(authViewModel)
        }
    }
}
