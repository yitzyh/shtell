# Infrastructure Rebuild Handoff
*Created: January 26, 2026*
*Branch: proper-infrastructure (from commit a23b684)*

## Version Roadmap

### TestFlight 2.1.0 - Dual-Axis Navigation
**Target:** February 2026
- TikTok-style vertical pull gestures
- Horizontal tab switching (3 tabs)
- WebView preloading (9 total)
- Instant content transitions
- Safari-style tab management

### TestFlight 2.2.0 - Enhanced Tabs
**Target:** March 2026
- Expand to 5+ tabs
- Tab groups/collections
- Cross-tab search
- Tab sync across devices

### TestFlight 2.3.0 - Content Discovery
**Target:** April 2026
- AI-powered recommendations
- Social features (following)
- Content collections
- Trending topics

### TestFlight 3.0.0 - Platform Expansion
**Target:** Q2 2026
- iPad optimization
- Mac Catalyst
- Widget extensions
- SharePlay support

## Current State

### What We Have (Stable)
- **Clean codebase** from commit a23b684 (v1.1.0 TestFlight release)
- **Working app** without crashes or build errors
- **Basic features** functional:
  - WebView browsing
  - Comments system
  - Saved pages
  - Sign in with Apple
  - BrowseForward content (hardcoded test data)

### What Failed (Tab Chaos)
- Parallel tab development created 200+ build errors
- CloudKit initialization crashes
- Missing file dependencies
- Navigation conflicts between tabs
- Default URL confusion (apple.com vs BrowseForward content)

## Infrastructure Plan

### Phase 1: Foundation (Current)
**Goal:** Stable base with proper data flow

1. **AWS Connection Setup**
   ```
   DumFlow App
      ↓
   Vercel Backend (proxy)
      ↓
   AWS DynamoDB
   ```
   - [ ] Test Vercel endpoints locally
   - [ ] Implement DynamoDBService properly
   - [ ] Remove all CloudKit dependencies
   - [ ] Add proper error handling

2. **BrowseForward Content Loading**
   - [ ] Connect to real AWS data (not hardcoded)
   - [ ] Implement category filtering
   - [ ] Add content refresh mechanism
   - [ ] Proper queue management

3. **WebView Management**
   - [ ] Single WebView instance (for now)
   - [ ] Proper URL loading from BrowseForward
   - [ ] Clean navigation state management
   - [ ] No crashes on button press

### Phase 2: Navigation System (TestFlight 2.1.0)
**Goal:** Dual-axis navigation - TikTok-style vertical gestures + horizontal tab switching

#### Core Navigation Design
```
Vertical Axis (TikTok-style):
- Pull-down → Next BrowseForward item
- Pull-up → Previous item
- WebView pool: 3 pages per tab (previous, current, next)

Horizontal Axis (Tab System):
- Swipe left/right → Switch tabs
- Tab bar at bottom (can be hidden)
- Each tab maintains its own navigation stack
```

#### Tab Architecture (9 WebViews Total)
```
Tab 1: [Prev WebView] [Current WebView] [Next WebView]
Tab 2: [Prev WebView] [Current WebView] [Next WebView]
Tab 3: [Prev WebView] [Current WebView] [Next WebView]
```

#### Implementation Specs
1. **Vertical Navigation (Pull-Forward)**
   - [ ] Pan gesture recognizer
   - [ ] Velocity threshold: 800 pts/sec
   - [ ] Distance threshold: 100pts or 15% screen height
   - [ ] Snap animation: 0.25s (matching TikTok)
   - [ ] WebView preloading for instant transitions
   - [ ] Memory management (<200MB total)

2. **Horizontal Tabs**
   - [ ] 3 concurrent tabs maximum
   - [ ] Safari-style tab switcher UI
   - [ ] Independent navigation stacks
   - [ ] State preservation on tab switch
   - [ ] WebView pool optimization
   - [ ] Tab bar hide/show on scroll

3. **WebView Pool Management**
   - [ ] 9 WebViews total (3 tabs × 3 pages)
   - [ ] Preload next/previous content
   - [ ] Lazy loading for non-visible tabs
   - [ ] Memory pressure handling
   - [ ] Clean deallocation

#### Tab Development Plan (Parallel Work)

**Tab 3: WebView Pool & Preloading**
- Implement WebViewPool class
- Manage 9 concurrent WebViews
- Preload BrowseForward content
- Handle memory efficiently

**Tab 4: Gesture Recognition System**
- Pan gesture recognizer
- Velocity/distance calculations
- Gesture conflict resolution
- Smooth animations

**Tab 5: Tab Management UI**
- Safari-style tab switcher
- Tab bar implementation
- State preservation
- Visual feedback

**Tab 6: Performance & Testing**
- Memory monitoring
- Performance profiling
- Edge case handling
- TestFlight preparation

### Phase 3: Optimization
- WebView preloading
- Content caching
- Performance monitoring
- Memory optimization (<200MB)

## Implementation Steps

### Step 1: AWS Connection (TODAY)
```swift
// DumFlow/Services/DynamoDBService.swift
class DynamoDBService {
    private let baseURL = "https://shtell.vercel.app/api"

    func fetchBrowseContent(category: String?) async -> [BrowseForwardItem] {
        // Implement proper API call
        // Handle errors gracefully
        // Return real data
    }
}
```

### Step 2: Update BrowseForwardViewModel
```swift
// Remove hardcoded test data
// Connect to DynamoDBService
// Implement proper refresh logic
```

### Step 3: Fix WebView Loading
```swift
// Load first BrowseForward item on launch
// No arbitrary URLs (no apple.com!)
// Proper state management
```

## Files to Modify

### Priority 1 (Core Infrastructure)
- `DumFlow/Services/DynamoDBService.swift` - Create/update
- `DumFlow/Features/BrowseForward/ViewModels/BrowseForwardViewModel.swift` - Connect to AWS
- `DumFlow/App/DumFlowApp.swift` - Clean initialization

### Priority 2 (Remove CloudKit)
- `DumFlow/Services/CloudKitService.swift` - Delete
- `DumFlow/Features/WebPages/ViewModels/WebPageViewModel.swift` - Remove CK references
- `DumFlow/Features/Comments/Services/CommentService.swift` - Switch to DynamoDB
- `DumFlow/Services/WebPageService.swift` - Switch to DynamoDB

### Priority 3 (Navigation)
- `DumFlow/Features/Browser/Views/WebView.swift` - Clean up
- `DumFlow/Shared/Views/ContentView.swift` - Prepare for navigation
- Create new navigation components (after infrastructure)

## Testing Checklist

### Basic Functionality
- [ ] App launches without crash
- [ ] Shows first BrowseForward item (not apple.com)
- [ ] Can browse to different URLs
- [ ] BrowseForward button works
- [ ] Comments load properly
- [ ] Sign in works

### AWS Integration
- [ ] Content loads from Vercel/DynamoDB
- [ ] Categories filter correctly
- [ ] Content refreshes properly
- [ ] Error states handled gracefully

### Performance
- [ ] Memory usage <200MB
- [ ] No memory leaks
- [ ] Smooth scrolling
- [ ] Fast content loading

## Known Issues to Avoid

1. **CloudKit Crashes**
   - Don't initialize CK containers as stored properties
   - Use computed properties or disable entirely

2. **Missing Files**
   - BrowseForwardItem model needs proper implementation
   - TrendView was never implemented (remove references)

3. **URL Type Mismatches**
   - Always use `.absoluteString` when converting URL to String
   - Be consistent with URL vs String types

4. **Default Content**
   - NEVER default to apple.com or arbitrary sites
   - ALWAYS start with first BrowseForward item
   - User wants curated content, not random websites

## Success Criteria

### Phase 1 Complete When:
- App connects to real AWS data
- No hardcoded test content
- All CloudKit removed
- No crashes or build errors
- First BrowseForward item loads on launch

### Ready for Phase 2 When:
- Infrastructure is stable for 24 hours
- All basic features work
- Memory usage acceptable
- Code is clean and documented

## Next Immediate Actions

1. **Open Xcode** ✓
2. **Switch to proper-infrastructure branch** ✓
3. **Implement DynamoDBService**
4. **Connect BrowseForwardViewModel to AWS**
5. **Test on simulator and device**
6. **Commit when stable**

## Notes

- We're starting fresh from a known-good state
- No parallel development until infrastructure is solid
- Test each change thoroughly before moving on
- Commit frequently to preserve working states
- User wants good infrastructure, not rushed features

## Commands for Quick Start

```bash
# You're already on the right branch
git status

# After making changes
git add .
git commit -m "Add AWS connection infrastructure"

# When ready to test
# Build in Xcode (Cmd+B)
# Run on simulator (Cmd+R)
```

## Contact Points

- Vercel Backend: https://shtell.vercel.app
- AWS Region: us-east-1
- DynamoDB Table: bfQueue
- CloudKit Container: iCloud.com.yitzy.DumFlow (TO BE REMOVED)

---

*This handoff represents a clean restart with proper infrastructure as the foundation. Build slowly and correctly rather than quickly with errors.*