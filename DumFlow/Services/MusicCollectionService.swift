import Foundation

// MARK: - Music Collection Service
class MusicCollectionService {
    static let shared = MusicCollectionService()
    
    private init() {}
    
    // MARK: - Genre Configuration
    private let musicGenres: [(name: String, searchTerms: [String])] = [
        ("Pop", ["pop music", "top 40", "mainstream pop", "chart hits"]),
        ("Hip-Hop", ["hip hop", "rap music", "hip hop official", "rap hits"]),
        ("Rock", ["rock music", "rock official", "classic rock", "alternative rock"]),
        ("R&B", ["r&b music", "soul music", "rnb official", "rhythm and blues"]),
        ("Electronic", ["electronic music", "EDM", "house music", "techno"]),
        ("Country", ["country music", "country official", "country hits", "nashville"]),
        ("Latin", ["latin music", "reggaeton", "latin pop", "spanish music"]),
        ("World", ["world music", "traditional music", "folk music", "cultural music"]),
        ("Indie", ["indie music", "alternative music", "independent music", "indie rock"]),
        ("Jazz", ["jazz music", "jazz official", "smooth jazz", "classic jazz"]),
        ("Blues", ["blues music", "blues official", "chicago blues", "delta blues"]),
        ("Ambient", ["ambient music", "chill music", "relaxing music", "meditation music"])
    ]
    
    // MARK: - Upload All Genres
    func uploadAllMusicGenres() async {
        print("🎵 Starting upload of all music genres...")
        print("📊 Target: \(musicGenres.count) genres × 2,000 videos = \(musicGenres.count * 2000) total videos")
        print("")
        
        var totalUploaded = 0
        
        for (index, genre) in musicGenres.enumerated() {
            print("🎯 Processing genre \(index + 1)/\(musicGenres.count): \(genre.name)")
            
            do {
                let videos = try await collectGenreVideos(genre: genre)
                let uploaded = try await InternetArchiveAWSDynamoService.shared.uploadBatch(videos)
                
                totalUploaded += uploaded
                print("✅ \(genre.name): \(uploaded) videos uploaded")
                print("📈 Progress: \(totalUploaded) total videos uploaded")
                print("")
                
                // Delay between genres to respect API limits
                if index < musicGenres.count - 1 {
                    print("⏳ Waiting 30 seconds before next genre...")
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                }
                
            } catch {
                print("❌ Failed to upload \(genre.name): \(error)")
                print("⏭️  Continuing with next genre...")
                print("")
            }
        }
        
        print("🎉 MUSIC COLLECTION COMPLETE!")
        print("📊 Final Results:")
        print("   • Total videos uploaded: \(totalUploaded)")
        print("   • Genres completed: \(musicGenres.count)")
        print("   • Database now contains: ~\(30000 + totalUploaded) total items")
        print("   • Ready for BrowseForward integration! 🚀")
    }
    
    // MARK: - Upload Single Genre
    func uploadSingleGenre(_ genreName: String) async throws -> Int {
        guard let genre = musicGenres.first(where: { $0.name.lowercased() == genreName.lowercased() }) else {
            throw NSError(domain: "MusicCollection", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Genre '\(genreName)' not found. Available genres: \(musicGenres.map { $0.name }.joined(separator: ", "))"
            ])
        }
        
        print("🎵 Uploading \(genre.name) music collection...")
        
        let videos = try await collectGenreVideos(genre: genre)
        let uploaded = try await InternetArchiveAWSDynamoService.shared.uploadBatch(videos)
        
        print("✅ \(genre.name) upload complete: \(uploaded) videos")
        return uploaded
    }
    
    // MARK: - Collect Genre Videos
    private func collectGenreVideos(genre: (name: String, searchTerms: [String])) async throws -> [AWSWebPageItem] {
        var allVideos: [AWSWebPageItem] = []
        let targetPerTerm = 2000 / genre.searchTerms.count // Distribute across search terms
        
        for (termIndex, searchTerm) in genre.searchTerms.enumerated() {
            print("🔍 Searching: '\(searchTerm)' (term \(termIndex + 1)/\(genre.searchTerms.count))")
            
            do {
                let videos = try await YouTubeAPIService.shared.collectGenreMusicVideos(
                    genre: searchTerm,
                    targetCount: targetPerTerm
                )
                
                allVideos.append(contentsOf: videos)
                print("📥 Collected \(videos.count) videos for '\(searchTerm)'")
                
                // Short delay between search terms
                if termIndex < genre.searchTerms.count - 1 {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
                
            } catch {
                print("⚠️  Failed to collect videos for '\(searchTerm)': \(error)")
                // Continue with other search terms
            }
        }
        
        // Ensure we don't exceed target count and remove duplicates
        let uniqueVideos = removeDuplicateVideos(allVideos)
        let finalVideos = Array(uniqueVideos.prefix(2000))
        
        print("🎯 Final collection for \(genre.name): \(finalVideos.count) unique videos")
        return finalVideos
    }
    
    // MARK: - Remove Duplicate Videos
    private func removeDuplicateVideos(_ videos: [AWSWebPageItem]) -> [AWSWebPageItem] {
        var seenUrls = Set<String>()
        return videos.filter { video in
            if seenUrls.contains(video.url) {
                return false
            } else {
                seenUrls.insert(video.url)
                return true
            }
        }
    }
    
    // MARK: - Test Single Genre
    func testGenreUpload(_ genreName: String) async {
        print("🧪 Testing \(genreName) music upload...")
        
        do {
            let uploaded = try await uploadSingleGenre(genreName)
            print("✅ Test successful: \(uploaded) \(genreName) videos uploaded")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // MARK: - Get Available Genres
    func getAvailableGenres() -> [String] {
        return musicGenres.map { $0.name }
    }
    
    // MARK: - Quick Demo Upload (100 videos per genre)
    func uploadMusicDemo() async {
        print("🎵 Starting DEMO upload - 100 videos per genre...")
        print("📊 Target: \(musicGenres.count) genres × 100 videos = \(musicGenres.count * 100) total videos")
        print("⏱️  This should take about 10-15 minutes")
        print("")
        
        var totalUploaded = 0
        
        for (index, genre) in musicGenres.enumerated() {
            print("🎯 Demo genre \(index + 1)/\(musicGenres.count): \(genre.name)")
            
            do {
                // Use first search term only for demo
                let videos = try await YouTubeAPIService.shared.collectGenreMusicVideos(
                    genre: genre.searchTerms[0],
                    targetCount: 100
                )
                
                let uploaded = try await InternetArchiveAWSDynamoService.shared.uploadBatch(videos)
                totalUploaded += uploaded
                
                print("✅ \(genre.name): \(uploaded) videos uploaded")
                print("📈 Demo progress: \(totalUploaded) total videos")
                print("")
                
                // Short delay for demo
                if index < musicGenres.count - 1 {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }
                
            } catch {
                print("❌ Demo failed for \(genre.name): \(error)")
                print("")
            }
        }
        
        print("🎉 DEMO COMPLETE!")
        print("📊 Demo uploaded: \(totalUploaded) videos across \(musicGenres.count) genres")
        print("🚀 Ready to run full upload when ready!")
    }
}

// MARK: - Test Functions
extension MusicCollectionService {
    func testAPIConnection() async {
        print("🧪 Testing YouTube API connection...")
        
        do {
            let videos = try await YouTubeAPIService.shared.collectGenreMusicVideos(
                genre: "pop music",
                targetCount: 5
            )
            
            print("✅ API connection successful!")
            print("📊 Sample data collected:")
            for (index, video) in videos.enumerated() {
                print("   \(index + 1). \(video.title)")
                print("      Views: \(video.interactions)")
                print("      URL: \(video.url)")
            }
            
        } catch {
            print("❌ API connection failed: \(error)")
            print("")
            print("🔧 Setup required:")
            print("   1. Get YouTube Data API v3 key from Google Cloud Console")
            print("   2. Set environment variable: export YOUTUBE_API_KEY=your_key_here")
            print("   3. Enable YouTube Data API v3 in Google Cloud Console")
        }
    }
}