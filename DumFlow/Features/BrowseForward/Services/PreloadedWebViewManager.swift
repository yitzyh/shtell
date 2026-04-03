import SwiftUI
import WebKit
import Combine

/// Manages a pool of preloaded WebViews for instant navigation transitions
@MainActor
class PreloadedWebViewManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentIndex: Int = 0
    @Published var isAtTopOfCurrentPage: Bool = true

    // MARK: - WebView Pool
    private var webViewPool: [WebViewWrapper] = []
    private let maxPreloadCount = 4 // Current + Next 2 + Previous 1
    private var scrollMonitorCancellable: AnyCancellable?

    // MARK: - Dependencies
    private weak var browseForwardViewModel: BrowseForwardViewModel?
    private weak var webBrowser: WebBrowser?
    private weak var webPageViewModel: WebPageViewModel?

    // MARK: - WebView Wrapper
    struct WebViewWrapper: Identifiable {
        let id = UUID()
        let webView: WKWebView
        var coordinator: WebViewCoordinator?
        var itemIndex: Int
        var isLoaded: Bool = false
    }

    // MARK: - WebView Coordinator for Scroll Detection
    class WebViewCoordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        @Published var isAtTop: Bool = true
        weak var webView: WKWebView?
        private var scrollObservation: NSKeyValueObservation?

        init(webView: WKWebView) {
            self.webView = webView
            super.init()

            webView.navigationDelegate = self
            webView.scrollView.delegate = self

            // Monitor scroll position with KVO
            scrollObservation = webView.scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
                self?.checkScrollPosition(scrollView)
            }
        }

        private func checkScrollPosition(_ scrollView: UIScrollView) {
            // With .automatic adjustment, "at top" means offset is at or near the adjusted top
            let atTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 50
            isAtTop = atTop
        }

        // MARK: - UIScrollViewDelegate
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            checkScrollPosition(scrollView)
        }

        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("🔄 PreloadedWebView: Finished loading")
        }

        deinit {
            scrollObservation?.invalidate()
        }
    }

    // MARK: - Initialization
    init(browseForwardViewModel: BrowseForwardViewModel? = nil,
         webBrowser: WebBrowser? = nil,
         webPageViewModel: WebPageViewModel? = nil) {
        self.browseForwardViewModel = browseForwardViewModel
        self.webBrowser = webBrowser
        self.webPageViewModel = webPageViewModel

        print("🎯 PreloadedWebViewManager: Initialized")
    }

    /// Set dependencies after initialization
    func setDependencies(browseForwardViewModel: BrowseForwardViewModel,
                        webBrowser: WebBrowser,
                        webPageViewModel: WebPageViewModel) {
        self.browseForwardViewModel = browseForwardViewModel
        self.webBrowser = webBrowser
        self.webPageViewModel = webPageViewModel
        print("🎯 PreloadedWebViewManager: Dependencies set")
    }

    // MARK: - Public Methods

    /// Initialize WebViews for the first batch of items
    func initializeWebViews() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else {
            print("❌ PreloadedWebViewManager: No items to display")
            return
        }

        // Start with the first 3 items
        let itemsToLoad = min(3, items.count)

        for index in 0..<itemsToLoad {
            let webView = createWebView()
            let coordinator = WebViewCoordinator(webView: webView)

            var wrapper = WebViewWrapper(
                webView: webView,
                coordinator: coordinator,
                itemIndex: index
            )

            // Load the URL
            let url = items[index].url
            webView.load(URLRequest(url: url))
            wrapper.isLoaded = true
            print("📱 PreloadedWebViewManager: Loading WebView #\(index) with URL: \(url)")


            webViewPool.append(wrapper)
        }

        // Monitor scroll position of current WebView
        updateScrollMonitoring()

        print("✅ PreloadedWebViewManager: Initialized \(webViewPool.count) WebViews")
    }

    /// Get the current WebView
    func getCurrentWebView() -> WKWebView? {
        guard currentIndex < webViewPool.count else { return nil }
        return webViewPool[currentIndex].webView
    }

    /// Get the next WebView (for peeking underneath)
    func getNextWebView() -> WKWebView? {
        let nextIndex = currentIndex + 1
        guard nextIndex < webViewPool.count else { return nil }
        return webViewPool[nextIndex].webView
    }

    /// Get the previous WebView (for peeking above)
    func getPrevWebView() -> WKWebView? {
        let prevIndex = currentIndex - 1
        guard prevIndex >= 0 else { return nil }
        return webViewPool[prevIndex].webView
    }

    /// Navigate to the previous item
    func navigateToPrevious() {
        guard currentIndex > 0 else { return }

        currentIndex -= 1
        updateScrollMonitoring()

        let items = browseForwardViewModel?.displayedItems ?? []
        let itemIndex = webViewPool[currentIndex].itemIndex
        guard itemIndex < items.count else { return }

        let url = items[itemIndex].url
        webBrowser?.urlString = url.absoluteString
        webBrowser?.isUserInitiatedNavigation = true

        print("⬅️ PreloadedWebViewManager: Navigating back to item \(itemIndex)")
    }

    /// Navigate to the next item
    func navigateToNext() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else {
            print("❌ PreloadedWebViewManager.navigateToNext: No items available")
            return
        }

        // If pool is empty, try to initialize it now
        if webViewPool.isEmpty {
            print("⚠️ PreloadedWebViewManager: Pool was empty, initializing now")
            initializeWebViews()
            return // Don't navigate on first initialization
        }

        // Guard against invalid current index
        guard currentIndex < webViewPool.count else {
            print("❌ PreloadedWebViewManager.navigateToNext: Invalid currentIndex \(currentIndex), pool size: \(webViewPool.count)")
            return
        }

        // Calculate next index with looping
        let nextItemIndex = (webViewPool[currentIndex].itemIndex + 1) % items.count

        print("➡️ PreloadedWebViewManager: Navigating from item \(webViewPool[currentIndex].itemIndex) to \(nextItemIndex)")

        // Move to next WebView if available
        if currentIndex + 1 < webViewPool.count {
            currentIndex += 1
        } else {
            // Need to recycle WebViews
            recycleWebViewsForward(targetItemIndex: nextItemIndex)
        }

        // Preload next WebView if needed
        preloadNextWebView()

        // Clean up old WebViews
        releaseOldWebViews()

        // Update scroll monitoring for new current WebView
        updateScrollMonitoring()

        // Update the browser URL
        if let url = items[safe: nextItemIndex]?.url {
            webBrowser?.urlString = url.absoluteString
            webBrowser?.isUserInitiatedNavigation = true
        }
    }

    // MARK: - Private Methods

    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        return webView
    }

    private func preloadNextWebView() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else { return }

        guard currentIndex < webViewPool.count else {
            print("❌ PreloadedWebViewManager.preloadNextWebView: Invalid currentIndex")
            return
        }

        // Check if we need to load more WebViews
        let currentItemIndex = webViewPool[currentIndex].itemIndex
        let nextItemsToPreload = 2 // Preload next 2 items

        for offset in 1...nextItemsToPreload {
            let preloadIndex = currentIndex + offset

            // Check if we already have this WebView in pool
            if preloadIndex < webViewPool.count {
                // WebView exists, check if it has the right content
                let expectedItemIndex = (currentItemIndex + offset) % items.count
                if webViewPool[preloadIndex].itemIndex != expectedItemIndex {
                    // Wrong content, reload it
                    loadWebView(at: preloadIndex, withItemIndex: expectedItemIndex)
                }
            } else if webViewPool.count < maxPreloadCount {
                // Create new WebView
                let itemIndex = (currentItemIndex + offset) % items.count
                let webView = createWebView()
                let coordinator = WebViewCoordinator(webView: webView)

                var wrapper = WebViewWrapper(
                    webView: webView,
                    coordinator: coordinator,
                    itemIndex: itemIndex
                )

                let url = items[itemIndex].url
                webView.load(URLRequest(url: url))
                wrapper.isLoaded = true
                print("📱 PreloadedWebViewManager: Preloading WebView for item #\(itemIndex)")

                webViewPool.append(wrapper)
            }
        }
    }

    private func loadWebView(at poolIndex: Int, withItemIndex itemIndex: Int) {
        guard let items = browseForwardViewModel?.displayedItems,
              poolIndex < webViewPool.count,
              itemIndex < items.count else { return }

        webViewPool[poolIndex].itemIndex = itemIndex

        let url = items[itemIndex].url
        webViewPool[poolIndex].webView.load(URLRequest(url: url))
        webViewPool[poolIndex].isLoaded = true
        print("🔄 PreloadedWebViewManager: Reloading WebView at pool index \(poolIndex) with item #\(itemIndex)")
    }

    private func recycleWebViewsForward(targetItemIndex: Int) {
        // When we run out of preloaded WebViews, recycle the oldest one
        guard webViewPool.count > 0 else {
            print("❌ PreloadedWebViewManager.recycleWebViewsForward: Pool is empty")
            return
        }

        // Move the first WebView to the end and reload it
        let recycled = webViewPool.removeFirst()
        webViewPool.append(recycled)

        // The target item is now at the last position
        currentIndex = webViewPool.count - 1

        // Load the new content
        loadWebView(at: webViewPool.count - 1, withItemIndex: targetItemIndex)
    }

    private func releaseOldWebViews() {
        // Keep only current + next 2 + previous 1
        // For now, we're managing a fixed pool size, so no release needed
        // This method is here for future memory optimization
    }

    private func updateScrollMonitoring() {
        guard currentIndex < webViewPool.count,
              let coordinator = webViewPool[currentIndex].coordinator else { return }

        scrollMonitorCancellable?.cancel()
        scrollMonitorCancellable = coordinator.$isAtTop
            .sink { [weak self] value in
                self?.isAtTopOfCurrentPage = value
            }

        print("🔍 PreloadedWebViewManager: Monitoring scroll for WebView at index \(currentIndex)")
    }
}
