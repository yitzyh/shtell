import Foundation
import WebKit
import SwiftUI
import Combine

// MARK: - Debug Logging Configuration
#if DEBUG
private let enablePreloadLogs = ProcessInfo.processInfo.environment["BROWSE_FORWARD_LOGS"] == "1"

private func preloadLog(_ message: String) {
    if enablePreloadLogs { print("🎯 PRELOAD: \(message)") }
}
#else
private func preloadLog(_ message: String) {}
#endif

// MARK: - Background WebView Preloading Manager
@MainActor
class BrowseForwardPreloadManager: ObservableObject {

    // MARK: - Properties
    private var backgroundWebView: WKWebView?
    private var preloadedURL: String?
    private var isPreloading = false

    weak var browseForwardViewModel: BrowseForwardViewModel?

    // References for positioning background WebView
    weak var currentWebView: WKWebView?
    weak var parentView: UIView?

    // Preload queue management
    private var preloadQueue: [String] = []
    private let maxPreloadQueue = 3

    // Performance tracking
    private var preloadStartTime: Date?
    private var successfulPreloads = 0
    private var preloadHitRate: Double = 0.0

    // Memory management
    private var preloadTimer: Timer?
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization
    init() {
        setupBackgroundWebView()
        setupMemoryWarningObserver()
        preloadLog("BrowseForwardPreloadManager initialized")
    }

    deinit {
        // Perform immediate cleanup without using Task since we're deinitializing
        preloadTimer?.invalidate()
        preloadTimer = nil

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }

        // Stop loading and clear WebView immediately
        backgroundWebView?.stopLoading()
        backgroundWebView?.navigationDelegate = nil
        backgroundWebView?.loadHTMLString("", baseURL: nil) // Clear content
        backgroundWebView?.removeFromSuperview()
        backgroundWebView = nil
        preloadedURL = nil

        preloadLog("Cleaned up preload manager in deinit")
    }

    // MARK: - Background WebView Setup
    private func setupBackgroundWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false // Disable for background loading
        config.mediaTypesRequiringUserActionForPlayback = .all // Disable auto-play for background

        // Use non-persistent data store for memory efficiency
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        backgroundWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: config)

        // Configure for background loading
        backgroundWebView?.isHidden = true
        backgroundWebView?.alpha = 0.0

        preloadLog("Background WebView configured")
    }

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    @MainActor
    private func handleMemoryWarning() {
        preloadLog("⚠️ Memory warning received - clearing preloaded content")
        backgroundWebView?.stopLoading()
        backgroundWebView?.navigationDelegate = nil
        backgroundWebView?.loadHTMLString("", baseURL: nil) // Clear content

        // Clear website data to free memory
        if let webView = backgroundWebView {
            webView.configuration.websiteDataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date.distantPast
            ) {
                preloadLog("💾 Cleared website data due to memory pressure")
            }
        }

        preloadedURL = nil
        preloadLog("💾 Cleared preloaded content due to memory pressure")
    }

    // MARK: - Public Interface

    /// Set references to current WebView and parent for positioning
    func setCurrentWebView(_ webView: WKWebView) {
        currentWebView = webView
        parentView = webView.superview
        preloadLog("Set current WebView reference")

        // If we already have preloaded content, position it behind now
        positionBackgroundWebViewIfReady()
    }

    /// Position background WebView behind current one when content is ready
    private func positionBackgroundWebViewIfReady() {
        guard let backgroundWebView = backgroundWebView,
              let currentWebView = currentWebView,
              let parentView = parentView,
              preloadedURL != nil else {
            return
        }

        // Only position if not already in view hierarchy
        if backgroundWebView.superview == nil {
            preloadLog("📍 Positioning background WebView behind current one")

            // Configure for reveal effect
            backgroundWebView.frame = currentWebView.frame
            backgroundWebView.transform = .identity
            backgroundWebView.isHidden = false
            backgroundWebView.alpha = 1.0

            // Position behind current WebView
            parentView.insertSubview(backgroundWebView, belowSubview: currentWebView)
        }
    }

    /// Start preloading the next BrowseForward content
    func startPreloading() {
        guard !isPreloading else {
            preloadLog("Already preloading, skipping")
            return
        }

        preloadLog("🚀 Starting automatic preload for instant BrowseForward")
        Task {
            await preloadNextContent()
        }
    }

    /// Preload multiple articles ahead for better instant display
    func startPreloadingQueue(count: Int = 2) {
        preloadLog("📦 Starting preload queue with \(count) items")
        Task {
            for i in 0..<count {
                if !isPreloading {
                    preloadLog("📦 Preloading item \(i + 1)/\(count)")
                    await preloadNextContent()
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay between preloads
                }
            }
        }
    }

    /// Get the preloaded WebView if content matches the requested URL
    func getPreloadedWebView(for url: String) -> WKWebView? {
        guard let preloadedURL = preloadedURL,
              preloadedURL == url,
              let webView = backgroundWebView else {
            preloadLog("No matching preloaded content for: \(cleanURLForLogging(url))")
            return nil
        }

        preloadLog("✅ Returning preloaded WebView for: \(cleanURLForLogging(url))")

        // Track successful preload usage
        successfulPreloads += 1
        updatePreloadHitRate()

        // Clean up the returned WebView's navigation delegate to prevent leaks
        webView.navigationDelegate = nil

        // Clear the preloaded state
        self.preloadedURL = nil
        self.backgroundWebView = nil

        // Setup new background WebView for next preload
        setupBackgroundWebView()

        // Start preloading next content immediately
        startPreloading()

        return webView
    }

    /// Swap the current main WebView with a preloaded one instantly with slide animation
    func swapToPreloadedContent(for url: String, in parentView: UIView, replacing currentWebView: WKWebView) -> WKWebView? {
        guard let preloadedWebView = getPreloadedWebView(for: url) else {
            return nil
        }

        preloadLog("🎬 Swapping to preloaded WebView with slide animation")

        // Configure preloaded WebView for main display
        preloadedWebView.isHidden = false
        preloadedWebView.alpha = 1.0
        preloadedWebView.frame = currentWebView.frame

        // Start the preloaded WebView above the visible area for slide animation
        preloadedWebView.transform = CGAffineTransform(translationX: 0, y: -parentView.bounds.height)

        // Add to parent view
        parentView.addSubview(preloadedWebView)

        // Animate slide down from top
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            preloadedWebView.transform = .identity
            currentWebView.transform = CGAffineTransform(translationX: 0, y: parentView.bounds.height)
            currentWebView.alpha = 0.9
        } completion: { _ in
            // Remove old WebView after animation
            currentWebView.removeFromSuperview()
            currentWebView.transform = .identity
            currentWebView.alpha = 1.0
        }

        return preloadedWebView
    }

    /// Get preloaded content instantly for immediate display
    func getInstantPreloadedContent(for url: String) -> (webView: WKWebView, url: String)? {
        guard let preloadedURL = preloadedURL,
              let webView = backgroundWebView else {
            preloadLog("No preloaded content available")
            return nil
        }

        preloadLog("⚡ Providing instant preloaded content")

        // Clean up the returned WebView's navigation delegate to prevent leaks
        webView.navigationDelegate = nil

        // Clear the preloaded state for reuse
        let result = (webView: webView, url: preloadedURL)
        self.preloadedURL = nil
        self.backgroundWebView = nil

        // Setup new background WebView for next preload
        setupBackgroundWebView()

        return result
    }

    /// Check if content is ready for instant display
    func hasPreloadedContent(for url: String) -> Bool {
        return preloadedURL == url && backgroundWebView != nil
    }

    /// Public cleanup method for external cleanup requests
    func cleanupResources() {
        cleanup()
    }

    // MARK: - Private Methods

    private func preloadNextContent() async {
        guard let browseForwardViewModel = browseForwardViewModel,
              !isPreloading else {
            preloadLog("Missing ViewModel or already preloading")
            return
        }

        isPreloading = true
        preloadStartTime = Date()
        preloadLog("Starting preload process...")

        do {
            // Get next URL to preload
            let nextURL = try await browseForwardViewModel.getRandomURL()

            guard let urlString = nextURL,
                  let url = URL(string: urlString) else {
                preloadLog("❌ Failed to get valid URL for preload")
                isPreloading = false
                return
            }

            // Skip if already preloaded
            if preloadedURL == urlString {
                preloadLog("⏩ URL already preloaded, skipping")
                isPreloading = false
                return
            }

            preloadLog("Preloading URL: \(cleanURLForLogging(urlString))")

            // Start loading in background WebView
            await loadInBackground(url: url)

        } catch {
            preloadLog("❌ Error getting next URL: \(error)")
            isPreloading = false
        }
    }

    private func loadInBackground(url: URL) async {
        guard let webView = backgroundWebView else {
            preloadLog("❌ No background WebView available")
            isPreloading = false
            return
        }

        let urlString = url.absoluteString
        preloadLog("Loading in background: \(cleanURLForLogging(urlString))")

        // Create a continuation to wait for navigation completion with timeout
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var hasResumed = false
            let coordinatorWrapper = CoordinatorWrapper()

            let coordinator = BackgroundWebViewCoordinator(
                onComplete: { [weak self] success in
                    if !hasResumed {
                        hasResumed = true
                        self?.handlePreloadComplete(url: urlString, success: success)
                        continuation.resume()
                    }
                }
            )

            coordinatorWrapper.coordinator = coordinator

            // Set navigation delegate temporarily - coordinator will be deallocated after completion
            webView.navigationDelegate = coordinator
            coordinator.webView = webView

            // Add timeout to prevent continuation leaks
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                if !hasResumed {
                    hasResumed = true
                    preloadLog("⏰ Preload timeout for: \(self?.cleanURLForLogging(urlString) ?? urlString)")
                    webView.navigationDelegate = nil
                    self?.handlePreloadComplete(url: urlString, success: false)
                    continuation.resume()
                }
            }

            // Load the URL
            webView.load(URLRequest(url: url))
        }
    }

    private func handlePreloadComplete(url: String, success: Bool) {
        if success {
            preloadedURL = url

            // Performance logging
            if let startTime = preloadStartTime {
                let duration = Date().timeIntervalSince(startTime)
                preloadLog("✅ Preload completed for: \(cleanURLForLogging(url)) in \(String(format: "%.2f", duration))s")
            } else {
                preloadLog("✅ Preload completed for: \(cleanURLForLogging(url))")
            }

            // Position the background WebView behind current one immediately
            positionBackgroundWebViewIfReady()
        } else {
            preloadLog("❌ Preload failed for: \(cleanURLForLogging(url))")
        }

        isPreloading = false
        preloadStartTime = nil
    }

    // MARK: - Memory Management

    private func updatePreloadHitRate() {
        // Simple hit rate calculation
        let totalRequests = max(1, successfulPreloads) // Avoid division by zero
        preloadHitRate = Double(successfulPreloads) / Double(totalRequests)
        preloadLog("📊 Preload hit rate: \(String(format: "%.1f", preloadHitRate * 100))% (\(successfulPreloads) hits)")
    }

    private func cleanup() {
        preloadTimer?.invalidate()
        preloadTimer = nil

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }

        backgroundWebView?.stopLoading()
        backgroundWebView?.navigationDelegate = nil
        backgroundWebView?.loadHTMLString("", baseURL: nil) // Clear content

        // Clear website data to free memory
        if let webView = backgroundWebView {
            webView.configuration.websiteDataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date.distantPast
            ) {
                preloadLog("💾 Cleared website data in cleanup")
            }
        }

        backgroundWebView?.removeFromSuperview()
        backgroundWebView = nil
        preloadedURL = nil
        preloadLog("Cleaned up preload manager")
    }

    // MARK: - Utility Methods

    private func cleanURLForLogging(_ urlString: String) -> String {
        if urlString.hasPrefix("data:") {
            return "[DATA_URL]"
        }

        if let url = URL(string: urlString) {
            let hostPath = "\(url.host ?? "unknown")\(url.path)"
            return hostPath.isEmpty ? urlString : hostPath
        }

        return urlString
    }
}

// MARK: - Coordinator Wrapper to prevent deallocation
private class CoordinatorWrapper {
    var coordinator: BackgroundWebViewCoordinator?
}

// MARK: - Background WebView Navigation Delegate
private class BackgroundWebViewCoordinator: NSObject, WKNavigationDelegate {

    let onComplete: (Bool) -> Void
    weak var webView: WKWebView?

    init(onComplete: @escaping (Bool) -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    private func completeAndCleanup(_ success: Bool) {
        // Clear the navigation delegate to break potential retain cycles
        webView?.navigationDelegate = nil
        onComplete(success)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        preloadLog("Background navigation completed successfully")
        completeAndCleanup(true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        preloadLog("Background navigation failed: \(error.localizedDescription)")
        completeAndCleanup(false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        preloadLog("Background provisional navigation failed: \(error.localizedDescription)")
        completeAndCleanup(false)
    }
}