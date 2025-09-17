#!/usr/bin/env python3
"""
DumFlow Browse-Forward Database Agent
====================================

Specialized agent for managing all AWS DynamoDB operations for DumFlow's BrowseForward feature.
Handles content fetching from web APIs, database population, querying, metadata generation,
and content optimization.

Author: Claude Code
Version: 1.0.0
Target: Creative professionals (20s-30s) seeking quality long-form content
"""

import boto3
import json
import requests
import hashlib
import re
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple, Any, Union
from urllib.parse import urlparse, urlencode
from dataclasses import dataclass, field
import logging
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
import asyncio
from botocore.exceptions import ClientError, BotoCoreError
try:
    import openai
    HAS_OPENAI = True
except ImportError:
    HAS_OPENAI = False

try:
    from bs4 import BeautifulSoup
    HAS_BS4 = True
except ImportError:
    HAS_BS4 = False

try:
    import feedparser
    HAS_FEEDPARSER = True
except ImportError:
    HAS_FEEDPARSER = False

import random

# Configuration
AWS_REGION = "us-east-1"
TABLE_NAME = "webpages"
MAX_RETRIES = 3
BATCH_SIZE = 25  # DynamoDB batch write limit
DEFAULT_LIMIT = 50
QUALITY_THRESHOLD = 5  # Minimum quality score for active content

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ContentItem:
    """Represents a webpage item in the database"""
    url: str
    title: str
    domain: str
    category: str
    source: str
    upvotes: int = 0
    interactions: int = 0
    tags: List[str] = field(default_factory=list)
    thumbnail_url: str = ""
    created_date: Optional[str] = None
    post_date: Optional[str] = None
    fetched_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    # Enhanced metadata fields
    text_content: Optional[str] = None
    ai_summary: Optional[str] = None
    reading_time_minutes: Optional[int] = None
    word_count: Optional[int] = None
    ai_topics: List[str] = field(default_factory=list)
    content_type: str = "article"
    quality_score: int = 5
    ai_keywords: List[str] = field(default_factory=list)
    related_categories: List[str] = field(default_factory=list)
    difficulty: str = "medium"
    thumbnail_description: Optional[str] = None
    alternative_headline: List[str] = field(default_factory=list)
    internal_links: List[str] = field(default_factory=list)
    paragraph_count: int = 0

    # BrowseForward specific fields
    bf_category: Optional[str] = None
    bf_subcategory: Optional[str] = None
    status: str = "active"  # active, inactive, desktopOnly
    is_active: bool = True

    # Social metrics
    comment_count: int = 0
    like_count: int = 0
    save_count: int = 0
    is_reported: int = 0
    report_count: int = 0

    @property
    def id(self) -> str:
        """Generate unique ID from URL"""
        return hashlib.md5(self.url.encode()).hexdigest()

class BrowseForwardDBAgent:
    """Main agent class for database operations"""

    def __init__(self, aws_access_key: str, aws_secret_key: str, region: str = AWS_REGION):
        """Initialize the agent with AWS credentials"""
        self.aws_access_key = aws_access_key
        self.aws_secret_key = aws_secret_key
        self.region = region
        self.table_name = TABLE_NAME

        # Initialize DynamoDB client
        self.dynamodb = boto3.client(
            'dynamodb',
            region_name=self.region,
            aws_access_key_id=self.aws_access_key,
            aws_secret_access_key=self.aws_secret_key
        )

        # Initialize resource for higher-level operations
        self.dynamodb_resource = boto3.resource(
            'dynamodb',
            region_name=self.region,
            aws_access_key_id=self.aws_access_key,
            aws_secret_access_key=self.aws_secret_key
        )

        self.table = self.dynamodb_resource.Table(self.table_name)

        # API configurations (set these before using respective methods)
        self.reddit_api_config = {}
        self.openai_api_key = None
        self.youtube_api_key = None

        logger.info(f"✅ BrowseForwardDBAgent initialized for table: {self.table_name}")

    # ===============================
    # CORE DATABASE OPERATIONS
    # ===============================

    def get_item(self, url: str) -> Optional[Dict[str, Any]]:
        """Get a single item by URL"""
        try:
            response = self.table.get_item(Key={'url': url})
            return response.get('Item')
        except Exception as e:
            logger.error(f"❌ Error getting item {url}: {e}")
            return None

    def put_item(self, item: ContentItem) -> bool:
        """Insert or update a single item"""
        try:
            # Convert to DynamoDB format
            dynamo_item = self._content_item_to_dynamo(item)

            self.table.put_item(Item=dynamo_item)
            logger.info(f"✅ Inserted/Updated item: {item.title[:50]}...")
            return True

        except Exception as e:
            logger.error(f"❌ Error putting item {item.url}: {e}")
            return False

    def batch_write_items(self, items: List[ContentItem]) -> Tuple[int, int]:
        """Batch write multiple items"""
        success_count = 0
        error_count = 0

        # Process in batches of 25 (DynamoDB limit)
        for i in range(0, len(items), BATCH_SIZE):
            batch = items[i:i + BATCH_SIZE]

            try:
                with self.table.batch_writer() as batch_writer:
                    for item in batch:
                        dynamo_item = self._content_item_to_dynamo(item)
                        batch_writer.put_item(Item=dynamo_item)
                        success_count += 1

                logger.info(f"✅ Batch write completed: {len(batch)} items")

            except Exception as e:
                logger.error(f"❌ Batch write error: {e}")
                error_count += len(batch)

        return success_count, error_count

    def delete_item(self, url: str) -> bool:
        """Delete an item by URL"""
        try:
            self.table.delete_item(Key={'url': url})
            logger.info(f"🗑️  Deleted item: {url}")
            return True
        except Exception as e:
            logger.error(f"❌ Error deleting item {url}: {e}")
            return False

    def update_item_status(self, url: str, status: str) -> bool:
        """Update the status of an item (active, inactive, desktopOnly)"""
        try:
            self.table.update_item(
                Key={'url': url},
                UpdateExpression='SET #status = :status, #is_active = :is_active, #updated_at = :updated_at',
                ExpressionAttributeNames={
                    '#status': 'status',
                    '#is_active': 'isActive',
                    '#updated_at': 'updatedAt'
                },
                ExpressionAttributeValues={
                    ':status': status,
                    ':is_active': status == 'active',
                    ':updated_at': datetime.now(timezone.utc).isoformat()
                }
            )
            logger.info(f"✅ Updated status for {url}: {status}")
            return True
        except Exception as e:
            logger.error(f"❌ Error updating status for {url}: {e}")
            return False

    # ===============================
    # QUERYING AND RETRIEVAL
    # ===============================

    def get_items_by_category(self, category: str, limit: int = DEFAULT_LIMIT, status: str = "active") -> List[Dict[str, Any]]:
        """Get items by BrowseForward category"""
        try:
            response = self.table.query(
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': category,
                    ':status': status
                },
                Limit=limit
            )
            return response.get('Items', [])
        except Exception as e:
            logger.error(f"❌ Error querying category {category}: {e}")
            return []

    def get_items_by_source(self, source: str, limit: int = DEFAULT_LIMIT) -> List[Dict[str, Any]]:
        """Get items by source (e.g., reddit-TrueReddit, internet-archive-science)"""
        try:
            response = self.table.query(
                IndexName='source-status-index',
                KeyConditionExpression='source = :source AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':source': source,
                    ':status': 'active'
                },
                Limit=limit
            )
            return response.get('Items', [])
        except Exception as e:
            logger.error(f"❌ Error querying source {source}: {e}")
            return []

    def scan_all_items(self, filters: Optional[Dict[str, str]] = None, limit: int = 1000) -> List[Dict[str, Any]]:
        """Scan table with optional filters"""
        items = []
        scan_kwargs = {'Limit': limit}

        if filters:
            filter_expression = []
            expression_attribute_values = {}

            for key, value in filters.items():
                filter_expression.append(f"{key} = :{key}")
                expression_attribute_values[f":{key}"] = value

            scan_kwargs['FilterExpression'] = ' AND '.join(filter_expression)
            scan_kwargs['ExpressionAttributeValues'] = expression_attribute_values

        try:
            response = self.table.scan(**scan_kwargs)
            items.extend(response.get('Items', []))

            # Handle pagination
            while 'LastEvaluatedKey' in response and len(items) < limit:
                scan_kwargs['ExclusiveStartKey'] = response['LastEvaluatedKey']
                response = self.table.scan(**scan_kwargs)
                items.extend(response.get('Items', []))

            return items[:limit]

        except Exception as e:
            logger.error(f"❌ Error scanning table: {e}")
            return []

    def get_webgames_by_status(self, status: str = "active") -> List[Dict[str, Any]]:
        """Get all webgames by status"""
        return self.get_items_by_category("webgames", limit=500, status=status)

    def get_database_stats(self) -> Dict[str, Any]:
        """Get comprehensive database statistics"""
        logger.info("📊 Gathering database statistics...")

        # Scan for sources and categories
        all_items = self.scan_all_items(limit=10000)

        stats = {
            'total_items': len(all_items),
            'sources': {},
            'categories': {},
            'bf_categories': {},
            'status_breakdown': {},
            'content_types': {},
            'quality_distribution': {}
        }

        for item in all_items:
            # Count sources
            source = item.get('source', 'unknown')
            stats['sources'][source] = stats['sources'].get(source, 0) + 1

            # Count categories
            category = item.get('category', 'unknown')
            stats['categories'][category] = stats['categories'].get(category, 0) + 1

            # Count BF categories
            bf_category = item.get('bfCategory')
            if bf_category:
                stats['bf_categories'][bf_category] = stats['bf_categories'].get(bf_category, 0) + 1

            # Count status
            status = item.get('status', 'unknown')
            stats['status_breakdown'][status] = stats['status_breakdown'].get(status, 0) + 1

            # Count content types
            content_type = item.get('contentType', 'unknown')
            stats['content_types'][content_type] = stats['content_types'].get(content_type, 0) + 1

            # Quality distribution
            quality = item.get('qualityScore', 0)
            quality_range = f"{quality//2*2}-{quality//2*2+1}"
            stats['quality_distribution'][quality_range] = stats['quality_distribution'].get(quality_range, 0) + 1

        return stats

    # ===============================
    # CONTENT FETCHING AND APIS
    # ===============================

    def fetch_reddit_content(self, subreddits: List[str], posts_per_sub: int = 15) -> List[ContentItem]:
        """Fetch content from Reddit subreddits"""
        items = []

        for subreddit in subreddits:
            logger.info(f"🔍 Fetching from r/{subreddit}...")

            try:
                # Fetch from Reddit API or RSS (simplified implementation)
                url = f"https://www.reddit.com/r/{subreddit}/hot.json?limit={posts_per_sub}"
                headers = {'User-Agent': 'DumFlow/1.0 (content aggregator)'}

                response = requests.get(url, headers=headers)
                if response.status_code == 200:
                    data = response.json()
                    posts = data.get('data', {}).get('children', [])

                    for post in posts:
                        post_data = post.get('data', {})

                        # Skip self posts and videos
                        if post_data.get('is_self') or post_data.get('is_video'):
                            continue

                        item = ContentItem(
                            url=post_data.get('url', ''),
                            title=post_data.get('title', ''),
                            domain=post_data.get('domain', ''),
                            category=self._categorize_subreddit(subreddit),
                            source=f"reddit-{subreddit}",
                            upvotes=post_data.get('score', 0),
                            interactions=post_data.get('num_comments', 0),
                            tags=[f"reddit", subreddit, self._categorize_subreddit(subreddit)],
                            thumbnail_url=post_data.get('thumbnail', ''),
                            created_date=datetime.fromtimestamp(post_data.get('created_utc', 0)).isoformat(),
                            bf_category=self._map_to_bf_category(subreddit),
                            quality_score=self._calculate_reddit_quality_score(post_data)
                        )
                        items.append(item)

                logger.info(f"✅ Fetched {len([i for i in items if i.source == f'reddit-{subreddit}'])} posts from r/{subreddit}")

            except Exception as e:
                logger.error(f"❌ Error fetching from r/{subreddit}: {e}")

        return items

    def fetch_hackernews_content(self, limit: int = 50) -> List[ContentItem]:
        """Fetch content from Hacker News"""
        items = []
        logger.info("🔍 Fetching from Hacker News...")

        try:
            # Get top story IDs
            top_stories_url = "https://hacker-news.firebaseio.com/v0/topstories.json"
            response = requests.get(top_stories_url)
            story_ids = response.json()[:limit]

            for story_id in story_ids:
                story_url = f"https://hacker-news.firebaseio.com/v0/item/{story_id}.json"
                story_response = requests.get(story_url)
                story_data = story_response.json()

                if story_data.get('type') == 'story' and story_data.get('url'):
                    item = ContentItem(
                        url=story_data.get('url', ''),
                        title=story_data.get('title', ''),
                        domain=urlparse(story_data.get('url', '')).netloc,
                        category="technology",
                        source="hackernews",
                        upvotes=story_data.get('score', 0),
                        interactions=story_data.get('descendants', 0),
                        tags=["hackernews", "technology", "startup"],
                        created_date=datetime.fromtimestamp(story_data.get('time', 0)).isoformat(),
                        bf_category="technology",
                        quality_score=min(10, max(1, story_data.get('score', 0) // 10))
                    )
                    items.append(item)

            logger.info(f"✅ Fetched {len(items)} stories from Hacker News")

        except Exception as e:
            logger.error(f"❌ Error fetching from Hacker News: {e}")

        return items

    def fetch_internet_archive_content(self, collections: List[str], items_per_collection: int = 20) -> List[ContentItem]:
        """Fetch content from Internet Archive collections"""
        items = []

        for collection in collections:
            logger.info(f"🔍 Fetching from Internet Archive collection: {collection}")

            try:
                # Internet Archive search API
                search_url = "https://archive.org/advancedsearch.php"
                params = {
                    'q': f'collection:{collection}',
                    'fl': 'identifier,title,description,date,downloads,mediatype',
                    'rows': items_per_collection,
                    'output': 'json'
                }

                response = requests.get(search_url, params=params)
                data = response.json()
                docs = data.get('response', {}).get('docs', [])

                for doc in docs:
                    item_url = f"https://archive.org/details/{doc.get('identifier', '')}"

                    item = ContentItem(
                        url=item_url,
                        title=doc.get('title', ''),
                        domain="archive.org",
                        category="internetarchive",
                        source=f"internet-archive-{collection}",
                        upvotes=int(doc.get('downloads', 0)) // 100,  # Scale downloads to upvote-like metric
                        interactions=0,
                        tags=["internetarchive", collection, doc.get('mediatype', '')],
                        created_date=doc.get('date'),
                        bf_category=self._map_archive_to_bf_category(collection),
                        content_type=doc.get('mediatype', 'unknown'),
                        text_content=doc.get('description', ''),
                        quality_score=self._calculate_archive_quality_score(doc)
                    )
                    items.append(item)

                logger.info(f"✅ Fetched {len([i for i in items if collection in i.source])} items from {collection}")

            except Exception as e:
                logger.error(f"❌ Error fetching from Internet Archive {collection}: {e}")

        return items

    # ===============================
    # CONTENT CLEANUP OPERATIONS
    # ===============================

    def cleanup_reddit_sources(self, sources_to_remove: List[str]) -> Tuple[int, int]:
        """Clean up specified Reddit sources"""
        removed_count = 0
        error_count = 0

        for source in sources_to_remove:
            logger.info(f"🧹 Cleaning up source: {source}")

            items = self.get_items_by_source(source, limit=1000)

            for item in items:
                if self.delete_item(item['url']):
                    removed_count += 1
                else:
                    error_count += 1

        logger.info(f"✅ Cleanup completed: {removed_count} removed, {error_count} errors")
        return removed_count, error_count

    def optimize_webgames_for_mobile(self) -> Dict[str, int]:
        """Optimize webgames by identifying mobile-friendly candidates"""
        logger.info("📱 Starting webgames mobile optimization...")

        # Get all desktopOnly webgames
        desktop_games = self.get_webgames_by_status("desktopOnly")

        mobile_friendly_domains = [
            'lichess.org', 'chess.com', 'eyezmaze.com', 'jayisgames.com',
            'gamejolt.com', 'koalabeast.com', 'foddy.net', 'superhotgame.com',
            'choiceofgames.com', 'ferryhalim.com', 'onemorelevel.com',
            'newcave.com', 'lukethompsondesign.com'
        ]

        mobile_keywords = [
            'puzzle', 'chess', 'card', 'word', 'trivia', 'quiz', 'simple',
            'tap', 'click', 'sudoku', 'solitaire', 'match', 'tetris',
            'tower defense', 'incremental', 'clicker', 'idle', 'text',
            'story', 'choose', 'decision', 'platformer', 'minimalist'
        ]

        candidates = []
        for game in desktop_games:
            score = self._score_mobile_compatibility(
                game.get('url', ''),
                game.get('title', ''),
                game.get('domain', ''),
                mobile_friendly_domains,
                mobile_keywords
            )

            if score >= 5:  # Good mobile candidate
                candidates.append((game, score))

        # Sort by score
        candidates.sort(key=lambda x: x[1], reverse=True)

        logger.info(f"📱 Found {len(candidates)} mobile-friendly candidates")

        stats = {
            'total_desktop_games': len(desktop_games),
            'mobile_candidates': len(candidates),
            'high_score_candidates': len([c for c in candidates if c[1] >= 8])
        }

        # Log top 10 candidates
        for i, (game, score) in enumerate(candidates[:10]):
            logger.info(f"{i+1:2d}. Score: {score:2d} | {game.get('title', '')[:50]}")

        return stats

    def mark_webgames_active(self, urls: List[str]) -> Tuple[int, int]:
        """Mark specific webgames as active"""
        success_count = 0
        error_count = 0

        for url in urls:
            if self.update_item_status(url, "active"):
                success_count += 1
            else:
                error_count += 1

        return success_count, error_count

    # ===============================
    # METADATA GENERATION
    # ===============================

    def generate_enhanced_metadata(self, items: List[ContentItem], use_ai: bool = False) -> List[ContentItem]:
        """Generate enhanced metadata for content items"""
        logger.info(f"🤖 Generating enhanced metadata for {len(items)} items...")

        enhanced_items = []

        for item in items:
            # Basic text analysis
            if item.text_content:
                item.word_count = len(item.text_content.split())
                item.reading_time_minutes = max(1, item.word_count // 200)  # Average reading speed
                item.paragraph_count = len([p for p in item.text_content.split('\n\n') if p.strip()])

            # Extract keywords from title and content
            if item.title:
                item.ai_keywords = self._extract_keywords(item.title)

            # Quality scoring
            item.quality_score = self._calculate_quality_score(item)

            # Content type inference
            item.content_type = self._infer_content_type(item)

            # Difficulty assessment
            item.difficulty = self._assess_difficulty(item)

            if use_ai and self.openai_api_key:
                # AI-powered enhancements (implement if OpenAI key is available)
                item = self._enhance_with_ai(item)

            enhanced_items.append(item)

        logger.info(f"✅ Enhanced metadata for {len(enhanced_items)} items")
        return enhanced_items

    # ===============================
    # UTILITY METHODS
    # ===============================

    def _content_item_to_dynamo(self, item: ContentItem) -> Dict[str, Any]:
        """Convert ContentItem to DynamoDB format"""
        dynamo_item = {
            'url': item.url,
            'id': item.id,
            'title': item.title,
            'domain': item.domain,
            'category': item.category,
            'source': item.source,
            'upvotes': item.upvotes,
            'interactions': item.interactions,
            'tags': item.tags,
            'thumbnailUrl': item.thumbnail_url,
            'fetchedAt': item.fetched_at,
            'updatedAt': item.updated_at,
            'status': item.status,
            'isActive': item.is_active,
            'qualityScore': item.quality_score,
            'contentType': item.content_type,
            'difficulty': item.difficulty,
            'wordCount': item.word_count or 0,
            'paragraphCount': item.paragraph_count,
            'commentCount': item.comment_count,
            'likeCount': item.like_count,
            'saveCount': item.save_count,
            'isReported': item.is_reported,
            'reportCount': item.report_count
        }

        # Add optional fields
        if item.bf_category:
            dynamo_item['bfCategory'] = item.bf_category
        if item.bf_subcategory:
            dynamo_item['bfSubcategory'] = item.bf_subcategory
        if item.created_date:
            dynamo_item['createdDate'] = item.created_date
        if item.post_date:
            dynamo_item['postDate'] = item.post_date
        if item.text_content:
            dynamo_item['textContent'] = item.text_content
        if item.ai_summary:
            dynamo_item['aiSummary'] = item.ai_summary
        if item.reading_time_minutes:
            dynamo_item['readingTimeMinutes'] = item.reading_time_minutes
        if item.ai_topics:
            dynamo_item['aiTopics'] = item.ai_topics
        if item.ai_keywords:
            dynamo_item['aiKeywords'] = item.ai_keywords
        if item.related_categories:
            dynamo_item['relatedCategories'] = item.related_categories
        if item.thumbnail_description:
            dynamo_item['thumbnailDescription'] = item.thumbnail_description
        if item.alternative_headline:
            dynamo_item['alternativeHeadline'] = item.alternative_headline
        if item.internal_links:
            dynamo_item['internalLinks'] = item.internal_links

        return dynamo_item

    def _categorize_subreddit(self, subreddit: str) -> str:
        """Map subreddit to content category"""
        category_map = {
            'TrueReddit': 'general',
            'Foodforthought': 'general',
            'longreads': 'culture',
            'webgames': 'games',
            'physics': 'science',
            'mealtimevideos': 'culture',
            'books': 'culture',
            'food': 'culture',
            'indepthstories': 'general',
            'nyc': 'local'
        }
        return category_map.get(subreddit, 'general')

    def _map_to_bf_category(self, source: str) -> str:
        """Map source to BrowseForward category"""
        if 'games' in source.lower():
            return 'webgames'
        elif any(sci in source.lower() for sci in ['physics', 'science']):
            return 'science'
        elif any(cult in source.lower() for cult in ['culture', 'books', 'art']):
            return 'culture'
        elif any(tech in source.lower() for tech in ['technology', 'hackernews']):
            return 'technology'
        else:
            return 'general'

    def _map_archive_to_bf_category(self, collection: str) -> str:
        """Map Internet Archive collection to BF category"""
        archive_map = {
            'texts': 'culture',
            'movies': 'culture',
            'audio': 'culture',
            'software': 'technology',
            'image': 'culture',
            'data': 'science'
        }
        return archive_map.get(collection, 'culture')

    def _calculate_reddit_quality_score(self, post_data: Dict[str, Any]) -> int:
        """Calculate quality score for Reddit post"""
        score = post_data.get('score', 0)
        comments = post_data.get('num_comments', 0)
        upvote_ratio = post_data.get('upvote_ratio', 0.5)

        quality = 5  # Base score

        if score > 100:
            quality += 2
        if score > 500:
            quality += 2
        if comments > 50:
            quality += 1
        if upvote_ratio > 0.8:
            quality += 1

        return min(10, max(1, quality))

    def _calculate_archive_quality_score(self, doc: Dict[str, Any]) -> int:
        """Calculate quality score for Internet Archive item"""
        downloads = int(doc.get('downloads', 0))

        if downloads > 10000:
            return 9
        elif downloads > 5000:
            return 8
        elif downloads > 1000:
            return 7
        elif downloads > 500:
            return 6
        else:
            return 5

    def _score_mobile_compatibility(self, url: str, title: str, domain: str,
                                  friendly_domains: List[str], mobile_keywords: List[str]) -> int:
        """Score mobile compatibility for webgames"""
        score = 0
        url_lower = url.lower()
        title_lower = title.lower()
        domain_lower = domain.lower()

        # Domain scoring
        if any(friendly_domain in domain_lower for friendly_domain in friendly_domains):
            score += 10

        # Keyword scoring
        keyword_matches = sum(1 for kw in mobile_keywords if kw in title_lower or kw in url_lower)
        score += keyword_matches * 2

        # Penalties for desktop indicators
        desktop_flags = ['multiplayer', 'mmo', 'fps', 'rts', 'keyboard', 'mouse', 'download', 'install']
        desktop_penalties = sum(1 for flag in desktop_flags if flag in title_lower or flag in url_lower)
        score -= desktop_penalties * 3

        # Simple domain bonus
        if '.' in domain and len(domain.split('.')[0]) <= 8:
            score += 2

        return max(0, score)

    def _calculate_quality_score(self, item: ContentItem) -> int:
        """Calculate comprehensive quality score"""
        score = 5  # Base score

        # Engagement metrics
        if item.upvotes > 100:
            score += 2
        if item.upvotes > 500:
            score += 2
        if item.interactions > 50:
            score += 1

        # Content quality indicators
        if item.word_count and item.word_count > 500:
            score += 1
        if item.word_count and item.word_count > 2000:
            score += 1

        # Source credibility
        trusted_sources = ['hackernews', 'wikipedia', 'internet-archive']
        if any(source in item.source for source in trusted_sources):
            score += 1

        return min(10, max(1, score))

    def _infer_content_type(self, item: ContentItem) -> str:
        """Infer content type from item properties"""
        if 'game' in item.category.lower() or 'webgames' in item.bf_category:
            return 'game'
        elif 'video' in item.tags:
            return 'video'
        elif item.word_count and item.word_count > 2000:
            return 'long-read'
        elif 'news' in item.category.lower():
            return 'news'
        else:
            return 'article'

    def _assess_difficulty(self, item: ContentItem) -> str:
        """Assess content difficulty level"""
        if item.word_count:
            if item.word_count < 300:
                return 'easy'
            elif item.word_count > 2000:
                return 'hard'

        # Science and technology tend to be harder
        if item.category in ['science', 'technology']:
            return 'medium-hard'

        return 'medium'

    def _extract_keywords(self, text: str) -> List[str]:
        """Extract keywords from text (simple implementation)"""
        # Remove common words and extract meaningful terms
        common_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were'}
        words = re.findall(r'\b[a-zA-Z]{3,}\b', text.lower())
        keywords = [word for word in words if word not in common_words]
        return list(set(keywords))[:10]  # Return unique keywords, max 10

    def _enhance_with_ai(self, item: ContentItem) -> ContentItem:
        """Enhance item with AI-generated content (placeholder)"""
        # This would integrate with OpenAI API for summaries, topics, etc.
        # Implementation depends on OpenAI API key availability
        logger.debug(f"AI enhancement for {item.title} (placeholder)")
        return item

    # ===============================
    # COMMAND LINE INTERFACE
    # ===============================

    def run_interactive_mode(self):
        """Run interactive command mode"""
        print("🤖 DumFlow Browse-Forward Database Agent")
        print("=" * 50)

        while True:
            print("\nAvailable commands:")
            print("1. stats - Show database statistics")
            print("2. cleanup - Clean up Reddit sources")
            print("3. webgames - Optimize webgames for mobile")
            print("4. fetch - Fetch new content")
            print("5. query - Query database")
            print("6. exit - Exit agent")

            choice = input("\nEnter command: ").strip().lower()

            if choice == '1' or choice == 'stats':
                self._show_stats()
            elif choice == '2' or choice == 'cleanup':
                self._interactive_cleanup()
            elif choice == '3' or choice == 'webgames':
                self._interactive_webgames()
            elif choice == '4' or choice == 'fetch':
                self._interactive_fetch()
            elif choice == '5' or choice == 'query':
                self._interactive_query()
            elif choice == '6' or choice == 'exit':
                print("👋 Goodbye!")
                break
            else:
                print("❌ Unknown command. Please try again.")

    def _show_stats(self):
        """Show database statistics"""
        stats = self.get_database_stats()

        print(f"\n📊 DATABASE STATISTICS")
        print("=" * 40)
        print(f"Total items: {stats['total_items']}")

        print(f"\n📂 SOURCES:")
        for source, count in sorted(stats['sources'].items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"  {source}: {count}")

        print(f"\n🏷️  BF CATEGORIES:")
        for category, count in sorted(stats['bf_categories'].items(), key=lambda x: x[1], reverse=True):
            print(f"  {category}: {count}")

        print(f"\n📊 STATUS BREAKDOWN:")
        for status, count in stats['status_breakdown'].items():
            print(f"  {status}: {count}")

    def _interactive_cleanup(self):
        """Interactive cleanup interface"""
        sources_to_remove = [
            'reddit-movies', 'reddit-gadgets', 'reddit-space',
            'reddit-psychology', 'reddit-TrueReddit', 'reddit-longreads'
        ]

        print(f"\nSources marked for cleanup:")
        for source in sources_to_remove:
            print(f"  - {source}")

        if input("Proceed with cleanup? (y/N): ").lower() == 'y':
            removed, errors = self.cleanup_reddit_sources(sources_to_remove)
            print(f"✅ Cleanup completed: {removed} removed, {errors} errors")
        else:
            print("❌ Cleanup cancelled")

    def _interactive_webgames(self):
        """Interactive webgames optimization"""
        stats = self.optimize_webgames_for_mobile()

        print(f"\n📱 WEBGAMES OPTIMIZATION RESULTS:")
        print(f"  Total desktop games: {stats['total_desktop_games']}")
        print(f"  Mobile candidates found: {stats['mobile_candidates']}")
        print(f"  High-score candidates: {stats['high_score_candidates']}")

    def _interactive_fetch(self):
        """Interactive content fetching"""
        print("\nContent sources:")
        print("1. Reddit")
        print("2. Hacker News")
        print("3. Internet Archive")

        choice = input("Select source (1-3): ").strip()

        if choice == '1':
            subreddits = ['TrueReddit', 'longreads', 'science']
            items = self.fetch_reddit_content(subreddits, 10)
            success, errors = self.batch_write_items(items)
            print(f"✅ Reddit fetch completed: {success} items added, {errors} errors")

        elif choice == '2':
            items = self.fetch_hackernews_content(25)
            success, errors = self.batch_write_items(items)
            print(f"✅ Hacker News fetch completed: {success} items added, {errors} errors")

        elif choice == '3':
            collections = ['texts', 'software']
            items = self.fetch_internet_archive_content(collections, 15)
            success, errors = self.batch_write_items(items)
            print(f"✅ Internet Archive fetch completed: {success} items added, {errors} errors")

    def _interactive_query(self):
        """Interactive database querying"""
        print("\nQuery options:")
        print("1. By category")
        print("2. By source")
        print("3. All webgames")

        choice = input("Select query type (1-3): ").strip()

        if choice == '1':
            category = input("Enter category: ").strip()
            items = self.get_items_by_category(category, limit=10)
            print(f"\nFound {len(items)} items in category '{category}':")
            for item in items[:5]:
                print(f"  - {item.get('title', '')[:60]}")

        elif choice == '2':
            source = input("Enter source: ").strip()
            items = self.get_items_by_source(source, limit=10)
            print(f"\nFound {len(items)} items from source '{source}':")
            for item in items[:5]:
                print(f"  - {item.get('title', '')[:60]}")

        elif choice == '3':
            active_games = self.get_webgames_by_status("active")
            inactive_games = self.get_webgames_by_status("desktopOnly")
            print(f"\nWebgames status:")
            print(f"  Active: {len(active_games)}")
            print(f"  Desktop-only: {len(inactive_games)}")


def main():
    """Main entry point"""
    # AWS credentials - replace with your credentials
    AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
    AWS_SECRET_KEY = "SVMqfKzPRgtLbL9JijZqQegrpWRkvLsR2caXYcy9"

    # Initialize agent
    agent = BrowseForwardDBAgent(AWS_ACCESS_KEY, AWS_SECRET_KEY)

    # Check command line arguments
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()

        if command == 'stats':
            agent._show_stats()
        elif command == 'cleanup':
            sources_to_remove = ['reddit-movies', 'reddit-gadgets', 'reddit-space', 'reddit-psychology']
            removed, errors = agent.cleanup_reddit_sources(sources_to_remove)
            print(f"✅ Cleanup completed: {removed} removed, {errors} errors")
        elif command == 'webgames':
            stats = agent.optimize_webgames_for_mobile()
            print(f"📱 Webgames optimization: {stats}")
        elif command == 'interactive':
            agent.run_interactive_mode()
        else:
            print(f"Unknown command: {command}")
            print("Available commands: stats, cleanup, webgames, interactive")
    else:
        # Default to interactive mode
        agent.run_interactive_mode()


if __name__ == "__main__":
    main()