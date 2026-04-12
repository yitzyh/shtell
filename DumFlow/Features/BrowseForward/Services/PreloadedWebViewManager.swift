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
        private var lastOffset: CGFloat = 0

        /// Scroll distance (pts) past the threshold needed to fully collapse the toolbar.
        private let collapseDistance: CGFloat = 200
        /// User must scroll this far down before toolbar starts collapsing.
        private let collapseThreshold: CGFloat = 150

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
            let delta = offset - lastOffset
            lastOffset = offset

            isAtTop = offset <= 80

            if delta < 0 {
                // Scrolling up — snap toolbar fully open immediately
                scrollProgress = 0.0
            } else if offset > collapseThreshold {
                // Scrolling down past threshold — gradually collapse
                let progress = min(1.0, max(0.0, (offset - collapseThreshold) / collapseDistance))
                scrollProgress = max(scrollProgress, progress)
            }
        }

        // MARK: - UIScrollViewDelegate
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            checkScrollPosition(scrollView)
        }

        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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

    }

    /// Set dependencies after initialization
    func setDependencies(browseForwardViewModel: BrowseForwardViewModel,
                        webBrowser: WebBrowser,
                        webPageViewModel: WebPageViewModel) {
        self.browseForwardViewModel = browseForwardViewModel
        self.webBrowser = webBrowser
        self.webPageViewModel = webPageViewModel
    }

    // MARK: - Public Methods

    /// Initialize WebViews for the first batch of items
    func initializeWebViews() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else {
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


            webViewPool.append(wrapper)
        }

        // Monitor scroll position of current WebView
        updateScrollMonitoring()

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

    }

    /// Navigate to the next item
    func navigateToNext() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else {
            return
        }

        if webViewPool.isEmpty {
            initializeWebViews()
            return
        }

        guard currentIndex < webViewPool.count else {
            return
        }

        let nextItemIndex = webViewPool[currentIndex].itemIndex + 1
        guard nextItemIndex < items.count else { return }


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
    }

    // MARK: - Private Methods

    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false

        // .automatic adds system safe area (status bar) automatically.
        // We add extra inset so page content starts below our overlay toolbars.
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: 60, right: 0)
        webView.scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 44, left: 0, bottom: 60, right: 0)

        return webView
    }

    private func preloadNextWebView() {
        guard let items = browseForwardViewModel?.displayedItems,
              !items.isEmpty else { return }

        guard currentIndex < webViewPool.count else {
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
    }

    private func updateScrollMonitoring() {
        guard currentIndex < webViewPool.count,
              let coordinator = webViewPool[currentIndex].coordinator else { return }

        let currentWebView = webViewPool[currentIndex].webView

        // Point webBrowser at the pool's active WKWebView so the toolbar back
        // button (webBrowser.goBack / canGoBack) talks to the right view.
        webBrowser?.wkWebView = currentWebView

        // Sync current item's URL into webBrowser so toolbar actions (save, comment) work.
        if let items = browseForwardViewModel?.displayedItems,
           let url = items[safe: webViewPool[currentIndex].itemIndex]?.url {
            webBrowser?.urlString = url.absoluteString
        }

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

        // Forward scroll state to webBrowser for toolbar animations.
        coordinator.$scrollProgress
            .sink { [weak self] progress in
                self?.webBrowser?.scrollProgress = progress
            }
            .store(in: &cancellables)

        coordinator.$isAtTop
            .sink { [weak self] atTop in
                self?.webBrowser?.isAtTopOfPage = atTop
            }
            .store(in: &cancellables)

    }
}
