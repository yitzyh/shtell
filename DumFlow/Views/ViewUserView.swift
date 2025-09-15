import SwiftUI
import CloudKit

struct ViewUserView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let userID: String
    
    @StateObject private var userViewModel = UserViewModel()
    @State private var replyComment: Comment?
    @State private var commentsUrlString: String?
    @State private var isFollowing = false
    @State private var isLoadingFollow = false
    
    init(userID: String, authViewModel: AuthViewModel) {
        self.userID = userID
        self._followService = StateObject(wrappedValue: FollowService(authViewModel: authViewModel))
    }
    
    @StateObject private var followService: FollowService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // User Header
                HStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.blue)
                        .padding(.trailing, 10)
                    
                    VStack(alignment: .leading) {
                        Text(userViewModel.user?.displayName ?? "Loading...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(userViewModel.user?.username ?? "loading")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Follow Button
                    if let currentUser = authViewModel.signedInUser,
                       let viewedUser = userViewModel.user,
                       currentUser.userID != viewedUser.userID {
                        Button {
                            Task {
                                isLoadingFollow = true
                                do {
                                    let newFollowState = try await followService.toggleFollow(followedUserID: userID)
                                    await MainActor.run {
                                        isFollowing = newFollowState
                                    }
                                } catch {
                                    print("Error toggling follow: \(error)")
                                }
                                isLoadingFollow = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isLoadingFollow {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                                
                                Text(isFollowing ? "Unfollow" : "Follow")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isFollowing ? Color.red : Color.blue)
                            .cornerRadius(20)
                        }
                        .disabled(isLoadingFollow)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(colorScheme == .dark ? .black : .white)
                
                Divider()
                
                // Comments Section
                if userViewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading comments...")
                        Spacer()
                    }
                } else if webPageViewModel.contentState.viewedUserComments.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "bubble")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No comments yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("This user hasn't posted any comments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(webPageViewModel.contentState.viewedUserComments.sorted { $0.dateCreated > $1.dateCreated }, id: \.commentID) { comment in
                        WebPageCommentRowView(
                            comment: comment,
                            commentsUrlString: $commentsUrlString,
                            onDismiss: {
                                // Don't dismiss the whole view, just handle navigation
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(colorScheme == .dark ? .black : .white)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
        }
        .onAppear {
            userViewModel.fetchUser(by: userID)
            webPageViewModel.fetchViewedUserComments(userID: userID) {
                // Comments loading handled by webPageViewModel
            }
            
            // Check if current user is following this user
            Task {
                do {
                    let followingStatus = try await followService.isFollowing(followedUserID: userID)
                    await MainActor.run {
                        isFollowing = followingStatus
                    }
                } catch {
                    print("Error checking follow status: \(error)")
                }
            }
        }
        .sheet(isPresented: .constant(commentsUrlString != nil), onDismiss: {
            commentsUrlString = nil
        }) {
            if let urlString = commentsUrlString {
                NavigationStack {
                    CommentView(urlString: urlString)
                        .environmentObject(webPageViewModel)
                        .presentationDetents([.fraction(0.75), .large])
                        .presentationDragIndicator(.visible)
                        .presentationContentInteraction(.scrolls)
                        .presentationCornerRadius(20)
                }
            }
        }
    }
}
