import Foundation
import WebKit

// MARK: - Preloaded WebView Model
struct PreloadedWebView {
    let webView: WKWebView
    let url: String
    let loadTimestamp: Date
    var estimatedMemory: Int

    // Estimated memory per WebView (in bytes)
    static let averageMemoryFootprint = 70_000_000 // 70MB

    init(webView: WKWebView, url: String, estimatedMemory: Int = PreloadedWebView.averageMemoryFootprint) {
        self.webView = webView
        self.url = url
        self.loadTimestamp = Date()
        self.estimatedMemory = estimatedMemory
    }

    // Age of this preloaded WebView
    var age: TimeInterval {
        return Date().timeIntervalSince(loadTimestamp)
    }

    // Is this WebView still fresh? (less than 5 minutes old)
    var isFresh: Bool {
        return age < 300 // 5 minutes
    }
}
