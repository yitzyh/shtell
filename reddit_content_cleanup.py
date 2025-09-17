#!/usr/bin/env python3
"""
Reddit Content Cleanup System
============================

Intelligent cleanup system for Reddit sources in DumFlow's database.
Focuses on removing outdated content while preserving high-quality timeless articles.

Target Sources for Cleanup:
- reddit-movies (231 items) - remove outdated reviews
- reddit-gadgets (277 items) - remove outdated tech content
- reddit-space (125 items) - filter for timeless content
- reddit-psychology (166 items) - keep quality articles only
- reddit-TrueReddit (269 items) - light cleanup, already good quality
- reddit-longreads (212 items) - perfect for audience, light cleanup

Author: Claude Code
Version: 1.0.0
"""

import boto3
import json
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Tuple, Any
import re

# Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

# Quality thresholds for each subreddit
CLEANUP_RULES = {
    "reddit-movies": {
        "aggressive": True,
        "min_upvotes": 50,
        "max_age_days": 365,
        "keywords_to_remove": [
            "trailer", "first look", "teaser", "poster", "box office", "weekend",
            "opening", "just watched", "discussion", "megathread", "oscar", "2020", "2021", "2022", "2023"
        ],
        "keywords_to_keep": [
            "analysis", "essay", "history", "criterion", "classic", "retrospective",
            "influence", "legacy", "masterpiece", "cinema", "auteur", "technique"
        ],
        "description": "Remove outdated movie news and reviews, keep film analysis"
    },
    "reddit-gadgets": {
        "aggressive": True,
        "min_upvotes": 30,
        "max_age_days": 180,
        "keywords_to_remove": [
            "rumor", "leak", "specs", "price", "release", "launch", "hands-on",
            "first look", "review", "unboxing", "deal", "sale", "discount", "iphone", "samsung"
        ],
        "keywords_to_keep": [
            "history", "evolution", "impact", "analysis", "retrospective",
            "technology", "innovation", "breakthrough", "study", "research"
        ],
        "description": "Remove outdated gadget news and reviews, keep tech analysis"
    },
    "reddit-space": {
        "moderate": True,
        "min_upvotes": 20,
        "max_age_days": 730,
        "keywords_to_remove": [
            "news", "today", "just", "breaking", "update", "launch", "mission",
            "iss", "spacex", "nasa announcement", "press conference"
        ],
        "keywords_to_keep": [
            "science", "discovery", "theory", "physics", "astronomy", "cosmology",
            "research", "study", "analysis", "history", "formation", "evolution"
        ],
        "description": "Filter space news, keep scientific content and discoveries"
    },
    "reddit-psychology": {
        "moderate": True,
        "min_upvotes": 25,
        "max_age_days": 1095,  # 3 years - psychology content ages well
        "keywords_to_remove": [
            "study shows", "new research", "researchers find", "according to",
            "breaking", "news", "just published"
        ],
        "keywords_to_keep": [
            "analysis", "theory", "cognitive", "behavioral", "understanding",
            "insight", "perspective", "framework", "concept", "principle"
        ],
        "description": "Light cleanup, keep quality psychology content"
    },
    "reddit-TrueReddit": {
        "light": True,
        "min_upvotes": 15,
        "max_age_days": 1095,  # Already high quality, minimal cleanup
        "keywords_to_remove": [
            "breaking", "just happened", "today", "this week", "current"
        ],
        "keywords_to_keep": [
            "analysis", "thoughtful", "in-depth", "perspective", "essay",
            "long-form", "investigation", "study", "research", "insight"
        ],
        "description": "Minimal cleanup - already high quality content"
    },
    "reddit-longreads": {
        "light": True,
        "min_upvotes": 10,
        "max_age_days": 1825,  # 5 years - long reads are timeless
        "keywords_to_remove": [
            "news", "breaking", "update", "developing"
        ],
        "keywords_to_keep": [
            "story", "narrative", "profile", "investigation", "history",
            "biography", "memoir", "essay", "analysis", "feature"
        ],
        "description": "Perfect for audience - minimal cleanup only"
    }
}

class RedditContentCleanup:
    """Handles intelligent cleanup of Reddit content"""

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

    def get_reddit_items(self, source: str) -> List[Dict[str, Any]]:
        """Get all items from a Reddit source"""
        try:
            response = self.dynamodb.query(
                TableName=TABLE_NAME,
                IndexName='source-status-index',
                KeyConditionExpression='source = :source',
                ExpressionAttributeValues={':source': {'S': source}},
                ProjectionExpression='#url, title, createdDate, upvotes, #source, #status',
                ExpressionAttributeNames={'#url': 'url', '#source': 'source', '#status': 'status'}
            )

            items = response.get('Items', [])

            # Handle pagination
            while 'LastEvaluatedKey' in response:
                response = self.dynamodb.query(
                    TableName=TABLE_NAME,
                    IndexName='source-status-index',
                    KeyConditionExpression='source = :source',
                    ExpressionAttributeValues={':source': {'S': source}},
                    ProjectionExpression='#url, title, createdDate, upvotes, #source, #status',
                    ExpressionAttributeNames={'#url': 'url', '#source': 'source', '#status': 'status'},
                    ExclusiveStartKey=response['LastEvaluatedKey']
                )
                items.extend(response.get('Items', []))

            return items

        except Exception as e:
            print(f"❌ Error fetching {source}: {e}")
            return []

    def evaluate_item_quality(self, item: Dict[str, Any], rules: Dict[str, Any]) -> Tuple[bool, str]:
        """Evaluate if an item should be kept based on quality rules"""
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', '').lower()
        upvotes = item.get('upvotes', {}).get('N', '0')
        created_date = item.get('createdDate', {}).get('S', '')

        try:
            upvotes = int(upvotes)
        except:
            upvotes = 0

        # Check upvote threshold
        if upvotes < rules['min_upvotes']:
            return False, f"Low upvotes ({upvotes} < {rules['min_upvotes']})"

        # Check age
        if created_date:
            try:
                created = datetime.fromisoformat(created_date.replace('Z', '+00:00'))
                age_days = (datetime.now(timezone.utc) - created).days
                if age_days > rules['max_age_days']:
                    return False, f"Too old ({age_days} days > {rules['max_age_days']})"
            except:
                pass  # Skip age check if date parsing fails

        # Check removal keywords
        for keyword in rules['keywords_to_remove']:
            if keyword in title:
                return False, f"Contains removal keyword: '{keyword}'"

        # Bonus for keep keywords
        keep_score = sum(1 for keyword in rules['keywords_to_keep'] if keyword in title)
        if keep_score > 0:
            return True, f"Contains {keep_score} quality keywords"

        # Default decision based on cleanup level
        if rules.get('aggressive'):
            return False, "Aggressive cleanup - default remove"
        elif rules.get('moderate'):
            return upvotes > rules['min_upvotes'] * 1.5, "Moderate cleanup - higher upvote requirement"
        else:  # light cleanup
            return True, "Light cleanup - default keep"

    def analyze_source(self, source: str, dry_run: bool = True) -> Dict[str, Any]:
        """Analyze a Reddit source for cleanup potential"""
        print(f"\n🔍 ANALYZING: {source}")
        print("=" * 60)

        if source not in CLEANUP_RULES:
            print(f"❌ No cleanup rules defined for {source}")
            return {}

        rules = CLEANUP_RULES[source]
        items = self.get_reddit_items(source)

        if not items:
            print(f"❌ No items found for {source}")
            return {}

        print(f"📊 Found {len(items)} items")
        print(f"🎯 Strategy: {rules['description']}")

        # Analyze each item
        keep_items = []
        remove_items = []

        for item in items:
            should_keep, reason = self.evaluate_item_quality(item, rules)

            if should_keep:
                keep_items.append((item, reason))
            else:
                remove_items.append((item, reason))

        # Generate statistics
        stats = {
            'source': source,
            'total_items': len(items),
            'keep_count': len(keep_items),
            'remove_count': len(remove_items),
            'removal_percentage': len(remove_items) / len(items) * 100 if items else 0,
            'keep_items': keep_items,
            'remove_items': remove_items
        }

        print(f"\n📊 ANALYSIS RESULTS:")
        print(f"  📈 Total items: {stats['total_items']}")
        print(f"  ✅ Keep: {stats['keep_count']} ({100-stats['removal_percentage']:.1f}%)")
        print(f"  🗑️  Remove: {stats['remove_count']} ({stats['removal_percentage']:.1f}%)")

        # Show sample items to remove
        print(f"\n🗑️  TOP 5 ITEMS TO REMOVE:")
        for i, (item, reason) in enumerate(remove_items[:5]):
            title = item.get('title', {}).get('S', '')[:50]
            upvotes = item.get('upvotes', {}).get('N', '0')
            print(f"  {i+1}. {title}... (↑{upvotes}) - {reason}")

        # Show sample items to keep
        print(f"\n✅ TOP 5 ITEMS TO KEEP:")
        for i, (item, reason) in enumerate(keep_items[:5]):
            title = item.get('title', {}).get('S', '')[:50]
            upvotes = item.get('upvotes', {}).get('N', '0')
            print(f"  {i+1}. {title}... (↑{upvotes}) - {reason}")

        return stats

    def execute_cleanup(self, source: str, stats: Dict[str, Any]) -> Tuple[int, int]:
        """Execute the actual cleanup for a source"""
        if not stats or stats['remove_count'] == 0:
            print(f"✅ No items to remove for {source}")
            return 0, 0

        print(f"\n🧹 EXECUTING CLEANUP: {source}")
        print(f"🗑️  Removing {stats['remove_count']} items...")

        success_count = 0
        error_count = 0

        # Remove items in batches
        for item, reason in stats['remove_items']:
            try:
                url = item.get('url', {}).get('S', '')
                self.table.delete_item(Key={'url': url})
                success_count += 1

                if success_count % 10 == 0:
                    print(f"  🗑️  Removed {success_count}/{stats['remove_count']} items...")

            except Exception as e:
                print(f"  ❌ Error removing item: {e}")
                error_count += 1

        print(f"✅ Cleanup completed: {success_count} removed, {error_count} errors")
        return success_count, error_count

    def run_full_analysis(self) -> Dict[str, Any]:
        """Run analysis on all Reddit sources"""
        print("🤖 REDDIT CONTENT CLEANUP ANALYSIS")
        print("=" * 70)
        print("Analyzing Reddit sources for intelligent content cleanup...")

        all_stats = {}
        total_items = 0
        total_removals = 0

        for source in CLEANUP_RULES.keys():
            stats = self.analyze_source(source, dry_run=True)
            if stats:
                all_stats[source] = stats
                total_items += stats['total_items']
                total_removals += stats['remove_count']

        print(f"\n📊 OVERALL ANALYSIS SUMMARY:")
        print("=" * 50)
        print(f"📈 Total Reddit items analyzed: {total_items}")
        print(f"🗑️  Total items marked for removal: {total_removals}")
        print(f"📉 Overall removal percentage: {total_removals/total_items*100:.1f}%")
        print(f"✅ Items to keep: {total_items - total_removals}")

        print(f"\n📊 BY SOURCE:")
        for source, stats in all_stats.items():
            print(f"  {source:20} | Remove: {stats['remove_count']:3d} ({stats['removal_percentage']:4.1f}%) | Keep: {stats['keep_count']:3d}")

        return all_stats

    def run_cleanup_batch(self, sources: List[str] = None) -> Dict[str, Any]:
        """Run cleanup on specified sources or all sources"""
        if sources is None:
            sources = list(CLEANUP_RULES.keys())

        print(f"\n🧹 EXECUTING REDDIT CLEANUP BATCH")
        print("=" * 50)

        results = {}
        total_removed = 0
        total_errors = 0

        for source in sources:
            print(f"\n📍 Processing: {source}")

            # First analyze
            stats = self.analyze_source(source, dry_run=True)

            if stats and stats['remove_count'] > 0:
                # Confirm before cleanup
                confirm = input(f"Remove {stats['remove_count']} items from {source}? (y/N): ")
                if confirm.lower() == 'y':
                    removed, errors = self.execute_cleanup(source, stats)
                    results[source] = {
                        'analyzed': stats['total_items'],
                        'removed': removed,
                        'errors': errors,
                        'kept': stats['keep_count']
                    }
                    total_removed += removed
                    total_errors += errors
                else:
                    print(f"❌ Skipped cleanup for {source}")
                    results[source] = {'skipped': True}
            else:
                results[source] = {'no_cleanup_needed': True}

        print(f"\n✅ CLEANUP BATCH COMPLETED")
        print(f"📊 Total items removed: {total_removed}")
        print(f"❌ Total errors: {total_errors}")

        return results

def main():
    """Main execution function"""
    cleanup = RedditContentCleanup()

    print("🤖 REDDIT CONTENT CLEANUP SYSTEM")
    print("=" * 50)
    print("Choose an option:")
    print("1. Analyze all Reddit sources (dry run)")
    print("2. Execute cleanup on specific sources")
    print("3. Execute full cleanup (all sources)")
    print("4. Show cleanup rules")

    choice = input("\nEnter choice (1-4): ").strip()

    if choice == '1':
        cleanup.run_full_analysis()

    elif choice == '2':
        print("\nAvailable sources:")
        for i, source in enumerate(CLEANUP_RULES.keys(), 1):
            print(f"  {i}. {source}")

        selected = input("\nEnter source numbers (comma-separated): ").strip()
        try:
            indices = [int(x.strip()) - 1 for x in selected.split(',')]
            sources = [list(CLEANUP_RULES.keys())[i] for i in indices if 0 <= i < len(CLEANUP_RULES)]
            cleanup.run_cleanup_batch(sources)
        except:
            print("❌ Invalid selection")

    elif choice == '3':
        print("⚠️  This will execute cleanup on ALL Reddit sources!")
        confirm = input("Are you sure? (yes/NO): ").strip()
        if confirm.lower() == 'yes':
            cleanup.run_cleanup_batch()
        else:
            print("❌ Cancelled")

    elif choice == '4':
        print("\n📋 CLEANUP RULES:")
        for source, rules in CLEANUP_RULES.items():
            print(f"\n{source}:")
            print(f"  Strategy: {rules['description']}")
            print(f"  Min upvotes: {rules['min_upvotes']}")
            print(f"  Max age: {rules['max_age_days']} days")
            print(f"  Remove keywords: {len(rules['keywords_to_remove'])} items")
            print(f"  Keep keywords: {len(rules['keywords_to_keep'])} items")

    else:
        print("❌ Invalid choice")

if __name__ == "__main__":
    main()