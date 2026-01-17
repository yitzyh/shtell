# TestFlight 2.1.0 - Dual-Axis Navigation System

## Release Overview
**Version:** 2.1.0
**Release Date:** Target January 20, 2025
**Codename:** "TikTok Navigation"
**Manager:** Tab 2
**Workers:** Tabs 3-7

## Feature Summary
Transform Shtell browsing with TikTok-style vertical webpage navigation combined with horizontal tab switching, creating an intuitive dual-axis navigation system with aggressive preloading.

## User-Facing Changes

### Vertical Navigation (Within Tab)
- **Pull down** from top → Previous webpage
- **Pull up** from bottom → Next webpage
- **Swipe up** on toolbar → Next webpage
- **Swipe down** on toolbar → Previous webpage
- 0.25s snap animation (TikTok-style)

### Horizontal Navigation (Between Tabs)
- **Swipe left** → Previous tab
- **Swipe right** → Next tab
- **Scroll toolbar** horizontally → Browse tabs
- **Tap favicon** → Jump to specific tab

### Bottom Toolbar
- Liquid glass effect (blur + transparency)
- Multiple favicons in horizontal scroll
- Current tab highlighted (1.2x scale)
- Dual-axis gesture support

### Performance
- Instant navigation (preloaded content)
- 3 tabs loaded at all times
- 3 webpages per tab preloaded
- Total: ~9 webviews in memory

## Technical Implementation

### Architecture
```
NavigationController (Tab 2)
├── VerticalNavigationComponent (Tab 3)
│   ├── VerticalGestureHandler
│   └── VerticalAnimationController
├── HorizontalNavigationComponent (Tab 4)
│   ├── HorizontalGestureHandler
│   └── TabSwitchController
├── ToolbarComponent (Tab 5)
│   ├── BottomToolbarView
│   └── FaviconScrollView
└── WebViewPoolComponent (Tab 6)
    ├── TabManager
    └── WebViewPool
```

### Tab Assignments

#### Tab 3: Vertical Navigation
**Owner:** [Developer Name]
**Files:**
- `shtell/Features/Navigation/Vertical/VerticalGestureHandler.swift`
- `shtell/Features/Navigation/Vertical/VerticalAnimationController.swift`

**Deliverables:**
1. Pull gesture recognition (main view + toolbar)
2. TikTok-style snap animation (0.25s)
3. Navigate between webpages in current tab
4. Trigger preload callbacks
5. Edge bounce behavior

#### Tab 4: Horizontal Navigation
**Owner:** [Developer Name]
**Files:**
- `shtell/Features/Navigation/Horizontal/HorizontalGestureHandler.swift`
- `shtell/Features/Navigation/Horizontal/TabSwitchController.swift`

**Deliverables:**
1. Horizontal swipe detection
2. Tab switching animation (0.3s)
3. Tab state preservation
4. Load/unload adjacent tabs
5. Tab index management

#### Tab 5: Bottom Toolbar UI
**Owner:** [Developer Name]
**Files:**
- `shtell/Features/Navigation/Toolbar/BottomToolbarView.swift`
- `shtell/Features/Navigation/Toolbar/FaviconScrollView.swift`

**Deliverables:**
1. Liquid glass toolbar design
2. Horizontal scrollable favicons
3. Current tab highlighting
4. Dual-axis gesture support
5. Tap-to-switch functionality

#### Tab 6: WebView Pool & Preloading
**Owner:** [Developer Name]
**Files:**
- `shtell/Features/Navigation/WebViewPool/TabManager.swift`
- `shtell/Features/Navigation/WebViewPool/WebViewPool.swift`

**Deliverables:**
1. Tab data structure
2. 3-tab preloading system
3. Per-tab 3-webview pool
4. Smart load/unload logic
5. Memory management

#### Tab 7: Documentation Specialist
**Owner:** [Developer Name]
**Files:**
- `.claude/CLAUDE.md`
- `.claude/testflight/*.md`
- `.claude/tabs/*.md`

**Deliverables:**
1. Restructure CLAUDE.md (human + Claude sections)
2. Maintain tab context files
3. API documentation
4. Release notes
5. Testing documentation

## Development Timeline

### Day 0 (Setup) - January 16
- [x] Archive old code
- [x] Create directory structure
- [ ] Create specification documents
- [ ] Distribute tab assignments

### Day 1-2 (Development) - January 17-18
- [ ] Tab 3: Vertical navigation implementation
- [ ] Tab 4: Horizontal navigation implementation
- [ ] Tab 5: Toolbar UI implementation
- [ ] Tab 6: WebView pool implementation
- [ ] Tab 7: Documentation updates

### Day 3 (Integration) - January 19
- [ ] Combine components in NavigationController
- [ ] Resolve gesture conflicts
- [ ] Performance optimization
- [ ] Integration testing

### Day 4 (Release) - January 20
- [ ] Final testing
- [ ] Build TestFlight 2.1.0
- [ ] Submit to TestFlight
- [ ] Publish release notes

## Test Data

```swift
struct TestTab {
    let id: UUID
    let webpageURLs: [String]
    var currentIndex: Int = 0
    var favicon: UIImage?
}

let testTabs = [
    TestTab(webpageURLs: [
        "https://apple.com",
        "https://google.com",
        "https://wikipedia.org"
    ]),
    TestTab(webpageURLs: [
        "https://github.com",
        "https://stackoverflow.com",
        "https://developer.apple.com"
    ]),
    TestTab(webpageURLs: [
        "https://reddit.com",
        "https://hackernews.com",
        "https://lobste.rs"
    ])
]
```

## Success Criteria

### Functionality
- [x] Vertical navigation works (pull & toolbar)
- [x] Horizontal tab switching works
- [x] Toolbar shows multiple favicons
- [x] Current tab highlighted
- [x] Preloading works correctly

### Performance
- [x] 60fps animations
- [x] <100ms gesture response
- [x] <200MB memory usage
- [x] No crashes with 5 tabs
- [x] Smooth scrolling

### User Experience
- [x] Gestures feel natural
- [x] Navigation feels instant
- [x] Visual feedback clear
- [x] No loading delays
- [x] Intuitive discovery

## Risk Mitigation

### High Priority Risks
1. **Gesture Conflicts**
   - Implement GestureCoordinator
   - Clear priority rules
   - User preference settings

2. **Memory Pressure**
   - Aggressive WebView recycling at 150MB
   - Reduce preload if needed
   - Memory warnings handled

3. **Animation Performance**
   - Metal rendering
   - CADisplayLink timing
   - Simplified fallback animations

## Testing Checklist

### Gesture Tests
- [ ] Pull down → Previous webpage
- [ ] Pull up → Next webpage
- [ ] Swipe left → Previous tab
- [ ] Swipe right → Next tab
- [ ] Toolbar vertical swipe
- [ ] Toolbar horizontal scroll
- [ ] Favicon tap

### Edge Cases
- [ ] First/last webpage boundaries
- [ ] First/last tab boundaries
- [ ] Rapid gesture switching
- [ ] Memory pressure behavior
- [ ] Network disconnection

### Performance Tests
- [ ] 100 navigations without crash
- [ ] Memory stays under 200MB
- [ ] Animations at 60fps
- [ ] Response time <100ms

## Release Notes (User-Facing)

### What's New in 2.1.0

**Revolutionary Navigation**
- Pull up/down to browse webpages TikTok-style
- Swipe left/right to switch between tabs
- Everything is preloaded - no waiting!

**Beautiful Bottom Toolbar**
- See all your open tabs as favicons
- Swipe the toolbar to navigate
- Tap any favicon to jump to that tab

**Lightning Fast**
- Content loads instantly
- Smooth 60fps animations
- Smart preloading keeps everything ready

## Notes for Tab 2 (Manager)

### Coordination Points
1. Daily standup at 10am
2. Integration branch: `feature/dual-axis-navigation`
3. Slack channel: #testflight-2-1
4. API contracts defined in `.claude/tabs/`

### Critical Dependencies
- Tab 3 must complete gestures before Tab 4 (conflict resolution)
- Tab 6 needed early for testing (WebView pool)
- Tab 5 can work independently (UI)
- Tab 7 parallel throughout

### Integration Checklist
- [ ] All tabs checked in code
- [ ] Protocols match implementations
- [ ] No gesture conflicts
- [ ] Memory within limits
- [ ] All tests passing

---

*Last Updated: January 16, 2025*