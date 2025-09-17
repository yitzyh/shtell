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
            KeyConditionExpression='bfCategory = :category',
            ExpressionAttributeValues={':category': {'S': 'webgames'}}
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

# ========== CLI INTERFACE ==========

def main():
    """Command-line interface for bf-db agent"""
    parser = argparse.ArgumentParser(description='BrowseForward Database Management Agent')

    # Command selection
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Analysis commands
    analyze_parser = subparsers.add_parser('analyze-source', help='Analyze a content source')
    analyze_parser.add_argument('source', help='Source name (e.g., reddit-movies)')

    stats_parser = subparsers.add_parser('content-stats', help='Database content statistics')

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

    args = parser.parse_args()

    # Initialize agent
    agent = BrowseForwardDB()

    # Execute command
    if args.command == 'analyze-source':
        agent.analyze_source(args.source)
    elif args.command == 'content-stats':
        agent.content_stats()
    elif args.command == 'cleanup-reddit':
        agent.cleanup_reddit(args.source)
    elif args.command == 'cleanup-webgames':
        agent.cleanup_webgames()
    elif args.command == 'cleanup-archive':
        agent.cleanup_archive(args.type)
    elif args.command == 'generate-metadata':
        agent.generate_metadata(args.source, args.limit)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()