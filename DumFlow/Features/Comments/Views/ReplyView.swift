//
//  ReplyView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/3/25.
//

import SwiftUI
import CloudKit

struct ReplyView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let parentComment: Comment
    @State private var newReply = ""
    @State private var replyComment: Comment?
    @FocusState private var textFieldIsFocused: Bool
    
    private var replies: [Comment] {
        webPageViewModel.contentState.comments.filter { $0.parentCommentID == parentComment.commentID }
    }
    
    var body: some View {
//        NavigationView {
            VStack(spacing: 0) {
                List {
                    // Parent comment with black background
                    CommentRowView(comment: parentComment, replyComment: $replyComment)
//                        .background(colorScheme == .dark ? Color.black : Color.gray.opacity(0.1))
                        .listRowBackground(colorScheme == .dark ? Color.black : Color.gray.opacity(0.1))

                    
                    // Replies with normal appearance
                    ForEach(replies) { reply in
                        CommentRowView(comment: reply, replyComment: $replyComment)
                            .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                            .listRowBackground(colorScheme == .dark ? Color(white: 0.07) : .white)
                    }
                }
                .listStyle(.plain)
                .background(colorScheme == .dark ? Color(white: 0.07) : .white)
                
                // Reply input - same as CommentView
                .safeAreaInset(edge: .bottom) {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Reply to comment", text: $newReply, axis: .vertical)
                            .lineLimit(5)
                            .focused($textFieldIsFocused)
                            .submitLabel(.next)
                            .onSubmit(createNewLine)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .padding(.leading, 16)
                            .padding(.trailing, !newReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 8 : 16)
                        
                        if !newReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button { postReply() } label: {
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
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Text("Replies")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
            }
//        }
    }
    
    private func createNewLine() {
        newReply += "\n"
    }
    
    private func postReply() {
        guard authViewModel.signedInUser != nil else { return }
        guard !newReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // If replying to a specific comment, use that comment's ID as parent
        // Otherwise, reply to the main parent comment
        let parentID = replyComment?.commentID ?? parentComment.commentID
        
        webPageViewModel.addComment(text: newReply, parentCommentID: parentID)
        newReply = ""
        replyComment = nil // Clear the reply target
        textFieldIsFocused = false
    }
}
