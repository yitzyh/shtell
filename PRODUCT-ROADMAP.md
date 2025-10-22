# Shtell Product Roadmap
*Updated: October 2025*

## Release Strategy
After initial TestFlight distribution as 1.1.7, we're resetting to proper semantic versioning starting with 1.0.0.

---

## Version 1.0.0 (Build 3) - Released to TestFlight
**Former: 1.1.7**

### Major Features
- **BrowseForward Feature**: Pull-down gesture to explore curated content
- **Category Selection**: Long-press orange arrow to choose discovery topics
- **Sign In with Apple**: Save and comment on webpages
- **Comment System**: Quote, view, post, and reply to comments
- **Long-press Bookmark**: Long-press bookmark button to open Saved Pages view
- **Splash Screen Enhancement**: Fixed shtell://beta metadata
  - Proper domain display ("shtell" instead of "url-379..." or "beta")
  - Custom title: "Shtell - The comment section for the internet"
  - App icon as favicon/thumbnail

### Bug Fixes
- Save button now works on first click with full metadata
- BrowseForward arrow direction corrected
- Long-press forward button crash fixed
- Comment count positioning improved
- Share to Shtell extension fixed
- URL normalization for shtell:// custom URLs fixed
- URL observer preventing data: URLs from polluting navigation fixed
- shortURL() extension now displays "shtell" for custom protocol

### Technical Improvements
- App display name changed from "DumFlow" to "Shtell"
- Cleaned up compiler warnings (onChange deprecation, variable mutability)
- Added proper CloudKit record handling for custom URLs
- New app logo added

---

## Version 1.0.1 (Planned)
**Former: 1.1.8**
**Focus: AWS Migration & Tabs**

### MUST HAVE

#### 1. Backend Migration (CRITICAL)
- **Complete AWS Migration - Clean Slate Approach** (Issue #1)
  - **AWS Infrastructure Setup**
    - DynamoDB tables: Users, Comments, WebPages, Likes, Saves, Follows
    - AWS Cognito identity pool configuration
    - API Gateway endpoints with IAM roles
    - Environment-based credential management
    - Remove hardcoded AWS credentials from Info.plist

  - **Authentication Flow**
    - Sign In with Apple → AWS Cognito integration
    - Temporary credentials with proper auth flow
    - User identity mapping (Apple ID → Cognito)

  - **iOS Code Migration**
    - Replace all CloudKit calls with AWS SDK calls
    - Update CommentService to use DynamoDB
    - Update WebPageViewModel to use DynamoDB
    - Update AuthService for Cognito
    - Implement cascading deletion for related records (Issue #5)

  - **Testing & Deployment**
    - Feature branch testing with TestFlight build
    - Performance testing and optimization
    - Clean data start (no migration of old CloudKit data)
    - TestFlight notes: users will need to re-save content after update

#### 2. Tabs
- **Tab System** (can be developed in parallel with AWS migration)
  - Multiple browser tabs (Safari-style tab management)
  - Tab bar UI (compact grid view)
  - Swipe between tabs
  - New tab button
  - Close tab gesture
  - Tab preview thumbnails
  - Persist tabs across app launches

### MAYBE (If Time Permits)

#### 3. WebView Preloading Optimization
- Background WebView preloading of next BrowseForward content
- Eliminate 1-3 second loading delay on pull-forward
- WebView pool management (1 previous + current + 2 next ~100-150 MB)
- Horizontal swipe back to previous webpage
- Smart memory management (~200MB total usage)
- Forward history integration with instant right-swipe navigation

#### 4. Save Loading Race Condition Fix (Issue #2)
- Fix race condition when saving webpages
- Ensure metadata loads before save operation completes
- Prevent incomplete webpage records (missing title, favicon, thumbnail)

### Branch Structure
```
MUST HAVE:
feature/aws-migration (PRIORITY 1)
├── feature/aws-infrastructure
├── feature/aws-cognito-auth
├── feature/aws-dynamodb-integration
└── feature/cloudkit-removal

feature/tabs (PRIORITY 2 - can develop in parallel)
├── feature/tab-manager
├── feature/tab-ui
└── feature/tab-persistence

MAYBE:
feature/webview-preloading (if time permits)
feature/save-race-condition-fix (if time permits)
```

---

## Version 1.0.2 (Planned)
**Former: 1.1.9**
**Focus: Performance, UX & Social Features**

### Core Features

#### Navigation & Performance
- **WebView Preloading Optimization** (from 1.0.1 maybe list)
  - Background WebView preloading of next BrowseForward content
  - Eliminate 1-3 second loading delay on pull-forward
  - WebView pool management
  - Horizontal swipe back to previous webpage
  - Smart memory management (~200MB total usage)

#### Bug Fixes
- **Save Loading Race Condition Fix** (Issue #2 - from 1.0.1 maybe list)
  - Fix race condition when saving webpages
  - Ensure metadata loads before save operation completes
  - Prevent incomplete webpage records

#### UX Improvements
- **Flexible Toolbar Positioning**
  - User preference settings (bottom horizontal, left vertical, auto-vertical)
  - Orientation detection for automatic landscape switching

#### Content & Comments
- **Enhanced Comment Features**
  - Improved reply thread UI
  - Comment notifications
  - Nested comment depth indicators
  - Comment moderation tools

- **Content Expansion**
  - Radio, science, AI categories
  - YouTube API integration
  - Reddit-design API

#### Monetization
- **Ad Integration**
  - Show native ads in CommentView
  - Configurable frequency (e.g., every 3rd pull)
  - Ad preloading and caching for smooth experience
  - Revenue tracking and analytics

#### Branding
- **Update App Logo**
  - Design and implement new logo
  - Update app icon across all sizes
  - Update splash screen branding

#### Social Platform
- **User Profiles**
  - Public user profiles with bio and stats
  - User comment history
  - Saved content collections
  - Profile customization

- **Following System**
  - Follow/unfollow users
  - Follower/following counts
  - Following activity feed
  - Follow suggestions

- **Social Feeds**
  - Personalized feed based on followed users
  - Discovery feed for popular content
  - Friend activity timeline
  - Social recommendations

- **User Interaction**
  - User-to-user messaging (optional)
  - @mentions in comments
  - User tagging
  - Social notifications


### Branch Structure
```
feature/webview-preloading
feature/save-race-condition-fix
feature/toolbar-positioning
feature/comments-v2
feature/content-expansion

feature/social-features
├── feature/user-profiles
├── feature/following-system
├── feature/social-feeds
└── feature/social-notifications
```

---

## Version 1.0.3+ (Future Roadmap)

### Comment Moderation
- **Report Functionality** (Issue - moved from incomplete features)
  - Report inappropriate comments
  - Moderation dashboard
  - Auto-flagging system
  - User blocking capabilities

### Content Discovery
- **Trending & Recommendations**
  - Trending content views
  - Personalized recommendations
  - Category-based trending
  - Time-based trending (daily, weekly)

### Additional API Integrations
- **Content Sources**
  - Medium API (tech articles, thought leadership)
  - Letterboxd API (film reviews, indie cinema)
  - Complex API (hip-hop, sneakers, pop culture)
  - Designboom API (architecture, design, art)
  - Polygon API (gaming, entertainment, tech culture)

### UX Enhancements
- **Reader Mode Improvements**
  - Enhanced readability
  - Custom fonts and themes
  - Text-to-speech integration

- **Gesture Controls**
  - Advanced navigation gestures
  - Customizable gesture mappings
  - Gesture tutorials

- **Content Filtering**
  - Advanced content filters
  - Custom blocklists
  - Content preferences
  - Time-sensitive filtering

### Performance
- **iOS WebKit Optimizations**
  - iOS 26+ performance improvements
  - Memory usage optimization
  - Battery efficiency improvements
  - Network performance tuning

---

## Content Strategy

### Target Audience
- **Demographics**: 20s-30s creative/tech professionals
- **Location**: NYC/Brooklyn (expanding nationwide)
- **Content Preference**: Quality long-form, thoughtful content, design/culture

### Content Categories by Priority

#### High-Priority (Active Development)
1. **Thoughtful Content**
   - r/TrueReddit, r/Foodforthought, r/longreads, r/indepthstories
   - Internet Archive books
   - 15-20 items/day target

2. **Science & Technology**
   - HackerNews, r/physics, YouTube tech
   - Internet Archive science
   - Medium tech articles (planned)

3. **Culture & Arts**
   - Internet Archive (art, culture)
   - r/books, Designboom (planned)
   - Letterboxd (planned)

4. **Entertainment**
   - r/webgames (mobile-friendly only)
   - YouTube music categories
   - TMDB movies, Letterboxd (planned)

#### Medium-Priority (Future)
5. **Local & Lifestyle**
   - r/food, r/mealtimevideos
   - NYC local APIs (planned)
   - Foursquare (planned)

### Content Quality Criteria
- **Keep**: Timeless content, educational value, creative inspiration
- **Remove**: Outdated news, tech reviews, time-sensitive content
- **Enhance**: Complete metadata, AI summaries, quality scores

### Paywall Domains (Blocked)
wsj.com, nytimes.com, nymag.com, ft.com, economist.com, bloomberg.com, washingtonpost.com, theathlantic.com, telegraph.co.uk, bostonglobe.com, latimes.com

---

## Feature Backlog (Unprioritized)

### UI/UX Ideas
- **Square Thumbnails** (Issue #6) - Use square thumbnails in WebPageRowView for better visual consistency
- Animate searchbar shortURL text transitions
- Floating mini-toolbar for fullscreen content
- Dark mode enhancements
- Accessibility improvements

### Reader Mode
- **Custom Reader Mode** (already 90% coded, just disabled)
  - Enhanced readability with article extraction
  - Customizable background colors (white/cream/dark/black)
  - Adjustable text colors and sizes
  - Multiple font families (system/serif/sans-serif/monospace)
  - Configurable line heights and content width
  - Text-to-speech integration (future)
  - Note: Safari Reader Mode available as interim solution

### Advanced Features
- Offline reading mode
- Reading analytics and stats
- Content collections/playlists
- Cross-device sync improvements
- Browser extension integration

### Enhanced Search
- **Microsoft API Web Crawler Integration**
  - Full-text search across saved content
  - Advanced filtering and sorting
  - Search history and suggestions
  - Keyword-based content discovery

---

## Success Metrics

### Version 1.0.1 Goals
- **Migration Success**: 100% of data operations running on AWS (zero CloudKit calls)
- **Authentication**: Seamless Sign In with Apple → Cognito flow
- **Performance**: Maintain or improve API response times vs CloudKit
- **Stability**: Zero data loss during clean slate migration
- **Tabs**: 60% of users open 2+ tabs per session

### Version 1.0.2 Goals
- **Performance**: <500ms average page load with preloading
- **Memory**: Maintain <200MB usage with preloaded WebViews
- **Social**: 20% of users follow at least 3 other users
- **Engagement**: 50% increase in comments from social features
- **Retention**: 15% improvement in DAU from social feeds
- **Growth**: 2x user growth from social discovery

### Long-term Goals
- **Content Quality**: 90%+ items with complete metadata
- **Mobile Compatibility**: 95%+ active content works on iPhone
- **Query Performance**: <200ms response time for BrowseForward
- **User Satisfaction**: 4.5+ App Store rating

---

## Development Workflow

### Branch Strategy
```
main (production)
├── develop (integration)
├── feature/[feature-name]
└── release/[version]
```

### Testing Requirements
- Unit tests for core functionality
- Integration tests for API endpoints
- UI tests for critical user flows
- Performance testing on physical devices
- TestFlight beta testing before release

### Release Process
1. Feature development on feature branches
2. Merge to develop for integration testing
3. Create release branch for final QA
4. TestFlight distribution to beta testers
5. Address feedback and bug fixes
6. App Store submission
7. Post-release monitoring

---

*This roadmap is a living document and subject to change based on user feedback, technical constraints, and business priorities.*
