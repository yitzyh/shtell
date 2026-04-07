# Session Handoff — 2026-04-02

## Session Summary

This session addressed two areas: a Sign in with Apple entitlement fix (P0) and a full rewrite of the TikTok-style vertical navigation system (P1). Swipe-up navigation is working. Swipe-down received a gesture fix but has not yet been tested on device.

---

## What Was Accomplished

### P0: Sign in with Apple Fix

- Added `com.apple.developer.applesignin` entitlement to `DumFlow/DumFlow.entitlements`
- **Manual step still required:** In Xcode → Target → Signing & Capabilities → add "Sign in with Apple" capability. Without this, the entitlement alone is insufficient.

### P1: TikTok-Style Vertical Navigation

#### Changes Made

| File | Change |
|------|--------|
| `DumFlow/Shared/Views/ContentView.swift` | Replaced `WebView` with `VerticalNavigationView()` |
| `DumFlow/Features/BrowseForward/Views/VerticalNavigationView.swift` | Full rewrite — uses `PreloadedWebViewManager` pool, `ForEach` keyed on `ObjectIdentifier(webView)` |
| `DumFlow/Features/BrowseForward/Views/PreloadedWebViewRepresentable.swift` | Full rewrite — attaches `UIPanGestureRecognizer` directly to `WKWebView` with `cancelsTouchesInView = false` |
| `DumFlow/Features/BrowseForward/Services/PreloadedWebViewManager.swift` | Added `getPrevWebView()` and `navigateToPrevious()` |
| `DumFlow/DumFlow.entitlements` | Added SIWA entitlement key |

#### Key Decisions

- **Black screen flash fix:** Used `ForEach` keyed on `ObjectIdentifier(webView)` so the same `WKWebView` instance stays in the same `UIKit` parent across slot changes. This prevents SwiftUI from re-creating the view hierarchy on every navigation.
- **Gesture fix:** Removed `gestureRecognizerShouldBegin` (which was incorrectly rejecting swipe-down because velocity is `(0,0)` at `shouldBegin` time). Replaced with translation-based direction filtering inside `handlePan`.

#### Current Behavior

- **Swipe UP:** Working. Animates current view off the top, next slides in from below (preloaded, instant).
- **Swipe DOWN:** Gesture fix applied this session. **Not yet tested on device — session ended before test.**
- **Forward button:** Works. Calls `webBrowser.browseForward()` → updates `browseForwardViewModel.currentItemIndex` → `onChange` in `VerticalNavigationView` calls `pool.navigateToNext()`.

---

## Current Architecture

```
ContentView (ZStack)
  ├── VerticalNavigationView              ← main content layer
  │     ├── PreloadedWebViewManager       (pool of 4 WKWebViews)
  │     │     ├── pool[0]: prev item WebView
  │     │     ├── pool[1]: current item WebView
  │     │     ├── pool[2]: next item WebView
  │     │     └── pool[3]: preloaded +2 WebView
  │     └── ForEach(slots, id: ObjectIdentifier(webView))
  │           └── PreloadedWebViewRepresentable (UIPanGestureRecognizer)
  ├── Card overlay (WebPageCardListView)
  └── Toolbars (FullToolbar + bottom)
```

---

## Known Issues (Prioritized)

### 1. Swipe Down — Untested
- Fix was applied (translation-based filtering in `handlePan`)
- **First action next session:** test on physical device

### 2. Combine Memory Leak in `PreloadedWebViewManager`
`updateScrollMonitoring()` creates a new `AnyCancellable` subscription on every navigation and never cancels the old one.

Fix:
```swift
// Add this property
private var scrollMonitorCancellable: AnyCancellable?

// In updateScrollMonitoring(), assign to it instead of .assign(to:)
scrollMonitorCancellable = somePublisher
    .sink { ... }
```

### 3. Old `WebViewPoolManager` Still Running
- Allocated in `DumFlowApp`, passed to `webBrowser`
- Preloads URLs into `WKWebViews` that are never displayed
- Wastes memory; should be removed or disabled

### 4. Card Overlay Re-renders 4x Per Navigation
- `🎴 Displaying card` logs fire 4 times per swipe
- Likely cause: missing `Equatable` conformance on `BrowseForwardItem`, or unnecessary `@Published` updates triggering redundant SwiftUI diffs

### 5. `BrowseForwardAPIService` Is a Stub
- Currently returns 5 hardcoded items (HN, Reddit, ArsTechnica, Verge, Kottke)
- After cycling through all 5, falls back to "No items available, using Wikipedia fallback"
- Real endpoint: `https://vercel-backend-azure-three.vercel.app/api/browse-content`
- Needs real `URLSession` call to Vercel → DynamoDB

### 6. Pool Recycling Bug
- After 4 navigations, `recycleWebViewsForward` sets `currentIndex = max(0, pool.count - 2)`
- This may not point to the correct newly-loaded item
- Needs audit and a correct index calculation

### 7. `browseForward()` Is Non-Sequential
- Picks items somewhat randomly from "unvisited" items rather than strictly sequential
- Eventually exhausts all 5 items and hits Wikipedia fallback

---

## Next Steps (In Priority Order)

1. **Test swipe-down on physical device** — confirm gesture fix works
2. **Fix Combine leak** in `PreloadedWebViewManager.updateScrollMonitoring()`
3. **Remove/disable old `WebViewPoolManager`** from `DumFlowApp`
4. **Implement real `BrowseForwardAPIService.fetchContent()`** with `URLSession` to Vercel
5. **Connect real AWS content** to `BrowseForwardViewModel` init
6. **Fix pool recycling index bug** in `recycleWebViewsForward`
7. **Add `Equatable` to `BrowseForwardItem`** to reduce card overlay re-renders

---

## Git Status

### Branch
`main` (other branches: `feature/aws-migration`, `feature/development`, `archive/old-browseforward`, `proper-infrastructure`)

### Untracked Files (not yet committed)
```
DumFlow/Features/BrowseForward/Services/PreloadedWebViewManager.swift
DumFlow/Features/BrowseForward/Views/PreloadedWebViewRepresentable.swift
DumFlow/Features/BrowseForward/Views/VerticalNavigationView.swift
```

These three files contain all the new vertical navigation work and should be committed before further development.

---

## Key File Paths

| Purpose | Path |
|---------|------|
| App entry point | `DumFlow/DumFlowApp.swift` |
| Main content view | `DumFlow/Shared/Views/ContentView.swift` |
| Vertical nav view | `DumFlow/Features/BrowseForward/Views/VerticalNavigationView.swift` |
| WebView representable | `DumFlow/Features/BrowseForward/Views/PreloadedWebViewRepresentable.swift` |
| WebView pool manager | `DumFlow/Features/BrowseForward/Services/PreloadedWebViewManager.swift` |
| BrowseForward API stub | `DumFlow/Features/BrowseForward/Services/BrowseForwardAPIService.swift` |
| BrowseForward view model | `DumFlow/Features/BrowseForward/ViewModels/BrowseForwardViewModel.swift` |
| Entitlements | `DumFlow/DumFlow.entitlements` |
| Project roadmap | `docs/MVP_ROADMAP.md` |

---

*Handoff generated: 2026-04-02*
