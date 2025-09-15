import SwiftUI

struct SavedWebPagesView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var webPageViewModel: WebPageViewModel
    @EnvironmentObject private var webBrowser: WebBrowser
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            Group {
                if webPageViewModel.contentState.savedWebPages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Saved Pages")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Pages you save will appear here")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(webPageViewModel.contentState.savedWebPages.sorted { webPage1, webPage2 in
                            let date1 = webPageViewModel.contentState.webPageSaveDates[webPage1.urlString] ?? Date.distantPast
                            let date2 = webPageViewModel.contentState.webPageSaveDates[webPage2.urlString] ?? Date.distantPast
                            return date1 > date2
                        }, id: \.id.recordName) { webPage in
                            WebPageRowView(
                                webPage: webPage,
                                commentsUrlString: .constant(nil),
                                onURLTap: { urlString in
                                    webBrowser.urlString = urlString
                                    webBrowser.isUserInitiatedNavigation = true
                                    dismiss()
                                },
                                shouldDismissOnURLTap: false
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}