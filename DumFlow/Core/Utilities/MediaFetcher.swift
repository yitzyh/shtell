import Foundation
import Combine
import UIKit

struct WebPageMedia {
    let title: String?
    let faviconData: Data?
    let thumbnailData: Data?
    
    init(title: String? = nil, faviconData: Data? = nil, thumbnailData: Data? = nil) {
        self.title = title
        self.faviconData = faviconData
        self.thumbnailData = thumbnailData
    }
}

class MediaFetcher {
    static let shared = MediaFetcher()
    
    private init() {}
    
    /// Fetch title, favicon, and thumbnail in a single HTML download
    func fetchAllMedia(for urlString: String) -> AnyPublisher<WebPageMedia, Never> {
        guard let url = URL(string: urlString) else {
            return Just(WebPageMedia()).eraseToAnyPublisher()
        }
        
        // Convert HTTP to HTTPS for App Transport Security
        let secureURL = convertToHTTPS(url)
        
        return fetchHTML(from: secureURL)
            .flatMap { html -> AnyPublisher<WebPageMedia, Never> in
                
                // Extract metadata using original functions
                let title = self.extractTitle(from: html)
                let faviconURL = self.extractFaviconURL(from: html, baseURL: secureURL)
                let thumbnailURL = self.extractThumbnailURL(from: html, baseURL: secureURL)
                
                
                // Download favicon and thumbnail in parallel
                let faviconPublisher: AnyPublisher<Data?, Never>
                if let faviconURL = faviconURL {
                    faviconPublisher = self.downloadImage(from: faviconURL)
                } else {
                    faviconPublisher = Just(nil).eraseToAnyPublisher()
                }
                
                let thumbnailPublisher: AnyPublisher<Data?, Never>
                if let thumbnailURL = thumbnailURL {
                    thumbnailPublisher = self.downloadImage(from: thumbnailURL)
                } else {
                    thumbnailPublisher = Just(nil).eraseToAnyPublisher()
                }
                
                return Publishers.CombineLatest(faviconPublisher, thumbnailPublisher)
                    .map { faviconData, thumbnailData in
                        
                        // Apply size limits to prevent processing crashes with huge images
                        let processedFaviconData = faviconData.map { data in
                            data.count < 50_000 ? self.optimizeFavicon(data) : nil
                        } ?? nil
                        
                        let processedThumbnailData = thumbnailData.map { data in
                            data.count < 500_000 ? self.optimizeThumbnail(data) : nil
                        } ?? nil
                        
                        if let faviconData = faviconData, faviconData.count >= 50_000 {
                        }
                        if let thumbnailData = thumbnailData, thumbnailData.count >= 500_000 {
                        }
                        
                        let result = WebPageMedia(
                            title: title,
                            faviconData: processedFaviconData,
                            thumbnailData: processedThumbnailData
                        )
                        return result
                    }
                    .eraseToAnyPublisher()
            }
            .replaceError(with: WebPageMedia())
            .eraseToAnyPublisher()
    }
    
    // MARK: - URL Security
    
    /// Convert HTTP URLs to HTTPS for App Transport Security compliance
    private func convertToHTTPS(_ url: URL) -> URL {
        guard url.scheme == "http" else { return url }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }
    
    // MARK: - HTML Fetching
    
    /// Downloads raw HTML from a URL with proper headers for social media scraping
    private func fetchHTML(from url: URL) -> AnyPublisher<String, Error> {
        
        // Reddit URL conversion for better scraping
        let scrapingURL: URL
        if let host = url.host?.lowercased(), host.contains("reddit.com") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.host = "old.reddit.com"
            scrapingURL = components?.url ?? url
        } else {
            scrapingURL = url
        }
        
        // Proper headers for social media content scraping
        var request = URLRequest(url: scrapingURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("upgrade-insecure-requests", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .timeout(10, scheduler: RunLoop.main)
            .map { data, _ in
                return String(data: data, encoding: .utf8) ?? ""
            }
            .mapError { error in
                print("❌ MediaFetcher: HTML fetch failed: \(error)")
                return error
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Content Extraction
    
    /// Extract title with social media priority (og:title, twitter:title, then <title>)
    private func extractTitle(from html: String) -> String? {
        if let og = extractMetaTag(from: html, with: "og:title") {
            return decodeHTMLEntities(in: og)
        }
        if let tw = extractMetaTag(from: html, with: "twitter:title") {
            return decodeHTMLEntities(in: tw)
        }
        return extractStandardTitle(from: html)
    }
    
    /// Extract favicon URL from HTML
    private func extractFaviconURL(from html: String, baseURL: URL) -> URL? {
        let patterns = [
            "<link[^>]*rel=\"icon\"[^>]*href=\"([^\"]+)\"",
            "<link[^>]*rel=\"apple-touch-icon\"[^>]*href=\"([^\"]+)\"",
            "<link[^>]*rel=\"shortcut icon\"[^>]*href=\"([^\"]+)\""
        ]
        
        for pattern in patterns {
            if let url = extractURL(from: html, pattern: pattern, baseURL: baseURL) {
                return convertToHTTPS(url)
            }
        }
        
        // Fallback to standard favicon path
        let faviconURL = URL(string: "/favicon.ico", relativeTo: baseURL)
        return faviconURL.map { convertToHTTPS($0) }
    }
    
    /// Extract thumbnail URL from HTML (prioritizes social media meta tags)
    private func extractThumbnailURL(from html: String, baseURL: URL) -> URL? {
        // Priority: Open Graph, Twitter, then first large image
        if let og = extractMetaTag(from: html, with: "og:image") {
            return URL(string: og, relativeTo: baseURL)
        }
        if let tw = extractMetaTag(from: html, with: "twitter:image") {
            return URL(string: tw, relativeTo: baseURL)
        }
        
        // Find first large image in content
        let imagePattern = "<img[^>]+src=\"([^\"]+)\""
        if let imageURL = extractURL(from: html, pattern: imagePattern, baseURL: baseURL) {
            return imageURL
        }
        
        return nil
    }
    
    /// Extract standard HTML title
    private func extractStandardTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<title>(.*?)</title>",
            options: .caseInsensitive
        ) else {
            return nil
        }
        let ns = html as NSString
        let results = regex.matches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        )
        if let match = results.first {
            let title = ns.substring(with: match.range(at: 1))
            return decodeHTMLEntities(in: title)
        }
        return nil
    }
    
    // MARK: - Async Methods for Temporary Data
    
    /// Fetch just the webpage title
    func fetchWebPageTitle(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let secureURL = convertToHTTPS(url)
        let html = try await fetchHTMLAsync(from: secureURL)
        return extractTitle(from: html) ?? urlString
    }
    
    /// Fetch just the favicon
    func fetchFavicon(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let secureURL = convertToHTTPS(url)
        let html = try await fetchHTMLAsync(from: secureURL)
        
        if let faviconURL = extractFaviconURL(from: html, baseURL: secureURL) {
            return try await downloadImageAsync(from: faviconURL)
        }
        
        throw URLError(.fileDoesNotExist)
    }
    
    /// Async HTML fetching
    private func fetchHTMLAsync(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Async image downloading
    private func downloadImageAsync(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    /// Extract meta tag content
    private func extractMetaTag(from html: String, with property: String) -> String? {
        let pattern = "<meta[^>]+property=\"\(property)\"[^>]+content=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return nil
        }
        let ns = html as NSString
        let matches = regex.matches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        )
        return matches.first.map { ns.substring(with: $0.range(at: 1)) }
    }
    
    /// Extract URL from HTML using regex pattern
    private func extractURL(from html: String, pattern: String, baseURL: URL) -> URL? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return nil
        }
        let ns = html as NSString
        let matches = regex.matches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        )
        if let match = matches.first {
            let urlString = ns.substring(with: match.range(at: 1))
            return URL(string: urlString, relativeTo: baseURL)
        }
        return nil
    }
    
    /// Decode HTML entities
    private func decodeHTMLEntities(in string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let decoded = (try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ))?.string
        return decoded ?? string
    }
    
    // MARK: - Image Downloading & Optimization
    
    /// Download image with timeout
    private func downloadImage(from url: URL) -> AnyPublisher<Data?, Never> {
        URLSession.shared.dataTaskPublisher(for: url)
            .timeout(5, scheduler: RunLoop.main)
            .map { $0.data }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    /// Optimize favicon to 48x48px PNG - moved to background thread
    private func optimizeFavicon(_ data: Data?) -> Data? {
        guard let data = data, let image = UIImage(data: data) else { return data }
        
        // Perform image processing on background thread
        return performImageProcessing {
            // Resize to 48x48px (optimal for @2x displays)
            let targetSize = CGSize(width: 48, height: 48)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false // Preserve transparency
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
            // Always use PNG to preserve transparency for favicons
            return resizedImage.pngData() ?? data
        }
    }
    
    /// Helper method to perform image processing on background thread
    private func performImageProcessing<T>(_ operation: @escaping () -> T) -> T {
        if Thread.isMainThread {
            // Dispatch to background and wait
            return DispatchQueue.global(qos: .utility).sync {
                return operation()
            }
        } else {
            // Already on background thread
            return operation()
        }
    }
    
    /// Optimize thumbnail to max 320px dimension
    private func optimizeThumbnail(_ data: Data?) -> Data? {
        guard let data = data else { return data }
        
        // Early size check - reject if already too small to need processing
        guard data.count > 15000 else { return data }
        
        guard let image = UIImage(data: data) else { return data }
        
        // Calculate proportional size with max dimension of 320px
        let maxDimension: CGFloat = 320
        let imageSize = image.size
        
        // Protect against NaN by ensuring dimensions are valid
        guard imageSize.width > 0 && imageSize.height > 0 else {
            print("⚠️ MediaFetcher: Invalid image dimensions - width: \(imageSize.width), height: \(imageSize.height)")
            return compressImageSmartly(image, targetSize: 50000)
        }
        
        let scale = min(maxDimension / imageSize.width, maxDimension / imageSize.height)
        
        // Only resize if image is larger than max dimension
        guard scale < 1.0 else {
            // Image is already small enough, use smart compression
            return compressImageSmartly(image, targetSize: 50000)
        }
        
        // Resize proportionally
        let targetSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        // Use smart compression for resized image
        return compressImageSmartly(resizedImage, targetSize: 50000)
    }
    
    /// Efficiently compress image using binary search approach
    private func compressImageSmartly(_ image: UIImage, targetSize: Int) -> Data? {
        // Binary search for optimal compression quality
        var minQuality: CGFloat = 0.1
        var maxQuality: CGFloat = 0.9
        var bestData: Data?
        
        // Max 4 iterations instead of potentially 10+ in while loop
        for _ in 0..<4 {
            let midQuality = (minQuality + maxQuality) / 2
            guard let data = image.jpegData(compressionQuality: midQuality) else { break }
            
            if data.count <= targetSize {
                bestData = data
                minQuality = midQuality
            } else {
                maxQuality = midQuality
            }
            
            // Early exit if we're close enough
            if abs(data.count - targetSize) < 5000 {
                return data
            }
        }
        
        // Fallback to minimum quality if binary search didn't work
        return bestData ?? image.jpegData(compressionQuality: 0.4)
    }
}

// MARK: - WebPageMedia Extensions

extension WebPageMedia {
    init(title: String?, faviconURL: URL?, thumbnailURL: URL?) {
        self.title = title
        self.faviconData = nil
        self.thumbnailData = nil
    }
}
