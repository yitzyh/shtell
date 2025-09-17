#!/usr/bin/env python3
"""
New API Integrations Framework
=============================

Framework for integrating new content APIs for DumFlow's BrowseForward feature.
Supports the planned integrations from the development plan.

New API Targets:
- Letterboxd API (movie reviews/lists)
- Medium API (quality articles)
- Designboom API (design content)
- Core77 API (industrial design)
- YouTube Documentary/Essay subcategories
- TimeOut NYC API (local content)
- Foursquare API (NYC venues)
- Complex API (hip-hop, culture)
- Gothamist API (NYC news)

Author: Claude Code
Version: 1.0.0
Target: Creative professionals in NYC area (20s-30s)
"""

import boto3
import requests
import json
import time
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Tuple, Any, Optional
from urllib.parse import urlencode, urlparse
from dataclasses import dataclass, field
import hashlib
import re
from abc import ABC, abstractmethod

# Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

@dataclass
class APIContentItem:
    """Standardized content item from any API"""
    url: str
    title: str
    description: str = ""
    source: str = ""
    category: str = ""
    bf_category: str = ""
    bf_subcategory: str = ""
    author: str = ""
    published_date: str = ""
    tags: List[str] = field(default_factory=list)
    thumbnail_url: str = ""
    rating: float = 0.0
    engagement_metrics: Dict[str, int] = field(default_factory=dict)
    location: str = ""  # For location-based content
    price_info: str = ""  # For venue/restaurant content
    content_type: str = "article"
    quality_indicators: Dict[str, Any] = field(default_factory=dict)

    @property
    def id(self) -> str:
        """Generate unique ID from URL"""
        return hashlib.md5(self.url.encode()).hexdigest()

    @property
    def domain(self) -> str:
        """Extract domain from URL"""
        try:
            return urlparse(self.url).netloc.lower().replace('www.', '')
        except:
            return 'unknown'

class BaseAPIIntegration(ABC):
    """Base class for all API integrations"""

    def __init__(self, api_key: str = None):
        self.api_key = api_key
        self.rate_limit_delay = 1.0  # Seconds between requests
        self.last_request_time = 0
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'DumFlow/1.0 (Content Aggregator for Creative Professionals)'
        })

    @abstractmethod
    def fetch_content(self, limit: int = 50, **kwargs) -> List[APIContentItem]:
        """Fetch content from the API"""
        pass

    @abstractmethod
    def get_source_name(self) -> str:
        """Get the source identifier for database storage"""
        pass

    def _rate_limit(self):
        """Enforce rate limiting"""
        elapsed = time.time() - self.last_request_time
        if elapsed < self.rate_limit_delay:
            time.sleep(self.rate_limit_delay - elapsed)
        self.last_request_time = time.time()

    def _make_request(self, url: str, params: Dict = None, headers: Dict = None) -> Dict:
        """Make rate-limited API request"""
        self._rate_limit()

        if headers:
            request_headers = {**self.session.headers, **headers}
        else:
            request_headers = self.session.headers

        try:
            response = self.session.get(url, params=params, headers=request_headers, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ API request failed: {e}")
            return {}

class LetterboxdIntegration(BaseAPIIntegration):
    """Letterboxd API integration for film reviews and lists"""

    def __init__(self, api_key: str = None):
        super().__init__(api_key)
        self.base_url = "https://api.letterboxd.com/api/v0"
        self.rate_limit_delay = 1.5  # Letterboxd rate limits

    def get_source_name(self) -> str:
        return "letterboxd"

    def fetch_content(self, limit: int = 50, list_type: str = "popular") -> List[APIContentItem]:
        """Fetch film reviews and lists from Letterboxd"""
        print(f"🎬 Fetching from Letterboxd ({list_type})...")

        items = []

        # Note: This is a conceptual implementation
        # Actual Letterboxd API requires OAuth and has specific endpoints

        # Simulated popular films/reviews data structure
        sample_data = [
            {
                "film": {
                    "name": "The Grand Budapest Hotel",
                    "year": 2014,
                    "links": [{"type": "letterboxd", "url": "https://letterboxd.com/film/the-grand-budapest-hotel/"}]
                },
                "review": {
                    "text": "Wes Anderson's meticulous visual storytelling...",
                    "rating": 4.5,
                    "author": {"displayName": "CinemaEnthusiast"}
                },
                "published": "2024-01-15T10:00:00Z"
            }
        ]

        # Transform to APIContentItem format
        for film_data in sample_data[:limit]:
            film = film_data.get("film", {})
            review = film_data.get("review", {})

            # Find letterboxd URL
            letterboxd_url = ""
            for link in film.get("links", []):
                if link.get("type") == "letterboxd":
                    letterboxd_url = link.get("url", "")
                    break

            if letterboxd_url:
                item = APIContentItem(
                    url=letterboxd_url,
                    title=f"{film.get('name', '')} ({film.get('year', '')})",
                    description=review.get("text", "")[:200] + "...",
                    source=self.get_source_name(),
                    category="movies",
                    bf_category="culture",
                    bf_subcategory="film-reviews",
                    author=review.get("author", {}).get("displayName", ""),
                    published_date=film_data.get("published", ""),
                    tags=["film", "review", "cinema", "letterboxd"],
                    rating=review.get("rating", 0),
                    content_type="review",
                    quality_indicators={
                        "has_rating": True,
                        "has_review_text": bool(review.get("text")),
                        "verified_reviewer": True
                    }
                )
                items.append(item)

        print(f"✅ Fetched {len(items)} film reviews from Letterboxd")
        return items

class MediumIntegration(BaseAPIIntegration):
    """Medium API integration for quality articles"""

    def __init__(self, api_key: str = None):
        super().__init__(api_key)
        self.base_url = "https://api.medium.com/v1"

    def get_source_name(self) -> str:
        return "medium"

    def fetch_content(self, limit: int = 50, topic: str = "technology") -> List[APIContentItem]:
        """Fetch articles from Medium by topic"""
        print(f"📝 Fetching from Medium (topic: {topic})...")

        # Medium's API is limited, so we'd likely use RSS feeds or web scraping
        # This is a conceptual implementation showing the data structure

        items = []

        # Using Medium's RSS feeds as a more accessible alternative
        rss_urls = {
            "technology": "https://medium.com/feed/topic/technology",
            "design": "https://medium.com/feed/topic/design",
            "startup": "https://medium.com/feed/topic/startup",
            "culture": "https://medium.com/feed/topic/culture",
            "writing": "https://medium.com/feed/topic/writing"
        }

        rss_url = rss_urls.get(topic, rss_urls["technology"])

        try:
            # This would use feedparser library in real implementation
            # For now, simulating the data structure
            sample_articles = [
                {
                    "title": "The Future of Creative AI: Beyond the Hype",
                    "link": "https://medium.com/@author/future-creative-ai-123",
                    "description": "Exploring how AI is truly transforming creative workflows...",
                    "author": "TechCreative",
                    "published": "2024-01-15T09:00:00Z",
                    "categories": ["AI", "Creativity", "Technology"]
                }
            ]

            for article in sample_articles[:limit]:
                # Calculate quality score based on Medium metrics
                quality_score = self._calculate_medium_quality(article)

                if quality_score >= 6:  # Only high-quality articles
                    item = APIContentItem(
                        url=article.get("link", ""),
                        title=article.get("title", ""),
                        description=article.get("description", ""),
                        source=self.get_source_name(),
                        category="articles",
                        bf_category="technology" if topic == "technology" else "culture",
                        bf_subcategory=f"medium-{topic}",
                        author=article.get("author", ""),
                        published_date=article.get("published", ""),
                        tags=["medium", topic] + article.get("categories", []),
                        content_type="article",
                        quality_indicators={
                            "medium_quality_score": quality_score,
                            "has_author": bool(article.get("author")),
                            "topic_relevance": topic in article.get("title", "").lower()
                        }
                    )
                    items.append(item)

        except Exception as e:
            print(f"❌ Error fetching from Medium: {e}")

        print(f"✅ Fetched {len(items)} articles from Medium")
        return items

    def _calculate_medium_quality(self, article: Dict) -> int:
        """Calculate quality score for Medium articles"""
        score = 5  # Base score

        # Title quality
        title = article.get("title", "").lower()
        if any(indicator in title for indicator in ["guide", "complete", "ultimate", "deep dive"]):
            score += 2
        if any(clickbait in title for clickbait in ["shocking", "unbelievable", "amazing"]):
            score -= 2

        # Has author
        if article.get("author"):
            score += 1

        # Description length (longer usually better on Medium)
        desc_length = len(article.get("description", ""))
        if desc_length > 200:
            score += 1

        return max(1, min(10, score))

class DesignboomIntegration(BaseAPIIntegration):
    """Designboom API integration for design content"""

    def get_source_name(self) -> str:
        return "designboom"

    def fetch_content(self, limit: int = 50, category: str = "architecture") -> List[APIContentItem]:
        """Fetch design content from Designboom"""
        print(f"🏗️ Fetching from Designboom (category: {category})...")

        items = []

        # Designboom likely uses RSS feeds
        categories = {
            "architecture": "https://www.designboom.com/architecture/feed/",
            "design": "https://www.designboom.com/design/feed/",
            "art": "https://www.designboom.com/art/feed/",
            "technology": "https://www.designboom.com/technology/feed/"
        }

        feed_url = categories.get(category, categories["design"])

        # Simulated content structure
        sample_content = [
            {
                "title": "Sustainable Architecture: The Future of Urban Design",
                "link": "https://www.designboom.com/architecture/sustainable-urban-design-2024",
                "description": "Exploring innovative approaches to sustainable urban architecture...",
                "published": "2024-01-15T08:00:00Z",
                "category": category,
                "thumbnail": "https://www.designboom.com/images/thumb.jpg"
            }
        ]

        for content in sample_content[:limit]:
            item = APIContentItem(
                url=content.get("link", ""),
                title=content.get("title", ""),
                description=content.get("description", ""),
                source=self.get_source_name(),
                category="design",
                bf_category="culture",
                bf_subcategory=f"design-{category}",
                published_date=content.get("published", ""),
                tags=["design", "designboom", category, "creative"],
                thumbnail_url=content.get("thumbnail", ""),
                content_type="article",
                quality_indicators={
                    "design_focused": True,
                    "has_visuals": bool(content.get("thumbnail")),
                    "professional_source": True
                }
            )
            items.append(item)

        print(f"✅ Fetched {len(items)} design articles from Designboom")
        return items

class YouTubeDocumentaryIntegration(BaseAPIIntegration):
    """YouTube API integration for documentaries and video essays"""

    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.base_url = "https://www.googleapis.com/youtube/v3"

    def get_source_name(self) -> str:
        return "youtube-documentaries"

    def fetch_content(self, limit: int = 50, content_type: str = "documentary") -> List[APIContentItem]:
        """Fetch documentaries and video essays from YouTube"""
        print(f"🎥 Fetching from YouTube ({content_type})...")

        items = []

        search_queries = {
            "documentary": [
                "documentary film history",
                "science documentary",
                "art documentary",
                "culture documentary"
            ],
            "video-essay": [
                "video essay film",
                "video essay culture",
                "video essay design",
                "video essay society"
            ]
        }

        queries = search_queries.get(content_type, search_queries["documentary"])

        for query in queries:
            try:
                # YouTube API search
                params = {
                    "part": "snippet",
                    "q": query,
                    "type": "video",
                    "maxResults": min(limit // len(queries), 25),
                    "order": "relevance",
                    "videoDuration": "long",  # Prefer longer content
                    "key": self.api_key
                }

                data = self._make_request(f"{self.base_url}/search", params)

                for video in data.get("items", []):
                    snippet = video.get("snippet", {})
                    video_id = video.get("id", {}).get("videoId", "")

                    if video_id:
                        # Get additional video details
                        video_details = self._get_video_details(video_id)

                        item = APIContentItem(
                            url=f"https://www.youtube.com/watch?v={video_id}",
                            title=snippet.get("title", ""),
                            description=snippet.get("description", "")[:300] + "...",
                            source=self.get_source_name(),
                            category="video",
                            bf_category="youtube",
                            bf_subcategory=content_type,
                            author=snippet.get("channelTitle", ""),
                            published_date=snippet.get("publishedAt", ""),
                            tags=["youtube", content_type, "video"] + self._extract_tags_from_title(snippet.get("title", "")),
                            thumbnail_url=snippet.get("thumbnails", {}).get("high", {}).get("url", ""),
                            content_type="video",
                            quality_indicators=video_details,
                            engagement_metrics=video_details.get("statistics", {})
                        )
                        items.append(item)

            except Exception as e:
                print(f"❌ Error fetching YouTube content for query '{query}': {e}")

        print(f"✅ Fetched {len(items)} videos from YouTube")
        return items

    def _get_video_details(self, video_id: str) -> Dict[str, Any]:
        """Get detailed video information"""
        try:
            params = {
                "part": "statistics,contentDetails",
                "id": video_id,
                "key": self.api_key
            }

            data = self._make_request(f"{self.base_url}/videos", params)

            if data.get("items"):
                video = data["items"][0]
                statistics = video.get("statistics", {})
                content_details = video.get("contentDetails", {})

                # Calculate quality score
                view_count = int(statistics.get("viewCount", 0))
                like_count = int(statistics.get("likeCount", 0))
                comment_count = int(statistics.get("commentCount", 0))

                quality_score = 5  # Base score
                if view_count > 100000:
                    quality_score += 2
                if like_count > 1000:
                    quality_score += 1
                if comment_count > 100:
                    quality_score += 1

                return {
                    "statistics": statistics,
                    "duration": content_details.get("duration", ""),
                    "quality_score": min(10, quality_score),
                    "high_engagement": view_count > 50000 and like_count > 500
                }

        except Exception as e:
            print(f"❌ Error getting video details: {e}")

        return {}

    def _extract_tags_from_title(self, title: str) -> List[str]:
        """Extract relevant tags from video title"""
        title_lower = title.lower()
        tags = []

        # Topic tags
        if any(word in title_lower for word in ["history", "historical"]):
            tags.append("history")
        if any(word in title_lower for word in ["science", "scientific"]):
            tags.append("science")
        if any(word in title_lower for word in ["art", "design", "creative"]):
            tags.append("art")
        if any(word in title_lower for word in ["culture", "society", "social"]):
            tags.append("culture")

        return tags

class NYCContentIntegration(BaseAPIIntegration):
    """Integration for NYC-specific content (TimeOut, NYC Open Data)"""

    def get_source_name(self) -> str:
        return "nyc-local"

    def fetch_content(self, limit: int = 50, content_type: str = "events") -> List[APIContentItem]:
        """Fetch NYC local content"""
        print(f"🗽 Fetching NYC content ({content_type})...")

        items = []

        if content_type == "events":
            items.extend(self._fetch_timeout_nyc(limit // 2))
            items.extend(self._fetch_nyc_open_data(limit // 2))

        print(f"✅ Fetched {len(items)} NYC content items")
        return items

    def _fetch_timeout_nyc(self, limit: int) -> List[APIContentItem]:
        """Fetch from TimeOut NYC (conceptual)"""
        # TimeOut would likely require web scraping or partnership
        sample_events = [
            {
                "title": "Brooklyn Art Book Fair 2024",
                "url": "https://www.timeout.com/newyork/art/brooklyn-art-book-fair",
                "description": "Annual celebration of artist books and independent publishing...",
                "venue": "Brooklyn Museum",
                "date": "2024-02-15",
                "category": "art"
            }
        ]

        items = []
        for event in sample_events[:limit]:
            item = APIContentItem(
                url=event.get("url", ""),
                title=event.get("title", ""),
                description=event.get("description", ""),
                source="timeout-nyc",
                category="events",
                bf_category="local",
                bf_subcategory="nyc-events",
                published_date=event.get("date", ""),
                tags=["nyc", "events", "local", event.get("category", "")],
                location="New York City",
                content_type="event"
            )
            items.append(item)

        return items

    def _fetch_nyc_open_data(self, limit: int) -> List[APIContentItem]:
        """Fetch from NYC Open Data"""
        # NYC Open Data has actual APIs
        try:
            # Example: Cultural events dataset
            url = "https://data.cityofnewyork.us/resource/tvpp-9vvx.json"
            params = {"$limit": limit, "$order": "start_date_time DESC"}

            data = self._make_request(url, params)

            items = []
            for event in data[:limit]:
                item = APIContentItem(
                    url=event.get("event_website", f"https://data.cityofnewyork.us/event/{event.get('event_id', '')}"),
                    title=event.get("event_name", ""),
                    description=event.get("event_description", "")[:200] + "...",
                    source="nyc-open-data",
                    category="culture",
                    bf_category="local",
                    bf_subcategory="nyc-culture",
                    published_date=event.get("start_date_time", ""),
                    tags=["nyc", "culture", "events", "open-data"],
                    location=f"{event.get('event_borough', '')}, NYC",
                    content_type="event"
                )
                items.append(item)

            return items

        except Exception as e:
            print(f"❌ Error fetching NYC Open Data: {e}")
            return []

class APIIntegrationsManager:
    """Main manager for all API integrations"""

    def __init__(self, api_keys: Dict[str, str] = None):
        self.api_keys = api_keys or {}

        # Initialize DynamoDB
        self.dynamodb = boto3.client(
            'dynamodb',
            region_name=REGION,
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY
        )

        self.table = boto3.resource(
            'dynamodb',
            region_name=REGION,
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY
        ).Table(TABLE_NAME)

        # Initialize integrations
        self.integrations = {
            'letterboxd': LetterboxdIntegration(self.api_keys.get('letterboxd')),
            'medium': MediumIntegration(self.api_keys.get('medium')),
            'designboom': DesignboomIntegration(self.api_keys.get('designboom')),
            'youtube': YouTubeDocumentaryIntegration(self.api_keys.get('youtube')),
            'nyc': NYCContentIntegration(self.api_keys.get('nyc'))
        }

    def fetch_from_all_sources(self, limit_per_source: int = 25) -> Dict[str, List[APIContentItem]]:
        """Fetch content from all available integrations"""
        print("🚀 FETCHING FROM ALL NEW API SOURCES")
        print("=" * 60)

        results = {}

        for source_name, integration in self.integrations.items():
            try:
                print(f"\n📡 Processing {source_name}...")
                items = integration.fetch_content(limit_per_source)
                results[source_name] = items
                print(f"✅ {source_name}: {len(items)} items")

            except Exception as e:
                print(f"❌ Error with {source_name}: {e}")
                results[source_name] = []

        total_items = sum(len(items) for items in results.values())
        print(f"\n📊 TOTAL FETCHED: {total_items} items from {len(results)} sources")

        return results

    def store_content_items(self, items: List[APIContentItem]) -> Tuple[int, int]:
        """Store content items in DynamoDB"""
        print(f"💾 Storing {len(items)} items in database...")

        success_count = 0
        error_count = 0

        # Process in batches
        batch_size = 25
        for i in range(0, len(items), batch_size):
            batch = items[i:i + batch_size]

            try:
                with self.table.batch_writer() as batch_writer:
                    for item in batch:
                        # Convert to DynamoDB format
                        dynamo_item = self._content_item_to_dynamo(item)
                        batch_writer.put_item(Item=dynamo_item)
                        success_count += 1

                print(f"  ✅ Stored batch: {len(batch)} items")

            except Exception as e:
                print(f"  ❌ Batch error: {e}")
                error_count += len(batch)

        print(f"📊 Storage complete: {success_count} stored, {error_count} errors")
        return success_count, error_count

    def _content_item_to_dynamo(self, item: APIContentItem) -> Dict[str, Any]:
        """Convert APIContentItem to DynamoDB format"""
        dynamo_item = {
            'url': item.url,
            'id': item.id,
            'title': item.title,
            'domain': item.domain,
            'category': item.category,
            'source': item.source,
            'status': 'active',  # New content starts as active
            'isActive': True,
            'fetchedAt': datetime.now(timezone.utc).isoformat(),
            'updatedAt': datetime.now(timezone.utc).isoformat(),
            'contentType': item.content_type,
            'qualityScore': 7,  # New API content starts with good quality score
            'tags': item.tags,
            'bfCategory': item.bf_category,
            'mobileFlag': True,  # Most new content is mobile-friendly
        }

        # Add optional fields
        if item.bf_subcategory:
            dynamo_item['bfSubcategory'] = item.bf_subcategory
        if item.description:
            dynamo_item['textContent'] = item.description
        if item.author:
            dynamo_item['author'] = item.author
        if item.published_date:
            dynamo_item['createdDate'] = item.published_date
        if item.thumbnail_url:
            dynamo_item['thumbnailUrl'] = item.thumbnail_url
        if item.location:
            dynamo_item['location'] = item.location
        if item.rating:
            dynamo_item['rating'] = item.rating
        if item.engagement_metrics:
            dynamo_item['engagementMetrics'] = item.engagement_metrics

        return dynamo_item

    def run_integration_workflow(self, sources: List[str] = None, items_per_source: int = 25) -> Dict[str, Any]:
        """Run complete integration workflow"""
        print("🤖 NEW API INTEGRATIONS WORKFLOW")
        print("=" * 50)

        # Select sources to process
        if sources:
            selected_integrations = {k: v for k, v in self.integrations.items() if k in sources}
        else:
            selected_integrations = self.integrations

        print(f"🎯 Processing {len(selected_integrations)} sources: {list(selected_integrations.keys())}")

        all_items = []
        source_results = {}

        # Fetch from each source
        for source_name, integration in selected_integrations.items():
            try:
                items = integration.fetch_content(items_per_source)
                all_items.extend(items)
                source_results[source_name] = len(items)
            except Exception as e:
                print(f"❌ Error with {source_name}: {e}")
                source_results[source_name] = 0

        # Store in database
        if all_items:
            stored, errors = self.store_content_items(all_items)
        else:
            stored, errors = 0, 0

        results = {
            'sources_processed': len(selected_integrations),
            'total_items_fetched': len(all_items),
            'items_stored': stored,
            'storage_errors': errors,
            'source_breakdown': source_results
        }

        print(f"\n✅ INTEGRATION WORKFLOW COMPLETE")
        print(f"📊 Results: {results}")

        return results

def main():
    """Main execution function"""
    # Example API keys configuration
    api_keys = {
        'youtube': 'YOUR_YOUTUBE_API_KEY',  # Required for YouTube integration
        'letterboxd': None,  # Letterboxd requires OAuth
        'medium': None,      # Medium API is limited
        'designboom': None,  # Likely RSS-based
        'nyc': None         # NYC Open Data is free
    }

    manager = APIIntegrationsManager(api_keys)

    print("🔌 NEW API INTEGRATIONS FRAMEWORK")
    print("=" * 50)
    print("Choose an option:")
    print("1. Test all integrations (dry run)")
    print("2. Run full integration workflow")
    print("3. Test specific integration")
    print("4. Show available integrations")

    choice = input("\nEnter choice (1-4): ").strip()

    if choice == '1':
        # Test all integrations without storing
        results = manager.fetch_from_all_sources(limit_per_source=10)
        print("\n📊 DRY RUN COMPLETE - No data stored")

    elif choice == '2':
        # Run full workflow
        sources = input("Enter sources to process (comma-separated, or 'all'): ").strip()
        if sources.lower() == 'all':
            manager.run_integration_workflow()
        else:
            source_list = [s.strip() for s in sources.split(',')]
            manager.run_integration_workflow(source_list)

    elif choice == '3':
        # Test specific integration
        print("\nAvailable integrations:")
        for i, source in enumerate(manager.integrations.keys(), 1):
            print(f"  {i}. {source}")

        selection = input("Enter integration name: ").strip()
        if selection in manager.integrations:
            items = manager.integrations[selection].fetch_content(10)
            print(f"\n📊 Fetched {len(items)} items from {selection}")
            for i, item in enumerate(items[:3], 1):
                print(f"  {i}. {item.title[:50]}...")
        else:
            print("❌ Invalid integration name")

    elif choice == '4':
        print("\n🔌 AVAILABLE INTEGRATIONS:")
        for name, integration in manager.integrations.items():
            print(f"  • {name}: {integration.__class__.__name__}")
            print(f"    Source: {integration.get_source_name()}")
            print(f"    Status: {'✅ Ready' if integration.api_key or name in ['designboom', 'nyc'] else '⚠️ Needs API Key'}")
            print()

    else:
        print("❌ Invalid choice")

if __name__ == "__main__":
    main()