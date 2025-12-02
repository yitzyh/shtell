//
//  ContentView.swift
//  WebPageTest
//
//  Created by Isaac Herskowitz on 6/26/24.
//

import SwiftUI
import SwiftData

struct WebPageRowView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    //    @State var isShowingComments = false
    //    @State var isSaved: Bool = false
    var webPage: WebPage
    
    @Binding var commentsUrlString: String?
    
    // NEW: Navigation properties for custom URL handling
    var onURLTap: ((String) -> Void)? = nil
    var shouldDismissOnURLTap: Bool = false
    
    @State private var isSaving: Bool = false
    @State private var isLiking: Bool = false
    @State private var likeAnimationTrigger: Bool = false
    
    // Cache-aware image data
    private var cachedImages: (favicon: Data?, thumbnail: Data?) {
        webPageViewModel.getCachedImages(for: webPage)
    }
    
    // HYBRID LIKE SYSTEM: Use ViewModel's local cache for instant like status
    // This eliminates race conditions and provides immediate visual feedback
    // Like status persists across app sessions and syncs with CloudKit in background
    private var isLiked: Bool {
        webPageViewModel.hasLiked(webPage)
    }
    
    // Simple count display
    private var likeCount: Int {
        webPageViewModel.getLikeCount(for: webPage)
    }
    
    private var isSaved: Bool {
        webPageViewModel.hasSaved(webPage)
    }

    
    init(webPage: WebPage,
         commentsUrlString: Binding<String?> = .constant(nil),
         onURLTap: ((String) -> Void)? = nil,
         shouldDismissOnURLTap: Bool = false) {
        self.webPage = webPage
        self._commentsUrlString = commentsUrlString
        self.onURLTap = onURLTap
        self.shouldDismissOnURLTap = shouldDismissOnURLTap
    }
    
    // Debug helpers for file sizes
    private var faviconSizeText: String {
        guard let data = webPage.faviconData else { return "Favicon: None" }
        let kb = Double(data.count) / 1024.0
        return String(format: "Favicon: %.1fKB", kb)
    }
    
    private var thumbnailSizeText: String {
        guard let data = webPage.thumbnailData else { return "Thumbnail: None" }
        let kb = Double(data.count) / 1024.0
        return String(format: "Thumbnail: %.1fKB", kb)
    }
    
    var body: some View {
        
        VStack(spacing: 0){
            
            // Debug file sizes (small text at top)
//            HStack {
//                Text(faviconSizeText)
//                    .font(.system(size: 10))
//                    .foregroundColor(.secondary)
//                Spacer()
//                Text(thumbnailSizeText)
//                    .font(.system(size: 10))
//                    .foregroundColor(.secondary)
//            }
//            .padding(.horizontal, 8)
//            .padding(.top, 2)
                        
            VStack{
                //HStack containing favicon and shortURL link
                HStack{
                    ZStack{
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color(uiColor: .systemGray4) : .white)
                            .frame(width: 25, height: 25)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(lineWidth: 1)
                            .frame(width: 25, height: 25)
                        
                        // Use cached data if available, otherwise fetch from URL
                        Group {
                            if cachedImages.favicon != nil {
                                FaviconView(faviconData: cachedImages.favicon)
                            } else {
                                FaviconView(urlString: webPage.urlString)
                            }
                        }
                        .frame(width: 15, height: 15)
                    }
                    .onTapGesture {
                        handleDomainTap()
                    }
                    
                    VStack{
                        Text(webPage.urlString.shortURL())
                            .font(.headline.bold())
                            .foregroundStyle(Color.blue)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .onTapGesture {
                                handleDomainTap()
                            }
                    }
                    
                    Text(webPage.dateCreated.timeAgoShort())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                    
                    

                    Spacer()
                }
                
                //HStack containing title text and thumbnail image
                HStack(alignment: .top){
                    Text(webPage.title)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            handleURLTap()
                        }
                                        
                    Spacer()
                    
                    ZStack(alignment: .topTrailing){
                        LazyThumbnailView(
                            thumbnailData: cachedImages.thumbnail,
                            faviconData: cachedImages.favicon,
                            urlString: webPage.urlString
                        )
                            .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary, lineWidth: 0.5))
                            .onTapGesture {
                                handleURLTap()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        //Thumbnail Saved
                        ZStack {
                            Image(systemName: "bookmark.fill")
                                .scaleEffect(x: 1.35, y: 0.95)
                                .foregroundColor(colorScheme == .dark ? Color(white: 0.07) : .white)

                            Image(systemName: "bookmark.fill")
                                .scaleEffect(x: 1.3, y: 0.9)
                                .foregroundColor(.orange)
                        }
                        .offset(x: -7, y: isSaved ? -4 : -16)  // Slides down from above
                        .opacity(isSaved ? 1.0 : 0.0)
                        .scaleEffect(isSaved ? 1.0 : 0.8)     // Slight scale for extra effect
                        .animation(.easeInOut(duration: 0.3), value: isSaved)
                    }
//                    .clipped()
                }
                .frame(maxWidth: .infinity)
                
                //HStack containing like/comment/save buttons + counts
                HStack{
                    HStack(alignment: .center) {
                        // Like Button
                        HStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .primary)
                                .opacity(isLiking ? 0.6 : 1.0)
                                .symbolEffect(.bounce, value: likeAnimationTrigger)
                            
                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.system(.footnote, weight: .light))
                                    .foregroundColor(isLiked ? .red : .primary)
                                    .lineLimit(1)
                                    .contentTransition(.numericText())
                                    .animation(.smooth(duration: 0.2), value: likeCount)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 28)
                        .frame(minWidth: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(/*isLiked ? .red :*/ .primary, lineWidth: 0.2)
                        )
                        .disabled(isLiking)
                        .onTapGesture {
                            guard authViewModel.signedInUser != nil else { return }
                            guard !isLiking else { return }
                            
                            // HYBRID LIKE SYSTEM: Instant UI response via local cache
                            // No need for @State management or optimistic updates
                            // ViewModel handles everything: local cache + CloudKit sync + persistence
                            
                            isLiking = true
                            // Only animate when liking (not unliking)
                            if !isLiked {
                                likeAnimationTrigger.toggle()
                            }
                            webPageViewModel.toggleLike(on: webPage, isCurrentlyLiked: isLiked) {
                                isLiking = false
                            }
                            
                            // UI updates automatically because isLiked computed property
                            // reads from webPageViewModel.likedWebPageURLs (which is @Published)
                        }
                        
                        // Comment Button and count
                        HStack {
                            Image(systemName: "bubble")
                                .foregroundColor(.primary)
                                .font(.system(.body, weight: .light))
                                .scaleEffect(0.95)
                                .offset(y: 0.5)
                            
                            if webPage.commentCount > 0 {
                                Text("\(webPage.commentCount)")
                                    .font(.system(.footnote, weight: .light))
                                    .lineLimit(1)
                                    .contentTransition(.numericText())
                                    .animation(.smooth(duration: 0.4), value: webPage.commentCount)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 28)
                        .frame(minWidth: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.primary, lineWidth: 0.2)
                        )
                        .onTapGesture {
                            commentsUrlString = webPage.urlString
                            // Don't set webPageViewModel.urlString here - let CommentView handle it
                        }
                        
                        // Save Button
                        HStack {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .foregroundColor(.primary)
                                .opacity(isSaving ? 0.6 : 1.0)
                                .font(.system(.body, weight: .light))
                                .scaleEffect(x: 1.3, y: 0.9)
                            
//                                .contentTransition(.symbolEffect(.replace)) // ✅ Uncomment this
//                                .animation(.easeInOut(duration: 0.2), value: isLiked) // ✅ Add this

                            if webPageViewModel.getSaveCount(for: webPage) > 0 {
                                Text("\(webPageViewModel.getSaveCount(for: webPage))")
                                    .font(.system(.footnote, weight: .light))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .contentTransition(.numericText())
                                    .animation(.smooth(duration: 0.2), value: webPageViewModel.getSaveCount(for: webPage))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 28)
                        .frame(minWidth: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.primary, lineWidth: 0.2)
                        )
                        .onTapGesture {
                            guard authViewModel.signedInUser != nil else { return }
                            guard !isSaving else { return }
                            
                            isSaving = true
                            webPageViewModel.toggleSave(on: webPage) {
                                isSaving = false
                            }
                            // Note: Save count updates are handled by ViewModel toggleSave method
                        }
                        .allowsHitTesting(!isSaving)
                        
                    }
                    
                    Spacer()
                }
                .font(.system(.title3, weight: .thin))
                .padding(.horizontal, 1)
            }
            .padding(20)
            Rectangle()
                .foregroundColor(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                .frame(height: 0.3)

        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .swipeActions() {
            Button{
                guard authViewModel.signedInUser != nil else { return }
                
                // Toggle Save
                withAnimation(.easeInOut(duration: 0.2)) {
                    webPageViewModel.toggleSave(on: webPage)
                }
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .environment(\.symbolVariants, .none)
            }
            .tint(isSaved ? .orange : .gray)
        }
        .onAppear {
            // Load and cache images if needed
            webPageViewModel.loadAndCacheImages(for: webPage)
        }
    }
    
    private func handleURLTap() {
        let urlString = webPage.urlString
        
        if let onURLTap = onURLTap {
            onURLTap(urlString)
        } else {
            webBrowser.urlString = urlString
            webBrowser.isUserInitiatedNavigation = true
            presentationMode.wrappedValue.dismiss()
        }
        
        if shouldDismissOnURLTap {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func handleDomainTap() {
        let domainURL = extractBaseDomain(from: webPage.urlString)
        
        if let onURLTap = onURLTap {
            onURLTap(domainURL)
        } else {
            webBrowser.urlString = domainURL
            webBrowser.isUserInitiatedNavigation = true
            presentationMode.wrappedValue.dismiss()
        }
        
        if shouldDismissOnURLTap {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func extractBaseDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        let scheme = url.scheme ?? "https"
        return "\(scheme)://\(host)"
    }
}

struct LazyThumbnailView: View {
    var thumbnailData: Data?
    var faviconData: Data?
    var urlString: String
    
    private var thumbnailWidth: CGFloat { 105 }
    private var thumbnailHeight: CGFloat { 79 }
    
    var body: some View {
        ZStack(alignment: .topTrailing){
            if let thumbnailData = thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                // First priority: Thumbnail image
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .clipped()
                    .cornerRadius(5)
            } else if let faviconData = faviconData, let faviconUIImage = UIImage(data: faviconData) {
                // Second priority: Favicon image
                VStack {
                    Image(uiImage: faviconUIImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(lineWidth: 0.2)
                }
            } else {
                // Third priority: Dynamic favicon URL (like BrowseForward)
                let domain = URL(string: urlString)?.host ?? urlString
                let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"

                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: thumbnailWidth, height: thumbnailHeight)

                    AsyncImage(url: URL(string: faviconURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                        case .failure, .empty:
                            VStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                Text(domain.prefix(1).uppercased())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .cornerRadius(5)
            }
        }
    }
}


