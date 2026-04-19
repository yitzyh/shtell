# CLAUDE.md - Shtell Project Master Documentation

<!--
=================================================================
PART 1: HUMAN DOCUMENTATION (Lines 1-350)
For executives, developers, designers, and team members
Clear, scannable, and progressively detailed
=================================================================
-->

# 📱 Shtell - Revolutionary iOS Browser with TikTok-Style Navigation

## Executive Summary (30-Second Read)

**Shtell** (formerly DumFlow) is an iOS browser reimagining web discovery through curated content and social commenting. Version 1.2.0 is on TestFlight with BrowseForward, comments, SIWA, and saved pages. Version 1.3.0 migrates everything from CloudKit to AWS DynamoDB for stability and zero iCloud dependency.

**Current Features:**
- **BrowseForward:** Pull-down for curated content across 5 categories
- **Comments:** Quote, reply, and discuss on any webpage
- **Social:** Sign In with Apple, saved pages, user profiles (coming)
- **Performance:** <100ms navigation, 60fps animations, <200MB memory

**Business Model:**
- **Market:** 20-30s creative professionals in NYC/Brooklyn
- **Content:** 15-20 curated items daily (no paywalls)
- **Monetization:** AdMob native ads (planned 3.1.0)
- **Growth:** Social features → viral content discovery

---

## Developer Overview (5-Minute Onboarding)

### Quick Start

```bash
# Clone and run
git clone https://github.com/[org]/shtell
cd shtell
open DumFlow.xcodeproj  # Legacy name in Xcode
# Select iPhone 15 Pro simulator
# Cmd+R to run
```

### Architecture at a Glance

```
┌─────────────────────────────────────┐
│           iOS App (SwiftUI)         │
├─────────────────────────────────────┤
│     Navigation Controller           │
│  ┌──────────┬──────────┬─────────┐ │
│  │Vertical  │Horizontal│ Toolbar │ │
│  │Navigation│Navigation│   UI    │ │
│  └──────────┴──────────┴─────────┘ │
├─────────────────────────────────────┤
│        WebView Pool (9x)            │
│     3 tabs × 3 pages each           │
├─────────────────────────────────────┤
│         Vercel Proxy API            │
└─────────────────────────────────────┘
         ▼              ▼
    AWS DynamoDB   Sign in with Apple
```

### Current Sprint: 1.3.0 — CloudKit → AWS Migration

**Goal:** Zero CloudKit dependency. DynamoDB via Vercel proxy for users, comments, saved pages. History goes local-only.
**Current TestFlight:** 1.2.0 (build 5)
**Status:** Pre-implementation (tables not yet created)

### Key Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| Frontend | SwiftUI + WebKit | iOS native app |
| Navigation | Custom gesture recognizers | Dual-axis control |
| Performance | WebView pooling | Instant navigation |
| Backend | AWS DynamoDB | Content storage |
| API | Vercel serverless | Proxy layer |
| Auth | Sign in with Apple | User accounts |

---

## Technical Deep Dive (Detailed Implementation)

### Navigation System Architecture

#### Vertical Navigation (TikTok-Style)
- **Pull down**: Navigate to previous webpage
- **Pull up**: Navigate to next webpage
- **Animation**: 0.25s spring (matching TikTok)
- **Threshold**: 50pt distance or 500pt/s velocity
- **Edge behavior**: Elastic bounce at boundaries

#### Horizontal Navigation (Tab Switching)
- **Swipe left**: Next tab
- **Swipe right**: Previous tab
- **Animation**: 0.3s slide transition
- **Max tabs**: 5 concurrent
- **Preloading**: Current ± 1 tab

#### Bottom Toolbar
- **Height**: 60pt with liquid glass effect
- **Favicons**: 32pt (40pt when selected)
- **Gestures**: Dual-axis support
- **Feedback**: Haptic on tab switch

### WebView Pool Management

```swift
// Pool Configuration
struct WebViewPoolConfig {
    static let maxWebViews = 9        // 3 tabs × 3 pages
    static let maxMemoryMB = 200      // Memory limit
    static let recycleThresholdMB = 150  // Start recycling
}

// Preload Strategy
enum PreloadPriority {
    case immediate  // Current page (0ms)
    case high      // Adjacent pages (200ms)
    case medium    // Adjacent tabs (500ms)
    case low       // Background (1000ms)
}
```

### Memory Management Strategy

1. **Normal (<150MB)**: Full 9-webview preloading
2. **Warning (150-180MB)**: Reduce to current tab only
3. **Critical (>180MB)**: Emergency cleanup, keep current page only

### API Architecture

#### Vercel Proxy Endpoints
```typescript
GET /api/browse-content          // Fetch content
GET /api/browse-content?category=tech  // Filter by category
GET /api/comments?url={url}      // Get comments
POST /api/comments               // Post comment
POST /api/auth/signin            // Apple auth
```

#### DynamoDB Schema

Naming convention: lowercase, hyphenated, no prefix. All tables use On-demand billing.

```yaml
# --- 1.3.0 (current) ---

webpages:                         # Browse content queue (existing)
  PK: url (S)
  GSIs: category-index, score-index

users:                            # 1.3.0
  PK: userID (S)
  GSIs: appleUserID-index, username-index
  Fields: userID, appleUserID, username, displayName, dateCreated

comments:                         # 1.3.0
  PK: urlString (S), SK: commentID (S)
  GSIs: userID-index
  Fields: urlString, commentID, text, userID, username, dateCreated,
          parentCommentID?, quotedText?, quotedTextSelector?, quotedTextOffset?

saved-webpages:                   # 1.3.0
  PK: userID (S), SK: urlString (S)
  Fields: userID, urlString, title, domain, dateSaved

# --- 1.4.0 ---

comment-likes:                    # 1.4.0
  PK: commentID (S), SK: userID (S)

webpage-likes:                    # 1.4.0
  PK: urlString (S), SK: userID (S)

saved-comments:                   # 1.4.0
  PK: userID (S), SK: commentID (S)

follows:                          # 1.4.0
  PK: followerID (S), SK: followedID (S)
  GSIs: followedID-index (for "who follows me")

blocks:                           # 1.4.0
  PK: userID (S), SK: blockedID (S)

mutes:                            # 1.4.0
  PK: userID (S), SK: mutedID (S)

# --- 2.0 ---

notifications:                    # 2.0
  PK: userID (S), SK: createdAt#notificationID (S)
```

### File Structure

```
shtell/
├── DumFlow.xcodeproj         # Xcode project (legacy name)
├── DumFlow/                  # iOS app source
│   ├── Features/
│   │   ├── Navigation/       # New dual-axis system
│   │   ├── Comments/         # Comment system
│   │   └── SavedPages/       # Bookmarks
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── DynamoDBService.swift
│   │   └── WebViewPool.swift
│   └── Views/
├── vercel-backend/           # Serverless API
│   ├── api/
│   └── package.json
└── .claude/                  # Documentation
    ├── CLAUDE.md (this file)
    ├── testflight/
    └── tabs/
```

### Performance Benchmarks

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Gesture Response | <50ms | 45ms | ✅ |
| Animation FPS | 60fps | 58fps | ⚠️ |
| Memory Usage | <200MB | 180MB | ✅ |
| Preload Time | <500ms | 450ms | ✅ |
| Tab Switch | <100ms | 95ms | ✅ |

### Testing Strategy

```swift
// Unit Tests
func testVerticalGestureRecognition()
func testHorizontalTabSwitching()
func testWebViewPoolRecycling()
func testMemoryPressureHandling()

// UI Tests
func testTikTokStyleNavigation()
func testToolbarInteraction()
func testTabManagement()

// Performance Tests
func test100NavigationsWithoutCrash()
func testMemoryUnder200MB()
func test60fpsAnimations()
```

<!--
=================================================================
PART 2: CLAUDE CONTEXT (Lines 351+)
Optimized for AI parsing and context understanding
Structured data, clear boundaries, no ambiguity
=================================================================
-->

## === CLAUDE CONTEXT BEGIN ===

### PROJECT_STATE
```yaml
app_name: Shtell
former_name: DumFlow
testflight_version: 1.2.0_build_5
current_dev_version: 1.3.0
status: active_development
sprint: CloudKit_to_AWS_migration
```

### ACTIVE_FEATURE_DEVELOPMENT
```yaml
feature: CloudKit_to_AWS_migration
version: 1.3.0
components:
  - vercel_api_routes: users, comments, saved-pages
  - dynamo_tables: shtell-users, shtell-comments, shtell-saved-pages
  - ios_models: User, Comment, SavedPage, BrowserHistoryEntry (Codable)
  - ios_services: ShtellAPIClient, UserAPIService, CommentAPIService, SavedPagesAPIService, LocalHistoryService
  - ios_viewmodels: AuthViewModel rewrite, WebPageViewModel simplification
  - cloudkit_deletion: CloudKit/ dir, CK_* models, *Like/*Save models, dead comment views
priority: HIGH
blockers: DynamoDB_tables_not_yet_created
deferred_to_1_4:
  - comment_likes
  - webpage_likes
  - user_profiles
  - follows_blocks_mutes
  - xcode_project_rename
```

### TECHNICAL_STACK
```yaml
ios:
  platform: iOS
  min_version: 16.0
  ui_framework: SwiftUI
  web_engine: WKWebView
  project_name: DumFlow.xcodeproj  # Legacy name

backend:
  database: AWS_DynamoDB
  api_proxy: Vercel_Serverless
  auth: Sign_in_with_Apple_to_Cognito
  region: us-east-1
```

### FILE_PATTERNS
```yaml
navigation_code: shtell/Features/Navigation/
old_code_archived: archive/old-browseforward
documentation: .claude/
backend_api: vercel-backend/api/
test_files: DumFlowTests/
```

### DEVELOPMENT_CONVENTIONS
```yaml
code_style:
  indentation: 2_spaces
  swift_version: 5.9
  swiftui: true
  uikit: avoid_when_possible

git:
  branch_pattern: feature/[name]
  commit_format: conventional_commits
  main_branch: main

testing:
  framework: XCTest
  ui_tests: XCUITest
  min_coverage: 70_percent
```

### CURRENT_PRIORITIES
```yaml
immediate:
  1: Create_DynamoDB_tables_in_AWS_console_(shtell-users,_shtell-comments,_shtell-saved-pages)
  2: Deploy_Vercel_API_routes_(users,_comments,_saved-pages)
  3: New_iOS_Codable_models_(Phase_1)
  4: ShtellAPIClient_+_service_layer_(Phase_2)
  5: Rewrite_AuthViewModel_(Phase_3)
  6: Rewrite_WebPageViewModel_(Phase_4)
  7: Clean_up_comment_views_(Phase_5)
  8: Delete_CloudKit_infrastructure_(Phase_6)
  9: Remove_import_CloudKit_from_all_files_(Phase_7)
  10: Strip_entitlements_(Phase_8)

next_sprint:
  1: Comment_likes_(1.4)
  2: Webpage_likes_(1.4)
  3: User_profiles_(1.4)
  4: AdMob_integration
```

### API_CONTRACTS
```yaml
navigation_controller:
  vertical:
    - navigateToNext()
    - navigateToPrevious()
  horizontal:
    - switchToTab(index)
    - createNewTab()
  toolbar:
    - updateFavicon(tabID, image)
    - highlightTab(index)
  pool:
    - getWebView(identifier)
    - recycleWebView(webview)
```

### PERFORMANCE_REQUIREMENTS
```yaml
hard_limits:
  max_memory_mb: 200
  min_fps: 55
  max_response_ms: 100

targets:
  memory_mb: 150
  fps: 60
  response_ms: 50
  preload_ms: 500
```

### DO_NOT_MODIFY
```yaml
protected:
  - AWS_credentials
  - Production_database
  - User_data
  - App_Store_metadata
  - Payment_processing
  - Analytics_tracking

deprecated:
  - CloudKit_integration
  - BrowseForward_old_implementation
  - Pull_to_refresh_gesture
```

### EXISTING_FEATURES
```yaml
shipped_1_2_0:
  - BrowseForward_content_discovery
  - Pull_down_gesture_for_content
  - Category_selection_long_press
  - Sign_in_with_Apple (SIWA_fix_in_1.2.0)
  - Comment_system_with_quotes
  - Reply_threads
  - Saved_pages_with_metadata
  - Share_to_Shtell_extension
  - Custom_shtell_protocol
  - CloudKit_backend (BEING_REPLACED)

in_development_1_3_0:
  - CloudKit_to_DynamoDB_migration
  - New_Vercel_API_routes_(users,_comments,_saved-pages)
  - Local_browser_history_(no_network)
  - Simplified_comment_model_(no_likes)

planned_1_4_0:
  - Comment_likes
  - Webpage_likes
  - User_profiles_(photo,_bio)
  - Follows_blocks_mutes

planned_2_x:
  - Cognito_authentication
  - Tab_persistence
  - WebView_optimization
  - TikTok_vertical_navigation
  - Horizontal_tab_switching
  - Bottom_toolbar_with_favicons
  - AdMob_integration

planned_3_0_0:
  - User_profiles
  - Following_system
  - Social_feeds
  - Activity_timeline
```

### CONTENT_STRATEGY
```yaml
target_audience:
  age: 20-35
  location: NYC_Brooklyn_focus
  interests: tech_creative_culture

content_sources:
  current:
    - Reddit: [TrueReddit, longreads, webgames]
    - HackerNews: tech_science
    - Internet_Archive: books_culture
    - TMDB: movies
  planned:
    - Medium: tech_articles
    - Letterboxd: film_reviews
    - Designboom: design_art
    - Polygon: gaming_culture

content_curation:
  daily_items: 15-20
  categories: [Science, Culture, Entertainment, News, Classics]
  quality_threshold: 0.7
  avoid: paywalled_content
  prioritize: mobile_friendly

content_scoring:
  factors: [relevance, quality, mobile_compatibility, freshness]
  ai_enhancement: metadata_generation
  deduplication: url_normalization
```

### BLOCKED_DOMAINS
```yaml
paywalls:
  - wsj.com
  - nytimes.com
  - ft.com
  - economist.com
  - bloomberg.com
  - washingtonpost.com
  - theathlantic.com
```

### BUILD_CONFIGURATION
```yaml
testflight:
  version: 2.1.0
  build: auto_increment
  distribution: internal_testing

app_store:
  bundle_id: com.shtell.browser
  team_id: [REDACTED]
  provisioning: automatic
```

## === CLAUDE CONTEXT END ===

---

*Last Updated: January 16, 2025*
*Documentation Version: 2.0*
*Maintained by: Tab 7 - Documentation System*