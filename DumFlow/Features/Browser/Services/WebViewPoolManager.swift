import Foundation
import WebKit
import SwiftUI

// MARK: - WebView Pool Manager
@MainActor
class WebViewPoolManager: ObservableObject {
    @Published private(set) var preloadedWebViews: [PreloadedWebView] = []
    @Published private(set) var isPreloading = false

    private let maxPoolSize = 2 // Preload 2 WebViews at a time
    private let memoryBudget = 140_000_000 // 140MB budget for 2 WebViews
    private var preloadQueue: [String] = []

    // Track which URLs we've already attempted to preload
    private var preloadedURLs: Set<String> = []

    // MARK: - Public Methods

    /// Preload the next URLs in the queue
    func preloadNextURLs(_ urls: [String]) {
        guard !isPreloading else {
            #if DEBUG
            print("⚠️ WebViewPoolManager: Already preloading, skipping")
            #endif
            return
        }

        // Filter out URLs we've already preloaded
        let newURLs = urls.filter { !preloadedURLs.contains($0) }
        guard !newURLs.isEmpty else {
            #if DEBUG
            print("⚠️ WebViewPoolManager: No new URLs to preload")
            #endif
            return
        }

        preloadQueue = Array(newURLs.prefix(maxPoolSize))

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("🔄 WebViewPoolManager: Preloading \(preloadQueue.count) URLs")
        }
        #endif

        Task {
            await startPreloading()
        }
    }

    /// Get a preloaded WebView for the given URL
    func getPreloadedWebView(for url: String) -> WKWebView? {
        guard let index = preloadedWebViews.firstIndex(where: { $0.url == url }) else {
            #if DEBUG
            print("❌ WebViewPoolManager: No preloaded WebView found for \(url)")
            #endif
            return nil
        }

        let preloaded = preloadedWebViews.remove(at: index)

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("✅ WebViewPoolManager: Retrieved preloaded WebView (age: \(String(format: "%.1f", preloaded.age))s)")
        }
        #endif

        // Remove from tracking
        preloadedURLs.remove(url)

        return preloaded.webView
    }

    /// Release a WebView back to the pool (for reuse)
    func releaseWebView(_ webView: WKWebView) {
        // Clean up the WebView
        webView.stopLoading()
        webView.configuration.userContentController.removeAllUserScripts()

        #if DEBUG
        print("🗑️ WebViewPoolManager: Released WebView")
        #endif
    }

    /// Handle memory warning - clear all preloaded WebViews
    func handleMemoryWarning() {
        #if DEBUG
        print("⚠️ WebViewPoolManager: Memory warning - clearing pool")
        #endif

        clearPool()
    }

    /// Clear the entire pool
    func clearPool() {
        for preloaded in preloadedWebViews {
            releaseWebView(preloaded.webView)
        }

        preloadedWebViews.removeAll()
        preloadedURLs.removeAll()
        preloadQueue.removeAll()
        isPreloading = false

        #if DEBUG
        print("🧹 WebViewPoolManager: Pool cleared")
        #endif
    }

    // MARK: - Private Methods

    private func startPreloading() async {
        guard !preloadQueue.isEmpty else { return }

        isPreloading = true

        for urlString in preloadQueue {
            // Check if we're at capacity
            guard preloadedWebViews.count < maxPoolSize else {
                #if DEBUG
                print("⚠️ WebViewPoolManager: Pool at capacity")
                #endif
                break
            }

            // Check memory budget
            guard checkMemoryBudget() else {
                #if DEBUG
                print("⚠️ WebViewPoolManager: Memory budget exceeded")
                #endif
                break
            }

            // Create and preload WebView
            await preloadURL(urlString)
        }

        isPreloading = false
        preloadQueue.removeAll()
    }

    private func preloadURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ WebViewPoolManager: Invalid URL: \(urlString)")
            #endif
            return
        }

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("🔄 WebViewPoolManager: Preloading \(url.host ?? urlString)")
        }
        #endif

        // Create WebView configuration
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()

        // Create WebView
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false

        // Start loading with timeout
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5.0)

        do {
            // Load with timeout monitoring
            webView.load(request)

            // Wait for initial load or timeout
            try await withTimeout(seconds: 5.0) {
                await self.waitForWebViewLoad(webView)
            }

            // Add to pool
            let preloaded = PreloadedWebView(webView: webView, url: urlString)
            preloadedWebViews.append(preloaded)
            preloadedURLs.insert(urlString)

            #if DEBUG
            if verboseLogging {
                print("✅ WebViewPoolManager: Successfully preloaded \(url.host ?? urlString)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ WebViewPoolManager: Failed to preload \(url.host ?? urlString): \(error.localizedDescription)")
            #endif

            // Clean up failed WebView
            webView.stopLoading()
        }
    }

    private func waitForWebViewLoad(_ webView: WKWebView) async {
        // Wait for the page to start loading (estimatedProgress > 0)
        while webView.estimatedProgress < 0.3 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    private func checkMemoryBudget() -> Bool {
        let usedMemory = preloadedWebViews.reduce(0) { $0 + $1.estimatedMemory }
        return usedMemory < memoryBudget
    }

    private func releaseOldestWebView() {
        guard let oldest = preloadedWebViews.min(by: { $0.loadTimestamp < $1.loadTimestamp }) else {
            return
        }

        if let index = preloadedWebViews.firstIndex(where: { $0.url == oldest.url }) {
            let removed = preloadedWebViews.remove(at: index)
            releaseWebView(removed.webView)
            preloadedURLs.remove(removed.url)

            #if DEBUG
            print("🗑️ WebViewPoolManager: Released oldest WebView (age: \(String(format: "%.1f", removed.age))s)")
            #endif
        }
    }
}

// MARK: - Timeout Helper
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

private struct TimeoutError: Error {}
