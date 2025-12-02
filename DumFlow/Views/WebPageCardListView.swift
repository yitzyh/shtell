import SwiftUI
import CloudKit

// MARK: - BrowseForwardCardView
struct BrowseForwardCardView: View {
    let item: BrowseForwardItem
    let pageBackgroundIsDark: Bool
    let onTap: (String) -> Void

    // Generate thumbnail from URL for known sources
    private var resolvedThumbnailUrl: String {
        let url = item.url.lowercased()

        // Check if thumbnail is a generic favicon (ignore these)
        let isGenericFavicon = (item.thumbnailUrl?.contains("favicon") ?? false) ||
                              (item.thumbnailUrl?.contains("redditstatic.com") ?? false) ||
                              (item.thumbnailUrl?.contains("google.com/s2/favicons") ?? false)

        // YouTube - ALWAYS try to extract video thumbnail
        if url.contains("youtube.com") || url.contains("youtu.be") {
            if let videoId = extractYouTubeVideoId(from: item.url) {
                // Use sddefault (640×480) for better quality on Retina displays
                return "https://img.youtube.com/vi/\(videoId)/sddefault.jpg"
            }
        }

        // Poki games - ALWAYS try to extract game image
        if url.contains("poki.com") {
            if let slug = extractPokiSlug(from: item.url) {
                // Increase quality to 92 and size to 800×800 for sharper images
                return "https://img.poki.com/cdn-cgi/image/quality=92,width=800,height=800,fit=cover,f=auto/\(slug)-icon.png"
            }
        }

        // Imgur - extract image ID
        if url.contains("imgur.com") {
            if let imageId = extractImgurId(from: item.url) {
                // Use huge size (1024px) for Retina displays
                return "https://i.imgur.com/\(imageId)h.jpg"
            }
        }

        // If we have a real thumbnail (not favicon), use it
        if let thumbnailUrl = item.thumbnailUrl,
           !thumbnailUrl.isEmpty &&
           !thumbnailUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
           !isGenericFavicon {
            return thumbnailUrl
        }

        return "" // No thumbnail available
    }

    private func extractYouTubeVideoId(from urlString: String) -> String? {
        // Handle youtube.com/watch?v=VIDEO_ID
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoId
        }

        // Handle youtu.be/VIDEO_ID
        if urlString.contains("youtu.be/") {
            let parts = urlString.components(separatedBy: "youtu.be/")
            if parts.count > 1 {
                let videoId = parts[1].components(separatedBy: "?")[0].components(separatedBy: "&")[0]
                return videoId
            }
        }

        return nil
    }

    private func extractPokiSlug(from urlString: String) -> String? {
        // Extract from poki.com/en/g/game-slug
        let pattern = "/g/([^/?]+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
           let range = Range(match.range(at: 1), in: urlString) {
            return String(urlString[range])
        }
        return nil
    }

    private func extractImgurId(from urlString: String) -> String? {
        // Handle imgur.com/imageId or i.imgur.com/imageId.ext
        let pattern = "imgur\\.com/([a-zA-Z0-9]+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
           let range = Range(match.range(at: 1), in: urlString) {
            return String(urlString[range])
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with full liquid glass overlay
            ZStack {
                // Check if we have a resolved thumbnail URL
                if resolvedThumbnailUrl.isEmpty {
                    // No thumbnail URL - show favicon immediately
                    let faviconURL = "https://www.google.com/s2/favicons?domain=\(item.domain)&sz=128"
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))

                        // Domain favicon
                        AsyncImage(url: URL(string: faviconURL)) { faviconPhase in
                            switch faviconPhase {
                            case .empty:
                                ProgressView()
                                    .tint(.secondary)
                            case .success(let favicon):
                                favicon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                            case .failure:
                                VStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                    Text(item.domain)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            @unknown default:
                                VStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                    Text(item.domain)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } else {
                    // Has thumbnail URL - try to load it
                    AsyncImage(url: URL(string: resolvedThumbnailUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    ProgressView()
                                        .tint(.secondary)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 150)
                                .clipped()
                        case .failure:
                            // Thumbnail failed - fallback to favicon
                            let faviconURL = "https://www.google.com/s2/favicons?domain=\(item.domain)&sz=128"
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))

                                AsyncImage(url: URL(string: faviconURL)) { faviconPhase in
                                    switch faviconPhase {
                                    case .empty:
                                        ProgressView()
                                            .tint(.secondary)
                                    case .success(let favicon):
                                        favicon
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 48, height: 48)
                                    case .failure:
                                        VStack(spacing: 4) {
                                            Image(systemName: "globe")
                                                .foregroundColor(.gray)
                                                .font(.title2)
                                            Text(item.domain)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    @unknown default:
                                        VStack(spacing: 4) {
                                            Image(systemName: "globe")
                                                .foregroundColor(.gray)
                                                .font(.title2)
                                            Text(item.domain)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Gradient overlay at bottom for text readability
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .black.opacity(0.3),
                        .black.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Subtle glass effect on top
                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.clear, in: Rectangle())
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.2)
                }
            }
            .frame(width: 200, height: 150)
            .cornerRadius(8)
            .overlay(alignment: .bottomLeading) {
                // Content Info - positioned over gradient
                VStack(alignment: .leading, spacing: 4) {
                    // Title - white with strong shadow for readability
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                    // Domain & Category
                    HStack {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                        Text(item.domain)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)

                        Spacer()

                        // Category tag - with backdrop
                        Text(item.category ?? item.bfCategory ?? "uncategorized")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Group {
                                    if #available(iOS 26.0, *) {
                                        Capsule()
                                            .fill(.clear)
                                            .glassEffect(.clear, in: Capsule())
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                            )
                    }
                    .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 200)
        .background(
            ZStack {
                // Base contrast layer for text readability (more transparent)
                RoundedRectangle(cornerRadius: 12)
                    .fill(pageBackgroundIsDark ? .black.opacity(0.3) : .white.opacity(0.4))

                // Glass effect on top
                Group {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.clear)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
        )
        .onTapGesture {
            onTap(item.url)
        }
    }
}

// MARK: - LoadingCardView
struct LoadingCardView: View {
    var body: some View {
        ZStack {
            // Background with glass effect
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)

            // Centered progress view on 4:3 canvas
            ProgressView()
                .tint(.secondary)
                .scaleEffect(1.2)
        }
        .frame(width: 200, height: 158)  // Match card: 150 + 8 (VStack spacing)
    }
}

struct WebPageCardListView: View {
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @Binding var commentsUrlString: String?

    var onURLTap: ((String) -> Void)? = nil
    var items: [BrowseForwardItem]? = nil // Optional items parameter for search results

    // Track which cards we've preloaded to avoid duplicate work
    @State private var preloadedCardIds: Set<String> = []
    // Loading state for better UX
    @State private var isLoading: Bool = false

    // Always use the unified displayedItems from ViewModel (single source of truth)
    private var displayItems: [BrowseForwardItem] {
        items ?? browseForwardViewModel.displayedItems
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if displayItems.isEmpty {
                // Show empty state message
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                    Text("No content available")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Select categories above to see content")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 158)
                .padding(.horizontal, 20)
            } else {
                LazyHStack(spacing: 16) {
                    // Show ALL items in queue, LazyHStack only loads visible ones
                    ForEach(displayItems) { item in
                        BrowseForwardCardView(
                            item: item,
                            pageBackgroundIsDark: webBrowser.pageBackgroundIsDark,
                            onTap: onURLTap ?? { _ in }
                        )
                        .onAppear {
                            print("🎴 Displaying card: \(item.title) | Domain: \(item.domain) | Category: \(item.category ?? "none")")
                            preloadNextCards(from: item)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func preloadNextCards(from currentItem: BrowseForwardItem) {
        let cardId = currentItem.url
        guard !preloadedCardIds.contains(cardId) else { return }
        preloadedCardIds.insert(cardId)

        guard let currentIndex = displayItems.firstIndex(where: { $0.url == currentItem.url }) else { return }

        // Loading more content is now handled automatically in getNextSlideURL()
        // when running low on items (maintains filters)

        print("🎴 Preloading cards around index \(currentIndex)")
        // AsyncImage handles thumbnail preloading automatically
    }
}
