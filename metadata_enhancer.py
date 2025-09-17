#!/usr/bin/env python3
"""
Enhanced Metadata Generation System
===================================

Advanced system for generating rich metadata for DumFlow content.
Analyzes content and generates tags, reading time, quality scores, and AI summaries.

Features:
- Content analysis and classification
- Reading time estimation
- Quality scoring algorithms
- Tag generation and categorization
- Mobile-friendly flag detection
- AI summary generation (when API available)
- Batch processing for large datasets

Author: Claude Code
Version: 1.0.0
Target: Creative professionals (20s-30s) seeking quality long-form content
"""

import boto3
import requests
import re
import json
from datetime import datetime, timezone
from typing import Dict, List, Tuple, Any, Optional
from urllib.parse import urlparse
from dataclasses import dataclass, field
import statistics
import hashlib
from bs4 import BeautifulSoup
import time

# Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

@dataclass
class ContentMetadata:
    """Enhanced metadata for content items"""
    url: str
    title: str
    tags: List[str] = field(default_factory=list)
    reading_time_minutes: int = 0
    word_count: int = 0
    quality_score: int = 5
    content_type: str = "article"
    difficulty: str = "medium"
    mobile_friendly: bool = False
    ai_summary: str = ""
    ai_topics: List[str] = field(default_factory=list)
    ai_keywords: List[str] = field(default_factory=list)
    paragraph_count: int = 0
    has_images: bool = False
    has_videos: bool = False
    domain_authority: str = "medium"
    engagement_potential: str = "medium"
    target_audience: List[str] = field(default_factory=list)
    related_categories: List[str] = field(default_factory=list)

# Content type patterns
CONTENT_TYPE_PATTERNS = {
    'long-read': {
        'min_words': 2000,
        'keywords': ['investigation', 'deep dive', 'analysis', 'essay', 'feature', 'profile', 'story'],
        'domains': ['newyorker.com', 'theatlantic.com', 'medium.com', 'substack.com']
    },
    'news': {
        'keywords': ['breaking', 'news', 'report', 'update', 'announcement', 'today', 'latest'],
        'domains': ['nytimes.com', 'washingtonpost.com', 'bbc.com', 'reuters.com', 'cnn.com']
    },
    'tutorial': {
        'keywords': ['how to', 'tutorial', 'guide', 'step by step', 'walkthrough', 'learn', 'beginner'],
        'domains': ['stackoverflow.com', 'github.com', 'dev.to', 'freecodecamp.org']
    },
    'review': {
        'keywords': ['review', 'rating', 'stars', 'pros and cons', 'verdict', 'opinion', 'critique'],
        'domains': ['rottentomatoes.com', 'imdb.com', 'metacritic.com', 'goodreads.com']
    },
    'game': {
        'keywords': ['play', 'game', 'puzzle', 'interactive', 'click', 'tap', 'levels'],
        'domains': ['itch.io', 'newgrounds.com', 'gamejolt.com', 'kongregate.com']
    },
    'video': {
        'keywords': ['watch', 'video', 'documentary', 'film', 'movie', 'episode'],
        'domains': ['youtube.com', 'vimeo.com', 'twitch.tv', 'archive.org']
    },
    'academic': {
        'keywords': ['research', 'study', 'paper', 'journal', 'academic', 'university', 'scholar'],
        'domains': ['arxiv.org', 'pubmed.gov', 'jstor.org', 'scholar.google.com']
    }
}

# Quality indicators by domain
DOMAIN_QUALITY_SCORES = {
    # High quality domains (8-10)
    'newyorker.com': 9, 'theatlantic.com': 9, 'harpers.org': 9,
    'nytimes.com': 8, 'washingtonpost.com': 8, 'theguardian.com': 8,
    'wikipedia.org': 8, 'archive.org': 8, 'jstor.org': 9,
    'nature.com': 9, 'science.org': 9, 'cell.com': 9,

    # Good quality domains (6-7)
    'medium.com': 6, 'substack.com': 6, 'aeon.co': 7,
    'vox.com': 6, 'wired.com': 7, 'ars-technica.com': 7,
    'hackernews.com': 6, 'reddit.com': 5, 'bbc.com': 7,

    # Average quality domains (4-5)
    'youtube.com': 4, 'buzzfeed.com': 3, 'huffpost.com': 4,
    'forbes.com': 5, 'techcrunch.com': 5, 'engadget.com': 5,

    # Variable quality domains (5)
    'github.com': 5, 'stackoverflow.com': 6, 'dev.to': 5,
}

# Target audience mapping
AUDIENCE_KEYWORDS = {
    'creative-professionals': [
        'design', 'creative', 'art', 'photography', 'graphic', 'visual',
        'branding', 'typography', 'aesthetic', 'portfolio', 'inspiration'
    ],
    'tech-professionals': [
        'programming', 'software', 'development', 'coding', 'engineering',
        'startup', 'technology', 'AI', 'machine learning', 'data science'
    ],
    'entrepreneurs': [
        'business', 'startup', 'entrepreneurship', 'marketing', 'growth',
        'strategy', 'leadership', 'innovation', 'venture capital', 'funding'
    ],
    'academics': [
        'research', 'study', 'academic', 'science', 'theory', 'analysis',
        'university', 'journal', 'peer-reviewed', 'methodology'
    ],
    'culture-enthusiasts': [
        'culture', 'arts', 'literature', 'film', 'music', 'history',
        'philosophy', 'society', 'anthropology', 'sociology'
    ]
}

class MetadataEnhancer:
    """Advanced metadata generation system"""

    def __init__(self):
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

        # Content analysis caches
        self.domain_analysis_cache = {}
        self.processed_count = 0

    def get_content_sample(self, source_filter: str = None, limit: int = 100) -> List[Dict[str, Any]]:
        """Get content items for metadata enhancement"""
        try:
            if source_filter:
                # Query specific source
                response = self.dynamodb.query(
                    TableName=TABLE_NAME,
                    IndexName='source-status-index',
                    KeyConditionExpression='source = :source',
                    ExpressionAttributeValues={':source': {'S': source_filter}},
                    Limit=limit
                )
            else:
                # Scan for items missing enhanced metadata
                response = self.dynamodb.scan(
                    TableName=TABLE_NAME,
                    FilterExpression='attribute_not_exists(aiKeywords) OR attribute_not_exists(readingTimeMinutes)',
                    Limit=limit
                )

            return response.get('Items', [])

        except Exception as e:
            print(f"❌ Error fetching content: {e}")
            return []

    def extract_text_content(self, url: str, title: str) -> Tuple[str, Dict[str, Any]]:
        """Extract and analyze text content from URL (simplified)"""
        # For now, use title and URL for analysis
        # In production, this would fetch and parse the actual webpage
        text_content = f"{title}"

        analysis = {
            'word_count': len(text_content.split()),
            'paragraph_count': len([p for p in text_content.split('\n') if p.strip()]),
            'has_images': False,  # Would detect from actual content
            'has_videos': False,  # Would detect from actual content
            'sentences': len([s for s in text_content.split('.') if s.strip()])
        }

        return text_content, analysis

    def generate_enhanced_metadata(self, item: Dict[str, Any]) -> ContentMetadata:
        """Generate comprehensive metadata for a content item"""
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', '')
        domain = item.get('domain', {}).get('S', '')
        source = item.get('source', {}).get('S', '')

        # Extract domain if not provided
        if not domain:
            try:
                domain = urlparse(url).netloc.lower()
                if domain.startswith('www.'):
                    domain = domain[4:]
            except:
                domain = 'unknown'

        # Get existing quality score or calculate
        existing_quality = item.get('qualityScore', {}).get('N')
        base_quality = int(existing_quality) if existing_quality else 5

        # Extract text content
        text_content, text_analysis = self.extract_text_content(url, title)

        # Generate metadata
        metadata = ContentMetadata(url=url, title=title)

        # Calculate reading time (average 200 words per minute)
        metadata.word_count = text_analysis['word_count']
        metadata.reading_time_minutes = max(1, metadata.word_count // 200)
        metadata.paragraph_count = text_analysis['paragraph_count']
        metadata.has_images = text_analysis['has_images']
        metadata.has_videos = text_analysis['has_videos']

        # Determine content type
        metadata.content_type = self._classify_content_type(title, url, domain, text_content)

        # Generate tags
        metadata.tags = self._generate_tags(title, url, domain, source, metadata.content_type)

        # Calculate enhanced quality score
        metadata.quality_score = self._calculate_enhanced_quality_score(
            base_quality, domain, metadata.word_count, source, title
        )

        # Determine difficulty
        metadata.difficulty = self._assess_difficulty(text_content, metadata.content_type, domain)

        # Mobile friendliness
        metadata.mobile_friendly = self._assess_mobile_friendliness(
            url, title, domain, metadata.content_type
        )

        # Domain authority
        metadata.domain_authority = self._assess_domain_authority(domain)

        # Target audience
        metadata.target_audience = self._identify_target_audience(title, text_content, domain, source)

        # Engagement potential
        metadata.engagement_potential = self._assess_engagement_potential(
            metadata.quality_score, metadata.content_type, metadata.word_count
        )

        # Generate AI keywords and topics
        metadata.ai_keywords = self._extract_keywords(title, text_content)
        metadata.ai_topics = self._extract_topics(title, text_content, domain, source)

        # Related categories
        metadata.related_categories = self._suggest_related_categories(
            metadata.ai_topics, metadata.content_type, source
        )

        return metadata

    def _classify_content_type(self, title: str, url: str, domain: str, content: str) -> str:
        """Classify content type based on multiple signals"""
        title_lower = title.lower()
        url_lower = url.lower()
        content_lower = content.lower()

        # Check each content type
        for content_type, patterns in CONTENT_TYPE_PATTERNS.items():
            score = 0

            # Keyword matching
            if 'keywords' in patterns:
                for keyword in patterns['keywords']:
                    if keyword in title_lower or keyword in content_lower:
                        score += 2
                    if keyword in url_lower:
                        score += 1

            # Domain matching
            if 'domains' in patterns:
                if any(d in domain for d in patterns['domains']):
                    score += 3

            # Word count threshold
            if 'min_words' in patterns:
                word_count = len(content.split())
                if word_count >= patterns['min_words']:
                    score += 2

            # Return first type that exceeds threshold
            if score >= 3:
                return content_type

        # Default classification
        word_count = len(content.split())
        if word_count > 2000:
            return 'long-read'
        elif word_count > 500:
            return 'article'
        else:
            return 'short-form'

    def _generate_tags(self, title: str, url: str, domain: str, source: str, content_type: str) -> List[str]:
        """Generate comprehensive tags for content"""
        tags = set()

        # Content type tag
        tags.add(content_type)

        # Source-based tags
        if source.startswith('reddit-'):
            tags.add('reddit')
            subreddit = source.replace('reddit-', '')
            tags.add(subreddit)
        elif 'hackernews' in source:
            tags.add('hackernews')
            tags.add('technology')
        elif 'internet-archive' in source:
            tags.add('archive')
            category = source.replace('internet-archive-', '')
            tags.add(category)

        # Domain-based tags
        if 'wikipedia' in domain:
            tags.add('reference')
            tags.add('encyclopedia')
        elif 'youtube' in domain:
            tags.add('video')
            tags.add('multimedia')
        elif any(edu in domain for edu in ['.edu', '.ac.']):
            tags.add('academic')
            tags.add('educational')

        # Content analysis tags
        title_lower = title.lower()

        # Topic tags
        topic_keywords = {
            'technology': ['tech', 'software', 'programming', 'AI', 'computer', 'digital'],
            'science': ['research', 'study', 'discovery', 'experiment', 'scientific'],
            'culture': ['art', 'music', 'film', 'book', 'culture', 'creative'],
            'history': ['historical', 'history', 'ancient', 'past', 'era'],
            'politics': ['political', 'government', 'policy', 'election', 'democracy'],
            'business': ['business', 'company', 'market', 'economy', 'finance'],
            'health': ['health', 'medical', 'wellness', 'fitness', 'nutrition'],
            'education': ['education', 'learning', 'school', 'university', 'course']
        }

        for topic, keywords in topic_keywords.items():
            if any(keyword in title_lower for keyword in keywords):
                tags.add(topic)

        # Quality indicators
        quality_indicators = ['analysis', 'in-depth', 'comprehensive', 'detailed', 'thorough']
        if any(indicator in title_lower for indicator in quality_indicators):
            tags.add('quality')

        return list(tags)[:10]  # Limit to 10 tags

    def _calculate_enhanced_quality_score(self, base_score: int, domain: str, word_count: int, source: str, title: str) -> int:
        """Calculate enhanced quality score using multiple factors"""
        score = base_score

        # Domain authority bonus/penalty
        if domain in DOMAIN_QUALITY_SCORES:
            domain_score = DOMAIN_QUALITY_SCORES[domain]
            score = (score + domain_score) // 2  # Average with domain score

        # Word count bonus
        if word_count > 2000:
            score += 2
        elif word_count > 1000:
            score += 1
        elif word_count < 100:
            score -= 1

        # Source quality
        if 'hackernews' in source or 'wikipedia' in source:
            score += 1
        elif 'internet-archive' in source:
            score += 1
        elif source.startswith('reddit-'):
            # Quality varies by subreddit
            quality_subreddits = ['TrueReddit', 'longreads', 'indepthstories']
            if any(sub in source for sub in quality_subreddits):
                score += 1

        # Title quality indicators
        title_lower = title.lower()
        quality_words = ['analysis', 'investigation', 'comprehensive', 'in-depth', 'study']
        clickbait_words = ['shocking', 'amazing', 'unbelievable', 'you won\'t believe']

        if any(word in title_lower for word in quality_words):
            score += 1
        if any(word in title_lower for word in clickbait_words):
            score -= 1

        return max(1, min(10, score))

    def _assess_difficulty(self, content: str, content_type: str, domain: str) -> str:
        """Assess content difficulty level"""
        # Base difficulty by content type
        type_difficulty = {
            'academic': 'hard',
            'tutorial': 'medium',
            'news': 'easy',
            'long-read': 'medium-hard',
            'game': 'easy'
        }

        base_difficulty = type_difficulty.get(content_type, 'medium')

        # Adjust based on domain
        if any(academic in domain for academic in ['.edu', 'arxiv', 'jstor', 'nature.com']):
            return 'hard'
        elif any(simple in domain for simple in ['wikipedia', 'bbc', 'vox']):
            return 'easy' if base_difficulty == 'easy' else 'medium'

        return base_difficulty

    def _assess_mobile_friendliness(self, url: str, title: str, domain: str, content_type: str) -> bool:
        """Assess if content is mobile-friendly"""
        # Games need special consideration
        if content_type == 'game':
            mobile_game_domains = ['lichess.org', 'chess.com', 'eyezmaze.com']
            return any(d in domain for d in mobile_game_domains)

        # Video content
        if content_type == 'video':
            return domain in ['youtube.com', 'vimeo.com']

        # Text content is generally mobile-friendly
        if content_type in ['article', 'long-read', 'news', 'tutorial']:
            return True

        # Academic content may be less mobile-friendly
        if content_type == 'academic':
            return False

        return True  # Default to mobile-friendly

    def _assess_domain_authority(self, domain: str) -> str:
        """Assess domain authority level"""
        if domain in DOMAIN_QUALITY_SCORES:
            score = DOMAIN_QUALITY_SCORES[domain]
            if score >= 8:
                return 'high'
            elif score >= 6:
                return 'medium'
            else:
                return 'low'

        # Heuristics for unknown domains
        if any(authoritative in domain for authoritative in ['.edu', '.gov', '.org']):
            return 'high'
        elif any(major in domain for major in ['nytimes', 'washingtonpost', 'bbc', 'theguardian']):
            return 'high'
        else:
            return 'medium'

    def _identify_target_audience(self, title: str, content: str, domain: str, source: str) -> List[str]:
        """Identify target audience segments"""
        audiences = []
        text = f"{title} {content} {domain}".lower()

        # Check audience keywords
        for audience, keywords in AUDIENCE_KEYWORDS.items():
            matches = sum(1 for keyword in keywords if keyword in text)
            if matches >= 2:  # Threshold for inclusion
                audiences.append(audience)

        # Source-based audience mapping
        if 'hackernews' in source:
            audiences.append('tech-professionals')
        elif 'reddit-TrueReddit' in source or 'reddit-longreads' in source:
            audiences.extend(['culture-enthusiasts', 'creative-professionals'])
        elif 'internet-archive' in source:
            audiences.append('culture-enthusiasts')

        return list(set(audiences))  # Remove duplicates

    def _assess_engagement_potential(self, quality_score: int, content_type: str, word_count: int) -> str:
        """Assess potential for user engagement"""
        score = quality_score

        # Content type bonuses
        engaging_types = ['game', 'video', 'tutorial']
        if content_type in engaging_types:
            score += 2
        elif content_type == 'long-read':
            score += 1
        elif content_type == 'academic':
            score -= 1

        # Word count considerations
        if content_type != 'game':
            if word_count > 3000:
                score -= 1  # Very long content may have lower completion rates
            elif 500 <= word_count <= 1500:
                score += 1  # Sweet spot for engagement

        # Convert to categorical
        if score >= 8:
            return 'high'
        elif score >= 6:
            return 'medium'
        else:
            return 'low'

    def _extract_keywords(self, title: str, content: str) -> List[str]:
        """Extract relevant keywords from content"""
        text = f"{title} {content}".lower()

        # Remove common words
        stop_words = {
            'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
            'of', 'with', 'by', 'is', 'are', 'was', 'were', 'been', 'have', 'has',
            'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may',
            'might', 'must', 'can', 'this', 'that', 'these', 'those', 'i', 'you',
            'he', 'she', 'it', 'we', 'they', 'me', 'him', 'her', 'us', 'them'
        }

        # Extract words (3+ characters, alphabetic)
        words = re.findall(r'\b[a-z]{3,}\b', text)
        keywords = [word for word in words if word not in stop_words]

        # Count frequency and return top keywords
        word_freq = {}
        for word in keywords:
            word_freq[word] = word_freq.get(word, 0) + 1

        # Return top 10 most frequent keywords
        sorted_keywords = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)
        return [word for word, freq in sorted_keywords[:10]]

    def _extract_topics(self, title: str, content: str, domain: str, source: str) -> List[str]:
        """Extract main topics/themes from content"""
        topics = set()
        text = f"{title} {content}".lower()

        # Topic detection patterns
        topic_patterns = {
            'artificial-intelligence': ['ai', 'artificial intelligence', 'machine learning', 'neural network'],
            'climate-change': ['climate', 'global warming', 'carbon', 'environment', 'sustainability'],
            'cryptocurrency': ['bitcoin', 'crypto', 'blockchain', 'ethereum', 'defi'],
            'space-exploration': ['space', 'nasa', 'mars', 'rocket', 'astronaut', 'satellite'],
            'health-wellness': ['health', 'medical', 'wellness', 'fitness', 'nutrition', 'mental health'],
            'social-media': ['social media', 'facebook', 'twitter', 'instagram', 'tiktok'],
            'remote-work': ['remote work', 'work from home', 'hybrid work', 'digital nomad'],
            'startup-entrepreneurship': ['startup', 'entrepreneur', 'venture capital', 'funding', 'ipo'],
            'creative-arts': ['design', 'art', 'creativity', 'photography', 'music', 'film'],
            'data-privacy': ['privacy', 'data protection', 'gdpr', 'surveillance', 'security']
        }

        for topic, patterns in topic_patterns.items():
            if any(pattern in text for pattern in patterns):
                topics.add(topic)

        # Source-based topic inference
        if 'reddit-webgames' in source:
            topics.add('gaming')
        elif 'internet-archive-science' in source:
            topics.add('scientific-research')
        elif 'hackernews' in source:
            topics.add('technology-trends')

        return list(topics)[:8]  # Limit to 8 topics

    def _suggest_related_categories(self, topics: List[str], content_type: str, source: str) -> List[str]:
        """Suggest related BrowseForward categories"""
        categories = set()

        # Map topics to categories
        topic_category_map = {
            'artificial-intelligence': ['technology', 'science'],
            'climate-change': ['science', 'culture'],
            'space-exploration': ['science'],
            'creative-arts': ['culture'],
            'gaming': ['webgames'],
            'scientific-research': ['science'],
            'technology-trends': ['technology']
        }

        for topic in topics:
            if topic in topic_category_map:
                categories.update(topic_category_map[topic])

        # Content type mapping
        type_category_map = {
            'game': ['webgames'],
            'video': ['youtube'],
            'long-read': ['long-reads'],
            'academic': ['science']
        }

        if content_type in type_category_map:
            categories.update(type_category_map[content_type])

        return list(categories)[:5]  # Limit to 5 categories

    def update_item_metadata(self, metadata: ContentMetadata) -> bool:
        """Update database item with enhanced metadata"""
        try:
            update_expression_parts = []
            expression_attribute_values = {}
            expression_attribute_names = {}

            # Build update expression
            fields_to_update = {
                'aiKeywords': metadata.ai_keywords,
                'aiTopics': metadata.ai_topics,
                'readingTimeMinutes': metadata.reading_time_minutes,
                'wordCount': metadata.word_count,
                'qualityScore': metadata.quality_score,
                'contentType': metadata.content_type,
                'difficulty': metadata.difficulty,
                'mobileFlag': metadata.mobile_friendly,
                'domainAuthority': metadata.domain_authority,
                'engagementPotential': metadata.engagement_potential,
                'targetAudience': metadata.target_audience,
                'relatedCategories': metadata.related_categories,
                'paragraphCount': metadata.paragraph_count,
                'hasImages': metadata.has_images,
                'hasVideos': metadata.has_videos,
                'updatedAt': datetime.now(timezone.utc).isoformat()
            }

            # Add enhanced tags
            if metadata.tags:
                fields_to_update['enhancedTags'] = metadata.tags

            for field, value in fields_to_update.items():
                update_expression_parts.append(f'#{field} = :{field}')
                expression_attribute_names[f'#{field}'] = field
                expression_attribute_values[f':{field}'] = value

            # Update the item
            self.table.update_item(
                Key={'url': metadata.url},
                UpdateExpression='SET ' + ', '.join(update_expression_parts),
                ExpressionAttributeNames=expression_attribute_names,
                ExpressionAttributeValues=expression_attribute_values
            )

            return True

        except Exception as e:
            print(f"❌ Error updating metadata for {metadata.url}: {e}")
            return False

    def process_content_batch(self, items: List[Dict[str, Any]], batch_size: int = 50) -> Dict[str, int]:
        """Process a batch of content items for metadata enhancement"""
        print(f"🤖 PROCESSING {len(items)} ITEMS FOR METADATA ENHANCEMENT")
        print("=" * 60)

        results = {
            'processed': 0,
            'updated': 0,
            'errors': 0,
            'skipped': 0
        }

        for i in range(0, len(items), batch_size):
            batch = items[i:i + batch_size]
            print(f"\n📦 Processing batch {i//batch_size + 1} ({len(batch)} items)...")

            for item in batch:
                try:
                    # Check if item already has enhanced metadata
                    if (item.get('aiKeywords') and
                        item.get('readingTimeMinutes') and
                        item.get('enhancedTags')):
                        results['skipped'] += 1
                        continue

                    # Generate metadata
                    metadata = self.generate_enhanced_metadata(item)

                    # Update database
                    if self.update_item_metadata(metadata):
                        results['updated'] += 1
                        print(f"  ✅ {metadata.title[:50]}...")
                    else:
                        results['errors'] += 1

                    results['processed'] += 1

                    # Rate limiting
                    if results['processed'] % 10 == 0:
                        time.sleep(1)  # Brief pause every 10 items

                except Exception as e:
                    print(f"  ❌ Error processing item: {e}")
                    results['errors'] += 1

        return results

    def run_metadata_enhancement(self, source_filter: str = None, limit: int = 500) -> Dict[str, Any]:
        """Run metadata enhancement workflow"""
        print("🚀 METADATA ENHANCEMENT WORKFLOW")
        print("=" * 50)

        # Get content to process
        print(f"📥 Fetching content items...")
        if source_filter:
            print(f"🎯 Filtering by source: {source_filter}")

        items = self.get_content_sample(source_filter, limit)

        if not items:
            print("❌ No items found to process")
            return {'error': 'No items found'}

        print(f"📊 Found {len(items)} items to process")

        # Process the batch
        results = self.process_content_batch(items)

        print(f"\n✅ METADATA ENHANCEMENT COMPLETED")
        print(f"📊 Results: {results}")

        return results

def main():
    """Main execution function"""
    enhancer = MetadataEnhancer()

    print("🤖 ENHANCED METADATA GENERATION SYSTEM")
    print("=" * 50)
    print("Choose an option:")
    print("1. Enhance all content metadata")
    print("2. Enhance specific source")
    print("3. Test single item")
    print("4. Show content type patterns")

    choice = input("\nEnter choice (1-4): ").strip()

    if choice == '1':
        limit = input("Enter max items to process (default 500): ").strip()
        limit = int(limit) if limit.isdigit() else 500
        enhancer.run_metadata_enhancement(limit=limit)

    elif choice == '2':
        source = input("Enter source name (e.g., reddit-TrueReddit): ").strip()
        limit = input("Enter max items to process (default 100): ").strip()
        limit = int(limit) if limit.isdigit() else 100
        enhancer.run_metadata_enhancement(source, limit)

    elif choice == '3':
        url = input("Enter URL to test: ").strip()
        # This would need implementation to fetch a single item by URL
        print("Single item testing not implemented in this demo")

    elif choice == '4':
        print("\n📋 CONTENT TYPE PATTERNS:")
        for content_type, patterns in CONTENT_TYPE_PATTERNS.items():
            print(f"\n{content_type.upper()}:")
            if 'keywords' in patterns:
                print(f"  Keywords: {', '.join(patterns['keywords'][:5])}...")
            if 'domains' in patterns:
                print(f"  Domains: {', '.join(patterns['domains'][:3])}...")
            if 'min_words' in patterns:
                print(f"  Min words: {patterns['min_words']}")

    else:
        print("❌ Invalid choice")

if __name__ == "__main__":
    main()