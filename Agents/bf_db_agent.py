#!/usr/bin/env python3
"""
bf-db Agent - BrowseForward Database Management System
Comprehensive database operations for DumFlow's content curation
"""

import boto3
import json
import sys
import argparse
from datetime import datetime, timedelta
from urllib.parse import urlparse
from collections import defaultdict
import re
import requests
import time
from bs4 import BeautifulSoup
from typing import List, Dict, Any, Optional, Tuple

# AWS Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

# Initialize DynamoDB client
dynamodb = boto3.client(
    'dynamodb',
    region_name=REGION,
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY
)

class BrowseForwardDB:
    """Main database management class for BrowseForward content"""

    def __init__(self):
        self.dynamodb = dynamodb
        self.table_name = TABLE_NAME

        # Content quality thresholds
        self.quality_thresholds = {
            'high': 80,
            'medium': 50,
            'low': 20
        }

        # Mobile-friendly domains (from webgames analysis)
        self.mobile_friendly_domains = [
            'lichess.org', 'chess.com', 'eyezmaze.com',
            'gamejolt.com', 'koalabeast.com', 'choiceofgames.com'
        ]

    # ========== ANALYSIS METHODS ==========

    def analyze_source(self, source: str) -> Dict[str, Any]:
        """Detailed analysis of a content source"""
        print(f"🔍 Analyzing source: {source}")
        print("=" * 60)

        # Query items from source
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='source-status-index',
            KeyConditionExpression='#source = :source',
            ExpressionAttributeNames={'#source': 'source'},
            ExpressionAttributeValues={':source': {'S': source}}
        )

        items = response.get('Items', [])
        total_count = len(items)

        # Analyze status distribution
        status_counts = defaultdict(int)
        category_counts = defaultdict(int)
        quality_scores = []

        for item in items:
            # Status
            status = item.get('status', {}).get('S', 'unknown')
            status_counts[status] += 1

            # Categories
            bf_category = item.get('bfCategory', {}).get('S', 'uncategorized')
            category_counts[bf_category] += 1

            # Quality indicators
            upvotes = int(item.get('upvotes', {}).get('N', 0))
            interactions = int(item.get('interactions', {}).get('N', 0))
            quality = self._calculate_quality_score(item)
            quality_scores.append(quality)

        # Calculate averages
        avg_quality = sum(quality_scores) / len(quality_scores) if quality_scores else 0

        # Determine recommendations
        recommendations = self._generate_source_recommendations(
            source, avg_quality, status_counts
        )

        report = {
            'source': source,
            'total_items': total_count,
            'status_distribution': dict(status_counts),
            'category_distribution': dict(category_counts),
            'average_quality': round(avg_quality, 2),
            'recommendations': recommendations
        }

        # Print report
        print(f"📊 Source: {source}")
        print(f"   Total items: {total_count}")
        print(f"   Average quality: {report['average_quality']}/100")
        print(f"\n📈 Status breakdown:")
        for status, count in status_counts.items():
            print(f"   {status}: {count} ({count/total_count*100:.1f}%)")
        print(f"\n🏷️  Category breakdown:")
        for cat, count in list(category_counts.items())[:5]:
            print(f"   {cat}: {count}")
        print(f"\n💡 Recommendations:")
        for rec in recommendations:
            print(f"   • {rec}")

        return report

    def analyze_category_sources(self, category: str, limit: int = None) -> Dict[str, Any]:
        """Analyze sources within a specific category"""
        print(f"🏷️  CATEGORY SOURCE ANALYSIS: {category.upper()}")
        print("=" * 60)

        # Query items by category using GSI
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': category},
                ':status': {'S': 'active'}
            }
        )

        items = response.get('Items', [])

        # Handle pagination for large categories
        while 'LastEvaluatedKey' in response:
            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': {'S': category},
                    ':status': {'S': 'active'}
                },
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        print(f"📊 Found {len(items):,} items in '{category}' category")

        if not items:
            print(f"❌ No items found for category: {category}")
            return {'category': category, 'total_items': 0, 'sources': {}}

        # Analyze sources within category
        source_counts = defaultdict(int)
        source_examples = defaultdict(list)
        status_counts = defaultdict(int)

        for item in items:
            source = item.get('source', {}).get('S', 'unknown')
            source_counts[source] += 1

            status = item.get('status', {}).get('S', 'unknown')
            status_counts[status] += 1

            # Store examples (limit per source)
            if len(source_examples[source]) < 3:
                title = item.get('title', {}).get('S', 'No Title')
                url = item.get('url', {}).get('S', 'No URL')
                source_examples[source].append({
                    'title': title,
                    'url': url,
                    'status': status
                })

        # Sort sources by count
        sorted_sources = sorted(source_counts.items(), key=lambda x: x[1], reverse=True)

        print(f"\n🌐 SOURCES IN '{category.upper()}' CATEGORY:")
        print("-" * 80)

        for i, (source, count) in enumerate(sorted_sources, 1):
            percentage = (count / len(items)) * 100
            print(f"{i:2d}. {source:<35} {count:4,} items ({percentage:5.1f}%)")

            # Show examples
            print(f"    Examples:")
            for j, example in enumerate(source_examples[source], 1):
                title_short = example['title'][:60] + "..." if len(example['title']) > 60 else example['title']
                status_indicator = "✅" if example['status'] == 'active' else "❌" if example['status'] == 'inactive' else "⚪"
                print(f"      {j}. {status_indicator} {title_short}")
                print(f"         {example['url']}")
            print()

        print(f"📈 STATUS BREAKDOWN:")
        for status, count in sorted(status_counts.items()):
            percentage = (count / len(items)) * 100
            print(f"   {status:<15} {count:4,} items ({percentage:5.1f}%)")

        return {
            'category': category,
            'total_items': len(items),
            'sources': dict(source_counts),
            'source_examples': dict(source_examples),
            'status_distribution': dict(status_counts)
        }

    def content_stats(self) -> Dict[str, Any]:
        """Overview of database content distribution"""
        print("📊 DATABASE CONTENT STATISTICS")
        print("=" * 60)

        # Scan for overall stats
        response = self.dynamodb.scan(
            TableName=self.table_name,
            Select='ALL_ATTRIBUTES'
        )

        items = response.get('Items', [])

        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = self.dynamodb.scan(
                TableName=self.table_name,
                Select='ALL_ATTRIBUTES',
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        # Analyze content
        source_counts = defaultdict(int)
        category_counts = defaultdict(int)
        status_counts = defaultdict(int)
        content_types = defaultdict(int)

        for item in items:
            source = item.get('source', {}).get('S', 'unknown')
            source_counts[source] += 1

            bf_category = item.get('bfCategory', {}).get('S', '')
            if bf_category:
                category_counts[bf_category] += 1

            status = item.get('status', {}).get('S', 'unknown')
            status_counts[status] += 1

            content_type = item.get('contentType', {}).get('S', 'article')
            content_types[content_type] += 1

        # Sort and display
        print(f"📈 TOTAL ITEMS: {len(items):,}")
        print(f"\n🌐 TOP SOURCES:")
        for source, count in sorted(source_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"   {source:<35} {count:,} items")

        print(f"\n🏷️  CATEGORIES:")
        for cat, count in sorted(category_counts.items()):
            print(f"   {cat:<20} {count:,} items")

        print(f"\n📊 STATUS DISTRIBUTION:")
        for status, count in sorted(status_counts.items()):
            print(f"   {status:<15} {count:,} items ({count/len(items)*100:.1f}%)")

        return {
            'total_items': len(items),
            'sources': dict(source_counts),
            'categories': dict(category_counts),
            'statuses': dict(status_counts),
            'content_types': dict(content_types)
        }

    # ========== CLEANUP METHODS ==========

    def cleanup_reddit(self, source: str = None) -> Dict[str, Any]:
        """Clean Reddit sources by removing outdated content"""
        reddit_sources = [
            'reddit-movies', 'reddit-gadgets', 'reddit-space',
            'reddit-psychology', 'reddit-TrueReddit', 'reddit-longreads'
        ] if not source else [source]

        print("🧹 REDDIT CLEANUP OPERATION")
        print("=" * 60)

        results = {}

        for reddit_source in reddit_sources:
            print(f"\n📰 Processing {reddit_source}...")

            # Get items from source
            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='source-status-index',
                KeyConditionExpression='#source = :source',
                ExpressionAttributeNames={'#source': 'source'},
                ExpressionAttributeValues={':source': {'S': reddit_source}}
            )

            items = response.get('Items', [])
            deactivated = 0
            kept = 0

            for item in items:
                url = item.get('url', {}).get('S', '')
                title = item.get('title', {}).get('S', '')

                # Determine if content should be kept
                should_keep = self._evaluate_reddit_content(reddit_source, item)

                if not should_keep:
                    # Mark as inactive
                    self.mark_inactive(url)
                    deactivated += 1
                    print(f"   🔴 Deactivated: {title[:50]}")
                else:
                    kept += 1
                    # Enhance metadata if keeping
                    self._enhance_item_metadata(item)

            results[reddit_source] = {
                'total': len(items),
                'kept': kept,
                'deactivated': deactivated
            }

            print(f"   ✅ Kept: {kept}, ❌ Deactivated: {deactivated}")

        return results

    def cleanup_webgames(self) -> Dict[str, Any]:
        """Find and activate mobile-friendly games"""
        print("🎮 WEBGAMES MOBILE OPTIMIZATION")
        print("=" * 60)

        # Get all webgames
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'},
                ':status': {'S': 'active'}
            }
        )

        items = response.get('Items', [])
        print(f"Found {len(items)} total webgames")

        activated = 0
        candidates = []

        for item in items:
            url = item.get('url', {}).get('S', '')
            title = item.get('title', {}).get('S', '')
            status = item.get('status', {}).get('S', 'unknown')

            if status != 'active':
                # Score mobile compatibility
                score = self._score_mobile_compatibility(url, title)
                candidates.append({
                    'url': url,
                    'title': title,
                    'score': score
                })

        # Sort by score and activate top candidates
        candidates.sort(key=lambda x: x['score'], reverse=True)

        print(f"\n🏆 TOP MOBILE-FRIENDLY CANDIDATES:")
        for i, game in enumerate(candidates[:20], 1):
            print(f"{i:2d}. Score {game['score']:3d} | {game['title'][:50]}")

            # Activate top 10
            if i <= 10 and game['score'] > 50:
                self.mark_active(game['url'])
                activated += 1
                print(f"    ✅ ACTIVATED")

        return {
            'total_games': len(items),
            'candidates_found': len(candidates),
            'activated': activated
        }

    def cleanup_archive(self, archive_type: str = None) -> Dict[str, Any]:
        """Filter Internet Archive content for quality"""
        archive_sources = [
            'internet-archive-culture', 'internet-archive-art',
            'internet-archive-history', 'internet-archive-science',
            'internet-archive-tech'
        ] if not archive_type else [f'internet-archive-{archive_type}']

        print("📚 INTERNET ARCHIVE CLEANUP")
        print("=" * 60)

        results = {}

        for source in archive_sources:
            print(f"\n📖 Processing {source}...")

            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='source-status-index',
                KeyConditionExpression='#source = :source',
                ExpressionAttributeNames={'#source': 'source'},
                ExpressionAttributeValues={':source': {'S': source}}
            )

            items = response.get('Items', [])
            enhanced = 0
            deactivated = 0

            for item in items:
                # Calculate quality score
                quality = self._calculate_quality_score(item)

                if quality < 30:
                    # Low quality - deactivate
                    url = item.get('url', {}).get('S', '')
                    self.mark_inactive(url)
                    deactivated += 1
                else:
                    # Enhance metadata
                    self._enhance_item_metadata(item)
                    enhanced += 1

            results[source] = {
                'total': len(items),
                'enhanced': enhanced,
                'deactivated': deactivated
            }

            print(f"   📈 Enhanced: {enhanced}, ❌ Deactivated: {deactivated}")

        return results

    # ========== METADATA METHODS ==========

    def generate_metadata(self, source: str = None, limit: int = 100) -> Dict[str, Any]:
        """Generate enhanced metadata for content"""
        print("🏷️  METADATA GENERATION")
        print("=" * 60)

        # Build query
        if source:
            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='source-status-index',
                KeyConditionExpression='#source = :source',
                ExpressionAttributeNames={'#source': 'source'},
                ExpressionAttributeValues={':source': {'S': source}},
                Limit=limit
            )
        else:
            response = self.dynamodb.scan(
                TableName=self.table_name,
                Limit=limit
            )

        items = response.get('Items', [])
        updated_count = 0

        for item in items:
            url = item.get('url', {}).get('S', '')

            # Generate metadata
            metadata = self._generate_item_metadata(item)

            # Update item with metadata
            if metadata:
                self._update_item_metadata(url, metadata)
                updated_count += 1

                if updated_count % 10 == 0:
                    print(f"   ✅ Updated {updated_count} items...")

        print(f"\n📊 Metadata generation complete: {updated_count} items updated")

        return {
            'processed': len(items),
            'updated': updated_count
        }

    # ========== HELPER METHODS ==========

    def _calculate_quality_score(self, item: Dict) -> int:
        """Calculate quality score for an item (0-100)"""
        score = 50  # Base score

        # Engagement metrics
        upvotes = int(item.get('upvotes', {}).get('N', 0))
        interactions = int(item.get('interactions', {}).get('N', 0))

        if upvotes > 100: score += 20
        elif upvotes > 50: score += 10
        elif upvotes > 10: score += 5

        if interactions > 500: score += 15
        elif interactions > 100: score += 10
        elif interactions > 50: score += 5

        # Content completeness
        if item.get('title', {}).get('S'): score += 5
        if item.get('thumbnailUrl', {}).get('S'): score += 5
        if item.get('aiSummary', {}).get('S'): score += 10
        if item.get('tags', {}).get('SS'): score += 5

        # Word count for articles
        word_count = int(item.get('wordCount', {}).get('N', 0))
        if word_count > 2000: score += 10  # Long-form content
        elif word_count > 500: score += 5

        return min(100, max(0, score))

    def _score_mobile_compatibility(self, url: str, title: str) -> int:
        """Score webgame mobile compatibility"""
        score = 50

        # Parse domain
        domain = urlparse(url).netloc.lower()

        # Check mobile-friendly domains
        if any(friendly in domain for friendly in self.mobile_friendly_domains):
            score += 30

        # Check title/URL for mobile indicators
        mobile_keywords = ['puzzle', 'chess', 'card', 'simple', 'tap', 'click']
        desktop_keywords = ['fps', 'mmo', 'keyboard', 'wasd', 'flash']

        for keyword in mobile_keywords:
            if keyword in title.lower() or keyword in url.lower():
                score += 10

        for keyword in desktop_keywords:
            if keyword in title.lower() or keyword in url.lower():
                score -= 15

        return max(0, min(100, score))

    def _evaluate_reddit_content(self, source: str, item: Dict) -> bool:
        """Determine if Reddit content should be kept"""
        # High-quality subreddits - keep most content
        if source in ['reddit-TrueReddit', 'reddit-longreads', 'reddit-Foodforthought']:
            quality = self._calculate_quality_score(item)
            return quality > 30

        # Tech/news subreddits - remove outdated content
        if source in ['reddit-gadgets', 'reddit-movies', 'reddit-space']:
            # Check if content is timeless
            title = item.get('title', {}).get('S', '').lower()
            outdated_keywords = ['review', 'announcement', 'launches', 'released',
                                'update', 'patch', 'trailer', 'teaser']

            if any(keyword in title for keyword in outdated_keywords):
                return False

            quality = self._calculate_quality_score(item)
            return quality > 50

        # Default: keep if quality is decent
        return self._calculate_quality_score(item) > 40

    def _generate_item_metadata(self, item: Dict) -> Dict[str, Any]:
        """Generate enhanced metadata for an item"""
        metadata = {}

        # Extract basic info
        title = item.get('title', {}).get('S', '')
        url = item.get('url', {}).get('S', '')
        source = item.get('source', {}).get('S', '')

        # Generate tags
        tags = self._generate_tags(title, source)
        if tags:
            metadata['tags'] = {'SS': tags}

        # Calculate word count (if text content exists)
        text_content = item.get('textContent', {}).get('S', '')
        if text_content:
            word_count = len(text_content.split())
            metadata['wordCount'] = {'N': str(word_count)}
            metadata['readingTime'] = {'N': str(max(1, word_count // 200))}

        # Determine content type
        if 'youtube' in source:
            metadata['contentType'] = {'S': 'video'}
        elif 'webgames' in source:
            metadata['contentType'] = {'S': 'game'}
        elif 'letterboxd' in source:
            metadata['contentType'] = {'S': 'review'}
        else:
            metadata['contentType'] = {'S': 'article'}

        # Calculate quality score
        quality = self._calculate_quality_score(item)
        metadata['qualityScore'] = {'N': str(quality)}

        # Mobile compatibility
        if 'webgames' in source:
            mobile_score = self._score_mobile_compatibility(url, title)
            metadata['mobileFriendly'] = {'BOOL': mobile_score > 60}

        return metadata

    def _generate_tags(self, title: str, source: str) -> List[str]:
        """Generate relevant tags for content"""
        tags = []

        # Source-based tags
        if 'reddit' in source:
            tags.append('reddit')
            subreddit = source.replace('reddit-', '')
            tags.append(subreddit)
        elif 'letterboxd' in source:
            tags.append('letterboxd')
            tags.append('movies')
            tags.append('reviews')

        # Content-based tags
        keywords = {
            'technology': ['tech', 'software', 'hardware', 'computer', 'digital'],
            'science': ['science', 'research', 'study', 'discovery', 'experiment'],
            'culture': ['culture', 'art', 'museum', 'history', 'society'],
            'entertainment': ['movie', 'film', 'game', 'music', 'video'],
            'design': ['design', 'architecture', 'creative', 'visual', 'aesthetic']
        }

        title_lower = title.lower()
        for tag, words in keywords.items():
            if any(word in title_lower for word in words):
                tags.append(tag)

        return list(set(tags))[:5]  # Max 5 tags

    def _enhance_item_metadata(self, item: Dict) -> None:
        """Enhance an item with generated metadata"""
        url = item.get('url', {}).get('S', '')
        metadata = self._generate_item_metadata(item)

        if metadata:
            self._update_item_metadata(url, metadata)

    def _update_item_metadata(self, url: str, metadata: Dict) -> None:
        """Update DynamoDB item with metadata"""
        update_expression_parts = []
        expression_attribute_values = {}

        for key, value in metadata.items():
            update_expression_parts.append(f"#{key} = :{key}")
            expression_attribute_values[f":{key}"] = value

        if update_expression_parts:
            try:
                self.dynamodb.update_item(
                    TableName=self.table_name,
                    Key={'url': {'S': url}},
                    UpdateExpression='SET ' + ', '.join(update_expression_parts),
                    ExpressionAttributeNames={f"#{k}": k for k in metadata.keys()},
                    ExpressionAttributeValues=expression_attribute_values
                )
            except Exception as e:
                print(f"   ⚠️  Error updating {url}: {e}")

    def _generate_source_recommendations(self, source: str, avg_quality: float,
                                        status_counts: Dict) -> List[str]:
        """Generate recommendations for a content source"""
        recommendations = []

        # Quality-based recommendations
        if avg_quality < 40:
            recommendations.append("Low quality content - consider removing or enhancing")
        elif avg_quality < 60:
            recommendations.append("Medium quality - enhance metadata and filter low performers")
        else:
            recommendations.append("High quality source - maintain and expand")

        # Status-based recommendations
        inactive_ratio = status_counts.get('inactive', 0) / sum(status_counts.values())
        if inactive_ratio > 0.5:
            recommendations.append(f"High inactive ratio ({inactive_ratio:.1%}) - review criteria")

        # Source-specific recommendations
        if 'reddit' in source and 'gadgets' in source:
            recommendations.append("Tech content ages quickly - filter for timeless articles")
        elif 'webgames' in source:
            recommendations.append("Continue mobile compatibility testing")
        elif 'archive' in source:
            recommendations.append("Rich content source - enhance with AI summaries")

        return recommendations

    def get_sample_urls(self, source: str, limit: int = 5) -> List[Dict[str, str]]:
        """Get sample URLs from a specific source"""
        print(f"🔗 Getting {limit} sample URLs from: {source}")
        print("=" * 60)

        # Query items from source
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='source-status-index',
            KeyConditionExpression='#source = :source',
            ExpressionAttributeNames={'#source': 'source'},
            ExpressionAttributeValues={':source': {'S': source}},
            Limit=limit
        )

        items = response.get('Items', [])
        samples = []

        for item in items:
            url = item.get('url', {}).get('S', 'No URL')
            title = item.get('title', {}).get('S', 'No Title')
            status = item.get('status', {}).get('S', 'unknown')

            samples.append({
                'url': url,
                'title': title,
                'status': status
            })

            print(f"{len(samples):2d}. {title[:80]}")
            print(f"    URL: {url}")
            print(f"    Status: {status}")
            print()

        return samples

    def mark_source_inactive(self, source: str) -> Dict[str, Any]:
        """Mark all items from a source as inactive (bulk operation)"""
        print(f"🔴 BULK INACTIVATION: {source}")
        print("=" * 60)

        # Query all items from source
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='source-status-index',
            KeyConditionExpression='#source = :source',
            ExpressionAttributeNames={'#source': 'source'},
            ExpressionAttributeValues={':source': {'S': source}}
        )

        items = response.get('Items', [])
        total_items = len(items)
        processed = 0

        print(f"Found {total_items} items to mark as inactive")

        # Process in batches for performance
        batch_size = 25  # DynamoDB batch limit
        for i in range(0, len(items), batch_size):
            batch = items[i:i + batch_size]

            # Prepare batch write request
            request_items = []
            for item in batch:
                url = item.get('url', {}).get('S', '')
                request_items.append({
                    'PutRequest': {
                        'Item': {
                            **item,  # Keep all existing attributes
                            'isActive': {'BOOL': False},
                            'status': {'S': 'inactive'},
                            'lastUpdated': {'S': datetime.now().isoformat()}
                        }
                    }
                })

            # Execute batch write
            try:
                self.dynamodb.batch_write_item(
                    RequestItems={
                        self.table_name: request_items
                    }
                )
                processed += len(batch)
                print(f"   ✅ Processed {processed}/{total_items} items...")

                # Small delay to avoid throttling
                time.sleep(0.1)

            except Exception as e:
                print(f"   ⚠️  Batch error: {e}")
                # Fall back to individual updates for this batch
                for item in batch:
                    url = item.get('url', {}).get('S', '')
                    try:
                        self.mark_inactive(url)
                        processed += 1
                    except Exception as individual_error:
                        print(f"   ❌ Failed to update {url}: {individual_error}")

        print(f"\n✅ BULK INACTIVATION COMPLETE")
        print(f"   Source: {source}")
        print(f"   Total items: {total_items}")
        print(f"   Successfully processed: {processed}")

        return {
            'source': source,
            'total_items': total_items,
            'processed': processed,
            'success_rate': processed / total_items if total_items > 0 else 0
        }

    def analyze_url_patterns(self, source: str, limit: int = 10) -> Dict[str, Any]:
        """Analyze URL patterns to assess conversion feasibility"""
        print(f"🔍 URL PATTERN ANALYSIS: {source}")
        print("=" * 60)

        # Get sample URLs
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='source-status-index',
            KeyConditionExpression='#source = :source',
            ExpressionAttributeNames={'#source': 'source'},
            ExpressionAttributeValues={':source': {'S': source}},
            Limit=limit
        )

        items = response.get('Items', [])
        url_patterns = {}
        conversion_analysis = {
            'total_analyzed': len(items),
            'pattern_groups': {},
            'conversion_feasibility': 'unknown',
            'recommended_action': '',
            'sample_urls': []
        }

        print(f"Analyzing {len(items)} URLs...")
        print()

        for i, item in enumerate(items, 1):
            url = item.get('url', {}).get('S', '')
            title = item.get('title', {}).get('S', 'No Title')

            # Parse URL structure
            parsed = urlparse(url)
            domain = parsed.netloc
            path = parsed.path
            query = parsed.query

            # Categorize URL pattern
            if 'search' in url.lower() or 'query' in url.lower() or '?q=' in url:
                pattern = 'search_query'
            elif '/book/show/' in path:
                pattern = 'direct_book_link'
            elif '/title/' in path:
                pattern = 'direct_movie_link'
            elif parsed.fragment:  # URLs with fragments
                pattern = 'fragment_based'
            elif query:
                pattern = 'query_parameter'
            else:
                pattern = 'direct_path'

            # Track patterns
            if pattern not in url_patterns:
                url_patterns[pattern] = []
            url_patterns[pattern].append(url)

            # Store sample for analysis
            conversion_analysis['sample_urls'].append({
                'number': i,
                'url': url,
                'title': title[:60],
                'pattern': pattern,
                'domain': domain
            })

            print(f"{i:2d}. Pattern: {pattern}")
            print(f"    Title: {title[:60]}")
            print(f"    URL: {url}")
            print()

        # Analyze patterns
        for pattern, urls in url_patterns.items():
            conversion_analysis['pattern_groups'][pattern] = {
                'count': len(urls),
                'percentage': len(urls) / len(items) * 100,
                'sample_url': urls[0] if urls else None
            }

        # Determine conversion feasibility
        if 'search_query' in url_patterns and len(url_patterns['search_query']) > len(items) * 0.8:
            conversion_analysis['conversion_feasibility'] = 'difficult'
            conversion_analysis['recommended_action'] = 'Requires API integration or complex URL transformation'
        elif 'direct_book_link' in url_patterns or 'direct_movie_link' in url_patterns:
            conversion_analysis['conversion_feasibility'] = 'feasible'
            conversion_analysis['recommended_action'] = 'Direct URL conversion possible with pattern mapping'
        else:
            conversion_analysis['conversion_feasibility'] = 'moderate'
            conversion_analysis['recommended_action'] = 'Mixed patterns - needs case-by-case analysis'

        # Print analysis summary
        print("📊 PATTERN ANALYSIS SUMMARY:")
        print("-" * 40)
        for pattern, data in conversion_analysis['pattern_groups'].items():
            print(f"{pattern:<20} {data['count']:3d} URLs ({data['percentage']:5.1f}%)")

        print(f"\n🎯 CONVERSION FEASIBILITY: {conversion_analysis['conversion_feasibility'].upper()}")
        print(f"💡 RECOMMENDATION: {conversion_analysis['recommended_action']}")

        return conversion_analysis

    # ========== BROWSEFORWARD OPTIMIZATION METHODS ==========

    def analyze_bf_category_population(self) -> Dict[str, Any]:
        """Analyze current bfCategory field population across database"""
        print("🔍 BROWSEFORWARD CATEGORY POPULATION ANALYSIS")
        print("=" * 60)

        # Scan entire database to analyze bfCategory vs category population
        response = self.dynamodb.scan(
            TableName=self.table_name,
            Select='ALL_ATTRIBUTES'
        )

        items = response.get('Items', [])

        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = self.dynamodb.scan(
                TableName=self.table_name,
                Select='ALL_ATTRIBUTES',
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        total_items = len(items)
        has_bf_category = 0
        has_category_only = 0
        uncategorized = 0

        source_category_mapping = defaultdict(lambda: defaultdict(int))
        missing_bf_category_sources = defaultdict(int)

        for item in items:
            bf_category = item.get('bfCategory', {}).get('S', '')
            category = item.get('category', {}).get('S', '')
            source = item.get('source', {}).get('S', 'unknown')

            if bf_category:
                has_bf_category += 1
                source_category_mapping[source][bf_category] += 1
            elif category:
                has_category_only += 1
                missing_bf_category_sources[source] += 1
                source_category_mapping[source][category] += 1
            else:
                uncategorized += 1

        # Calculate percentages
        bf_percentage = (has_bf_category / total_items * 100) if total_items > 0 else 0
        category_only_percentage = (has_category_only / total_items * 100) if total_items > 0 else 0

        print(f"📊 TOTAL ITEMS: {total_items:,}")
        print(f"✅ Items with bfCategory: {has_bf_category:,} ({bf_percentage:.1f}%)")
        print(f"⚠️  Items with category only: {has_category_only:,} ({category_only_percentage:.1f}%)")
        print(f"❌ Uncategorized items: {uncategorized:,} ({uncategorized/total_items*100:.1f}%)")

        print(f"\n🌐 TOP SOURCES MISSING bfCategory:")
        for source, count in sorted(missing_bf_category_sources.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"   {source:<40} {count:,} items")

        print(f"\n🏷️  CURRENT bfCategory DISTRIBUTION:")
        bf_categories = defaultdict(int)
        for item in items:
            bf_cat = item.get('bfCategory', {}).get('S', '')
            if bf_cat:
                bf_categories[bf_cat] += 1

        for cat, count in sorted(bf_categories.items()):
            print(f"   {cat:<20} {count:,} items")

        return {
            'total_items': total_items,
            'has_bf_category': has_bf_category,
            'has_category_only': has_category_only,
            'uncategorized': uncategorized,
            'bf_category_percentage': bf_percentage,
            'missing_sources': dict(missing_bf_category_sources),
            'bf_category_distribution': dict(bf_categories),
            'source_mapping': dict(source_category_mapping)
        }

    def bulk_populate_bf_categories(self, dry_run: bool = True) -> Dict[str, Any]:
        """Bulk populate bfCategory fields based on existing category and source data"""
        print("🚀 BULK bfCategory POPULATION")
        print("=" * 60)
        print(f"Mode: {'DRY RUN' if dry_run else 'LIVE UPDATE'}")
        print()

        # Category mapping strategy based on source analysis
        source_to_bf_category = {
            # Movies & Entertainment
            'letterboxd': 'movies',
            'tmdb-to-imdb': 'movies',
            'imdb-top-250': 'movies',

            # Long-form Reading
            'reddit-longreads': 'long-reads',
            'reddit-Foodforthought': 'long-reads',
            'reddit-indepthstories': 'long-reads',
            'reddit-TrueReddit': 'long-reads',

            # Technology
            'hackernews': 'technology',
            'reddit-programming': 'technology',
            'reddit-gadgets': 'technology',

            # Books & Literature
            'google-books-to-goodreads': 'books',
            'goodreads': 'books',

            # Games
            'webgames': 'webgames',

            # Science & Education
            'reddit-science': 'science',
            'reddit-space': 'science',
            'wikipedia': 'science',

            # Art & Culture
            'designboom': 'art',
            'reddit-art': 'art',

            # Food & Lifestyle
            'reddit-food': 'food',

            # History
            'reddit-history': 'history',

            # YouTube Content
            'youtube': 'youtube'
        }

        # Internet Archive mapping
        archive_mapping = {
            'internet-archive-culture': 'culture',
            'internet-archive-art': 'art',
            'internet-archive-history': 'history',
            'internet-archive-science': 'science',
            'internet-archive-tech': 'technology',
            'internet-archive-books': 'books'
        }
        source_to_bf_category.update(archive_mapping)

        # Query items that need bfCategory population
        print("🔍 Finding items that need bfCategory population...")

        response = self.dynamodb.scan(
            TableName=self.table_name,
            FilterExpression='attribute_not_exists(bfCategory) OR bfCategory = :empty',
            ExpressionAttributeValues={':empty': {'S': ''}}
        )

        items = response.get('Items', [])

        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = self.dynamodb.scan(
                TableName=self.table_name,
                FilterExpression='attribute_not_exists(bfCategory) OR bfCategory = :empty',
                ExpressionAttributeValues={':empty': {'S': ''}},
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        print(f"Found {len(items):,} items needing bfCategory population")

        # Categorize items for update
        update_stats = defaultdict(int)
        update_items = []

        for item in items:
            url = item.get('url', {}).get('S', '')
            source = item.get('source', {}).get('S', '')
            category = item.get('category', {}).get('S', '')

            # Determine bfCategory based on source mapping
            bf_category = None

            if source in source_to_bf_category:
                bf_category = source_to_bf_category[source]
            elif category:
                # Use existing category as fallback
                bf_category = category
            else:
                # Skip uncategorizable items
                update_stats['skipped'] += 1
                continue

            update_items.append({
                'url': url,
                'source': source,
                'current_category': category,
                'new_bf_category': bf_category
            })
            update_stats[bf_category] += 1

        print(f"\n📊 UPDATE SUMMARY:")
        for category, count in sorted(update_stats.items()):
            print(f"   {category:<20} {count:,} items")

        if dry_run:
            print("\n✅ DRY RUN COMPLETE - No changes made")
            print("💡 Run with dry_run=False to apply changes")
            return {
                'mode': 'dry_run',
                'total_found': len(items),
                'planned_updates': len(update_items),
                'update_stats': dict(update_stats)
            }

        # Execute bulk updates
        print(f"\n🚀 EXECUTING BULK UPDATE for {len(update_items):,} items...")
        updated_count = 0
        batch_size = 25

        for i in range(0, len(update_items), batch_size):
            batch = update_items[i:i + batch_size]

            try:
                # Use batch update requests
                for item in batch:
                    self.dynamodb.update_item(
                        TableName=self.table_name,
                        Key={'url': {'S': item['url']}},
                        UpdateExpression='SET bfCategory = :bf_category',
                        ExpressionAttributeValues={
                            ':bf_category': {'S': item['new_bf_category']}
                        }
                    )
                    updated_count += 1

                if updated_count % 100 == 0:
                    print(f"   ✅ Updated {updated_count}/{len(update_items)} items...")

            except Exception as e:
                print(f"   ⚠️  Batch error: {e}")

        print(f"\n✅ BULK UPDATE COMPLETE: {updated_count:,} items updated")

        return {
            'mode': 'live_update',
            'total_found': len(items),
            'successfully_updated': updated_count,
            'update_stats': dict(update_stats)
        }

    def optimize_gsi_queries(self) -> Dict[str, Any]:
        """Analyze and optimize GSI query patterns for BrowseForward"""
        print("⚡ GSI QUERY OPTIMIZATION ANALYSIS")
        print("=" * 60)

        recommendations = []

        # Test current GSI performance
        print("🔍 Testing category-status-index GSI performance...")

        # Test query efficiency for different categories
        test_categories = ['movies', 'long-reads', 'technology', 'books', 'webgames']
        query_performance = {}

        for category in test_categories:
            start_time = time.time()

            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': {'S': category},
                    ':status': {'S': 'active'}
                },
                Limit=10  # Small limit for performance testing
            )

            end_time = time.time()
            query_time = (end_time - start_time) * 1000  # Convert to ms

            items_count = len(response.get('Items', []))
            query_performance[category] = {
                'query_time_ms': round(query_time, 2),
                'items_returned': items_count,
                'has_items': items_count > 0
            }

            print(f"   {category:<15} {query_time:.1f}ms ({items_count} items)")

        # Analyze GSI coverage
        print(f"\n📊 GSI COVERAGE ANALYSIS:")

        # Check how many items can be efficiently queried via GSI
        gsi_queryable = 0
        total_active = 0

        response = self.dynamodb.scan(
            TableName=self.table_name,
            FilterExpression='#status = :active',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':active': {'S': 'active'}},
            Select='COUNT'
        )

        while True:
            total_active += response.get('Count', 0)

            if 'LastEvaluatedKey' not in response:
                break

            response = self.dynamodb.scan(
                TableName=self.table_name,
                FilterExpression='#status = :active',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':active': {'S': 'active'}},
                Select='COUNT',
                ExclusiveStartKey=response['LastEvaluatedKey']
            )

        # Check items with bfCategory (GSI queryable)
        response = self.dynamodb.scan(
            TableName=self.table_name,
            FilterExpression='#status = :active AND attribute_exists(bfCategory) AND bfCategory <> :empty',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':active': {'S': 'active'},
                ':empty': {'S': ''}
            },
            Select='COUNT'
        )

        while True:
            gsi_queryable += response.get('Count', 0)

            if 'LastEvaluatedKey' not in response:
                break

            response = self.dynamodb.scan(
                TableName=self.table_name,
                FilterExpression='#status = :active AND attribute_exists(bfCategory) AND bfCategory <> :empty',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':active': {'S': 'active'},
                    ':empty': {'S': ''}
                },
                Select='COUNT',
                ExclusiveStartKey=response['LastEvaluatedKey']
            )

        gsi_coverage = (gsi_queryable / total_active * 100) if total_active > 0 else 0

        print(f"   Total active items: {total_active:,}")
        print(f"   GSI queryable items: {gsi_queryable:,}")
        print(f"   GSI coverage: {gsi_coverage:.1f}%")

        # Generate recommendations
        if gsi_coverage < 80:
            recommendations.append("❗ Low GSI coverage - run bulk_populate_bf_categories() to improve")

        if gsi_coverage > 95:
            recommendations.append("✅ Excellent GSI coverage - queries should be very efficient")

        # Check for hot partitions
        avg_query_time = sum(perf['query_time_ms'] for perf in query_performance.values()) / len(query_performance)
        if avg_query_time > 100:
            recommendations.append("⚠️ Slow query times - consider optimizing GSI or data distribution")
        else:
            recommendations.append("✅ Good query performance")

        print(f"\n💡 RECOMMENDATIONS:")
        for rec in recommendations:
            print(f"   {rec}")

        return {
            'query_performance': query_performance,
            'total_active_items': total_active,
            'gsi_queryable_items': gsi_queryable,
            'gsi_coverage_percentage': gsi_coverage,
            'average_query_time_ms': avg_query_time,
            'recommendations': recommendations
        }

    def populate_bf_subcategories(self, dry_run: bool = True) -> Dict[str, Any]:
        """Populate bfSubcategory fields for better content organization"""
        print("🏷️  bfSubcategory POPULATION STRATEGY")
        print("=" * 60)
        print(f"Mode: {'DRY RUN' if dry_run else 'LIVE UPDATE'}")

        # Subcategory mapping based on content analysis
        subcategory_mapping = {
            # Movies subcategories
            'movies': {
                'letterboxd': 'film-reviews',
                'tmdb-to-imdb': 'film-database',
                'imdb-top-250': 'classic-films'
            },

            # Long-reads subcategories
            'long-reads': {
                'reddit-longreads': 'journalism',
                'reddit-Foodforthought': 'essays',
                'reddit-TrueReddit': 'analysis',
                'reddit-indepthstories': 'investigative'
            },

            # Technology subcategories
            'technology': {
                'hackernews': 'tech-news',
                'reddit-programming': 'development',
                'reddit-gadgets': 'hardware'
            },

            # Science subcategories
            'science': {
                'reddit-science': 'research',
                'reddit-space': 'astronomy',
                'wikipedia': 'education'
            },

            # YouTube subcategories
            'youtube': {
                'youtube-documentaries': 'documentaries',
                'youtube-essays': 'video-essays',
                'youtube-nature': 'nature'
            }
        }

        # Find items that need bfSubcategory population
        items_to_update = []
        stats = defaultdict(int)

        # Query by bfCategory to use GSI efficiently
        for bf_category, source_mapping in subcategory_mapping.items():
            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                FilterExpression='attribute_not_exists(bfSubcategory) OR bfSubcategory = :empty',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': {'S': bf_category},
                    ':status': {'S': 'active'},
                    ':empty': {'S': ''}
                }
            )

            items = response.get('Items', [])

            # Handle pagination
            while 'LastEvaluatedKey' in response:
                response = self.dynamodb.query(
                    TableName=self.table_name,
                    IndexName='category-status-index',
                    KeyConditionExpression='bfCategory = :category AND #status = :status',
                    FilterExpression='attribute_not_exists(bfSubcategory) OR bfSubcategory = :empty',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':category': {'S': bf_category},
                        ':status': {'S': 'active'},
                        ':empty': {'S': ''}
                    },
                    ExclusiveStartKey=response['LastEvaluatedKey']
                )
                items.extend(response.get('Items', []))

            # Process items for this category
            for item in items:
                url = item.get('url', {}).get('S', '')
                source = item.get('source', {}).get('S', '')

                if source in source_mapping:
                    subcategory = source_mapping[source]
                    items_to_update.append({
                        'url': url,
                        'source': source,
                        'bf_category': bf_category,
                        'bf_subcategory': subcategory
                    })
                    stats[f"{bf_category}.{subcategory}"] += 1

        print(f"📊 SUBCATEGORY ASSIGNMENT PLAN:")
        for subcat, count in sorted(stats.items()):
            print(f"   {subcat:<30} {count:,} items")

        total_updates = len(items_to_update)
        print(f"\nTotal items to update: {total_updates:,}")

        if dry_run:
            print("\n✅ DRY RUN COMPLETE - No changes made")
            return {
                'mode': 'dry_run',
                'planned_updates': total_updates,
                'subcategory_stats': dict(stats)
            }

        # Execute updates
        print(f"\n🚀 UPDATING bfSubcategory for {total_updates:,} items...")
        updated_count = 0

        for item in items_to_update:
            try:
                self.dynamodb.update_item(
                    TableName=self.table_name,
                    Key={'url': {'S': item['url']}},
                    UpdateExpression='SET bfSubcategory = :subcategory',
                    ExpressionAttributeValues={
                        ':subcategory': {'S': item['bf_subcategory']}
                    }
                )
                updated_count += 1

                if updated_count % 100 == 0:
                    print(f"   ✅ Updated {updated_count}/{total_updates} items...")

            except Exception as e:
                print(f"   ⚠️  Error updating {item['url']}: {e}")

        print(f"\n✅ bfSubcategory POPULATION COMPLETE: {updated_count:,} items updated")

        return {
            'mode': 'live_update',
            'total_updated': updated_count,
            'subcategory_stats': dict(stats)
        }

    # ========== DATABASE OPERATIONS ==========

    def mark_inactive(self, url: str) -> None:
        """Mark an item as inactive (soft delete)"""
        self.dynamodb.update_item(
            TableName=self.table_name,
            Key={'url': {'S': url}},
            UpdateExpression='SET isActive = :inactive, #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':inactive': {'BOOL': False},
                ':status': {'S': 'inactive'}
            }
        )

    def mark_active(self, url: str) -> None:
        """Mark an item as active"""
        self.dynamodb.update_item(
            TableName=self.table_name,
            Key={'url': {'S': url}},
            UpdateExpression='SET isActive = :active, #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':active': {'BOOL': True},
                ':status': {'S': 'active'}
            }
        )

    def delete_source_completely(self, source: str) -> Dict[str, Any]:
        """Completely delete all items from a source (hard delete)"""
        print(f"🗑️  COMPLETE DELETION: {source}")
        print("=" * 60)

        # Query all items from source
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='source-status-index',
            KeyConditionExpression='#source = :source',
            ExpressionAttributeNames={'#source': 'source'},
            ExpressionAttributeValues={':source': {'S': source}}
        )

        items = response.get('Items', [])

        # Handle pagination if there are more items
        while 'LastEvaluatedKey' in response:
            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='source-status-index',
                KeyConditionExpression='#source = :source',
                ExpressionAttributeNames={'#source': 'source'},
                ExpressionAttributeValues={':source': {'S': source}},
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        total_items = len(items)
        deleted = 0
        failed = 0

        print(f"Found {total_items} items to delete")

        if total_items == 0:
            print("No items found for this source")
            return {
                'source': source,
                'total_items': 0,
                'deleted': 0,
                'failed': 0,
                'success_rate': 0
            }

        # Process in batches for performance
        batch_size = 25  # DynamoDB batch limit
        for i in range(0, len(items), batch_size):
            batch = items[i:i + batch_size]

            # Prepare batch delete request
            request_items = []
            for item in batch:
                url = item.get('url', {}).get('S', '')
                request_items.append({
                    'DeleteRequest': {
                        'Key': {'url': {'S': url}}
                    }
                })

            # Execute batch delete
            try:
                self.dynamodb.batch_write_item(
                    RequestItems={
                        self.table_name: request_items
                    }
                )
                deleted += len(batch)
                print(f"   ✅ Deleted {deleted}/{total_items} items...")

                # Small delay to avoid throttling
                time.sleep(0.1)

            except Exception as e:
                print(f"   ⚠️  Batch delete error: {e}")
                # Fall back to individual deletes for this batch
                for item in batch:
                    url = item.get('url', {}).get('S', '')
                    try:
                        self.dynamodb.delete_item(
                            TableName=self.table_name,
                            Key={'url': {'S': url}}
                        )
                        deleted += 1
                    except Exception as individual_error:
                        print(f"   ❌ Failed to delete {url}: {individual_error}")
                        failed += 1

        print(f"\n✅ COMPLETE DELETION FINISHED")
        print(f"   Source: {source}")
        print(f"   Total items: {total_items}")
        print(f"   Successfully deleted: {deleted}")
        print(f"   Failed: {failed}")

        return {
            'source': source,
            'total_items': total_items,
            'deleted': deleted,
            'failed': failed,
            'success_rate': deleted / total_items if total_items > 0 else 0
        }

    # ========== API INTEGRATION METHODS ==========

    # Future Content Categories (Planned for Implementation):
    # - couches: Furniture and interior design content focused on seating and living spaces

    def integrate_letterboxd(self, limit: int = 100) -> Dict[str, Any]:
        """Integrate Letterboxd movie reviews and lists via web scraping"""
        print("🎬 LETTERBOXD API INTEGRATION")
        print("=" * 60)

        added_count = 0
        errors = 0

        # Letterboxd lists to scrape
        lists_to_scrape = [
            'https://letterboxd.com/films/popular/this/week/',
            'https://letterboxd.com/films/popular/this/month/',
            'https://letterboxd.com/films/by/rating/',
            'https://letterboxd.com/films/ajax/popular/size/small/page/1/'
        ]

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }

        for list_url in lists_to_scrape:
            if added_count >= limit:
                break

            try:
                print(f"📡 Fetching: {list_url}")
                response = requests.get(list_url, headers=headers, timeout=10)
                response.raise_for_status()

                soup = BeautifulSoup(response.content, 'html.parser')

                # Find film posters/links
                film_links = soup.find_all('div', class_='film-poster')

                for film_div in film_links[:20]:  # Limit per list
                    if added_count >= limit:
                        break

                    try:
                        # Extract film data
                        film_link = film_div.find('a')
                        if not film_link:
                            continue

                        film_url = 'https://letterboxd.com' + film_link.get('href')
                        film_title = film_link.get('data-film-name', 'Unknown Film')

                        # Get additional metadata
                        img_tag = film_div.find('img')
                        poster_url = img_tag.get('src') if img_tag else None

                        # Create DynamoDB item
                        item = {
                            'url': {'S': film_url},
                            'title': {'S': f"{film_title} - Letterboxd"},
                            'source': {'S': 'letterboxd'},
                            'bfCategory': {'S': 'movies'},
                            'contentType': {'S': 'review'},
                            'status': {'S': 'active'},
                            'isActive': {'BOOL': True},
                            'dateAdded': {'S': datetime.now().isoformat()},
                            'qualityScore': {'N': '75'},  # Default high score for curated content
                            'tags': {'SS': ['letterboxd', 'movies', 'reviews', 'film']}
                        }

                        if poster_url:
                            item['thumbnailUrl'] = {'S': poster_url}

                        # Add to DynamoDB
                        self._add_item_to_db(item)
                        added_count += 1
                        print(f"   ✅ Added: {film_title}")

                        # Rate limiting
                        time.sleep(0.5)

                    except Exception as e:
                        errors += 1
                        print(f"   ⚠️  Error processing film: {e}")

            except Exception as e:
                errors += 1
                print(f"   ❌ Error fetching {list_url}: {e}")

            # Rate limiting between lists
            time.sleep(2)

        print(f"\n✅ Letterboxd integration complete: {added_count} items added, {errors} errors")

        return {
            'source': 'letterboxd',
            'items_added': added_count,
            'errors': errors,
            'status': 'completed'
        }

    def integrate_medium(self, limit: int = 100) -> Dict[str, Any]:
        """Integrate Medium articles via RSS feeds and scraping"""
        print("📝 MEDIUM API INTEGRATION")
        print("=" * 60)

        added_count = 0
        errors = 0

        # Medium topic RSS feeds (high-quality topics for your audience)
        medium_feeds = [
            'https://medium.com/feed/topic/technology',
            'https://medium.com/feed/topic/design',
            'https://medium.com/feed/topic/startup',
            'https://medium.com/feed/topic/culture',
            'https://medium.com/feed/topic/programming',
            'https://medium.com/feed/topic/architecture'
        ]

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }

        for feed_url in medium_feeds:
            if added_count >= limit:
                break

            try:
                print(f"📡 Fetching: {feed_url}")
                response = requests.get(feed_url, headers=headers, timeout=10)
                response.raise_for_status()

                # Parse RSS XML
                soup = BeautifulSoup(response.content, 'xml')
                items = soup.find_all('item')

                for item in items[:15]:  # Limit per feed
                    if added_count >= limit:
                        break

                    try:
                        title = item.find('title').text.strip()
                        link = item.find('link').text.strip()
                        description = item.find('description').text.strip() if item.find('description') else ''
                        pub_date = item.find('pubDate').text.strip() if item.find('pubDate') else ''
                        creator = item.find('dc:creator').text.strip() if item.find('dc:creator') else 'Unknown'

                        # Extract category from feed URL
                        category = feed_url.split('/')[-1]

                        # Create DynamoDB item
                        db_item = {
                            'url': {'S': link},
                            'title': {'S': title},
                            'source': {'S': 'medium'},
                            'bfCategory': {'S': 'articles'},
                            'contentType': {'S': 'article'},
                            'status': {'S': 'active'},
                            'isActive': {'BOOL': True},
                            'dateAdded': {'S': datetime.now().isoformat()},
                            'author': {'S': creator},
                            'qualityScore': {'N': '70'},  # Default good score for Medium
                            'tags': {'SS': ['medium', 'articles', category, 'longform']}
                        }

                        if description:
                            # Clean description (remove HTML)
                            clean_desc = BeautifulSoup(description, 'html.parser').get_text()[:500]
                            db_item['aiSummary'] = {'S': clean_desc}

                            # Estimate word count
                            word_count = len(clean_desc.split()) * 3  # Rough estimate
                            db_item['wordCount'] = {'N': str(word_count)}
                            db_item['readingTime'] = {'N': str(max(1, word_count // 200))}

                        # Add to DynamoDB
                        self._add_item_to_db(db_item)
                        added_count += 1
                        print(f"   ✅ Added: {title[:50]}...")

                        time.sleep(0.3)  # Rate limiting

                    except Exception as e:
                        errors += 1
                        print(f"   ⚠️  Error processing article: {e}")

            except Exception as e:
                errors += 1
                print(f"   ❌ Error fetching {feed_url}: {e}")

            time.sleep(1)  # Rate limiting between feeds

        print(f"\n✅ Medium integration complete: {added_count} items added, {errors} errors")

        return {
            'source': 'medium',
            'items_added': added_count,
            'errors': errors,
            'status': 'completed'
        }

    def integrate_designboom(self, limit: int = 100) -> Dict[str, Any]:
        """Integrate Designboom architecture and design content"""
        print("🏗️ DESIGNBOOM API INTEGRATION")
        print("=" * 60)

        added_count = 0
        errors = 0

        # Designboom category pages
        designboom_urls = [
            'https://www.designboom.com/architecture/',
            'https://www.designboom.com/design/',
            'https://www.designboom.com/art/',
            'https://www.designboom.com/technology/'
        ]

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }

        for category_url in designboom_urls:
            if added_count >= limit:
                break

            try:
                print(f"📡 Fetching: {category_url}")
                response = requests.get(category_url, headers=headers, timeout=10)
                response.raise_for_status()

                soup = BeautifulSoup(response.content, 'html.parser')

                # Find article links (Designboom structure)
                articles = soup.find_all('article', class_='post')

                for article in articles[:20]:  # Limit per category
                    if added_count >= limit:
                        break

                    try:
                        # Extract article data
                        title_link = article.find('h2', class_='entry-title').find('a')
                        if not title_link:
                            continue

                        title = title_link.text.strip()
                        article_url = title_link.get('href')

                        # Get thumbnail
                        img_tag = article.find('img')
                        thumbnail = img_tag.get('src') if img_tag else None

                        # Get excerpt
                        excerpt_div = article.find('div', class_='entry-excerpt')
                        excerpt = excerpt_div.text.strip() if excerpt_div else ''

                        # Extract category from URL
                        category = category_url.split('/')[-2]

                        # Create DynamoDB item
                        item = {
                            'url': {'S': article_url},
                            'title': {'S': title},
                            'source': {'S': 'designboom'},
                            'bfCategory': {'S': 'design'},
                            'contentType': {'S': 'article'},
                            'status': {'S': 'active'},
                            'isActive': {'BOOL': True},
                            'dateAdded': {'S': datetime.now().isoformat()},
                            'qualityScore': {'N': '80'},  # High score for design content
                            'tags': {'SS': ['designboom', 'design', category, 'architecture', 'creative']}
                        }

                        if thumbnail:
                            item['thumbnailUrl'] = {'S': thumbnail}

                        if excerpt:
                            item['aiSummary'] = {'S': excerpt[:300]}
                            word_count = len(excerpt.split()) * 4  # Estimate full article
                            item['wordCount'] = {'N': str(word_count)}
                            item['readingTime'] = {'N': str(max(2, word_count // 200))}

                        # Add to DynamoDB
                        self._add_item_to_db(item)
                        added_count += 1
                        print(f"   ✅ Added: {title[:50]}...")

                        time.sleep(0.5)  # Rate limiting

                    except Exception as e:
                        errors += 1
                        print(f"   ⚠️  Error processing article: {e}")

            except Exception as e:
                errors += 1
                print(f"   ❌ Error fetching {category_url}: {e}")

            time.sleep(2)  # Rate limiting between categories

        print(f"\n✅ Designboom integration complete: {added_count} items added, {errors} errors")

        return {
            'source': 'designboom',
            'items_added': added_count,
            'errors': errors,
            'status': 'completed'
        }

    def integrate_youtube_subcategories(self, limit: int = 100) -> Dict[str, Any]:
        """Integrate YouTube subcategories: documentaries, video essays, nature"""
        print("🎥 YOUTUBE SUBCATEGORIES INTEGRATION")
        print("=" * 60)

        # Note: This requires YouTube Data API key
        # For now, using search terms that would work with the API

        subcategories = {
            'documentaries': [
                'documentary film', 'nature documentary', 'history documentary',
                'science documentary', 'art documentary'
            ],
            'video-essays': [
                'video essay', 'film analysis', 'culture analysis',
                'design breakdown', 'architecture explained'
            ],
            'nature': [
                'nature footage', 'wildlife documentary', 'natural wonders',
                'landscape timelapse', 'ocean documentary'
            ]
        }

        print("⚠️  YouTube Data API integration framework ready")
        print("🔑 Required: YouTube Data API key in environment variables")
        print("\n📋 Categories prepared for integration:")

        total_terms = 0
        for category, terms in subcategories.items():
            print(f"\n🎯 {category.upper()}:")
            for term in terms:
                print(f"   • {term}")
                total_terms += 1

        print(f"\n✅ YouTube subcategories framework ready: {total_terms} search terms prepared")
        print("💡 Next step: Add YouTube Data API key and implement actual fetching")

        return {
            'source': 'youtube-subcategories',
            'categories_prepared': len(subcategories),
            'search_terms': total_terms,
            'status': 'framework_ready'
        }

    def _add_item_to_db(self, item: Dict[str, Any]) -> None:
        """Add item to DynamoDB with error handling"""
        try:
            self.dynamodb.put_item(
                TableName=self.table_name,
                Item=item,
                ConditionExpression='attribute_not_exists(#url)',
                ExpressionAttributeNames={'#url': 'url'}
            )
        except self.dynamodb.exceptions.ConditionalCheckFailedException:
            # Item already exists, skip
            pass
        except Exception as e:
            print(f"   ⚠️  Error adding item to DB: {e}")
            raise

    def get_all_categories_for_api(self, active_only: bool = True) -> List[str]:
        """
        Get all distinct categories for API consumption
        This method should be used by the Vercel API instead of hardcoded categories

        Args:
            active_only: If True, only return categories that have active content

        Returns:
            List of category names sorted alphabetically
        """
        try:
            categories = set()

            if active_only:
                # Use paginator to handle large datasets efficiently
                paginator = self.dynamodb.get_paginator('scan')
                page_iterator = paginator.paginate(
                    TableName=self.table_name,
                    FilterExpression='attribute_exists(bfCategory) AND #status = :status',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={':status': {'S': 'active'}},
                    ProjectionExpression='bfCategory'
                )
            else:
                # Get all categories regardless of status
                paginator = self.dynamodb.get_paginator('scan')
                page_iterator = paginator.paginate(
                    TableName=self.table_name,
                    FilterExpression='attribute_exists(bfCategory)',
                    ProjectionExpression='bfCategory'
                )

            for page in page_iterator:
                for item in page.get('Items', []):
                    bf_category = item.get('bfCategory', {}).get('S')
                    if bf_category:
                        categories.add(bf_category)

            return sorted(list(categories))

        except Exception as e:
            print(f"❌ Error getting categories for API: {e}")
            # Fallback to known categories if query fails
            return [
                'art', 'books', 'culture', 'food', 'history',
                'movies', 'science', 'technology', 'webgames',
                'wikipedia', 'youtube'
            ]

    def get_categories_with_counts_for_api(self) -> Dict[str, int]:
        """
        Get categories with their active item counts for API consumption

        Returns:
            Dictionary mapping category names to their active item counts
        """
        try:
            category_counts = defaultdict(int)

            paginator = self.dynamodb.get_paginator('scan')
            page_iterator = paginator.paginate(
                TableName=self.table_name,
                FilterExpression='attribute_exists(bfCategory) AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':status': {'S': 'active'}},
                ProjectionExpression='bfCategory'
            )

            for page in page_iterator:
                for item in page.get('Items', []):
                    bf_category = item.get('bfCategory', {}).get('S')
                    if bf_category:
                        category_counts[bf_category] += 1

            return dict(category_counts)

        except Exception as e:
            print(f"❌ Error getting category counts for API: {e}")
            return {}

    def update_webgames_category(self, dry_run: bool = True) -> Dict[str, Any]:
        """
        Update all webgames items to change bfCategory from 'webgames' to 'games'
        to match iOS app expectations

        Args:
            dry_run: If True, shows what would be updated without making changes

        Returns:
            Dictionary with update statistics
        """
        print("🎮 UPDATING WEBGAMES CATEGORY: 'webgames' → 'games'")
        print("=" * 60)
        print(f"Mode: {'DRY RUN' if dry_run else 'LIVE UPDATE'}")
        print()

        # Query all items with bfCategory = 'webgames'
        response = self.dynamodb.query(
            TableName=self.table_name,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category',
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'}
            }
        )

        items = response.get('Items', [])

        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = self.dynamodb.query(
                TableName=self.table_name,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category',
                ExpressionAttributeValues={
                    ':category': {'S': 'webgames'}
                },
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        total_items = len(items)
        print(f"🔍 Found {total_items:,} items with bfCategory='webgames'")

        if total_items == 0:
            print("✅ No items found with bfCategory='webgames' - nothing to update")
            return {
                'total_found': 0,
                'updated': 0,
                'active_games': 0,
                'inactive_games': 0
            }

        # Analyze current status distribution
        status_counts = defaultdict(int)
        active_games = []
        inactive_games = []

        for item in items:
            status = item.get('status', {}).get('S', 'unknown')
            status_counts[status] += 1

            url = item.get('url', {}).get('S', '')
            title = item.get('title', {}).get('S', 'No Title')

            if status == 'active':
                active_games.append({'url': url, 'title': title})
            else:
                inactive_games.append({'url': url, 'title': title, 'status': status})

        print(f"\n📊 CURRENT STATUS DISTRIBUTION:")
        for status, count in sorted(status_counts.items()):
            percentage = (count / total_items) * 100
            print(f"   {status:<15} {count:4,} items ({percentage:5.1f}%)")

        print(f"\n🎯 ACTIVE WEBGAMES (currently not showing in iOS app):")
        for i, game in enumerate(active_games[:10], 1):  # Show first 10
            title_short = game['title'][:70] + "..." if len(game['title']) > 70 else game['title']
            print(f"   {i:2d}. {title_short}")

        if len(active_games) > 10:
            print(f"   ... and {len(active_games) - 10} more active games")

        if dry_run:
            print(f"\n✅ DRY RUN COMPLETE")
            print(f"💡 Would update {total_items:,} items from 'webgames' to 'games'")
            print(f"🎮 {len(active_games)} active games would become visible in iOS app")
            print("🚀 Run with --live flag to execute the update")
            return {
                'mode': 'dry_run',
                'total_found': total_items,
                'would_update': total_items,
                'active_games': len(active_games),
                'inactive_games': len(inactive_games),
                'status_distribution': dict(status_counts)
            }

        # Execute the update
        print(f"\n🚀 EXECUTING UPDATE: {total_items:,} items...")
        updated_count = 0
        failed_count = 0

        # Process in batches for better performance
        batch_size = 25
        for i in range(0, len(items), batch_size):
            batch = items[i:i + batch_size]

            for item in batch:
                url = item.get('url', {}).get('S', '')
                try:
                    # Update bfCategory from 'webgames' to 'games'
                    self.dynamodb.update_item(
                        TableName=self.table_name,
                        Key={'url': {'S': url}},
                        UpdateExpression='SET bfCategory = :new_category',
                        ExpressionAttributeValues={
                            ':new_category': {'S': 'games'}
                        },
                        ConditionExpression='bfCategory = :old_category',
                        ExpressionAttributeNames={},
                        ReturnValues='NONE'
                    )
                    updated_count += 1

                except Exception as e:
                    failed_count += 1
                    print(f"   ⚠️  Failed to update {url}: {e}")

            # Progress update
            if updated_count % 100 == 0 or updated_count + failed_count == total_items:
                print(f"   ✅ Progress: {updated_count}/{total_items} updated, {failed_count} failed")

            # Small delay to avoid throttling
            time.sleep(0.1)

        success_rate = (updated_count / total_items * 100) if total_items > 0 else 0

        print(f"\n🎉 UPDATE COMPLETE!")
        print(f"   📊 Total items found: {total_items:,}")
        print(f"   ✅ Successfully updated: {updated_count:,}")
        print(f"   ❌ Failed updates: {failed_count:,}")
        print(f"   📈 Success rate: {success_rate:.1f}%")
        print(f"   🎮 Active games now visible in iOS: {len(active_games):,}")

        if updated_count > 0:
            print(f"\n💡 iOS app should now show webgames in 'games' category")
            print(f"🔄 You may need to refresh the app to see the changes")

        return {
            'mode': 'live_update',
            'total_found': total_items,
            'successfully_updated': updated_count,
            'failed_updates': failed_count,
            'success_rate': success_rate,
            'active_games': len(active_games),
            'inactive_games': len(inactive_games),
            'status_distribution': dict(status_counts)
        }

# ========== CLI INTERFACE ==========

def main():
    """Command-line interface for bf-db agent"""
    parser = argparse.ArgumentParser(description='BrowseForward Database Management Agent')

    # Command selection
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Analysis commands
    analyze_parser = subparsers.add_parser('analyze-source', help='Analyze a content source')
    analyze_parser.add_argument('source', help='Source name (e.g., reddit-movies)')

    category_parser = subparsers.add_parser('analyze-category', help='Analyze sources within a category')
    category_parser.add_argument('category', help='Category name (e.g., long-reads)')
    category_parser.add_argument('--limit', type=int, help='Limit number of items analyzed')

    stats_parser = subparsers.add_parser('content-stats', help='Database content statistics')

    # Sample URLs command
    sample_parser = subparsers.add_parser('sample-urls', help='Get sample URLs from a source')
    sample_parser.add_argument('source', help='Source name (e.g., google-books-to-goodreads)')
    sample_parser.add_argument('--limit', type=int, default=5, help='Number of URLs to retrieve')

    # URL pattern analysis command
    pattern_parser = subparsers.add_parser('analyze-url-patterns', help='Analyze URL patterns for conversion feasibility')
    pattern_parser.add_argument('source', help='Source name (e.g., google-books-to-goodreads)')
    pattern_parser.add_argument('--limit', type=int, default=10, help='Number of URLs to analyze')

    # Bulk inactivation command
    bulk_inactive_parser = subparsers.add_parser('mark-source-inactive', help='Mark entire source as inactive')
    bulk_inactive_parser.add_argument('source', help='Source name to mark inactive')

    # Bulk deletion command
    bulk_delete_parser = subparsers.add_parser('delete-source-completely', help='Completely delete entire source')
    bulk_delete_parser.add_argument('source', help='Source name to completely delete')

    # Cleanup commands
    reddit_parser = subparsers.add_parser('cleanup-reddit', help='Clean Reddit sources')
    reddit_parser.add_argument('--source', help='Specific Reddit source', default=None)

    games_parser = subparsers.add_parser('cleanup-webgames', help='Find mobile-friendly games')

    archive_parser = subparsers.add_parser('cleanup-archive', help='Clean Internet Archive')
    archive_parser.add_argument('--type', help='Archive type (culture/art/history/science/tech)')

    # Metadata commands
    metadata_parser = subparsers.add_parser('generate-metadata', help='Generate metadata')
    metadata_parser.add_argument('--source', help='Specific source', default=None)
    metadata_parser.add_argument('--limit', type=int, default=100, help='Items to process')

    # BrowseForward optimization commands
    bf_analyze_parser = subparsers.add_parser('analyze-bf-categories', help='Analyze bfCategory population')

    bf_api_parser = subparsers.add_parser('get-api-categories', help='Get all categories for API use')
    bf_api_parser.add_argument('--include-inactive', action='store_true', help='Include categories without active content')

    bf_populate_parser = subparsers.add_parser('populate-bf-categories', help='Bulk populate bfCategory fields')
    bf_populate_parser.add_argument('--dry-run', action='store_true', default=True, help='Dry run mode (default)')
    bf_populate_parser.add_argument('--live', action='store_true', help='Execute live updates')

    bf_subcategory_parser = subparsers.add_parser('populate-bf-subcategories', help='Populate bfSubcategory fields')
    bf_subcategory_parser.add_argument('--dry-run', action='store_true', default=True, help='Dry run mode (default)')
    bf_subcategory_parser.add_argument('--live', action='store_true', help='Execute live updates')

    gsi_optimize_parser = subparsers.add_parser('optimize-gsi-queries', help='Analyze GSI query performance')

    # Webgames category update command
    webgames_update_parser = subparsers.add_parser('update-webgames-category', help='Update webgames bfCategory from "webgames" to "games"')
    webgames_update_parser.add_argument('--dry-run', action='store_true', default=True, help='Dry run mode (default)')
    webgames_update_parser.add_argument('--live', action='store_true', help='Execute live updates')

    # API integration commands
    letterboxd_parser = subparsers.add_parser('integrate-letterboxd', help='Integrate Letterboxd content')
    letterboxd_parser.add_argument('--limit', type=int, default=100, help='Items to process')

    medium_parser = subparsers.add_parser('integrate-medium', help='Integrate Medium articles')
    medium_parser.add_argument('--limit', type=int, default=100, help='Items to process')

    designboom_parser = subparsers.add_parser('integrate-designboom', help='Integrate Designboom content')
    designboom_parser.add_argument('--limit', type=int, default=100, help='Items to process')

    youtube_parser = subparsers.add_parser('integrate-youtube-subcategories', help='Integrate YouTube subcategories')
    youtube_parser.add_argument('--limit', type=int, default=100, help='Items to process')

    args = parser.parse_args()

    # Initialize agent
    agent = BrowseForwardDB()

    # Execute command
    if args.command == 'analyze-source':
        agent.analyze_source(args.source)
    elif args.command == 'analyze-category':
        agent.analyze_category_sources(args.category, args.limit)
    elif args.command == 'content-stats':
        agent.content_stats()
    elif args.command == 'sample-urls':
        agent.get_sample_urls(args.source, args.limit)
    elif args.command == 'analyze-url-patterns':
        agent.analyze_url_patterns(args.source, args.limit)
    elif args.command == 'mark-source-inactive':
        agent.mark_source_inactive(args.source)
    elif args.command == 'delete-source-completely':
        agent.delete_source_completely(args.source)
    elif args.command == 'cleanup-reddit':
        agent.cleanup_reddit(args.source)
    elif args.command == 'cleanup-webgames':
        agent.cleanup_webgames()
    elif args.command == 'cleanup-archive':
        agent.cleanup_archive(args.type)
    elif args.command == 'generate-metadata':
        agent.generate_metadata(args.source, args.limit)
    elif args.command == 'analyze-bf-categories':
        agent.analyze_bf_category_population()
    elif args.command == 'get-api-categories':
        active_only = not args.include_inactive
        categories = agent.get_all_categories_for_api(active_only=active_only)
        category_counts = agent.get_categories_with_counts_for_api()

        print("🚀 CATEGORIES FOR API CONSUMPTION")
        print("=" * 60)
        print(f"Active content only: {active_only}")
        print(f"Total categories: {len(categories)}")
        print()

        print("📋 Categories list (JSON format for API):")
        print(json.dumps({"categories": categories}, indent=2))

        if category_counts:
            print("\n📊 Category counts (active content only):")
            for category in categories:
                count = category_counts.get(category, 0)
                print(f"   {category:<15} {count:,} items")

        print("\n💡 Implementation note:")
        print("Replace hardcoded categories in Vercel API with this query result")

    elif args.command == 'populate-bf-categories':
        dry_run = not args.live if hasattr(args, 'live') else True
        agent.bulk_populate_bf_categories(dry_run=dry_run)
    elif args.command == 'populate-bf-subcategories':
        dry_run = not args.live if hasattr(args, 'live') else True
        agent.populate_bf_subcategories(dry_run=dry_run)
    elif args.command == 'optimize-gsi-queries':
        agent.optimize_gsi_queries()
    elif args.command == 'integrate-letterboxd':
        agent.integrate_letterboxd(args.limit)
    elif args.command == 'integrate-medium':
        agent.integrate_medium(args.limit)
    elif args.command == 'integrate-designboom':
        agent.integrate_designboom(args.limit)
    elif args.command == 'integrate-youtube-subcategories':
        agent.integrate_youtube_subcategories(args.limit)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()