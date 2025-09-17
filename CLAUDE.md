# DumFlow Development Plan

## TestFlight Release Schedule

### Version 1.1.7 (Current - Complete Pull-Forward)
#### Pull-Forward Feature (Social Media-Style Content Discovery)
- Replace pull-to-refresh with instant next webpage display
- Preload next webpage in background WebView for instant switching
- Slide animation from top (no loading screen/orange background)
- Maintain WebView history stack for navigation back
- Display ads between pull-forward webpages for monetization

#### Implementation Plan
**Phase 1: WebView Preloading System**
- Preload next BrowseForward page in background WebView
- Replace pull-to-refresh gesture handler
- Implement slide-in animation for next webpage

**Phase 2: Navigation Stack Management (MOVED TO 1.1.8)**
- Maintain 1 previous + current + 2 next WebViews (~100-150 MB)
- Add horizontal swipe back to previous webpage
- Memory management for WebView pool

**Phase 2.5: Forward History Integration (MOVED TO 1.1.8)**
- Preload 2-3 BrowseForward URLs into WebView forward history
- Enable instant right-swipe navigation using native `goForward()`
- Background WebView pool for seamless content preloading
- Smart memory management to maintain ~200MB total usage

**Phase 3: Ad Integration (MOVED TO 1.1.8)**
- Implement ad views between pull-forward content
- Ad frequency configuration (e.g., every 3rd pull)
- Ad loading and caching for smooth experience
- Revenue tracking and analytics integration

#### Branch Structure
```bash
feature/pull-forward          # Main pull-forward integration
├── feature/pull-forward-ui   # WebView preloading, gestures, animations
├── feature/pull-forward-aws  # Content queries, preloading optimization
└── feature/pull-forward-ads  # Ad integration, frequency control, analytics
```

### Version 1.1.8 (Comments System & Advanced Content Curation)
#### Navigation Stack Management
- Maintain 1 previous + current + 2 next WebViews (~100-150 MB)
- Add horizontal swipe back to previous webpage
- Memory management for WebView pool

#### Forward History Integration
- Preload 2-3 BrowseForward URLs into WebView forward history
- Enable instant right-swipe navigation using native `goForward()`
- Background WebView pool for seamless content preloading
- Smart memory management to maintain ~200MB total usage

#### Ad Integration
- Implement ad views between pull-forward content
- Ad frequency configuration (e.g., every 3rd pull)
- Ad loading and caching for smooth experience
- Revenue tracking and analytics integration

#### Comment System on Webpages
- User comments on articles and webpages
- Reply threads and nested comments
- Comment moderation and reporting
- Integration with existing content system

#### Flexible Toolbar Positioning System
- User preference settings for toolbar position (bottom horizontal, left vertical, auto-vertical on landscape)
- Separate HorizontalBottomToolbar and VerticalLeftToolbar components
- Orientation detection for automatic switching in landscape mode
- Preserve existing scroll-based animations and functionality

#### Advanced Content Curation (feature/pull-forward-aws)
- Create radio subcategory under internet archive for audio content
- Implement science and AI content categories
- Add long reads category for in-depth articles
- Integrate reddit-design API endpoint
- Add YouTube API integration for science, history, and trailers subcategories

#### Branch Structure
```bash
feature/comments              # Comment system on webpages
├── feature/comments-ui       # Comment views, reply threads
├── feature/comments-aws      # Comment storage, moderation
└── feature/pull-forward-aws  # Advanced content curation and API integration
```

### Version 1.1.9 (Social Features)
#### User Profiles and Social Features
- User profiles and following system
- Social feeds and user-to-user interaction
- Social discovery and recommendations
- Friend connections and social graph

#### Branch Structure
```bash
feature/social-features       # User profiles, following, feeds
├── feature/social-ui         # Profile views, social feeds
└── feature/social-aws        # User relationships, social data
```

### Version 1.2.0 (Content Discovery & Security)
#### Security Improvements
- **AWS Credential Security Migration** - Remove hardcoded AWS credentials from app
- Implement AWS Cognito authentication or API Gateway with IAM roles
- Use temporary credentials and proper authentication flow
- Environment-based credential management for development

#### Content Discovery Features
- Enhanced search and recommendations
- Microsoft API web crawler for search function
- Trending content views
- Advanced content categorization
- Performance optimizations
- *Maybe: Create a floating mini-toolbar that appears over fullscreen content*

---

## Content Sources & APIs

### Currently Integrated
#### News & Discussion
- **HackerNews API** - Tech news, startup discussions, programming content
- **Reddit API** - Current subreddits:
  - r/TrueReddit (15 items) - thoughtful content
  - r/Foodforthought (15 items) - intellectual discussions
  - r/longreads (12 items) - in-depth articles
  - r/webgames (6 items) - browser games
  - r/physics (4 items) - physics discussions
  - r/mealtimevideos (3 items) - educational videos
  - r/books (3 items) - book discussions
  - r/food (2 items) - food content
  - r/indepthstories (1 item) - investigative journalism
  - **MARKED FOR DELETION:** r/psychology, r/space, r/gadgets, r/movies, r/philosophy

#### Archive & Culture
- **Internet Archive API** - Books, art, culture, history, science, tech content
- **Google Books API** - Book metadata and previews
- **Open Library API** - Book information and availability
- **Wikipedia API** - Featured articles, geography, health, technology

#### Entertainment
- **YouTube API** - Music content (electronic, hip-hop, indie, latin, pop, r&b, rock)
- **TMDB API** - Movie database integration with IMDB

### Planned Integration (NYC/Brooklyn Demo Target)
#### Local NYC Content
- **r/nyc** - NYC-specific discussions, local events, city life
- **TimeOut NYC API** - Events, restaurants, nightlife, local culture
- **NYC Open Data API** - Local events, cultural happenings, city data
- **Foursquare API** - NYC restaurant discoveries, local venue recommendations
- **Gothamist API** - NYC-specific news, culture, local stories

#### Professional & Culture
- **Medium API** - Tech articles, startup stories, career advice, thought leadership
- **Complex API** - Hip-hop, sneakers, pop culture, food (NYC-focused content)
- **Designboom API** - Architecture, design, art, creative culture

#### Entertainment & Discovery
- **Letterboxd API** - Film reviews, movie discussions, indie cinema
- **Polygon API** - Gaming, entertainment, tech culture content

### Content Categories by BrowseForward Type
#### Science & Technology
- Internet Archive Science, HackerNews, Reddit (r/physics), YouTube Tech
- *Planned*: Medium API (tech articles), Designboom (design/tech)

#### Culture & Arts
- Internet Archive (Art, Culture), Reddit (r/books, r/longreads)
- *Planned*: Complex API, Gothamist, Letterboxd

#### Local & Lifestyle
- Reddit (r/food, r/mealtimevideos), YouTube Music
- *Planned*: r/nyc, TimeOut NYC, Foursquare, NYC Open Data

#### Long Reads & Thoughtful Content
- Reddit (r/TrueReddit, r/longreads, r/Foodforthought, r/indepthstories), Internet Archive Books
- *Planned*: Medium API

---

## Feature Ideas / Backlog

### UI/UX Enhancements
- **Animate searchbar shortURL text animation feature** - Smooth text transitions when URL changes in search bar
- iOS 26 WebKit performance optimizations (on feature branch `feature/ios26-webkit-performance`)

### Future Considerations
- Reader mode improvements
- Enhanced gesture controls
- Advanced content filtering

---

## Development Commands

### Build & Test
```bash
# Build project
xcodebuild -project DumFlow.xcodeproj -scheme DumFlow -configuration Debug

# Run tests
xcodebuild test -project DumFlow.xcodeproj -scheme DumFlow

# Clean build folder
xcodebuild clean -project DumFlow.xcodeproj
```

### Debug Logging Control
Environment variables to control console output during development:
- `DYNAMO_LOGS=1` - Enable DynamoDB query logging
- `NETWORK_LOGS=1` - Enable network request/response logging  
- `AWS_LOGS=1` - Enable AWS credential and signing logging
- `MEMORY_LOGS=1` - Enable memory usage tracking
- `BROWSE_FORWARD_LOGS=1` - Enable BrowseForward flow logging

**Usage in Xcode:**
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. Add variables as needed (e.g. `DYNAMO_LOGS` = `1`)

### Database Statistics
```bash
# Get total count of all database items
alias db-total="python3 count_wikipedia.py"

# Get database statistics by category/source
alias db-categories="python3 -c 'import boto3; 
dynamodb = boto3.client(\"dynamodb\", region_name=\"us-east-1\", aws_access_key_id=\"AKIAUON2G4CIEFYOZEJX\", aws_secret_access_key=\"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\"); 
resp = dynamodb.scan(TableName=\"webpages\", Select=\"ALL_ATTRIBUTES\"); 
sources = {}; 
categories = {}; 
for item in resp[\"Items\"]: 
    source = item.get(\"source\", {}).get(\"S\", \"unknown\"); 
    sources[source] = sources.get(source, 0) + 1; 
    if \"bf_categories\" in item: 
        cats = item[\"bf_categories\"].get(\"L\", []); 
        for cat in cats: 
            cat_name = cat.get(\"S\", \"unknown\"); 
            categories[cat_name] = categories.get(cat_name, 0) + 1; 
print(\"📊 SOURCES:\"); 
for k,v in sorted(sources.items()): print(f\"  {k}: {v}\"); 
print(\"\\n📂 CATEGORIES:\"); 
for k,v in sorted(categories.items()): print(f\"  {k}: {v}\")'"

# Get detailed content breakdown by tags and source
alias db-detailed="python3 debug_categories.py"

# Check specific content types
alias db-webgames="python3 check_webgames.py"
alias db-food="python3 check_food_sources.py"
alias db-reddit="python3 check_reddit_food.py"

# Verify tagging and categorization
alias db-verify-tags="python3 verify_webgames_tags.py"
alias db-schema="python3 check_table_schema.py"
```

### Code Quality
```bash
# Run SwiftLint (if configured)
swiftlint

# Run SwiftFormat (if configured)
swiftformat .
```

---

## Content Filtering

### Paywall Domains
Domains blocked from BrowseForward content due to paywall restrictions:
- `wsj.com` - Wall Street Journal
- `nytimes.com` - New York Times
- `nymag.com` - New York Magazine
- `ft.com` - Financial Times
- `economist.com` - The Economist
- `bloomberg.com` - Bloomberg
- `washingtonpost.com` - Washington Post
- `theathlantic.com` - The Atlantic
- `telegraph.co.uk` - The Telegraph
- `bostonglobe.com` - Boston Globe
- `latimes.com` - Los Angeles Times

**Location in code:** `DumFlow/Features/BrowseForward/ViewModels/BrowseForwardViewModel.swift:41-45`

---

## Notes
- Always test horizontal navigation on physical device for accurate gesture feel
- Monitor memory usage with multiple preloaded WebViews
- Ensure accessibility support for horizontal navigation