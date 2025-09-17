import SwiftUI
import CloudKit

// MARK: - Mock Data Structures
struct MockCard {
    let id: String
    let title: String
    let domain: String
    let thumbnailUrl: String
    let url: String
}

// MARK: - MockCardView with Liquid Glass Background
struct MockCardView: View {
    let card: MockCard
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail Image
            AsyncImage(url: URL(string: card.thumbnailUrl)) { image in
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
                Text(card.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                // Domain
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(card.domain)
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
                        Text("125")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "book")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("5 min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
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
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onTapGesture {
            onTap()
        }
    }
}

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
            LazyHStack(spacing: 16) {
                ForEach(mockCards, id: \.id) { card in
                    MockCardView(card: card) {
                        onURLTap?(card.url)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // Mock data for preview
    private var mockCards: [MockCard] {
        [
            MockCard(
                id: "1",
                title: "Scientists Discover New Exoplanet",
                domain: "space.com",
                thumbnailUrl: "https://via.placeholder.com/200x120/4A90E2/ffffff?text=Space",
                url: "https://space.com/exoplanet-discovery"
            ),
            MockCard(
                id: "2",
                title: "AI Breakthrough in Medical Diagnosis",
                domain: "techcrunch.com",
                thumbnailUrl: "https://via.placeholder.com/200x120/50C878/ffffff?text=AI",
                url: "https://techcrunch.com/ai-medical"
            ),
            MockCard(
                id: "3",
                title: "Climate Change Solutions",
                domain: "reuters.com",
                thumbnailUrl: "https://via.placeholder.com/200x120/FF6B35/ffffff?text=Climate",
                url: "https://reuters.com/climate-solutions"
            ),
            MockCard(
                id: "4",
                title: "New Architecture Trends",
                domain: "designboom.com",
                thumbnailUrl: "https://via.placeholder.com/200x120/9B59B6/ffffff?text=Design",
                url: "https://designboom.com/architecture"
            ),
            MockCard(
                id: "5",
                title: "Quantum Computing Progress",
                domain: "nature.com",
                thumbnailUrl: "https://via.placeholder.com/200x120/E67E22/ffffff?text=Quantum",
                url: "https://nature.com/quantum-computing"
            )
        ]
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
