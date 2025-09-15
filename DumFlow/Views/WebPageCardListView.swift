import SwiftUI
import CloudKit

// MARK: - BrowseForwardCardView
struct BrowseForwardCardView: View {
    let item: BrowseForwardItem
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail Image
            AsyncImage(url: URL(string: item.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 120)
                    .clipped()
                    .cornerRadius(8)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            // Content Info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                // Domain
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Engagement metrics
                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.orange)
//                        Text("\(formatNumber(item.upvotes))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
//                    if let readingTime = item.readingTimeMinutes {
//                        HStack(spacing: 2) {
//                            Image(systemName: "book")
//                                .font(.caption2)
//                                .foregroundColor(.blue)
//                            Text("\(readingTime) min")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                    }
                    
                    Spacer()
                }
            }
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            onTap(item.url)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

struct WebPageCardListView: View {
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @Binding var commentsUrlString: String?
    
    var onURLTap: ((String) -> Void)? = nil
    
    // Track which cards we've preloaded to avoid duplicate work
    @State private var preloadedCardIds: Set<String> = []
    // Loading state for better UX
    @State private var isLoading: Bool = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                if isLoading && browseForwardViewModel.browseQueue.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading fresh content...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
//                    LazyHStack(spacing: 16) {
//                        ForEach(Array(browseForwardViewModel.browseQueue.prefix(30)), id: \.url) { item in
//                            BrowseForwardCardView(
//                                item: item,
//                                onTap: { url in
//                                    onURLTap?(url)
//                                }
//                            )
//                            .id(item.url)
//                            .onAppear {
//                                preloadNextCards(from: item)
//                            }
//                        }
//                    }
//                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            // Initialize shared browse queue when view appears
            Task {
                isLoading = true
                await browseForwardViewModel.initializeBrowseQueue()
                isLoading = false
            }
        }
        .onChange(of: authViewModel.signedInUser?.userID) { _, _ in
            // Reinitialize queue when user changes
            Task {
                isLoading = true
                await browseForwardViewModel.initializeBrowseQueue()
                isLoading = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BrowseForwardPreferencesChanged"))) { _ in
            // Refresh queue when preferences change
            Task {
                print("📱 BrowseForward preferences changed, refreshing queue...")
                isLoading = true
                await browseForwardViewModel.refreshBrowseQueue()
                isLoading = false
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
