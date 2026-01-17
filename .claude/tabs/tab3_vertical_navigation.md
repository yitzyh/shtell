# Tab 3 Context - Vertical Navigation Component

## Your Mission
Implement TikTok-style vertical navigation for browsing webpages within a single tab. Users can pull up/down or swipe the toolbar vertically to navigate between webpages with smooth snap animations.

## Component Overview

You own the **Vertical Navigation** system that allows users to navigate between webpages in the current tab using vertical gestures. This is similar to how TikTok users swipe between videos, but for web content.

## Files You Own

```
shtell/Features/Navigation/Vertical/
├── VerticalGestureHandler.swift      # Main gesture recognition
├── VerticalAnimationController.swift  # Snap animations
└── VerticalStateManager.swift        # Navigation state
```

## Implementation Requirements

### 1. Gesture Recognition

Create `VerticalGestureHandler.swift`:

```swift
protocol VerticalNavigationDelegate: AnyObject {
    func willNavigateToNext()
    func didNavigateToNext()
    func willNavigateToPrevious()
    func didNavigateToPrevious()
    func canNavigateToNext() -> Bool
    func canNavigateToPrevious() -> Bool
}

class VerticalGestureHandler: NSObject {
    // Configuration
    static let velocityThreshold: CGFloat = 500
    static let distanceThreshold: CGFloat = 50

    weak var delegate: VerticalNavigationDelegate?

    // Gesture recognizers
    private var panGestureRecognizer: UIPanGestureRecognizer!

    // State tracking
    private var startPoint: CGPoint = .zero
    private var isNavigating = false

    func attachToView(_ view: UIView) {
        // Attach pan gesture to main view
    }

    func attachToToolbar(_ toolbar: UIView) {
        // Attach vertical swipe to toolbar
    }
}
```

### 2. Animation Controller

Create `VerticalAnimationController.swift`:

```swift
class VerticalAnimationController {
    // TikTok-style timing
    static let animationDuration: TimeInterval = 0.25
    static let springDamping: CGFloat = 0.8
    static let initialSpringVelocity: CGFloat = 0.5

    func animateToNext(
        currentView: UIView,
        nextView: UIView,
        in container: UIView,
        completion: @escaping () -> Void
    ) {
        // Snap animation going up
    }

    func animateToPrevious(
        currentView: UIView,
        previousView: UIView,
        in container: UIView,
        completion: @escaping () -> Void
    ) {
        // Snap animation going down
    }

    func cancelAnimation() {
        // Handle interrupted animations
    }
}
```

### 3. State Management

Create `VerticalStateManager.swift`:

```swift
class VerticalStateManager: ObservableObject {
    enum NavigationState {
        case idle
        case dragging(translation: CGFloat)
        case animating(direction: Direction)
        case bouncing // At edges
    }

    enum Direction {
        case up    // To next webpage
        case down  // To previous webpage
    }

    @Published var state: NavigationState = .idle
    @Published var currentIndex: Int = 0
    @Published var canGoNext: Bool = true
    @Published var canGoPrevious: Bool = false
}
```

## Key Behaviors

### Pull Gestures
1. **Pull Down** (from top): Navigate to previous webpage
2. **Pull Up** (from bottom): Navigate to next webpage
3. **Threshold**: 50 points minimum drag distance
4. **Velocity**: >500 points/sec triggers navigation even with less distance

### Toolbar Swipes
1. **Swipe Up** on toolbar: Next webpage
2. **Swipe Down** on toolbar: Previous webpage
3. Should feel responsive and immediate

### Animation Details
- Duration: **0.25 seconds** (match TikTok timing)
- Type: Spring animation with damping
- Feel: Snappy, not floaty
- Interruption: Must handle gesture cancellation smoothly

### Edge Behavior
- At first webpage: Bounce animation when pulling down
- At last webpage: Bounce animation when pulling up
- Visual feedback that you've reached the end

## Integration Points

### With NavigationController (Tab 2)
```swift
class NavigationController {
    let verticalNav: VerticalNavigationComponent // Your component

    func setupVerticalNavigation() {
        verticalNav.delegate = self
    }
}

extension NavigationController: VerticalNavigationDelegate {
    func willNavigateToNext() {
        // Tab 2 handles WebView swap
    }
}
```

### With WebView Pool (Tab 6)
You don't manage WebViews directly. You just notify the NavigationController when navigation should happen, and Tab 6 provides the preloaded WebViews.

### With Toolbar (Tab 5)
Tab 5 creates the toolbar UI, but you attach gesture recognizers to detect vertical swipes on it.

## Testing Your Component

### Unit Tests
```swift
func testVerticalGestureRecognition()
func testVelocityThreshold()
func testDistanceThreshold()
func testEdgeBouncing()
func testAnimationTiming()
func testGestureCancellation()
```

### Manual Testing
1. Pull down slowly → Should navigate if >50 points
2. Quick flick up → Should navigate even with small distance
3. Pull at edges → Should bounce
4. Start pull then cancel → Should snap back
5. Rapid pulls → Should queue properly

## Performance Requirements

- Gesture response: <50ms
- Animation: Consistent 60fps
- Memory: Minimal overhead (<5MB)
- No gesture conflicts with Tab 4's horizontal gestures

## Common Pitfalls to Avoid

1. **Don't manage WebViews** - Tab 6 handles that
2. **Don't handle horizontal gestures** - Tab 4 owns those
3. **Don't create the toolbar UI** - Tab 5 does that
4. **Don't block during animation** - Keep gestures responsive

## Example Usage

```swift
// In your implementation
let gestureHandler = VerticalGestureHandler()
let animator = VerticalAnimationController()
let state = VerticalStateManager()

// NavigationController will connect everything
gestureHandler.delegate = navigationController
gestureHandler.attachToView(mainWebViewContainer)
gestureHandler.attachToToolbar(bottomToolbar)
```

## Questions You Might Have

**Q: How do I know if there are more webpages?**
A: The delegate methods `canNavigateToNext()` and `canNavigateToPrevious()` tell you.

**Q: What if user pulls horizontally?**
A: Ignore it. If horizontal movement > vertical, let Tab 4 handle it.

**Q: How do I test animation timing?**
A: Use XCTest's expectation with 0.25s timeout to verify animation duration.

## Success Criteria

Your component is successful when:
1. Vertical navigation feels exactly like TikTok
2. No conflicts with horizontal navigation
3. Animations are smooth 60fps
4. Edge bouncing provides clear feedback
5. Both pull and toolbar swipes work perfectly

## Delivery

Push your code to:
```bash
git checkout main
git add shtell/Features/Navigation/Vertical/
git commit -m "feat: Implement vertical navigation component for TestFlight 2.1.0"
git push
```

---

**Remember**: You're building the vertical navigation engine. Keep it focused, fast, and smooth. The TikTok-style snap is key to the user experience!