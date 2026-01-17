# Tab 6 Context - WebView Pool & Memory Management

## Your Mission
Implement a smart WebView pool that manages ~9 WKWebViews efficiently (3 tabs × 3 webpages each), handles preloading, memory pressure, and ensures instant navigation without any loading delays.

## Component Overview

You own the **WebView Pool** system - the engine that makes navigation feel instant. You manage a pool of WKWebViews, preload content strategically, and handle memory pressure gracefully. Think of yourself as the memory optimizer who ensures users never see a loading screen.

## Files You Own

```
shtell/Features/Navigation/WebViewPool/
├── WebViewPool.swift              # Core pool management
├── TabManager.swift               # Tab data and state
├── PreloadStrategy.swift          # Smart preloading logic
├── MemoryManager.swift            # Memory pressure handling
└── WebViewFactory.swift           # WebView creation/config
```

## Implementation Requirements

### 1. WebView Pool Core

Create `WebViewPool.swift`:

```swift
import WebKit

class WebViewPool {
    // Pool configuration
    static let maxWebViews = 9  // 3 tabs × 3 pages
    static let maxMemoryMB = 200

    // The pool
    private var activeWebViews: [UUID: WKWebView] = [:]
    private var recycledWebViews: [WKWebView] = []

    // Current state
    private var loadedTabs: Set<UUID> = []
    private var memoryUsageMB: Int = 0

    // WebView management
    func getWebView(for identifier: WebViewIdentifier) -> WKWebView {
        // Return existing or create new
    }

    func recycleWebView(_ webView: WKWebView) {
        // Clean and add to recycled pool
    }

    func preloadURL(_ url: URL, identifier: WebViewIdentifier) {
        // Load URL in background
    }

    struct WebViewIdentifier {
        let tabID: UUID
        let position: Position // .previous, .current, .next

        enum Position {
            case previous
            case current
            case next
        }
    }
}
```

### 2. Tab Manager

Create `TabManager.swift`:

```swift
class TabManager: ObservableObject {
    // Tab structure
    struct Tab {
        let id: UUID
        var webpages: [Webpage]
        var currentIndex: Int
        var isLoaded: Bool

        struct Webpage {
            let url: URL
            var scrollPosition: CGPoint
            var isLoaded: Bool
            var favicon: UIImage?
            var title: String?
        }
    }

    @Published var tabs: [Tab] = []
    @Published var currentTabIndex: Int = 0

    // Tab lifecycle
    func loadTab(at index: Int) {
        guard index < tabs.count else { return }
        let tab = tabs[index]

        // Load current + adjacent webpages
        let indicesToLoad = [
            max(0, tab.currentIndex - 1),  // Previous
            tab.currentIndex,                // Current
            min(tab.webpages.count - 1, tab.currentIndex + 1)  // Next
        ]

        for pageIndex in indicesToLoad {
            let webpage = tab.webpages[pageIndex]
            preloadWebpage(webpage, in: tab)
        }
    }

    func unloadTab(at index: Int) {
        // Release WebViews for this tab
    }

    private func preloadWebpage(_ webpage: Webpage, in tab: Tab) {
        let identifier = WebViewPool.WebViewIdentifier(
            tabID: tab.id,
            position: determinePosition(webpage, in: tab)
        )
        webViewPool.preloadURL(webpage.url, identifier: identifier)
    }
}
```

### 3. Preload Strategy

Create `PreloadStrategy.swift`:

```swift
class PreloadStrategy {
    // Strategy configuration
    struct Config {
        let tabRadius: Int = 1       // Load ±1 tabs
        let pageRadius: Int = 1      // Load ±1 pages per tab
        let priorityDelay: TimeInterval = 0.0   // Current = immediate
        let adjacentDelay: TimeInterval = 0.2   // Adjacent = 200ms delay
        let backgroundDelay: TimeInterval = 0.5  // Background = 500ms delay
    }

    private let config = Config()
    private var loadQueue: OperationQueue

    func calculateLoadPriority(
        tabIndex: Int,
        currentTabIndex: Int,
        pageIndex: Int,
        currentPageIndex: Int
    ) -> LoadPriority {
        let tabDistance = abs(tabIndex - currentTabIndex)
        let pageDistance = abs(pageIndex - currentPageIndex)

        if tabDistance == 0 && pageDistance == 0 {
            return .immediate  // Current tab, current page
        } else if tabDistance == 0 && pageDistance == 1 {
            return .high      // Current tab, adjacent page
        } else if tabDistance == 1 && pageDistance == 0 {
            return .medium    // Adjacent tab, current page
        } else {
            return .low       // Everything else
        }
    }

    enum LoadPriority {
        case immediate
        case high
        case medium
        case low
        case none
    }

    func schedulePreload(
        url: URL,
        priority: LoadPriority,
        completion: @escaping (WKWebView) -> Void
    ) {
        let delay: TimeInterval
        switch priority {
        case .immediate: delay = 0.0
        case .high: delay = 0.2
        case .medium: delay = 0.5
        case .low: delay = 1.0
        case .none: return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Perform preload
        }
    }
}
```

### 4. Memory Manager

Create `MemoryManager.swift`:

```swift
class MemoryManager {
    // Memory thresholds
    static let warningThresholdMB = 150
    static let criticalThresholdMB = 180

    private var currentUsageMB: Int = 0
    private var memoryPressureLevel: MemoryPressureLevel = .normal

    enum MemoryPressureLevel {
        case normal    // <150MB
        case warning   // 150-180MB
        case critical  // >180MB
    }

    func registerMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        memoryPressureLevel = .critical
        performEmergencyCleanup()
    }

    func performEmergencyCleanup() {
        // 1. Release all recycled WebViews
        // 2. Unload non-adjacent tabs
        // 3. Clear WebView caches
        // 4. Force garbage collection
    }

    func shouldLoadNewWebView() -> Bool {
        return currentUsageMB < Self.warningThresholdMB
    }

    func priorityForMemoryLevel() -> PreloadStrategy.LoadPriority {
        switch memoryPressureLevel {
        case .normal:
            return .high
        case .warning:
            return .medium
        case .critical:
            return .none  // Stop all preloading
        }
    }
}
```

### 5. WebView Factory

Create `WebViewFactory.swift`:

```swift
class WebViewFactory {
    // Shared configuration for all WebViews
    private lazy var configuration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()

        // Optimize for performance
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.suppressesIncrementalRendering = true

        // Privacy
        config.websiteDataStore = .default()

        // Disable internal scrolling (Tab 3 handles gestures)
        config.preferences.javaScriptEnabled = true

        return config
    }()

    func createWebView() -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Disable scrolling (we handle gestures)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        // Optimize rendering
        webView.configuration.preferences.setValue(
            true,
            forKey: "acceleratedDrawingEnabled"
        )

        return webView
    }

    func configureForPreloading(_ webView: WKWebView) {
        // Lower priority for background loading
        webView.configuration.processPool = WKProcessPool()
    }

    func reset(_ webView: WKWebView) {
        // Clear for recycling
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)

        // Clear back/forward list
        webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: {}
        )
    }
}
```

## Pool Management Strategy

### Loading Priority
1. **Current tab, current page**: Immediate (0ms)
2. **Current tab, adjacent pages**: High (200ms)
3. **Adjacent tabs, current page**: Medium (500ms)
4. **Other**: Low priority or skip

### Memory Strategy
- **Normal (<150MB)**: Full preloading
- **Warning (150-180MB)**: Reduce to current tab only
- **Critical (>180MB)**: Stop preloading, recycle aggressively

### Recycling Rules
1. Keep current tab's 3 WebViews always
2. Keep adjacent tabs if memory allows
3. Recycle others after 30 seconds unused
4. Emergency: Keep only current webpage

## Integration Points

### With Navigation Controller (Tab 2)
```swift
// Tab 2 requests WebViews
func getWebViewForNavigation(
    tabID: UUID,
    direction: NavigationDirection
) -> WKWebView {
    return webViewPool.getWebView(for: identifier)
}
```

### With Tab 3 (Vertical)
```swift
// Provide WebViews for vertical navigation
func getNextWebpage(in tab: UUID) -> WKWebView? {
    return getWebView(for: .init(tabID: tab, position: .next))
}

func getPreviousWebpage(in tab: UUID) -> WKWebView? {
    return getWebView(for: .init(tabID: tab, position: .previous))
}
```

### With Tab 4 (Horizontal)
```swift
// Load/unload tabs on switch
func handleTabSwitch(from: Int, to: Int) {
    unloadTab(at: from - 2)  // Unload far tab
    loadTab(at: to + 1)       // Preload next adjacent
}
```

### With Tab 5 (Toolbar)
```swift
// Provide favicons when loaded
func webView(_ webView: WKWebView, didLoadFavicon favicon: UIImage) {
    toolbar.updateFavicon(for: tabID, favicon: favicon)
}
```

## Testing Your Component

### Unit Tests
```swift
func testPoolCreation()
func testWebViewRecycling()
func testPreloadStrategy()
func testMemoryPressureHandling()
func testTabLoading()
func testMaxWebViewLimit()
```

### Performance Tests
- Load 9 WebViews simultaneously
- Memory usage under 200MB
- Preload time <500ms
- Recycling efficiency
- Memory warning recovery

### Stress Tests
- Rapid tab switching (20 switches in 10s)
- Memory pressure simulation
- Network timeout handling
- JavaScript heavy sites
- Video content loading

## Common Pitfalls to Avoid

1. **Don't enable WebView scrolling** - Tab 3 handles all scrolling
2. **Don't load all URLs immediately** - Follow priority strategy
3. **Don't ignore memory warnings** - Critical for app stability
4. **Don't recreate WebViews unnecessarily** - Recycle when possible
5. **Don't block main thread** - All loading async

## Success Criteria

Your pool succeeds when:
1. Navigation feels instant (no loading screens)
2. Memory stays under 200MB
3. Handles memory pressure gracefully
4. Preloading is intelligent and efficient
5. No crashes or freezes

## Delivery

Push your code to:
```bash
git checkout main
git add shtell/Features/Navigation/WebViewPool/
git commit -m "feat: Implement WebView pool with smart preloading for TestFlight 2.1.0"
git push
```

---

**Remember**: You're the performance guardian. Every millisecond counts, every megabyte matters. Make the pool so efficient that users think all content is stored locally!