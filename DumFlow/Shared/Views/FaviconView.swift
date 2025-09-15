import SwiftUI
import Combine

struct FaviconView: View {
    // Support both direct data and URL fetching
    private let faviconData: Data?
    private let urlString: String?
    
    @State private var fetchedFaviconData: Data?
    @State private var cancellables = Set<AnyCancellable>()
    
    // Initializer for direct favicon data (existing usage)
    init(faviconData: Data?) {
        self.faviconData = faviconData
        self.urlString = nil
    }
    
    // Initializer for URL-based fetching (new usage)
    init(urlString: String) {
        self.faviconData = nil
        self.urlString = urlString
    }
    
    var body: some View {
        Group {
            // Use direct data if available, otherwise use fetched data
            if let data = faviconData ?? fetchedFaviconData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(4)
            } else if faviconData != nil {
                // Direct data case with no data - show skeleton
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .redacted(reason: .placeholder)
            } else {
                // URL case with no data yet - show globe
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .onAppear {
            if let urlString = urlString {
                loadFavicon(from: urlString)
            }
        }
        .onChange(of: urlString) { _, newURL in
            if let newURL = newURL {
                loadFavicon(from: newURL)
            }
        }
    }
    
    private func loadFavicon(from urlString: String) {
        cancellables.removeAll()
        fetchedFaviconData = nil
        
        FaviconFetcher.fetchFavicon(for: urlString)
            .receive(on: DispatchQueue.main)
            .sink { data in
                self.fetchedFaviconData = data
            }
            .store(in: &cancellables)
    }
}

#Preview {
    VStack(spacing: 20) {
        // URL-based usage
        FaviconView(urlString: "https://www.apple.com")
            .frame(width: 32, height: 32)
        
        FaviconView(urlString: "https://www.google.com")
            .frame(width: 24, height: 24)
        
        // Data-based usage (with nil data to show skeleton)
        FaviconView(faviconData: nil)
            .frame(width: 16, height: 16)
    }
    .padding()
}