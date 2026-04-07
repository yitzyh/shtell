# TestFlight 2.1 Development Status
**Created:** January 27, 2026 12:36 AM
**Current State:** Phase 0 Complete, Blockers Identified

---

## ✅ Completed Tasks

### Phase 0: Cleanup (Complete)
- ✅ Deleted obsolete worktrees (`Shtell-instant-loading`, `Shtell-feature`)
- ✅ Deleted merged branch `feature/instant-loading-v1.2.0`
- ✅ Switched to `main` branch for development
- ✅ Fixed CloudKit lazy loading
  - Updated `CloudKitManager.swift` with lazy initialization
  - Updated services: `WebPageService`, `CommentService`, `BrowserHistoryService`
  - Build succeeds ✅

---

## ❌ Current Blockers (CRITICAL)

### 1. Sign in with Apple Error
**Error:** `AuthorizationError 1000`
**Screenshot:** User sees "The operation couldn't be completed" on sign in

**Likely Causes:**
- Bundle ID mismatch in Apple Developer portal
- Entitlements not configured correctly
- App Group identifier mismatch
- Running on physical device without proper provisioning profile

**Files to Check:**
```
DumFlow/DumFlow.entitlements
DumFlow.xcodeproj/project.pbxproj (bundle ID)
Apple Developer Portal: App IDs & Capabilities
```

**Current Entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.yitzy.Shtell</string>
	</array>
</dict>
</plist>
```

**Missing:**
- Sign in with Apple capability
- CloudKit capability
- iCloud key-value storage

**Fix Required:**
1. Add Sign in with Apple entitlement
2. Add CloudKit container entitlement
3. Verify bundle ID: `com.shtell.browser` or similar
4. Check Apple Developer Portal configuration

---

### 2. AWS Content Not Loading
**Issue:** BrowseForwardViewModel shows hardcoded 5-item array
**Expected:** Should load from Vercel API → DynamoDB

**Current Implementation:**
```swift
// DumFlow/Features/BrowseForward/ViewModels/BrowseForwardViewModel.swift
init() {
    // Initialize with better sample data for testing
    items = [
        BrowseForwardItem(url: URL(string: "https://news.ycombinator.com")!, ...),
        // ... hardcoded items
    ]
}
```

**Should Be:**
```swift
init() {
    Task {
        await loadFromAPI()
    }
}

func loadFromAPI() async {
    do {
        let apiItems = try await BrowseForwardAPIService.shared.fetchContent()
        self.items = apiItems
    } catch {
        print("Error loading content: \(error)")
    }
}
```

**API Service Status:**
- `BrowseForwardAPIService.swift` exists but is STUB implementation
- Returns sample data, not real API calls
- Vercel endpoint: `https://vercel-backend-azure-three.vercel.app/api/browse-content`

**Fix Required:**
1. Implement real API calls in `BrowseForwardAPIService`
2. Update `BrowseForwardViewModel` to call API on init
3. Add error handling and loading states
4. Test with real DynamoDB data

---

## 📋 Remaining Work for TestFlight 2.1

### Phase 1: Fix Blockers (PRIORITY)
**Estimated:** 2-4 hours

**1. Fix Sign in with Apple (1-2 hours)**
```bash
Tasks:
□ Update DumFlow.entitlements with all required capabilities
□ Verify bundle ID matches Apple Developer portal
□ Add Sign in with Apple capability in Xcode
□ Test on physical device
□ Fallback: Allow "Skip" or "Continue as Guest" for testing
```

**2. Connect Real AWS Content (1-2 hours)**
```bash
Tasks:
□ Implement BrowseForwardAPIService.fetchContent()
  - URLSession request to Vercel API
  - JSON decoding to BrowseForwardItem
  - Error handling
□ Update BrowseForwardViewModel.init() to load from API
□ Add loading state UI
□ Test with real DynamoDB categories
```

---

### Phase 2: Vertical Scroll Navigation (1-2 days)
**Goal:** TikTok-style pull up/down between BrowseForward items

**Tasks:**
```
Day 1:
□ Create VerticalScrollGestureHandler.swift
  - UIPanGestureRecognizer
  - Velocity tracking (800 pts/sec threshold)
  - Distance tracking (100pts threshold)
□ WebView preloading (3 pages: prev/current/next)
□ 0.25s spring animation
□ Test on iPhone after each change

Day 2:
□ Connect to BrowseForwardViewModel
□ Haptic feedback (light/medium/success)
□ Polish loading states
□ Performance testing
□ TestFlight build
```

---

## 🏗️ Architecture Notes

### Current State
```
iOS App (SwiftUI)
    ↓
BrowseForwardViewModel (hardcoded data) ❌
    ↓
[No API calls yet]
```

### Target State
```
iOS App (SwiftUI)
    ↓
BrowseForwardViewModel
    ↓
BrowseForwardAPIService
    ↓
Vercel Serverless API
    ↓
AWS DynamoDB (webpages table)
```

### Files Modified Today
```
✅ DumFlow/CloudKit/CloudKitManager.swift (lazy loading)
✅ DumFlow/Services/WebPageService.swift (use shared manager)
✅ DumFlow/Features/Comments/Services/CommentService.swift (use shared manager)
✅ DumFlow/Features/Browser/Services/BrowserHistoryService.swift (use shared manager)
```

### Files That Need Work
```
❌ DumFlow/DumFlow.entitlements (add Sign in with Apple)
❌ DumFlow/Features/BrowseForward/Services/BrowseForwardAPIService.swift (implement real API)
❌ DumFlow/Features/BrowseForward/ViewModels/BrowseForwardViewModel.swift (connect to API)
```

---

## 🔧 Quick Start Guide for Next Session

### Option A: Fix Blockers First (Recommended)
```bash
# 1. Fix entitlements
open DumFlow.xcodeproj
# Navigate to: DumFlow target → Signing & Capabilities
# Add: Sign in with Apple, CloudKit, App Groups

# 2. Implement real API service
# Edit: DumFlow/Features/BrowseForward/Services/BrowseForwardAPIService.swift
# Replace stub with URLSession calls to Vercel

# 3. Test on iPhone
# Build and run (Cmd+R)
# Check: Content loads from AWS, Sign in works
```

### Option B: Build Vertical Scroll Anyway (Skip Auth for Now)
```bash
# 1. Create new file
touch DumFlow/Features/Navigation/VerticalScrollGestureHandler.swift

# 2. Implement gesture handler
# See INFRASTRUCTURE_HANDOFF.md for specs

# 3. Test gestures without auth
# Use hardcoded content for now
```

---

## 📱 Testing Checklist

### Before Moving Forward:
- [ ] App launches without crash ✅
- [ ] CloudKit initializes lazily ✅
- [ ] Sign in with Apple works ❌ (blocker)
- [ ] Content loads from AWS ❌ (blocker)
- [ ] Can browse 5+ pages
- [ ] Memory < 100MB

### For TestFlight 2.1:
- [ ] Vertical scroll works (pull up = next, pull down = previous)
- [ ] Preloading makes transitions instant
- [ ] Smooth 60fps animations
- [ ] Haptic feedback on gestures
- [ ] No crashes after 50+ page scrolls
- [ ] Memory < 100MB with 3 WebViews loaded

---

## 🚨 Critical Decisions Needed

### 1. Sign in with Apple - Should we:
**Option A:** Fix it properly (2 hours, blocks TestFlight)
**Option B:** Add "Skip" button, fix in 2.2 (30 mins, ship faster)
**Option C:** Remove sign in requirement for browsing (1 hour)

**Recommendation:** Option C - Let users browse without auth, prompt sign in only for comments/saves

### 2. AWS Content - Should we:
**Option A:** Fix API service now (2 hours, proper solution)
**Option B:** Use hardcoded "better" sample data (30 mins, ship faster)

**Recommendation:** Option A - Fix it now, foundation for everything else

### 3. Timeline:
**If we fix both blockers:** TestFlight 2.1 ships in 2-3 days
**If we skip auth + use samples:** TestFlight 2.1 ships in 1-2 days (but incomplete)

---

## 🔗 Related Documents

- `INFRASTRUCTURE_HANDOFF.md` - Original 2.1 plan (now modified)
- `.claude/CLAUDE.md` - Project documentation
- `vercel-backend/api/browse-content.js` - API endpoint code

---

## 💬 User Feedback

**From screenshot at 12:36 AM:**
> "get this error when try to sign in, no tags from aws content showing up"

**Translation:**
1. Auth is broken (AuthorizationError 1000)
2. Content isn't loading from AWS (still hardcoded)

**Status:** Both issues identified, fixes planned above

---

*Last Updated: January 27, 2026 12:36 AM*
*Next Update: After fixing blockers*
