////
////  ReplyView.swift
////  DumFlow
////
////  Created by Isaac Herskowitz on 5/12/24.
////
//
//import SwiftData
//import SwiftUI
//import Foundation
//
//
//struct InfiniteReplyView: View {
//    
//    
//    
//    @Environment(\.colorScheme) var colorScheme
////    @Environment(\.modelContext) var modelContext
//    @Environment(\.dismiss) var dismiss
//    @Environment(\.presentationMode) var presentationMode
////    @EnvironmentObject var viewModel: WebPageViewModel
////    @StateObject var viewModel: CommentViewModel
//    
//    @FocusState private var textFieldIsFocused: Bool
//    private var initialFocusState: Bool
//    
//    @State private var comment: Comment
//            
//    init(comment: Comment, /*modelContext: ModelContext,*/ textFieldIsFocused: Bool = false){
//        self.comment = comment
////        _viewModel = StateObject(wrappedValue: { CommentViewModel(comment: comment, user: userManager.user, modelContext: modelContext) }())
////        _viewModel = StateObject(wrappedValue: CommentViewModel(comment: comment, userManager: UserManager()))
//        self.initialFocusState = textFieldIsFocused
//
////        self._textFieldIsFocused = FocusState()
////        DispatchQueue.main.async {
////            self._textFieldIsFocused.wrappedValue = textFieldIsFocused
////        }
////        self._textFieldIsFocused.wrappedValue = textFieldIsFocused
//    }
//    
//    @State private var replyComment: Comment?
//    @State private var newReply = ""
////    @State var currentUser: User = User
//    @State private var showCommentView = false
//
//    func createNewLine(){
//        newReply = newReply + "\n"
//        textFieldIsFocused = true
//    }
//    
//    var body: some View {
////        NavigationStack{
//            ZStack{
//                //VStack containing comment and replies:
//                VStack{
//                    
//                    List{
//                        if let webPage = comment.webPage{
//                            ParentWebPageRowView(webPage: webPage)
//                                .padding(.top, 10)
//                                .padding(.horizontal, 12.5)
//                                .background(colorScheme == .dark ? .black : Color(uiColor: .systemGray5))
//                                .foregroundColor(colorScheme == .dark ? Color(uiColor: .systemGray4) : .white )
//                                .listRowInsets(EdgeInsets())
//                                .simultaneousGesture(TapGesture().onEnded{
//                                    presentationMode.wrappedValue.dismiss()
//                                    print("ParentWebPageRowView: presentationMode.wrappedValue.dismiss()")
//                                })
//                                .padding(.bottom, 3)
//                        }
//
////                        parentCommentsView(for: comment)
////                            .listRowInsets(EdgeInsets())
////                            .padding(.horizontal, 15)
//                        
//                        ZStack(alignment: .bottom){
//                            CommentRowView(/*modelContext: modelContext,*/ comment: comment, replyComment: $replyComment){
//                                presentationMode.wrappedValue.dismiss()
//                                print("CommentRowView: presentationMode.wrappedValue.dismiss()")
//                            }
//                            
//                                .padding(.horizontal, 15)
//                                .padding(.bottom, 10)
////                                .onTapGesture {
//////                                    dismiss()
////                                    presentationMode.wrappedValue.dismiss()
////                                    print("CommentRowView: presentationMode.wrappedValue.dismiss()")
////                                }
////                                .simultaneousGesture(TapGesture().onEnded{
////                                    presentationMode.wrappedValue.dismiss()
////                                    print("CommentRowView: presentationMode.wrappedValue.dismiss()")
////                                })
//                            Rectangle()
//                                .frame(height: 1)
//                                .frame(maxWidth: .infinity)
//                                .foregroundColor(.secondary)
//                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//                        }
//                        .listRowInsets(EdgeInsets())
//                                     
////                        ForEach(comment.childComments, id: \.id){ comment in
////                            CommentRowView(modelContext: modelContext, comment: comment, replyComment:  $replyComment)
////                        }
//
////                        if let replies = comment.childComments{
////                            ForEach(replies, id: \.id){ comment in
////                                CommentRowView(/*modelContext: modelContext,*/ comment: comment, replyComment:  $replyComment)
////                            }
////                        }
//                    }
//                    .listStyle(.plain)
//                    .listRowSpacing(0)
//                    .background(Color(UIColor.systemBackground))
//                }
//                .padding(.bottom, 30)
////                .navigationDestination(item: $replyComment){item in
////                    InfiniteReplyView(comment: item, modelContext: modelContext)
////                }
////                .onChange(of: replyComment){
////                    comment = replyComment ?? comment
////                }
//                
//                //Vstack containing the comment textfield and button
//                VStack{
//                    HStack(alignment: .bottom){
//                        TextField("New message", text: $newReply, axis: .vertical)
//                            .lineLimit(5)
//                            .focused($textFieldIsFocused)
//                            .submitLabel(.next)
//                            .onSubmit(createNewLine)
//                            .padding(.vertical, 10)
//                            .padding(.leading, 20)
//                            .textFieldStyle(.plain)
//                        if textFieldIsFocused == true{
//                            VStack{
//                                Button{
////                                    if !newReply.isEmpty{
////                                        viewModel.addReply(user: userManager.user, text: newReply)
////                                        newReply = ""
////                                        textFieldIsFocused = false
////                                    }
//                                } label: {
//                                    Image(systemName: "arrow.up.circle.fill")
//                                        .resizable()
//                                        .frame(width: 35, height: 35)
//                                }
//                                .font(.largeTitle)
//                                .padding(.bottom, 3)
//                                .padding(.trailing, 4)
//                            }
//                        }
//
//                    }
//                    .frame(width: UIScreen.main.bounds.size.width-30, alignment: .bottomTrailing)
//                    .background(
//                        RoundedRectangle(cornerRadius: 20.0, style: .circular)
//                            .stroke(.gray, lineWidth: 1)
//                            .fill(Color(UIColor.systemBackground))
//                            .frame(width: UIScreen.main.bounds.size.width-30)
//                    )
//                }
//                .frame(maxHeight: .infinity, alignment: .bottom)
//            }
////            .background(colorScheme == .dark ? .black : .white)
//            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
//            .font(.body)
//            .onAppear{
//                if initialFocusState {
//                    DispatchQueue.main.async {
//                        textFieldIsFocused = true
//                    }
//                }
//            }        
//    }
//    
////    @ViewBuilder
////    private func parentCommentsView(for comment: Comment) -> some View {
////        let parentComments = parentComments(for: comment)
////
////        ForEach(parentComments.reversed(), id: \.id) { parentComment in
////            CommentRowView(comment: parentComment, replyComment: $replyComment)
////            ParentCommentRowView(comment: parentComment, replyComment: $replyComment)
////        }
////    }
//    
//    
////    private func parentComments(for comment: Comment) -> [Comment]{
////        var currentComment: Comment? = comment
////        var parentComments: [Comment] = []
//
////        while let parentComment = currentComment?.parentComment{
////            parentComments.append(parentComment)
////            currentComment = parentComment
////        }
//        
////        return parentComments
////    }
//    
//}
//
//struct ParentCommentsView: View{
//    
//    var childComment: Comment
//    @State private var parentComments: [Comment] = []
//    
//    init(for childComment: Comment) {
//        self.childComment = childComment
//    }
//    
//    var body: some View{
//        ForEach(parentComments.reversed(), id: \.id) { parentComment in
//            ParentCommentRowView(comment: parentComment)
//        }
//        .onAppear{
////            parentComments = getParentComments(for: childComment)
//        }
//    }
////     func getParentComments(for comment: Comment) -> [Comment]{
////        var currentComment: Comment? = comment
////        var parentComments: [Comment] = []
//
////        while let parentComment = currentComment?.parentComment{
////            parentComments.append(parentComment)
////            currentComment = parentComment
////        }
//        
////        return parentComments
////    }
//}
//
//var raondomColors: [Color] = [.red, .yellow, .green, .blue, .orange, .purple, .cyan, .indigo, .mint, .teal]
////
////func createPreviewComment() -> Comment {
////    let user = User(name: "Yitzy", displayName: "shvitzmeister")
////    let urlString = "https://www.npr.org"
////    let text = "The former president has decided to dramatically alter his Republican National Convention (RNC) speech to focus on national unity."
////    let webPage = WebPage()
////    webPage.title = "Jews reported to actually be really cool and awesome, here why that is bad for Biden:"
////    
//////    let childComment = Comment(user: user, urlString: urlString, text: text, webPage: webPage)
//////    
////    let parentComment = Comment(user: user, urlString: urlString, text: text, webPage: webPage)
////            
////    return parentComment
////}
//
////#Preview {
////        
////    let comment = createPreviewComment()
////    
////    InfiniteReplyView(comment: comment)
////}
