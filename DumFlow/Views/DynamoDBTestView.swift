import SwiftUI

struct DynamoDBTestView: View {
    @State private var articles: [AWSWebPageItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCategory: String = "all"
    
    private let categories = [
        ("all", "All Articles"),
        ("nasa", "NASA"),
        ("computermagazines", "Computer Magazines"),
        ("gutenberg", "Classic Books"),
        ("museum", "Museum Art"),
        ("historical", "Historical Documents"),
        ("radio", "Radio Shows")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                categoryPicker
                
                if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else if isLoading {
                    loadingView
                } else if articles.isEmpty {
                    emptyView
                } else {
                    articlesList
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("DynamoDB Test")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await fetchArticles()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await fetchArticles()
            }
        }
    }
    
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category Filter")
                .font(.headline)
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedCategory) {
                Task {
                    await fetchArticles()
                }
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Connection Error")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Retry") {
                Task {
                    await fetchArticles()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Fetching articles from DynamoDB...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Articles Found")
                .font(.headline)
            
            Text("No articles found for the selected category. Try a different filter or check your DynamoDB connection.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var articlesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📊 Total Count: \(articles.count) items")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                Text("Tag: \(selectedCategory)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            List(articles, id: \.id) { article in
                ArticleRowView(article: article)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private func fetchArticles() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let dynamoDBService = DynamoDBWebPageService.shared
            let fetchedArticles: [AWSWebPageItem]
            
            // Test the actual DynamoDB service with new CloudKit fields
            let limit = 10
            
            if selectedCategory == "all" {
                fetchedArticles = try await dynamoDBService.fetchPopular(limit: limit)
            } else {
                fetchedArticles = try await dynamoDBService.fetchByTags([selectedCategory], limit: limit)
            }
            
            // Debug print to verify CloudKit fields are working
            if let firstItem = fetchedArticles.first {
                print("🧪 TEST RESULTS:")
                print("   Title: \(firstItem.title)")
                print("   External upvotes: \(firstItem.upvotes)")
                print("   App likeCount: \(firstItem.likeCount ?? -1)") // Should be 0
                print("   App commentCount: \(firstItem.commentCount ?? -1)") // Should be 0
                print("   App saveCount: \(firstItem.saveCount ?? -1)") // Should be 0
                print("   Domain: \(firstItem.domain)")
            }
            
            await MainActor.run {
                self.articles = fetchedArticles
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.articles = []
            }
            print("❌ DynamoDB Test Error: \(error)")
        }
    }
    
}

struct ArticleRowView: View {
    let article: AWSWebPageItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: article.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(article.domain)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(article.source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // NEW: Display CloudKit fields for testing
                HStack {
                    Text("👍 \(article.upvotes)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("❤️ \(article.likeCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("💬 \(article.commentCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(article.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DynamoDBTestView()
}
