# Tab 4 Context - Horizontal Navigation Component

## Your Mission
Implement horizontal tab switching that allows users to swipe left/right between different browser tabs, similar to mobile Safari's tab switching but with instant preloaded content.

## Component Overview

You own the **Horizontal Navigation** system that manages tab switching through horizontal gestures. Users can swipe between tabs or use the toolbar's horizontal scroll to navigate their open tabs.

## Files You Own

```
shtell/Features/Navigation/Horizontal/
├── HorizontalGestureHandler.swift    # Swipe gesture recognition
├── TabSwitchAnimator.swift          # Tab transition animations
├── TabStateManager.swift            # Tab state and lifecycle
└── TabPreloadCoordinator.swift      # Adjacent tab loading
```

## Implementation Requirements

### 1. Gesture Handler

Create `HorizontalGestureHandler.swift`:

```swift
protocol HorizontalNavigationDelegate: AnyObject {
    func willSwitchToTab(at index: Int)
    func didSwitchToTab(at index: Int)
    func canSwitchToTab(at index: Int) -> Bool
    func numberOfTabs() -> Int
}

class HorizontalGestureHandler: NSObject {
    // Configuration
    static let velocityThreshold: CGFloat = 300
    static let distanceThreshold: CGFloat = 80

    weak var delegate: HorizontalNavigationDelegate?

    // Current state
    private var currentTabIndex: Int = 0
    private var isDragging = false

    func attachToView(_ view: UIView) {
        // Main view horizontal swipes
    }

    func attachToToolbar(_ toolbar: UIView) {
        // Toolbar horizontal scroll
    }

    func handleSwipeLeft() {
        // Switch to next tab
    }

    func handleSwipeRight() {
        // Switch to previous tab
    }
}
```

### 2. Tab Switch Animator

Create `TabSwitchAnimator.swift`:

```swift
class TabSwitchAnimator {
    // Animation timing (slightly slower than vertical)
    static let animationDuration: TimeInterval = 0.3
    static let springDamping: CGFloat = 0.85

    enum TransitionStyle {
        case slide
        case zoom
        case fade
    }

    func animateTabSwitch(
        from currentTab: UIView,
        to nextTab: UIView,
        direction: Direction,
        style: TransitionStyle = .slide,
        completion: @escaping () -> Void
    ) {
        // Smooth tab transition
    }

    func animateTabClose(
        tab: UIView,
        completion: @escaping () -> Void
    ) {
        // Tab closing animation
    }
}
```

### 3. Tab State Manager

Create `TabStateManager.swift`:

```swift
class TabStateManager: ObservableObject {
    struct Tab {
        let id: UUID
        var urlHistory: [URL]
        var currentURLIndex: Int
        var scrollPosition: CGPoint
        var favicon: UIImage?
        var title: String
        var lastAccessed: Date
        var isLoaded: Bool
    }

    @Published var tabs: [Tab] = []
    @Published var currentTabIndex: Int = 0
    @Published var visibleTabIndices: Set<Int> = []

    // Tab limits
    static let maxTabs = 5
    static let preloadRadius = 1 // Load ±1 tabs

    func createNewTab(with url: URL? = nil) -> Tab {
        // Create and add new tab
    }

    func closeTab(at index: Int) {
        // Remove tab and adjust indices
    }

    func switchToTab(at index: Int) {
        // Update current tab and trigger preloading
    }
}
```

### 4. Preload Coordinator

Create `TabPreloadCoordinator.swift`:

```swift
class TabPreloadCoordinator {
    private let tabManager: TabStateManager

    // Which tabs should be loaded
    func tabsToPreload(currentIndex: Int, totalTabs: Int) -> [Int] {
        // Return indices of tabs to keep loaded
        // Current + adjacent (left & right)
    }

    func loadTab(at index: Int) {
        // Request Tab 6 to load WebViews for this tab
    }

    func unloadTab(at index: Int) {
        // Tell Tab 6 to release WebViews for this tab
    }

    func handleTabSwitch(from oldIndex: Int, to newIndex: Int) {
        // Update preloading strategy
        // Load: newIndex ± 1
        // Unload: tabs outside radius
    }
}
```

## Key Behaviors

### Horizontal Swipes
1. **Swipe Left**: Next tab (index + 1)
2. **Swipe Right**: Previous tab (index - 1)
3. **Threshold**: 80 points minimum (wider than vertical)
4. **Velocity**: >300 points/sec for quick switches

### Tab Management
1. **Max Tabs**: 5 tabs maximum
2. **Preloading**: Current tab + 1 left + 1 right
3. **Memory**: Unload tabs beyond radius
4. **State**: Preserve scroll position and history

### Animation Style
- Duration: **0.3 seconds** (slightly slower than vertical)
- Style: Slide transition (like Safari)
- Direction: Follow swipe direction
- Overlap: Slight parallax effect

### Edge Behavior
- At first tab: Elastic bounce on swipe right
- At last tab: Elastic bounce on swipe left
- Visual feedback at boundaries

## Integration Points

### With NavigationController (Tab 2)
```swift
class NavigationController {
    let horizontalNav: HorizontalNavigationComponent // Your component

    func setupHorizontalNavigation() {
        horizontalNav.delegate = self
    }
}

extension NavigationController: HorizontalNavigationDelegate {
    func willSwitchToTab(at index: Int) {
        // Prepare tab switch
    }
}
```

### With Toolbar (Tab 5)
```swift
// Tab 5 notifies you when favicon is tapped
func faviconTapped(at index: Int) {
    switchToTab(at: index)
}

// You notify Tab 5 to update highlighted favicon
func didSwitchToTab(at index: Int) {
    toolbar.highlightFavicon(at: index)
}
```

### With WebView Pool (Tab 6)
```swift
// Request WebViews for specific tab
func loadWebViewsForTab(at index: Int) {
    webViewPool.loadTab(tabID: tabs[index].id)
}

// Release WebViews when unloading
func unloadWebViewsForTab(at index: Int) {
    webViewPool.releaseTab(tabID: tabs[index].id)
}
```

### With Vertical Navigation (Tab 3)
```swift
// Gesture priority
if abs(horizontalVelocity) > abs(verticalVelocity) {
    // You handle it (horizontal wins)
} else {
    // Tab 3 handles it (vertical wins)
}
```

## Tab Data Structure

```swift
// Example tab setup for testing
let testTabs = [
    Tab(
        id: UUID(),
        urlHistory: [
            URL(string: "https://apple.com")!,
            URL(string: "https://developer.apple.com")!
        ],
        currentURLIndex: 0,
        favicon: UIImage(named: "apple_favicon"),
        title: "Apple"
    ),
    Tab(
        id: UUID(),
        urlHistory: [
            URL(string: "https://github.com")!
        ],
        currentURLIndex: 0,
        favicon: UIImage(named: "github_favicon"),
        title: "GitHub"
    ),
    // ... more tabs
]
```

## Testing Your Component

### Unit Tests
```swift
func testHorizontalSwipeRecognition()
func testTabSwitchAnimation()
func testTabPreloading()
func testTabStatePreservation()
func testMaxTabLimit()
func testEdgeBouncing()
```

### Manual Testing
1. Swipe between 3 tabs rapidly
2. Create 5 tabs (max) and test limit
3. Switch tabs and verify state preserved
4. Test toolbar favicon sync
5. Memory test with 5 tabs loaded

## Performance Requirements

- Tab switch: <100ms response
- Animation: Smooth 60fps
- Memory: ~40MB per tab (3 WebViews each)
- Preload time: <500ms per tab

## Common Pitfalls to Avoid

1. **Don't handle vertical gestures** - Tab 3 owns those
2. **Don't create WebViews** - Tab 6 manages the pool
3. **Don't render the toolbar** - Tab 5 handles UI
4. **Don't block during animations** - Keep responsive

## Success Criteria

Your component succeeds when:
1. Tab switching feels instant (preloaded)
2. Animations are smooth and directional
3. Tab state perfectly preserved
4. Memory usage stays under control
5. No conflicts with vertical navigation

## Delivery

Push your code to:
```bash
git checkout main
git add shtell/Features/Navigation/Horizontal/
git commit -m "feat: Implement horizontal tab navigation for TestFlight 2.1.0"
git push
```

---

**Remember**: You're building the tab management engine. Make tab switching feel effortless and instant. The preloading strategy is critical for the "no loading" experience!