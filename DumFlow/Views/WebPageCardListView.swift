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
        let isGenericFavicon = item.thumbnailUrl.contains("favicon") ||
                              item.thumbnailUrl.contains("redditstatic.com") ||
                              item.thumbnailUrl.contains("google.com/s2/favicons")

        // YouTube - ALWAYS try to extract video thumbnail
        if url.contains("youtube.com") || url.contains("youtu.be") {
            print("📺 Detected YouTube URL: \(item.url)")
            if let videoId = extractYouTubeVideoId(from: item.url) {
                let thumbnailUrl = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
                print("✅ Generated YouTube thumbnail: \(thumbnailUrl)")
                return thumbnailUrl
            } else {
                print("❌ Failed to extract YouTube video ID")
            }
        }

        // Poki games - ALWAYS try to extract game image
        if url.contains("poki.com") {
            print("🎮 Detected Poki URL: \(item.url)")
            if let slug = extractPokiSlug(from: item.url) {
                let thumbnailUrl = "https://img.poki.com/cdn-cgi/image/quality=78,width=600,height=600,fit=cover,f=auto/\(slug)-icon.png"
                print("✅ Generated Poki thumbnail: \(thumbnailUrl)")
                return thumbnailUrl
            } else {
                print("❌ Failed to extract Poki slug")
            }
        }

        // Imgur - extract image ID
        if url.contains("imgur.com") {
            print("🖼️ Detected Imgur URL: \(item.url)")
            if let imageId = extractImgurId(from: item.url) {
                let thumbnailUrl = "https://i.imgur.com/\(imageId)l.jpg"
                print("✅ Generated Imgur thumbnail: \(thumbnailUrl)")
                return thumbnailUrl
            }
        }

        // If we have a real thumbnail (not favicon), use it
        if !item.thumbnailUrl.isEmpty &&
           !item.thumbnailUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
           !isGenericFavicon {
            print("🖼️ Using existing thumbnail: \(item.thumbnailUrl)")
            return item.thumbnailUrl
        }

        print("⚠️ No thumbnail available for: \(item.domain)")
        return "" // No thumbnail available
    }

    private func extractYouTubeVideoId(from urlString: String) -> String? {
        print("🔎 Extracting video ID from: \(urlString)")

        // Handle youtube.com/watch?v=VIDEO_ID
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
            print("✅ Extracted video ID (youtube.com): \(videoId)")
            return videoId
        }

        // Handle youtu.be/VIDEO_ID
        if urlString.contains("youtu.be/") {
            let parts = urlString.components(separatedBy: "youtu.be/")
            if parts.count > 1 {
                let videoId = parts[1].components(separatedBy: "?")[0].components(separatedBy: "&")[0]
                print("✅ Extracted video ID (youtu.be): \(videoId)")
                return videoId
            }
        }

        print("❌ Could not extract video ID")
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
            let imageId = String(urlString[range])
            print("✅ Extracted Imgur ID: \(imageId)")
            return imageId
        }
        print("❌ Failed to extract Imgur ID")
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
                    let _ = print("🌐 Loading favicon for \(item.domain): \(faviconURL)")
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))

                        // Domain favicon
                        AsyncImage(url: URL(string: faviconURL)) { faviconPhase in
                            switch faviconPhase {
                            case .empty:
                                let _ = print("⏳ Favicon loading for \(item.domain)")
                                ProgressView()
                                    .tint(.secondary)
                            case .success(let favicon):
                                let _ = print("✅ Favicon loaded for \(item.domain)")
                                favicon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                            case .failure(let error):
                                let _ = print("❌ Favicon failed for \(item.domain): \(error)")
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
                                let _ = print("⚠️ Unknown favicon state for \(item.domain)")
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
                                .frame(width: 200, height: 120)
                                .clipped()
                        case .failure(let error):
                            // Thumbnail failed - fallback to favicon
                            let _ = print("❌ Image load failed for \(resolvedThumbnailUrl): \(error)")
                            let faviconURL = "https://www.google.com/s2/favicons?domain=\(item.domain)&sz=128"
                            let _ = print("🌐 Fallback to favicon for \(item.domain): \(faviconURL)")
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))

                                AsyncImage(url: URL(string: faviconURL)) { faviconPhase in
                                    switch faviconPhase {
                                    case .empty:
                                        let _ = print("⏳ Fallback favicon loading for \(item.domain)")
                                        ProgressView()
                                            .tint(.secondary)
                                    case .success(let favicon):
                                        let _ = print("✅ Fallback favicon loaded for \(item.domain)")
                                        favicon
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 48, height: 48)
                                    case .failure(let error):
                                        let _ = print("❌ Fallback favicon failed for \(item.domain): \(error)")
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
                                        let _ = print("⚠️ Unknown fallback favicon state for \(item.domain)")
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

                // Liquid glass overlay on thumbnail
                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.clear, in: Rectangle())
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                }
            }
            .frame(width: 200, height: 120)
            .cornerRadius(8)

            // Content Info
            VStack(alignment: .leading, spacing: 4) {
                // Title - adaptive color
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(pageBackgroundIsDark ? .white : .black)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)

                // Domain & Category
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(pageBackgroundIsDark ? .white.opacity(0.7) : .black.opacity(0.7))
                    Text(item.domain)
                        .font(.caption)
                        .foregroundColor(pageBackgroundIsDark ? .white.opacity(0.7) : .black.opacity(0.7))
                        .lineLimit(1)

                    Spacer()

                    // Category tag - liquid glass pill
                    Text(item.category)
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
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
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
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 120)
                .cornerRadius(8)
                .overlay(
                    ProgressView()
                        .tint(.secondary)
                )

            // Content placeholder
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                    .cornerRadius(4)

                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 12)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

struct WebPageCardListView: View {
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @Binding var commentsUrlString: String?

    var onURLTap: ((String) -> Void)? = nil

    // Track which cards we've preloaded to avoid duplicate work
    @State private var preloadedCardIds: Set<String> = []
    // Loading state for better UX
    @State private var isLoading: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if browseForwardViewModel.browseQueue.isEmpty {
                // Show placeholder while loading
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        LoadingCardView()
                    }
                }
                .padding(.horizontal, 20)
            } else {
                LazyHStack(spacing: 16) {
                    // Show ALL items in queue, LazyHStack only loads visible ones
                    ForEach(browseForwardViewModel.browseQueue) { item in
                        BrowseForwardCardView(
                            item: item,
                            pageBackgroundIsDark: webBrowser.pageBackgroundIsDark,
                            onTap: onURLTap ?? { _ in }
                        )
                        .onAppear {
                            print("🎴 Displaying card: \(item.title) | Domain: \(item.domain) | Category: \(item.category)")
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
        
        guard let currentIndex = browseForwardViewModel.browseQueue.firstIndex(where: { $0.url == currentItem.url }) else { return }
        
        // If user is getting close to end, trigger loading more content
        if currentIndex >= browseForwardViewModel.browseQueue.count - 10 {
            Task {
                await browseForwardViewModel.loadMoreToQueue()
            }
        }
        
        print("🎴 Preloading cards around index \(currentIndex)")
        // AsyncImage handles thumbnail preloading automatically
    }
}
