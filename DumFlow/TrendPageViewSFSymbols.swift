import SwiftUI

struct TrendPageViewSFSymbols: View {
    let symbols = [
        ("globe", "Global discovery"),
        ("safari", "Web exploration"),
        ("newspaper", "News and articles"),
        ("sparkles", "Trending content"),
        ("chart.line.uptrend.xyaxis", "Trending up"),
        ("chart.bar", "Popular content"),
        ("eye", "What's being viewed"),
        ("binoculars", "Discover content"),
        ("magnifyingglass.circle", "Search and find"),
        ("lightbulb", "Bright ideas"),
        ("star.circle", "Featured content"),
        ("rocket", "Trending fast"),
        ("waveform.path", "Pulse of content"),
        ("antenna.radiowaves.left.and.right", "Broadcasting trends"),
        ("network", "Connected discovery"),
        ("square.grid.3x3", "Content grid"),
        ("rectangle.stack", "Stacked content"),
        ("list.bullet.rectangle", "Content lists"),
        ("doc.text.magnifyingglass", "Content search"),
        ("play.rectangle", "Media discovery")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(symbols, id: \.0) { symbol, description in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(.thinMaterial)
                                    .frame(width: 59, height: 59)
                                
                                Image(systemName: symbol)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(symbol)
                                .font(.caption2)
                                .fontWeight(.semibold)
                            
                            Text(description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: 100)
                    }
                }
                .padding()
            }
            .navigationTitle("Trend Page SF Symbols")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    TrendPageViewSFSymbols()
}