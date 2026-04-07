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
    private let maxPreloadCount = 5 // Current + Next 3 + Previous 1
    private var scrollMonitorCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var canGoBackObserver: NSKeyValueObservation?

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
        @Published var scrollProgress: CGFloat = 0.0
        weak var webView: WKWebView?
        private var scrollObservation: NSKeyValueObservation?

        /// Distance (pts) of scroll needed to fully collapse the toolbar.
        private let collapseDistance: CGFloat = 60

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
            let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            isAtTop = offset <= 50
            scrollProgress = min(1.0, max(0.0, offset / collapseDistance))
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

    /// The content item index the pool is currently showing.
    var currentItemIndex: Int {
        guard currentIndex < webViewPool.count else { return 0 }
        return webViewPool[currentIndex].itemIndex
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

        print("⬅️ PreloadedWebViewManager: Navigating back to item \(itemIndex)")
    }

    /// Navigate to the next item
    func navigateToNext() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else {
            print("❌ PreloadedWebViewManager.navigateToNext: No items available")
            return
        }

        if webViewPool.isEmpty {
            print("⚠️ PreloadedWebViewManager: Pool was empty, initializing now")
            initializeWebViews()
            return
        }

        guard currentIndex < webViewPool.count else {
            print("❌ PreloadedWebViewManager.navigateToNext: Invalid currentIndex \(currentIndex), pool size: \(webViewPool.count)")
            return
        }

        let nextItemIndex = webViewPool[currentIndex].itemIndex + 1
        guard nextItemIndex < items.count else { return }

        print("➡️ PreloadedWebViewManager: Navigating from item \(webViewPool[currentIndex].itemIndex) to \(nextItemIndex)")

        // Advance into the next slot (already preloaded) or fallback-create one
        if currentIndex + 1 < webViewPool.count {
            currentIndex += 1
        } else {
            // Preloading fell behind — create on demand
            let webView = createWebView()
            let coordinator = WebViewCoordinator(webView: webView)
            var wrapper = WebViewWrapper(webView: webView, coordinator: coordinator, itemIndex: nextItemIndex)
            webView.load(URLRequest(url: items[nextItemIndex].url))
            wrapper.isLoaded = true
            webViewPool.append(wrapper)
            currentIndex = webViewPool.count - 1
        }

        // Sliding window: keep at most 1 item behind currentIndex so there is
        // always room in the pool for preloading 2 items ahead.
        while currentIndex > 1 {
            webViewPool.removeFirst()
            currentIndex -= 1
        }

        preloadNextWebView()
        updateScrollMonitoring()

        if let url = items[safe: webViewPool[currentIndex].itemIndex]?.url {
            webBrowser?.urlString = url.absoluteString
        }
    }

    /// Re-initializes the pool with the current items from the ViewModel.
    /// Reuses existing WKWebViews (just loads new URLs) to avoid inserting new
    /// UIKit views into the hierarchy, which would steal keyboard focus.
    func reinitializeWebViews() {
        guard let items = browseForwardViewModel?.displayedItems, !items.isEmpty else { return }

        scrollMonitorCancellable?.cancel()
        currentIndex = 0
        isAtTopOfCurrentPage = true

        let slotsToFill = min(3, items.count)

        // Reuse existing WebViews — just point them at new URLs
        for i in 0..<min(slotsToFill, webViewPool.count) {
            webViewPool[i].itemIndex = i
            webViewPool[i].isLoaded = true
            webViewPool[i].webView.load(URLRequest(url: items[i].url))
        }

        // Trim any excess pool slots
        if webViewPool.count > slotsToFill {
            webViewPool.removeLast(webViewPool.count - slotsToFill)
        }

        // Create new WebViews only if the pool was smaller than needed
        for i in webViewPool.count..<slotsToFill {
            let webView = createWebView()
            let coordinator = WebViewCoordinator(webView: webView)
            var wrapper = WebViewWrapper(webView: webView, coordinator: coordinator, itemIndex: i)
            webView.load(URLRequest(url: items[i].url))
            wrapper.isLoaded = true
            webViewPool.append(wrapper)
        }

        updateScrollMonitoring()
        print("🔄 PreloadedWebViewManager: Re-initialized pool with new items")
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
        let nextItemsToPreload = 3 // Preload next 3 items

        for offset in 1...nextItemsToPreload {
            let targetItemIndex = currentItemIndex + offset
            guard targetItemIndex < items.count else { break }

            let preloadIndex = currentIndex + offset

            if preloadIndex < webViewPool.count {
                if webViewPool[preloadIndex].itemIndex != targetItemIndex {
                    loadWebView(at: preloadIndex, withItemIndex: targetItemIndex)
                }
            } else if webViewPool.count < maxPreloadCount {
                let webView = createWebView()
                let coordinator = WebViewCoordinator(webView: webView)
                var wrapper = WebViewWrapper(webView: webView, coordinator: coordinator, itemIndex: targetItemIndex)
                webView.load(URLRequest(url: items[targetItemIndex].url))
                wrapper.isLoaded = true
                print("📱 PreloadedWebViewManager: Preloading WebView for item #\(targetItemIndex)")
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

    private func updateScrollMonitoring() {
        guard currentIndex < webViewPool.count,
              let coordinator = webViewPool[currentIndex].coordinator else { return }

        let currentWebView = webViewPool[currentIndex].webView

        // Point webBrowser at the pool's active WKWebView so the toolbar back
        // button (webBrowser.goBack / canGoBack) talks to the right view.
        webBrowser?.wkWebView = currentWebView

        // KVO-sync canGoBack from the active WKWebView into webBrowser.
        canGoBackObserver?.invalidate()
        canGoBackObserver = currentWebView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.webBrowser?.canGoBack = wv.canGoBack
            }
        }

        scrollMonitorCancellable?.cancel()
        scrollMonitorCancellable = coordinator.$isAtTop
            .sink { [weak self] value in
                self?.isAtTopOfCurrentPage = value
            }

        // Forward scroll progress to webBrowser so ContentView can collapse toolbars.
        coordinator.$scrollProgress
            .sink { [weak self] progress in
                self?.webBrowser?.scrollProgress = progress
            }
            .store(in: &cancellables)

        print("🔍 PreloadedWebViewManager: Monitoring scroll for WebView at index \(currentIndex)")
    }
}
