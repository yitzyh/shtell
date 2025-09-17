# bf-db Agent - BrowseForward Database Management System

## Agent Purpose
The `bf-db` agent is a specialized database management system for DumFlow's BrowseForward feature. It handles all AWS DynamoDB operations, content curation, API integration, and quality optimization for the pull-forward browsing experience.

## Target Audience
- **Primary**: Creative professionals and tech-savvy users in their 20s-30s
- **Location Focus**: NYC/Brooklyn area (expanding nationwide)
- **Content Preference**: Quality long-form articles, thoughtful content, design/culture

## Database Architecture

### AWS DynamoDB Structure
- **Table**: `webpages` (region: us-east-1)
- **Items**: 60,991+ total (was 833 in older analysis, now significantly expanded)
- **Primary Key**: `url` (HASH)
- **Global Secondary Indexes**:
  - `category-status-index`: bfCategory (HASH) + status (RANGE)
  - `status-index`: status (HASH)
  - `source-status-index`: source (HASH) + status (RANGE)

### Current Content Distribution
```
Movies/Entertainment: 12,736 items (tmdb-to-imdb, reddit-movies)
Books: 13,881 items (google-books, internet-archive-books, reddit-books)
Culture/Art: 10,042 items (internet-archive-culture/art, wikipedia-art)
Science/Tech: 11,270 items (hackernews, reddit-physics, internet-archive-science)
Quality Articles: 3,761 items (reddit-TrueReddit, Foodforthought, longreads)
Games: 493 items (reddit-webgames - 1 active, 186 inactive, needs mobile optimization)
Music: 755 items (youtube-music categories)
```

## Priority Tasks

### 1. Content Cleanup (Immediate)
**Reddit Sources to Clean:**
- `reddit-movies` (697 items) - remove outdated reviews
- `reddit-gadgets` (858 items) - remove outdated tech content
- `reddit-space` (389 items) - filter for timeless content
- `reddit-psychology` (549 items) - keep quality articles only
- `reddit-TrueReddit` (741 items) - light cleanup, already high quality
- `reddit-longreads` (678 items) - perfect for audience, light cleanup

**Cleanup Method**: Set `isActive=false` (soft delete preserves data)

### 2. Webgames Mobile Optimization
- **Current State**: 493 total games, 1 active, 186 inactive
- **Goal**: Find mobile-friendly games from remaining 306 desktopOnly items
- **Method**: Use existing Python scripts' mobile compatibility criteria
- **Success Metric**: 50+ active mobile-friendly games

### 3. Enhanced Metadata Generation
Generate for ALL content:
- `tags` - topic keywords for categorization
- `wordCount` - article length
- `readingTime` - estimated minutes to read
- `contentType` - article/video/audio/game
- `qualityScore` - engagement/relevance rating (0-100)
- `mobileFriendly` - boolean for iPhone Safari compatibility
- `difficulty` - beginner/intermediate/advanced
- `aiSummary` - brief content description
- `bfCategory` - primary category for BrowseForward
- `bfSubcategory` - subcategory for refined filtering

### 4. New API Integration
**Priority Order:**
1. **Letterboxd API** - Movie reviews/lists for film enthusiasts
2. **Medium API** - Quality long-form articles
3. **Designboom API** - Architecture/design content
4. **Core77 API** - Industrial design content
5. **YouTube Subcategories**:
   - Documentaries
   - Video essays
   - Nature content
   - Music videos
6. **NYC Local** (for Version 1.1.8):
   - r/nyc subreddit
   - TimeOut NYC API
   - Gothamist API
   - NYC Open Data API

### 5. Internet Archive Quality Filtering
Clean up 25,000+ items across:
- `internet-archive-culture` (5,000 items)
- `internet-archive-art` (5,000 items)
- `internet-archive-history` (5,000 items)
- `internet-archive-science` (4,999 items)
- `internet-archive-tech` (5,000 items)

## Technical Implementation

### Core Operations
```python
# Query Examples
def fetch_active_content(category, limit=200):
    """Query using category-status-index GSI"""
    return dynamodb.query(
        TableName='webpages',
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :cat AND #status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={
            ':cat': {'S': category},
            ':status': {'S': 'active'}
        },
        Limit=limit
    )

def mark_inactive(url):
    """Soft delete by setting isActive=false"""
    return dynamodb.update_item(
        TableName='webpages',
        Key={'url': {'S': url}},
        UpdateExpression='SET isActive = :inactive, #status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={
            ':inactive': {'BOOL': False},
            ':status': {'S': 'inactive'}
        }
    )
```

### Integration with Swift Services
- **Service**: `DynamoDBWebPageService.swift`
- **Method**: `fetchBFQueueItems()` with `isActiveOnly=true`
- **Models**: `AWSWebPageItem.swift`, `BrowseForwardItem.swift`
- **Query Limit**: 200 items per request (optimized for preloading)

## Content Curation Strategy

### High-Priority Keep Categories
1. **Thoughtful Content**:
   - r/TrueReddit (15 items/day target)
   - r/Foodforthought (15 items/day)
   - r/longreads (12 items/day)
   - Internet Archive books

2. **NYC Local Content** (Version 1.1.8):
   - r/nyc (new addition)
   - TimeOut NYC events
   - Gothamist articles
   - Local venue recommendations

3. **Creative/Design**:
   - Designboom (architecture/design)
   - Core77 (industrial design)
   - Internet Archive art/culture

4. **Entertainment**:
   - r/webgames (mobile-friendly only)
   - YouTube music videos
   - Letterboxd movie reviews
   - TMDB movies

### Content Quality Criteria
- **Keep**: Timeless content, educational value, creative inspiration
- **Remove**: Outdated news, tech reviews, time-sensitive content
- **Enhance**: Add metadata, summaries, quality scores to all content

## Success Metrics
- **Content Quality**: 90%+ items have complete metadata
- **Mobile Compatibility**: 95%+ active content works on iPhone
- **User Engagement**: Higher interaction rates on curated content
- **API Reliability**: 99%+ uptime for content fetching
- **Query Performance**: <200ms response time for BrowseForward

## Database Credentials (Development)
```python
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"
```

## Agent Commands

### Analysis Commands
- `analyze-source <source>` - Detailed analysis of a content source
- `content-stats` - Overview of database content distribution
- `quality-report` - Content quality metrics report

### Cleanup Commands
- `cleanup-reddit` - Clean all Reddit sources
- `cleanup-webgames` - Find mobile-friendly games
- `cleanup-archive` - Filter Internet Archive content

### Integration Commands
- `add-api <api-name>` - Integrate new content source
- `test-api <api-name>` - Test API connectivity
- `fetch-content <source> <limit>` - Fetch new content

### Metadata Commands
- `generate-metadata <source>` - Add enhanced metadata
- `calculate-quality` - Generate quality scores
- `tag-content` - Auto-generate tags

## Notes
- Never remove content based solely on age or upvotes
- Focus on enrichment over deletion
- All deletions are soft deletes (isActive=false)
- Prioritize quality content for creative professionals
- Target demographic: NYC 20s-30s creative/tech professionals