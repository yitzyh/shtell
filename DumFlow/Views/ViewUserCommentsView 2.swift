import SwiftData
import SwiftUI
import Foundation
import WebKit

struct ViewUserCommentsView: View {
    


//    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var webBroswer: WebBrowser
    @Environment(\.colorScheme) var colorScheme
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

            
    var comments: [Comment] = []
    
    @State var replyComment: Comment?
    
    @State private var user: User
    
    @State private var newName = ""
    @State private var newDisplayName = ""
    @State private var isShowingSwipeAction = false

    @State private var currentUserIndex = 0
    @State private var likeCount = 23
    
    @State var isShowingComments = false
    @State var commentsWebPage: WebPage?
    @State var commentReplies: Comment?

        
    
    enum FilterType {
        case isUser, isLiked
    }
    
    let filter: FilterType
    
    init(filter: FilterType, user: User) {
        self.filter = filter
        self.user = user
        
//        switch filter{
//        case .isLiked:
//            if let comments = user.likedComments{
//                self.comments = comments
//            }
//        case .isUser:
//            if let comments = user.comments{
//                self.comments = comments
//            }
//        case .isSaved:
//            _comments = Query(filter: #Predicate { $0.isSaved == true }, sort: \Comment.dateCreated, order: .reverse)
                        
//        case .all:
//            _comments = Query(sort: \Comment.dateCreated, order: .reverse)
//        }
    }

        
    var body: some View {
        
        NavigationStack{
            VStack{
                Text("The compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions")
//                List{
//                    ForEach(comments){ comment in
//                        VStack(spacing: 0){
//                            if let webPage = comment.webPage {
//                                ParentWebPageRowView(webPage: webPage, isShowingSwipeAction: false)
//                                    .padding(.leading, 12.5)
//                                    .padding(.trailing, 15)
//                                    .padding(.top, 15)
//                                    .onTapGesture {
//                                        webBroswer.urlString = comment.webPage?.urlString ?? "https://apple.com"
//                                        webBroswer.isUserInitiatedNavigation = true
//                                        self.presentationMode.wrappedValue.dismiss()
//                                    }
//                                    .fixedSize(horizontal: false, vertical: true)
//                            }
//                            CommentRowView(
////                                modelContext: modelContext,
//                                comment: comment,
//                                replyComment: $replyComment,
//                                isShowingSwipeAction: false,
//                                isVUVNavlink: false)
//                                .padding(.horizontal, 15)
//                                .padding(.bottom, 15)
//                        }
////                        .background(colorScheme == .dark ? .black : .white)
//
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .listRowSeparator(.hidden)
//                        .cornerRadius(10)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 10)
//                                .stroke(Color(.systemGray6), lineWidth: 1.5)
//                        )
//                        .swipeActions() {
//                            NavigationLink{
//                                InfiniteReplyView(comment: comment/*, modelContext: modelContext*/, textFieldIsFocused: true)
//                            } label: {
//                                Label("Reply", systemImage: "arrowshape.turn.up.left")
//                                    .tint(.blue)
//                            }
//                            if isShowingSwipeAction{
//                                Button{
//                                    comment.isSaved.toggle()
//                                } label: {
//                                    Image(systemName: comment.isSaved ? "bookmark.fill" : "bookmark")
//                                }
//                                .tint(Color.yellow)
//                            }
//                        }
//                    }
////                    .listRowInsets(EdgeInsets())
////                    .border(.yellow)
//                    .listRowBackground(Color.clear)
//
////                    .listRowBackground(colorScheme == .dark ? .black : .white)
//                    
//
//                }
////                .scrollContentBackground(.hidden)
//                .scrollContentBackground(.hidden)
////                .listRowBackground(Color.purple)
//
////                .background(.blue)
////                .ignoresSafeArea()
//                .listStyle(.plain)
////                .border(.green, width: 3)
////                .transition(.slide)
////                .listRowSpacing(10.0)
////                .sheet(item: $commentsWebPage){ webPage in
////                    CommentView(urlString: webPage.urlString, modelContext: modelContext)
////                        .presentationDetents([.fraction(0.75), .large])
////                }
//                .sheet(item: $replyComment){ comment in
//                    CommentView(urlString: comment.urlString/*, navToComment: comment*/)
//                        .presentationDragIndicator(.visible)
//                }
            }
            .background(colorScheme == .dark ? .black : .white)

        }
    }
}




//#Preview {
//    let user = User(name: "Yitzy", displayName: "shvitzmeister")
//    let urlString = "https://www.google.com"
//    let text = "The former president has decided to dramatically alter his Republican National Convention (RNC) speech to focus on national unity."
//    
//    let webPage = WebPage(urlString: urlString)
//    
//    var comment = Comment(user: user, urlString: urlString, text: "fdgdgdg", webPage: webPage)
//    
//    UserCommentsView(filter: .isLiked, user: user)
//        .modelContainer(for: [Comment.self, User.self])
//}
