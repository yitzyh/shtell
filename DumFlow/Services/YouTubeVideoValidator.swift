import Foundation

/// Service to validate YouTube videos before adding them to database
/// Prevents dead/unavailable videos from being stored
class YouTubeVideoValidator {
    static let shared = YouTubeVideoValidator()
    
    private init() {}
    
    /// Validate if a YouTube video is available using oEmbed API
    /// Returns true if video is available, false if dead/unavailable
    func isVideoAvailable(videoId: String) async -> Bool {
        do {
            let oembed_url = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json"
            
            guard let url = URL(string: oembed_url) else {
                print("⚠️ YouTubeVideoValidator: Invalid URL for video \(videoId)")
                return false
            }
            
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    // Video is available
                    return true
                case 404:
                    // Video is dead/unavailable
                    print("💀 YouTubeVideoValidator: Video \(videoId) is unavailable (404)")
                    return false
                case 403:
                    // Private video - treat as unavailable for our purposes
                    print("🔒 YouTubeVideoValidator: Video \(videoId) is private (403)")
                    return false
                default:
                    // Rate limited or other error - assume available to be safe
                    print("⚠️ YouTubeVideoValidator: Unexpected status \(httpResponse.statusCode) for video \(videoId), assuming available")
                    return true
                }
            }
            
            return true // Default to available if no HTTP response
            
        } catch {
            print("⚠️ YouTubeVideoValidator: Error checking video \(videoId): \(error), assuming available")
            return true // Assume available on error to avoid false negatives
        }
    }
    
    /// Validate multiple videos in batch with rate limiting
    func validateVideos(videoIds: [String]) async -> [String] {
        var validVideoIds: [String] = []
        
        print("🔍 YouTubeVideoValidator: Validating \(videoIds.count) videos...")
        
        for (index, videoId) in videoIds.enumerated() {
            let isValid = await isVideoAvailable(videoId: videoId)
            
            if isValid {
                validVideoIds.append(videoId)
            }
            
            // Rate limiting - small delay between requests
            if index < videoIds.count - 1 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        }
        
        let filteredCount = videoIds.count - validVideoIds.count
        if filteredCount > 0 {
            print("🧹 YouTubeVideoValidator: Filtered out \(filteredCount) dead videos")
        }
        
        print("✅ YouTubeVideoValidator: \(validVideoIds.count)/\(videoIds.count) videos are valid")
        return validVideoIds
    }
    
    /// Extract video ID from YouTube URL
    func extractVideoId(from url: String) -> String? {
        let patterns = [
            #"(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})"#,
            #"youtube\.com/v/([a-zA-Z0-9_-]{11})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) {
                if let range = Range(match.range(at: 1), in: url) {
                    return String(url[range])
                }
            }
        }
        
        return nil
    }
}