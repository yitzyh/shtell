# History Handoff: Unified Navigation & Analytics

**Date:** 2026-02-04
**Feature:** 1.1.1 Vertical Swipe Navigation - History/Back Button
**Status:** Ready for Planning (Use Opus) → Implementation (Use Sonnet with auto-accept)
**Related:** See `HANDOFF_UI_STACKED_CARDS.md` for UI/animations work

---

## Context: What We're Building

Implement **unified global history** that works seamlessly across multiple stacked WebViews:
- Back button traverses all pages across all BrowseForward items
- Automatically switches between WebView cards when needed
- Integrates with existing `BrowserHistoryService` for analytics
- Tracks viewing time, scroll depth, engagement per item

---

## Current State (Before This Work)

### What Exists Today

✅ **BrowserHistoryService** (`DumFlow/Features/Browser/Services/BrowserHistoryService.swift`)
- Tracks browser history with CloudKit
- Records: URL, title, timestamp, viewDuration, scrollDepth
- Methods: `addToHistory()`, `trackPageExit()`, `updateScrollDepth()`
- Already working for normal browser navigation

✅ **Single WebView Navigation**
- Each WebView has its own WKWebView history
- Back button works within current WebView only
- User navigates: Page A → clicks link → Page B → back button → Page A

### What's Missing

❌ **Global History Across WebViews**
Problem scenario:
```
1. BrowseForward Item #1 (WebView A) - game1.com
2. User clicks link → article.com (still WebView A)
3. User pulls down to Item #2 (WebView B) - game2.com
4. User presses back button → NOTHING HAPPENS (back is WebView A's history, but we're in WebView B)
```

❌ **BrowseForward Analytics**
- Not tracking which BrowseForward items user views
- Not tracking time spent per item
- No data for future recommendation algorithm

---

## Requirements: Unified History System

### User Experience Goals

#### 1. Seamless Back Navigation
**User journey:**
```
Step 1: BrowseForward Item #1 (game1.com) - WebView A
Step 2: Click link → article.com - WebView A
Step 3: Pull down → Item #2 (game2.com) - WebView B
Step 4: Click link → tutorial.com - WebView B
Step 5: Back button → tutorial.com → game2.com (WebView B) ✅
Step 6: Back button → game2.com → article.com (SWITCHES to WebView A!) ✅
Step 7: Back button → article.com → game1.com (WebView A) ✅
```

**Key behavior:**
- Back button always goes to previous page in chronological order
- Automatically switches to correct WebView if needed
- Feels like one continuous browser, not separate WebViews

#### 2. Analytics Tracking
**For each BrowseForward item viewed:**
- **URL & title** of the item
- **Time spent** on the item (from first load to navigation away)
- **Scroll depth** (how far down they scrolled - 0% to 100%)
- **Engagement signals:**
  - Did they click any links within the page?
  - Did they navigate away quickly (<5s) or spend time (>30s)?
  - Did they pull down to next item, or use back button to leave?

**Data storage:**
- Save to CloudKit via `BrowserHistoryService`
- One record per BrowseForward item viewed
- Enable future recommendation algorithm

---

## Technical Architecture

### Global History Stack

**Data structure:**
```swift
struct HistoryEntry {
    let url: String
    let webViewID: String // Identifies which WebView/card
    let timestamp: Date
    let pageTitle: String?

    // For BrowseForward items only
    let isBrowseForwardItem: Bool
    let browseForwardIndex: Int?
}

class GlobalNavigationHistory: ObservableObject {
    @Published var historyStack: [HistoryEntry] = []
    @Published var currentIndex: Int = 0 // Where we are in the stack

    func addEntry(_ entry: HistoryEntry)
    func goBack() -> (webViewID: String, url: String)?
    func goForward() -> (webViewID: String, url: String)?
    func canGoBack() -> Bool
    func canGoForward() -> Bool
}
```

**How it works:**
1. Every navigation (link click, pull-down) adds entry to `historyStack`
2. Back button calls `goBack()` → returns which WebView + URL to show
3. If returned webViewID ≠ current WebView → switch cards
4. Update `currentIndex` to track position in history

### WebView Coordination

**Integration with PreloadedWebViewManager (from UI handoff):**
```swift
class PreloadedWebViewManager {
    var webViews: [String: WKWebView] = [:] // webViewID → WKWebView
    var currentWebViewID: String

    // Called by GlobalNavigationHistory
    func switchToWebView(_ webViewID: String, url: String) {
        // If WebView exists in memory → display it
        // If not in memory → reload it (going back beyond previous 1)
        // Trigger card slide animation
    }
}
```

### BrowserHistoryService Integration

**Track BrowseForward items:**
```swift
// When user navigates to BrowseForward item
func trackBrowseForwardItemView(item: BrowseForwardItem) {
    let urlString = item.url
    let title = item.title

    // Start tracking time
    browserHistoryService.addToHistory(
        urlString: urlString,
        title: title,
        referrerURL: nil
    )

    // Note: This is a BrowseForward item (not just a clicked link)
    // Could add custom field to BrowserHistory model
}

// When user leaves BrowseForward item (pulls to next or clicks back)
func trackBrowseForwardItemExit(didClickLinks: Bool) {
    browserHistoryService.trackPageExit(
        didComment: false,
        didLike: false,
        didSave: false
    )
    // Logs time spent, scroll depth automatically
}
```

---

## Implementation Plan (with Testing Checkpoints)

### PHASE 1: Global History Data Structure
**Goal:** Create the history tracking system without UI changes

**Tasks:**
1. Create `GlobalNavigationHistory.swift`:
   - Define `HistoryEntry` struct
   - Create `GlobalNavigationHistory` class (ObservableObject)
   - Implement `addEntry()`, `goBack()`, `goForward()`
   - Implement `canGoBack()`, `canGoForward()`

2. Add to ContentView environment:
   ```swift
   @StateObject private var globalHistory = GlobalNavigationHistory()
   ```

3. Track BrowseForward item navigations:
   - When `navigateToNext()` called → add HistoryEntry
   - Set `isBrowseForwardItem = true`
   - Record `browseForwardIndex`

4. Add console logging:
   ```swift
   print("📚 History: Added entry - \(url)")
   print("📚 History stack: \(historyStack.map { $0.url })")
   print("📚 Current index: \(currentIndex)/\(historyStack.count)")
   ```

**🧪 TEST CHECKPOINT 1:**
- [ ] Build succeeds
- [ ] Navigate through 3 BrowseForward items (pull down twice)
- [ ] Console shows history entries being added
- [ ] Console shows history stack growing: [url1, url2, url3]
- [ ] `canGoBack()` returns true after first navigation
- [ ] No UI changes yet (just data structure working)
- **STOP HERE - Report results before continuing**

---

### PHASE 2: Track Link Clicks Within WebViews
**Goal:** Capture when user clicks links inside BrowseForward items

**Tasks:**
1. Add WKNavigationDelegate to WebView coordinator:
   ```swift
   func webView(_ webView: WKWebView,
                decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

       if navigationAction.navigationType == .linkActivated {
           // User clicked a link
           let url = navigationAction.request.url?.absoluteString ?? ""
           globalHistory.addEntry(HistoryEntry(
               url: url,
               webViewID: webViewID,
               timestamp: Date(),
               pageTitle: nil,
               isBrowseForwardItem: false,
               browseForwardIndex: nil
           ))
           print("📚 History: Link clicked - \(url)")
       }

       decisionHandler(.allow)
   }
   ```

2. Track page title updates:
   ```swift
   // When page finishes loading
   func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
       let title = webView.title
       // Update last history entry with title
       globalHistory.updateLastEntryTitle(title)
   }
   ```

**🧪 TEST CHECKPOINT 2:**
- [ ] Build succeeds
- [ ] Navigate to BrowseForward item (e.g., a game)
- [ ] Click a link within the page
- [ ] Console shows: `📚 History: Link clicked - <url>`
- [ ] History stack now has 2 entries: [browseForwardItem, clickedLink]
- [ ] Page titles are captured and logged
- **STOP HERE - Report results before continuing**

---

### PHASE 3: Implement Back Button Logic
**Goal:** Make back button traverse global history

**Tasks:**
1. Find existing back button in ContentView:
   - Should be in toolbar or navigation bar
   - Currently calls `webBrowser.goBack()` or similar

2. Replace with global history back:
   ```swift
   Button(action: {
       if let previous = globalHistory.goBack() {
           handleGlobalBack(webViewID: previous.webViewID, url: previous.url)
       }
   }) {
       Image(systemName: "chevron.left")
   }
   .disabled(!globalHistory.canGoBack())
   ```

3. Implement `handleGlobalBack()`:
   ```swift
   func handleGlobalBack(webViewID: String, url: String) {
       print("⬅️ Global back: switching to WebView \(webViewID), URL: \(url)")

       // Check if it's the current WebView
       if webViewID == currentWebViewID {
           // Same WebView - use native WKWebView.goBack()
           currentWebView.goBack()
       } else {
           // Different WebView - need to switch cards
           preloadedWebViewManager.switchToWebView(webViewID, url: url)
           // This will trigger card slide animation
       }
   }
   ```

4. Add visual feedback:
   - Disable back button when `!canGoBack()`
   - Update button appearance (gray out when disabled)

**🧪 TEST CHECKPOINT 3:**
- [ ] Build succeeds
- [ ] Navigate: Item #1 → click link → Item #2
- [ ] Press back button → goes to clicked link (in Item #1's WebView)
- [ ] Console shows: `⬅️ Global back: switching to WebView A`
- [ ] WebView switches back to previous card
- [ ] Press back again → goes to Item #1 original page
- [ ] Back button disabled when at start of history
- **STOP HERE - Report results before continuing**

---

### PHASE 4: WebView Switching with Animation
**Goal:** Smooth card transitions when switching WebViews via back button

**Tasks:**
1. Add `switchToWebView()` in PreloadedWebViewManager:
   ```swift
   func switchToWebView(_ targetWebViewID: String, url: String) {
       // Check if WebView is in memory
       if let webView = webViews[targetWebViewID] {
           // WebView exists - animate to it
           animateCardSwitch(to: targetWebViewID, direction: .backward)
       } else {
           // WebView not in memory - reload it
           let newWebView = createWebView(url: url)
           webViews[targetWebViewID] = newWebView
           animateCardSwitch(to: targetWebViewID, direction: .backward)
       }

       currentWebViewID = targetWebViewID
   }

   func animateCardSwitch(to webViewID: String, direction: CardSwipeDirection) {
       withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
           if direction == .backward {
               // Slide current card down, previous card slides in from top
               currentCardOffset = UIScreen.main.bounds.height
               previousCardOffset = 0
           } else {
               // Forward navigation (from global forward button, if exists)
               currentCardOffset = -UIScreen.main.bounds.height
               nextCardOffset = 0
           }
       }
   }
   ```

2. Handle card positioning for backward navigation:
   - Previous card should be positioned above current (negative offset)
   - Slide current down, previous slides down to 0

3. Test with existing forward animation:
   - Ensure forward (pull-down) and backward (back button) feel consistent

**🧪 TEST CHECKPOINT 4:**
- [ ] Build succeeds
- [ ] Navigate forward through items, click links
- [ ] Press back button → card slides in from top smoothly
- [ ] Animation feels natural (same spring physics as forward)
- [ ] Multiple backs in a row → smooth transitions
- [ ] Forward and backward animations are consistent
- **STOP HERE - Report results before continuing**

---

### PHASE 5: BrowserHistoryService Integration
**Goal:** Log BrowseForward item views to CloudKit for analytics

**Tasks:**
1. Track when BrowseForward item becomes active:
   ```swift
   func didDisplayBrowseForwardItem(_ item: BrowseForwardItem) {
       print("📊 Analytics: Starting to track - \(item.url)")

       browserHistoryService.addToHistory(
           urlString: item.url,
           title: item.title,
           referrerURL: previousItemURL
       )

       // Store start time for this item
       itemStartTime = Date()
       currentItemURL = item.url
   }
   ```

2. Track when user leaves BrowseForward item:
   ```swift
   func didLeaveBrowseForwardItem(didClickLinks: Bool) {
       guard let itemURL = currentItemURL else { return }

       let timeSpent = Date().timeIntervalSince(itemStartTime ?? Date())
       print("📊 Analytics: User spent \(timeSpent)s on item")

       browserHistoryService.trackPageExit(
           didComment: false,
           didLike: false,
           didSave: false
       )

       // Reset tracking
       itemStartTime = nil
       currentItemURL = nil
   }
   ```

3. Integrate scroll depth tracking:
   - WebView coordinator already tracks scroll position (from Phase 3 in UI handoff)
   - Pass scroll depth to BrowserHistoryService:
     ```swift
     browserHistoryService.updateScrollDepth(scrollPercentage)
     ```

4. Handle navigation scenarios:
   - Pull down to next → call `didLeaveBrowseForwardItem(didClickLinks: linksWereClicked)`
   - Back button away → call `didLeaveBrowseForwardItem()`
   - App backgrounded → save current state

**🧪 TEST CHECKPOINT 5:**
- [ ] Build succeeds
- [ ] Navigate to BrowseForward item → console shows analytics start
- [ ] Spend 10 seconds, scroll halfway down
- [ ] Pull down to next item
- [ ] Console shows: `📊 Analytics: User spent 10s on item`
- [ ] Check CloudKit Dashboard → new BrowserHistory record created
- [ ] Record has: URL, title, viewDuration ≈ 10s, scrollDepth ≈ 0.5
- **STOP HERE - Report results before continuing**

---

### PHASE 6: Memory Management for History
**Goal:** Prevent memory leaks, handle edge cases

**Tasks:**
1. Limit global history stack size:
   ```swift
   private let maxHistorySize = 100

   func addEntry(_ entry: HistoryEntry) {
       historyStack.append(entry)

       // Trim old entries if too large
       if historyStack.count > maxHistorySize {
           historyStack.removeFirst(historyStack.count - maxHistorySize)
           currentIndex = min(currentIndex, historyStack.count - 1)
       }
   }
   ```

2. Clean up WebViews when going back beyond "previous 1":
   - If user goes back to Item #1, and we're now on Item #5
   - Items #2, #3, #4 should be released from memory
   - Only keep: previous 1, current, next 2

3. Handle app lifecycle:
   - App goes to background → save history state (optional)
   - App terminated → history is lost (acceptable for MVP)
   - Future: persist to UserDefaults or CloudKit

4. Handle edge cases:
   - Empty history → back button disabled
   - At end of history → forward button disabled (if you add one)
   - User navigates forward after going back → truncate forward history

**🧪 TEST CHECKPOINT 6:**
- [ ] Build succeeds
- [ ] Navigate through 20+ items
- [ ] History stack doesn't exceed 100 entries
- [ ] Go back 10 times, then forward 5 times → history state correct
- [ ] Memory usage stable (use Xcode Instruments)
- [ ] No memory leaks after 100+ navigations
- **STOP HERE - Report results before continuing**

---

### PHASE 7: Polish & Edge Cases
**Goal:** Handle unusual scenarios gracefully

**Tasks:**
1. **Forward button (optional):**
   - Add forward button next to back
   - Uses `globalHistory.goForward()`
   - Disabled when `!canGoForward()`

2. **History truncation on new navigation:**
   ```swift
   // If user goes: A → B → C → back → back → D
   // History should be: A → B → D (not A → B → C → D)
   func addEntry(_ entry: HistoryEntry) {
       // Truncate forward history if we're in the middle
       if currentIndex < historyStack.count - 1 {
           historyStack = Array(historyStack[0...currentIndex])
       }
       historyStack.append(entry)
       currentIndex = historyStack.count - 1
   }
   ```

3. **Fast back/forward tapping:**
   - Debounce rapid button presses
   - Don't allow back if animation in progress

4. **Visual history indicator (optional):**
   - Show "2/15" or dots at bottom
   - Updates as user navigates
   - Fades out after 2 seconds

5. **Error handling:**
   - What if WebView fails to load? (network error, 404)
   - Skip to next history entry? Show error page?
   - Log to console, don't crash

**🧪 TEST CHECKPOINT 7:**
- [ ] Build succeeds
- [ ] Test branching history: A → B → back → C (no B in history after C)
- [ ] Rapid back button taps don't cause crashes
- [ ] Forward button works correctly
- [ ] History indicator updates in real-time (if implemented)
- [ ] Network errors handled gracefully
- **STOP HERE - Report results before continuing**

---

## Key Files Reference

### Files You'll Create
- **New:** `DumFlow/Services/GlobalNavigationHistory.swift` - History stack manager
- **New:** `DumFlow/Models/HistoryEntry.swift` - Data model (or define in GlobalNavigationHistory)

### Files You'll Modify
- `DumFlow/Shared/Views/ContentView.swift` - Back button logic, history integration
- `DumFlow/Features/Browser/Views/WebView.swift` - WKNavigationDelegate for link tracking
- `PreloadedWebViewManager.swift` - Add `switchToWebView()` method (from UI handoff)

### Files to Reference (Existing)
- `DumFlow/Features/Browser/Services/BrowserHistoryService.swift`
  - Lines 42-79: `addToHistory()` - use this for BrowseForward tracking
  - Lines 82-108: `trackPageExit()` - call when leaving items
  - Lines 110-113: `updateScrollDepth()` - pass scroll percentage

- `DumFlow/Models/BrowserHistory.swift` (check if exists)
  - May need to extend model with `isBrowseForwardItem` field

### Documentation
- `/docs/SESSION_HANDOFF_1.1.1.md` - Context
- `/docs/HANDOFF_UI_STACKED_CARDS.md` - UI work (done in parallel)
- `/docs/MVP_ROADMAP.md` - Overall plan

---

## Integration with UI Work

**This work depends on UI handoff completing:**
- `PreloadedWebViewManager` structure (Phase 1 of UI)
- Multiple WebView management
- Card animation system

**Integration points:**
1. **After UI Phase 1 complete:**
   - You can start Phase 1-2 (history data structure + link tracking)

2. **After UI Phase 2-3 complete:**
   - Start Phase 3 (back button logic)

3. **After UI Phase 5 complete:**
   - Implement Phase 4 (WebView switching animations)

4. **Independent:**
   - Phase 5 (BrowserHistoryService) can be done anytime

**Recommended approach:**
- UI tab does Phases 1-3 first
- History tab does Phases 1-2 in parallel
- Then coordinate for Phases 3-4 (need both UI and history working together)

---

## Success Criteria

✅ **Navigation:** Back button traverses all pages across all WebViews
✅ **Switching:** Automatically switches to correct WebView with smooth animation
✅ **Analytics:** Each BrowseForward item logged with time, scroll depth
✅ **Memory:** History stack limited to 100 entries, no leaks
✅ **Edge cases:** Handles branching history, rapid taps, errors gracefully
✅ **CloudKit:** Data appears in CloudKit Dashboard
✅ **UX:** Feels like one seamless browser, not separate WebViews

---

## Testing Strategy

### Manual Testing Checklist
Run after each phase checkpoint:
- [ ] Build in Xcode → Physical iPhone
- [ ] Navigate: Item #1 → click link → Item #2 → click link → Item #3
- [ ] Press back 4 times → should return to Item #1 original page
- [ ] Verify card animations are smooth during back navigation
- [ ] Check console logs for history events
- [ ] Open CloudKit Dashboard → verify BrowserHistory records
- [ ] Check record fields: URL, viewDuration, scrollDepth populated

### CloudKit Verification
1. Open CloudKit Dashboard: https://icloud.developer.apple.com/
2. Select container: `iCloud.com.yitzy.DumFlow`
3. Select database: Public Database
4. Query `BrowserHistory` record type
5. Look for records with BrowseForward item URLs
6. Verify fields populated correctly

### Memory Testing
- Use Xcode Instruments → Allocations
- Monitor WKWebView instances (should max at 4)
- Monitor history stack size (should max at 100)
- No memory leaks after 100+ navigations

---

## Notes for Opus Planning Phase

**When using Opus to create detailed implementation plan:**

1. Review this entire handoff + UI handoff (HANDOFF_UI_STACKED_CARDS.md)
2. Understand dependencies between UI and History work
3. Identify coordination points with UI tab
4. Flag potential challenges:
   - WKNavigationDelegate might conflict with existing delegates
   - BrowserHistory model may need schema changes
   - CloudKit save timing (async, might fail)
   - Synchronizing history state with WebView state
5. Design data flow:
   - How does history stack stay in sync with WebView state?
   - What if WebView navigates via JavaScript (not user click)?
   - How to detect when WebView finishes loading vs fails?
6. Propose testing approach:
   - Unit tests for GlobalNavigationHistory
   - Integration tests with CloudKit (mock vs real)
   - E2E test for full user journey

**Then hand off to Sonnet for implementation with auto-accept enabled**

---

## Quick Start Commands

```bash
# Verify current state
git status

# Work on same branch as UI (recommended)
git checkout feature/stacked-card-ui

# Or create separate branch
git checkout -b feature/unified-history

# After each checkpoint, test build
# In Xcode: Product → Build (⌘B)

# When all checkpoints pass:
git add .
git commit -m "feat: Implement unified navigation history with analytics"

# Merge both UI and History features
git checkout main
git merge feature/stacked-card-ui
git merge feature/unified-history
```

---

## Coordination Strategy

**Recommended workflow:**

### Option A: Sequential (Safer)
1. UI tab completes all 7 phases first
2. Then History tab starts, uses completed UI infrastructure
3. Less coordination needed, but slower

### Option B: Parallel (Faster)
1. UI tab: Phases 1-3 (WebView management, layout, scroll detection)
2. History tab: Phases 1-2 (history data structure, link tracking) - parallel
3. **Sync point:** Both tabs stop, review progress
4. UI tab: Phases 4-5 (drag animations, navigation)
5. History tab: Phase 3 (back button) - uses UI tab's WebView manager
6. **Sync point:** Test integration
7. Both tabs: Remaining phases (Phase 6-7 for each)
8. **Final sync:** Full integration testing

**Recommended: Option B with clear sync points**

---

Good luck! 🚀 Remember to STOP at each test checkpoint and coordinate with UI tab at sync points!
