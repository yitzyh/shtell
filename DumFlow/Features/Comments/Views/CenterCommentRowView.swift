//
//  CenterCommentRowView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/20/24.
//

import Foundation
import SwiftUI

struct CenterCommentRowView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WebPageViewModel
    var comment: Comment
    @Binding var replyComment: Comment?
    
    @State var isParent: Bool = false
    @State private var size: CGSize = .zero
    @State private var foregroundColor: Color = .primary
    
    init(comment: Comment, viewModel: WebPageViewModel, replyComment: Binding<Comment?> = .constant(nil), isParent: Bool = false) {
        self.comment = comment
        self.viewModel = viewModel
        self._replyComment = replyComment
        self.isParent = isParent
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 7){
            VStack{
                //comment.user.name, comment.isSaved
                HStack{
                    // ✅ UPDATED: Use CloudKit username property
                    Image(systemName: "\(comment.userID.first?.lowercased() ?? "p").circle")
                        .font(.body)
                        .foregroundColor(foregroundColor)
                        .onAppear{
                            foregroundColor = randomColors.randomElement() ?? .blue
                        }
                    HStack{
                        // ✅ UPDATED: Direct username access
                        Text("@\(comment.userID.prefix(8))")
                            .font(.footnote)
                    }
                    Spacer()
                }
                
                //Comment.text
                HStack{
                    // ✅ UPDATED: Direct text access (no optional)
                    Text(comment.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.callout)
                }
                .onTapGesture {
                    replyComment = comment
                }
                
                //comment.isLiked/likeCount, comment button/count, and comment.dateCreated.
                HStack{
                    // ✅ UPDATED: Use CloudKit properties
                    Image(systemName: "heart.fill")
                        .foregroundColor(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                    
                    Text(comment.likeCount > 0 ? String(comment.likeCount) : "")
                        .contentTransition(.numericText(value: Double(comment.likeCount)))
                        .animation(.smooth(duration: 0.4), value: comment.likeCount)
                        .foregroundColor(.secondary)

                    Image(systemName: "bubble")
                    // 🚀 TODO: Add reply count when implemented in CloudKit
                    
                    Spacer()
                    // ✅ UPDATED: Use CloudKit dateCreated
                    Text(comment.dateCreated.timeAgoShort())
                }
                .frame(height:20)
                .font(.callout)
                .foregroundColor(.secondary)
            }
            .padding(.top, 1.4)
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
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .tint(.blue)
            }
            Button{
                // 🚀 TODO: Implement CloudKit save functionality
//                viewModel.toggleSave(on: comment)
            } label: {
                Label("Save", systemImage: "star")
            }
            .tint(.yellow)
        }
    }
}

// ✅ UPDATED: Support for random colors
let randomColors: [Color] = [.red, .yellow, .green, .blue, .orange, .purple, .cyan, .indigo, .mint, .teal]
