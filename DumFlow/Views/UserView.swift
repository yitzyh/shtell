import SwiftData
import SwiftUI
import Foundation

struct UserView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel

                
    @State var comments: [Comment] = []
    @State private var allUsers: [User] = []

    var body: some View {
        
        VStack(spacing: 0){
            HStack{
                Image(systemName: "\(String(describing: authViewModel.signedInUser?.username.first?.lowercased())).circle.fill")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .padding(.trailing, 5)
                    .padding(.leading, 20)
                VStack(alignment: .leading){
                    Text(authViewModel.signedInUser?.displayName ?? "displayName")
                        .font(.headline)
                    Text("@\(authViewModel.signedInUser?.username ?? "username")")
                        .font(.caption)
                }
                
                Spacer()
                
            }
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? .black : .white)
                                    
            Rectangle()
                .frame(maxWidth: .infinity)
                .frame(height: 0.3)
                .foregroundColor(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
            
//            TabView{
//                Group{
//                    UserCommentsView(filter: .all, user: authViewModel.signedInUser)
//                        .tabItem {
//                            Label("all", systemImage: "circle")
//                        }
//                    UserCommentsView(filter: .isUser, user: authViewModel.signedInUser)
//                        .tabItem {
//                            Label("Comments", systemImage: "bubble")
//                        }
//                    UserCommentsView(filter: .isLiked, user: authViewModel.signedInUser)
//                        .tabItem {
//                            Label("Liked", systemImage: "heart")
//                        }
//                    UserCommentsView(filter: .isSaved, user: authViewModel.signedInUser)
//                        .tabItem {
//                            Label("Saved", systemImage: "bookmark")
//                        }
//                }
//                .toolbarBackground(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5), for: .tabBar)
//                .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
//            }
            
        }
//        .onAppear{
//            User.insertTestUsersIfNeeded(context: modelContext)
//            allUsers = userManager.fetchAllUsers(/*from: modelContext*/)
//        }
        .background(colorScheme == .dark ? .black : .white)
        .navigationTitle(authViewModel.signedInUser?.username.lowercased() ?? "authViewModel.signedInUser")

    }
}

// MARK: - Preview

#Preview {    
    UserView()
}
