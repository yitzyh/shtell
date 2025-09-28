//
//  ParentCommentRowView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/20/24.
//

import SwiftUI

struct ParentWebPageRowView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    


    let webPage: WebPage
    var onURLTap: ((String) -> Void)? = nil
    

    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            // Favicon or placeholder icon
            if let data = webPage.faviconData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }

            // Title and URL
            VStack(alignment: .leading, spacing: 4) {
                Text(webPage.title)
                    .font(.system(.callout, weight: .semibold))
                    .lineLimit(2)
                Text(webPage.urlString)
                    .font(.system(.footnote, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            // Like button and count
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? .red : .secondary)
                    .font(.system(.callout, weight: .light))
                    .onTapGesture {
                        guard authViewModel.signedInUser != nil else { return }
                        isLiked.toggle()
//                        webPageViewModel.toggleLike(on: webPage)
                    }

                Text("\(webPage.likeCount + (isLiked ? 1 : 0))")
                    .font(.system(.footnote, weight: .light))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.4), value: webPage.likeCount + (isLiked ? 1 : 0))
            }

            // Save button and count
            HStack(spacing: 4) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isSaved ? .blue : .secondary)
                    .font(.system(.callout, weight: .light))
                    .onTapGesture {
                        guard authViewModel.signedInUser != nil else { return }
                        isSaved.toggle()
//                        webPageViewModel.toggleSave(on: webPage)
                    }

                Text("\(webPage.saveCount + (isSaved ? 1 : 0))")
                    .font(.system(.footnote, weight: .light))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.4), value: webPage.saveCount + (isSaved ? 1 : 0))
            }
        }
        .padding(.vertical, 8)
        .onAppear {
//            if let user = authViewModel.signedInUser {
                self.isLiked = webPageViewModel.hasLiked(webPage)
                self.isSaved = webPageViewModel.hasSaved(webPage)
//            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                guard authViewModel.signedInUser != nil else { return }
                isSaved.toggle()
                webPageViewModel.toggleSave(on: webPage)
            } label: {
                Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
            }
            .tint(.blue)

            Button {
                guard authViewModel.signedInUser != nil else { return }
                isLiked.toggle()
//                webPageViewModel.toggleLike(on: webPage)
            } label: {
                Label(isLiked ? "Unlike" : "Like", systemImage: isLiked ? "heart.fill" : "heart")
            }
            .tint(.red)
        }
    }

    
    // 🔥 FIXED: Simplified helper function with proper dismissal logic
    private func handleURLTap() {
        let urlString = webPage.urlString
        
        if let onURLTap = onURLTap {
            // Execute the custom URL handler (which should handle dismissal)
            onURLTap(urlString)
        } else {
            // Default behavior - navigate in browser and dismiss
            webBrowser.urlString = urlString
            webBrowser.isUserInitiatedNavigation = true
            presentationMode.wrappedValue.dismiss()
        }
    }
}

