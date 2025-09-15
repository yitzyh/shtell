//
//  CompactWePageRowView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/10/25.
//
import SwiftUI

enum CompactRowData {
    case webPage(WebPage)
    case temporary(TemporaryWebPageData)
    
    var title: String {
        switch self {
        case .webPage(let webPage):
            return webPage.title
        case .temporary(let data):
            return data.title
        }
    }
    
    var faviconData: Data? {
        switch self {
        case .webPage(let webPage):
            return webPage.faviconData
        case .temporary(let data):
            return data.faviconData
        }
    }
    
    var urlString: String {
        switch self {
        case .webPage(let webPage):
            return webPage.urlString
        case .temporary(let data):
            return data.urlString
        }
    }
    
    var webPage: WebPage? {
        switch self {
        case .webPage(let webPage):
            return webPage
        case .temporary:
            return nil
        }
    }
}

struct CompactWePageRowView: View{
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let data: CompactRowData
    @State private var isSaving: Bool = false
    @State private var isLiking: Bool = false
    
    private var webPage: WebPage? {
        data.webPage
    }
    
    // Computed properties like CommentRowView
    private var isLiked: Bool {
        guard let webPage = webPage else { return false }
        return webPageViewModel.hasLiked(webPage)
    }
    
    private var isSaved: Bool {
        guard let webPage = webPage else { return false }
        return webPageViewModel.hasSaved(webPage)
    }
    
    var body: some View{
        
        // Simple like system - use computed properties

        HStack{
            HStack{
                //favicon
                ZStack{
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color(uiColor: .systemGray4) : .white)
                        .frame(width: 25, height: 25)

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(lineWidth: 1)
                        .frame(width: 25, height: 25)

                    if let faviconData = data.faviconData {
                        FaviconView(faviconData: faviconData)
                            .frame(width: 15, height: 15)
                    } else {
                        // Shimmer placeholder for favicon
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 15, height: 15)
                            .redacted(reason: .placeholder)
                    }
                }
                
                if data.title.isEmpty {
                    // Shimmer placeholder for title
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 180, height: 14)
                        .redacted(reason: .placeholder)
                } else {
                    Text(data.title)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .onTapGesture {
                webBrowser.urlString = data.urlString
                webBrowser.isUserInitiatedNavigation = true
                self.presentationMode.wrappedValue.dismiss()
            }
            
            Spacer()
            
            //like/reply/save buttons
            HStack(spacing: 8){
                if let webPage = webPage {
                    // Active buttons for WebPage
                    // Likes
                Button {
                    guard !isLiking else { 
                        print("🚫 COMPACT: Blocked tap - already liking")
                        return 
                    }
                    guard authViewModel.signedInUser != nil else { return }
                    
                    print("🔥 COMPACT: Tap! isLiked=\(isLiked), count=\(webPageViewModel.getLikeCount(for: webPage))")
                    isLiking = true
                    webPageViewModel.toggleLike(on: webPage, isCurrentlyLiked: isLiked) {
                        print("🔥 COMPACT: Completion! new count=\(webPageViewModel.getLikeCount(for: webPage))")
                        isLiking = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .primary)
                            .opacity(isLiking ? 0.6 : 1.0)
                            .font(.caption)
                            .frame(width: 12)
                        
                        Text(webPageViewModel.getLikeCount(for: webPage) > 0 ? "\(webPageViewModel.getLikeCount(for: webPage))" : "")
                            .font(.caption2)
                            .frame(minWidth: 12, alignment: .leading)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.2), value: webPageViewModel.getLikeCount(for: webPage))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLiking)
                
                // Comments
                HStack(spacing: 6) {
                    Image(systemName: "bubble")
                        .font(.caption)
                        .frame(width: 12)
                    
                    Text(webPage.commentCount > 0 ? "\(webPage.commentCount)" : "")
                        .font(.caption2)
                        .frame(minWidth: 12, alignment: .leading)
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.4), value: webPage.commentCount)
                }

                // Save
                Button {
                    guard !isSaving else { return }
                    guard authViewModel.signedInUser != nil else { return }
                    
                    isSaving = true
                    webPageViewModel.toggleSave(on: webPage) {
                        isSaving = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "star.fill" : "star")
                            .scaleEffect(x: 1.3, y: 0.9)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .opacity(isSaving ? 0.6 : 1.0)
                            .frame(width: 12)
                        
                        Text(webPageViewModel.getSaveCount(for: webPage) > 0 ? "\(webPageViewModel.getSaveCount(for: webPage))" : "")
                            .font(.caption2)
                            .frame(minWidth: 5, alignment: .leading)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.2), value: webPageViewModel.getSaveCount(for: webPage))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                } else {
                    // Disabled buttons for temporary data
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(width: 12)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "bubble")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(width: 12)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "star")
                            .scaleEffect(x: 1.3, y: 0.9)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                    }
                }
            }
            .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }
}

