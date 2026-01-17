# Tab 5 Context - Bottom Toolbar UI Component

## Your Mission
Create a beautiful liquid glass bottom toolbar that displays tab favicons, supports dual-axis gestures, and provides visual feedback for the current tab. Think Safari meets TikTok with a premium glass aesthetic.

## Component Overview

You own the **Bottom Toolbar UI** that serves as the visual control center for navigation. Users can see all their open tabs as favicons, scroll through them, and use the toolbar for both vertical and horizontal navigation gestures.

## Files You Own

```
shtell/Features/Navigation/Toolbar/
├── BottomToolbarView.swift          # Main toolbar container
├── FaviconScrollView.swift          # Horizontal favicon scroller
├── ToolbarGestureCoordinator.swift  # Dual-axis gesture support
├── GlassEffectView.swift            # Liquid glass visual effect
└── FaviconItemView.swift           # Individual favicon display
```

## Implementation Requirements

### 1. Main Toolbar View

Create `BottomToolbarView.swift`:

```swift
import SwiftUI

struct BottomToolbarView: View {
    // View Model
    @ObservedObject var viewModel: ToolbarViewModel

    // Design constants
    static let height: CGFloat = 60
    static let blurRadius: CGFloat = 20
    static let backgroundOpacity: Double = 0.92

    var body: some View {
        ZStack {
            // Liquid glass background
            GlassEffectView()

            // Favicon scroll view
            FaviconScrollView(
                favicons: viewModel.favicons,
                currentIndex: viewModel.currentTabIndex,
                onFaviconTapped: viewModel.handleFaviconTap
            )
        }
        .frame(height: Self.height)
        .overlay(
            // Top border line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

class ToolbarViewModel: ObservableObject {
    @Published var favicons: [FaviconItem] = []
    @Published var currentTabIndex: Int = 0
    @Published var isScrolling: Bool = false

    func handleFaviconTap(at index: Int) {
        // Notify Tab 4 to switch tabs
    }

    func highlightTab(at index: Int) {
        withAnimation(.spring(response: 0.3)) {
            currentTabIndex = index
        }
    }
}
```

### 2. Favicon Scroll View

Create `FaviconScrollView.swift`:

```swift
struct FaviconScrollView: View {
    let favicons: [FaviconItem]
    let currentIndex: Int
    let onFaviconTapped: (Int) -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favicons.indices, id: \.self) { index in
                        FaviconItemView(
                            item: favicons[index],
                            isSelected: index == currentIndex,
                            onTap: { onFaviconTapped(index) }
                        )
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: currentIndex) { newIndex in
                // Auto-scroll to selected favicon
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
```

### 3. Individual Favicon View

Create `FaviconItemView.swift`:

```swift
struct FaviconItemView: View {
    let item: FaviconItem
    let isSelected: Bool
    let onTap: () -> Void

    // Animation states
    @State private var isPressed: Bool = false
    @State private var glowIntensity: Double = 0

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Favicon image
                Image(uiImage: item.favicon ?? defaultFavicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: isSelected ? 40 : 32,
                        height: isSelected ? 40 : 32
                    )
                    .cornerRadius(8)
                    .shadow(
                        color: isSelected ? .blue.opacity(0.6) : .clear,
                        radius: isSelected ? 8 : 0
                    )

                // Page indicator dots (if multiple pages in tab)
                if item.pageCount > 1 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(item.pageCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 3, height: 3)
                        }
                    }
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3))
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}

struct FaviconItem {
    let id: UUID
    let favicon: UIImage?
    let title: String
    let pageCount: Int
    let url: URL?
}
```

### 4. Glass Effect View

Create `GlassEffectView.swift`:

```swift
struct GlassEffectView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: blurEffect)

        // Add gradient overlay for depth
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.1).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.3]

        view.layer.addSublayer(gradientLayer)

        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Update if needed
    }
}
```

### 5. Gesture Coordinator

Create `ToolbarGestureCoordinator.swift`:

```swift
class ToolbarGestureCoordinator: NSObject {
    // Gesture recognizers from Tab 3 & Tab 4
    private var verticalGesture: UIPanGestureRecognizer?
    private var horizontalGesture: UIPanGestureRecognizer?

    func attachGestures(to view: UIView) {
        // This coordinates with Tab 3 & Tab 4
        // They will attach their recognizers here
    }

    func configureGesturePriorities() {
        // Horizontal scroll has priority for small movements
        // Vertical swipe needs larger threshold
    }

    // Visual feedback during gestures
    func showVerticalIndicator(direction: Direction) {
        // Show arrow or glow
    }

    func showHorizontalIndicator(direction: Direction) {
        // Show swipe indicator
    }
}
```

## Visual Design Specifications

### Dimensions
- **Height**: 60pt total
- **Safe area**: Account for home indicator
- **Favicon size**: 32pt (normal), 40pt (selected)
- **Spacing**: 12pt between favicons
- **Padding**: 16pt horizontal

### Glass Effect
- **Blur**: Ultra thin material
- **Opacity**: 0.92 background
- **Border**: 0.5pt white at 20% opacity
- **Shadow**: Subtle top shadow for depth

### Animations
- **Selection**: Spring animation 0.3s
- **Tap feedback**: Scale to 0.95
- **Glow**: Pulse animation when selected
- **Auto-scroll**: Smooth centering

### Colors
- **Background**: System glass
- **Selected**: Blue glow (#007AFF)
- **Inactive**: 60% opacity
- **Border**: White 20% opacity

## Gesture Support

### What You Handle
1. **Favicon taps**: Direct tab switching
2. **Horizontal scroll**: Browse through favicons
3. **Visual feedback**: Show gesture indicators

### What Others Handle
1. **Vertical swipes**: Tab 3 attaches gestures
2. **Horizontal swipes**: Tab 4 attaches gestures
3. **WebView management**: Tab 6 provides content

## Integration Points

### With Tab 3 (Vertical)
```swift
// Tab 3 attaches vertical gesture to your toolbar
verticalNav.attachToToolbar(toolbarView)

// You provide visual feedback
func showVerticalSwipeIndicator(direction: .up) {
    // Display arrow or glow
}
```

### With Tab 4 (Horizontal)
```swift
// Update highlighted favicon when tab switches
func highlightFavicon(at index: Int) {
    viewModel.highlightTab(at: index)
}

// Notify when favicon tapped
func faviconTapped(at index: Int) {
    horizontalNav.switchToTab(at: index)
}
```

### With Tab 6 (WebView Pool)
```swift
// Get favicon for loaded webpage
func updateFavicon(for tabID: UUID, favicon: UIImage) {
    viewModel.updateFavicon(tabID: tabID, image: favicon)
}
```

## Testing Your Component

### Visual Tests
- Glass effect in light/dark mode
- Favicon scaling animation
- Selection highlighting
- Auto-scroll behavior
- Edge cases (1 tab, 5 tabs)

### Interaction Tests
- Tap to switch tabs
- Horizontal scroll smoothness
- Gesture feedback
- Animation performance
- Memory with many favicons

### Accessibility
- VoiceOver labels
- Dynamic Type support
- High contrast mode
- Haptic feedback

## Performance Requirements

- Render at 60fps during all animations
- Blur effect optimized for battery
- Smooth scrolling with 5+ favicons
- Instant tap response (<50ms)

## Success Criteria

Your toolbar succeeds when:
1. Glass effect looks premium
2. Favicons clearly show tab state
3. Current tab obviously highlighted
4. Gestures feel responsive
5. Animations are smooth and purposeful

## Delivery

Push your code to:
```bash
git checkout main
git add shtell/Features/Navigation/Toolbar/
git commit -m "feat: Implement liquid glass bottom toolbar for TestFlight 2.1.0"
git push
```

---

**Remember**: You're creating the visual centerpiece of the navigation system. Make it beautiful, functional, and delightful to use. The glass effect and smooth animations are key to the premium feel!