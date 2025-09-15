import SwiftUI
import CloudKit

struct WebPageCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let webPage: WebPage
    let cardWidth: CGFloat = 200
    let cardHeight: CGFloat = 280
    
    // Take up 40% of card height
    private var thumbnailHeight: CGFloat { cardHeight * 0.4 }
    
    @Binding var commentsUrlString: String?
    
    var onURLTap: ((String) -> Void)? = nil
    
    // Cache-aware image data
    private var cachedImages: (favicon: Data?, thumbnail: Data?) {
        webPageViewModel.getCachedImages(for: webPage)
    }
    
    init(webPage: WebPage,
         commentsUrlString: Binding<String?> = .constant(nil),
         onURLTap: ((String) -> Void)? = nil) {
        self.webPage = webPage
        self._commentsUrlString = commentsUrlString
        self.onURLTap = onURLTap
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top third - Thumbnail image (edge to edge, touching top)
            ZStack {
                if let thumbnailData = cachedImages.thumbnail, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: thumbnailHeight)
                        .clipped()
                } else if let faviconData = cachedImages.favicon, let faviconUIImage = UIImage(data: faviconData) {
                    VStack {
                        Image(uiImage: faviconUIImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                    }
                    .frame(width: cardWidth, height: thumbnailHeight)
                    .background(Color.gray.opacity(0.2))
                } else {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: cardWidth, height: thumbnailHeight)
                        .overlay {
                            Text(webPage.urlString.shortURL().prefix(1).uppercased())
                                .font(.title2)
                                .opacity(0.6)
                        }
                }
            }
            .onTapGesture {
                handleURLTap()
            }
            
            // Middle and bottom content
            VStack(spacing: 6) {
                // Middle - Favicon, domain, and date
                HStack(spacing: 6) {
                    // Mini favicon
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorScheme == .dark ? Color(uiColor: .systemGray4) : .white)
                            .frame(width: 16, height: 16)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(lineWidth: 0.5)
                            .frame(width: 16, height: 16)
                        
                        FaviconView(faviconData: cachedImages.favicon)
                            .frame(width: 10, height: 10)
                    }
                    
                    // Domain name
                    Text(webPage.urlString.shortURL())
                        .font(.caption)
                        .foregroundStyle(Color.blue)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Date
                    Text(webPage.dateCreated.timeAgoShort())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Title
                Text(webPage.title)
                    .font(.callout)
                    .fontWeight(.bold)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        handleURLTap()
                    }
                
                Spacer(minLength: 0)
                
                // Bottom - Mini comments button
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble")
                            .foregroundColor(.primary)
                            .font(.system(size: 12, weight: .light))
                        
                        if webPage.commentCount > 0 {
                            Text("\(webPage.commentCount)")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary, lineWidth: 0.3)
                    )
                    .onTapGesture {
                        commentsUrlString = webPage.urlString
                    }
                    
                    Spacer()
                }
            }
            .padding(10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(uiColor: .systemGray6) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            webPageViewModel.loadAndCacheImages(for: webPage)
        }
    }
    
    private func handleURLTap() {
        let urlString = webPage.urlString
        
        if let onURLTap = onURLTap {
            onURLTap(urlString)
        }
    }
}


#Preview {
    let authViewModel = AuthViewModel()
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    
    return WebPageCardView(
        webPage: WebPage(
            id: CKRecord.ID(recordName: "preview-id"),
            urlString: "https://example.com/article",
            title: "This is a sample article title that might be a bit longer",
            domain: "example.com",
            dateCreated: Date(),
            commentCount: 42,
            likeCount: 0,
            saveCount: 0,
            isReported: 0,
            reportCount: 0,
            faviconData: nil,
            thumbnailData: nil
        )
    )
    .environmentObject(webPageViewModel)
    .environmentObject(authViewModel)
}
