# Shtell MVP Roadmap - Low Context Handoff

## Current State
- **Version:** 1.1.0 (commit `2187a58`)
- **Status:** Stable on TestFlight
- **Working:** AWS content, CloudKit comments, Sign in with Apple, categories/tags

## Goal
Build Instagram/TikTok-level polish for web content discovery

---

## MVP Roadmap (3 weeks to launch-ready)

### **Phase 1: TikTok Navigation** (1.1.1 - 1.1.4) - 10 days

**1.1.1** - Vertical swipe gesture (2-3 days)
- Swipe up = next page, down = previous
- 60fps animations
- Spring physics matching TikTok

**1.1.2** - WebView preloading (2-3 days)
- Pool of 3-5 preloaded pages
- <100ms navigation time
- Memory < 200MB

**1.1.3** - Animation polish (2-3 days)
- Haptic feedback
- Edge bounce
- Perfect transitions

**1.1.4** - Performance tuning (2 days)
- 60fps guarantee
- Battery optimization

---

### **Phase 2: AWS Migration** (1.2.0) - 6 days

- CloudKit → DynamoDB
- Cognito authentication
- Stable backend for growth

---

### **Phase 3: Smart Algorithm** (1.3.0) - 5-7 days

- Learn user preferences
- Personalized content ranking
- "For You" feed
- Diversity in recommendations

---

### **Phase 4: TBD** (1.4.0+)
Decide after 1.3.0:
- Social features?
- Creator tools?
- Discovery?

---

### **Phase 5: Launch** (2.0.0)
App Store submission

---

## Next Steps

**START: 1.1.1 Vertical Swipe**
1. Create branch: `git checkout -b feature/vertical-nav-1.1.1`
2. Build vertical swipe navigation
3. Test on device
4. Ship to TestFlight in 2-3 days

---

## Technical Context

**Current Architecture:**
- iOS app (SwiftUI)
- AWS DynamoDB content (via Vercel API: `vercel-backend-azure-three.vercel.app`)
- CloudKit for comments (will migrate to AWS in 1.2.0)
- BrowseForwardViewModel manages content
- WebView pool for performance

**Key Files:**
- `/DumFlow/Features/BrowseForward/ViewModels/BrowseForwardViewModel.swift`
- `/DumFlow/Shared/Views/ContentView.swift`
- `/DumFlow/Features/BrowseForward/Services/BrowseForwardAPIService.swift`

**Deployment:**
- Team: SA8Y57H242
- Bundle: com.yitzy.Shtell
- TestFlight build number: 4

---

**Ship small, ship often. 2-3 day cycles.**
