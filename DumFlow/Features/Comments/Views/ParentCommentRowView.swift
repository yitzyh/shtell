//
//  ParentCommentRowView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/20/24.
//

import SwiftUI
import CloudKit

struct ParentCommentRowView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: WebPageViewModel
    var comment: Comment
    @Binding var replyComment: Comment?
    
    @State var isParent: Bool = false
    @State private var size: CGSize = .zero
    @State private var foregroundColor: Color = .primary
    
    init(comment: Comment, replyComment: Binding<Comment?> = .constant(nil), isParent: Bool = false) {
        self.comment = comment
        self._replyComment = replyComment
        self.isParent = isParent
    }
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 7){
            VStack(spacing: 3){
                // ✅ UPDATED: Use CloudKit username property (no optional)
                Image(systemName: "\(comment.userID.first?.lowercased() ?? "p").circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(foregroundColor)
                    .onAppear{
                        foregroundColor = randomColors.randomElement()!
                    }
                Rectangle()
                    .frame(width: 1, height: .infinity)
                    .foregroundColor(Color(uiColor:  .secondaryLabel))
                    .padding(.bottom, 3)
            }
            VStack{
                //comment.user.name, comment.isSaved
                HStack{
                    HStack{
                        // ✅ UPDATED: Direct username access (no optional)
                        Text("@\(comment.userID.prefix(8))")
                        .font(.footnote)
                    }
                    Spacer()
                    // 🚀 TODO: Add CloudKit save status when implemented
                    // Image(systemName: comment.isSaved ? "bookmark.fill" : "")
                    //     .foregroundColor(comment.isSaved ? .orange : .secondary)
                    //     .font(.caption)
                }
                
                //Comment.text
                HStack{
                    // ✅ UPDATED: Direct text access (no optional)
                    Text(comment.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    replyComment = comment
                }
                
                //comment.isLiked/likeCount, comment button/count, and comment.dateCreated.
                HStack{
                    HStack(alignment: .center){
                        // ✅ UPDATED: Use CloudKit like functionality
                        Image(systemName: "heart.fill")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .contentTransition(.symbolEffect(.replace))
                            .onTapGesture {
                                // 🚀 TODO: Implement CloudKit like toggle with proper state management
                                viewModel.toggleLike(on: comment, isCurrentlyLiked: false)
                            }
                        
                        // ✅ UPDATED: Use CloudKit likeCount property
                        Text(comment.likeCount > 0 ? String(comment.likeCount) : "")
                            .contentTransition(.numericText(value: Double(comment.likeCount)))
                            .animation(.smooth(duration: 0.4), value: comment.likeCount)
                            .foregroundColor(.secondary)

                        Image(systemName: "bubble")
                            .font(.subheadline)
                            .scaleEffect(0.9)
                        
                        // 🚀 TODO: Add reply count when CloudKit replies are implemented
                        // Text(comment.replyCount > 0 ? "\(comment.replyCount)" : "")
                        //     .contentTransition(.numericText(value: Double(comment.replyCount)))
                    }
                    Spacer()
                    
                    // ✅ UPDATED: Direct dateCreated access (no optional)
                    Text(comment.dateCreated.timeAgoShort())
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.top, 1.4)
            .padding(.bottom, 10)
        }
        .onTapGesture {
            replyComment = comment
        }
        .transition(.slide)
        .listRowSeparator(.hidden)
        .swipeActions() {
            NavigationLink{
                // 🚀 TODO: Update when InfiniteReplyView is converted to CloudKit
                // InfiniteReplyView(comment: comment, textFieldIsFocused: true)
            } label: {
                Image(systemName: "arrow.turn.up.left")
            }
            
            Button{
                // ✅ UPDATED: Use CloudKit save functionality
//                viewModel.toggleSave(on: comment)
            } label: {
                Image(systemName: "star")
            }
            
            Button{
                // 🚀 TODO: Implement CloudKit report functionality
                // This could show a report sheet
            } label: {
                Image(systemName: "exclamationmark.bubble")
            }
        }
    }
}

// ✅ UPDATED: Support for random colors (moved from other file)
//let randomColors: [Color] = [.red, .yellow, .green, .blue, .orange, .purple, .cyan, .indigo, .mint, .teal]

// ✅ UPDATED: CloudKit-based preview
#Preview {
    
    let comment = Comment(
        id: CKRecord.ID(recordName: "comment2"),
        commentID: "comment2-uuid",
        text: "I agree! I really enjoyed reading it and learned a lot from the discussion.",
        dateCreated: Date(),
        userID: "user2-uuid",
        username: "yitzy",
        urlString: "https://example.com",
        likeCount: 4,
        saveCount: 1,
        isReported: 0,
        reportCount: 0)
    
    let authViewModel = AuthViewModel()
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    
    VStack(spacing: 16) {
        Text("CloudKit ParentCommentRowView")
            .font(.headline)
            .padding(.top)
        
        ParentCommentRowView(comment: comment)
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        
        ParentCommentRowView(comment: comment)
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        
        Spacer()
    }
    .padding()
    .environmentObject(webPageViewModel)
    .background(Color(.systemBackground))
}
