import SwiftUI

struct ContentViewMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Binding var isShowingHistory: Bool
    @Binding var isShowingSafariView: Bool
    @Binding var isShowingBrowseForwardPreferences: Bool
    @Binding var isSafariReaderMode: Bool
    @Binding var isShowingSaved: Bool
    @State private var isShowingDynamoDBTest: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Top section - Square buttons
                    VStack(spacing: 20) {
                        HStack(spacing: 12) {
                            // Share
                            SquareMenuButton(
                                icon: "square.and.arrow.up",
                                title: "Share",
                                action: {
                                    dismiss()
                                    // Share functionality handled by ShareLink
                                }
                            )
                            
                            // History
                            SquareMenuButton(
                                icon: "clock",
                                title: "History",
                                action: {
                                    dismiss()
                                    isShowingHistory = true
                                }
                            )
                            
                            // Browse Forward
                            SquareMenuButton(
                                icon: "arrow.up",
                                title: "Browse Forward",
                                action: {
                                    dismiss()
                                    isShowingBrowseForwardPreferences = true
                                }
                            )
                        }
                        
                        HStack(spacing: 12) {
                            // DynamoDB Test
                            SquareMenuButton(
                                icon: "cylinder.split.1x2",
                                title: "DB Test",
                                action: {
                                    dismiss()
                                    isShowingDynamoDBTest = true
                                }
                            )
                            
                            Spacer()
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            // Reload
                            SquareMenuButton(
                                icon: "arrow.clockwise",
                                title: "Reload",
                                action: {
                                    dismiss()
                                    webBrowser.reload()
                                }
                            )
                            
                            // Safari
                            SquareMenuButton(
                                icon: "safari",
                                title: "Safari",
                                action: {
                                    dismiss()
                                    isSafariReaderMode = false
                                    isShowingSafariView = true
                                }
                            )
                            
                            // Saved
                            SquareMenuButton(
                                icon: "star.fill",
                                title: "Saved",
                                action: {
                                    dismiss()
                                    isShowingSaved = true
                                }
                            )
                        }
                }
                .padding(.top, 5)
                .padding(.horizontal, 20)
                
                Spacer()
                    .frame(height: 40)
                
                .padding(.horizontal, 20)
                
                Spacer()
                    .frame(minHeight: 50)
                }
            }
            .background(Color(.systemGray6))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDynamoDBTest) {
            DynamoDBTestView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct SquareMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.primary)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
            }
            .padding(.vertical, 8)
            .frame(width: 100, height: 90)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    init(icon: String, title: String, iconColor: Color = .primary, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    let browseForwardViewModel = BrowseForwardViewModel()
    
    return ContentViewMenuView(
        isShowingHistory: .constant(false),
        isShowingSafariView: .constant(false),
        isShowingBrowseForwardPreferences: .constant(false),
        isSafariReaderMode: .constant(false),
        isShowingSaved: .constant(false)
    )
    .environmentObject(authViewModel)
    .environmentObject(webBrowser)
    .environmentObject(webPageViewModel)
    .environmentObject(browseForwardViewModel)
}
