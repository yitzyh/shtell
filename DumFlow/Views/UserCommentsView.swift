//
//  UserCommentsView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/9/25.
//

import SwiftUI
import Foundation
import WebKit

struct UserCommentsView: View {
    @EnvironmentObject private var webBrowser: WebBrowser
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State var comments: [Comment] = []
    @State var replyComment: Comment?
    @State var isShowingComments = false
    @State var commentsWebPage: WebPage?

    enum FilterType {
        case isLiked, isSaved, isUser, all
    }
    
    init(filter: FilterType) {
        // 🚀 TODO: Implement CloudKit filtering when services are ready
        switch filter{
        case .isLiked:
            print("case .isLiked - TODO: Implement CloudKit liked comments fetch")
        case .isSaved:
            print("case .isSaved - TODO: Implement CloudKit saved comments fetch")
        case .isUser:
            print("case .isUser - TODO: Implement CloudKit user comments fetch")
        case .all:
            print("case .all - TODO: Implement CloudKit all comments fetch")
        }
    }

    var body: some View {
        NavigationStack{
            VStack{
                List{
                    ForEach(comments){ comment in
                        VStack(spacing: 0){
                            // if let webPage = comment.webPage {
                            //     ParentWebPageRowView(webPage: webPage, isShowingSwipeAction: false)
                            //         .padding(.leading, 12.5)
                            //         .padding(.trailing, 15)
                            //         .padding(.top, 15)
                            //         .onTapGesture {
                            //             webBrowser.urlString = webPage.urlString
                            //             webBrowser.isUserInitiatedNavigation = true
                            //             self.presentationMode.wrappedValue.dismiss()
                            //         }
                            //         .fixedSize(horizontal: false, vertical: true)
                            // }
                            
                            CommentRowView(comment: comment, replyComment: $replyComment, isShowingSwipeAction: false)
                                .padding(.horizontal, 15)
                                .padding(.bottom, 15)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowSeparator(.hidden)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray6), lineWidth: 1.5)
                        )
                    }
                }
                .listStyle(.plain)
                .sheet(item: $replyComment){ comment in
                    CommentView(urlString: comment.urlString)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
}
