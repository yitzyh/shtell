#!/usr/bin/env python3
"""
Internet Archive Content Quality Filter
======================================

Advanced filtering system for Internet Archive content in DumFlow's database.
Focuses on quality assessment and curation for creative professionals.

Target Collections for Filtering:
- internet-archive-culture (1,673 items) - Arts, literature, cultural content
- internet-archive-art (1,616 items) - Visual arts, galleries, exhibitions
- internet-archive-history (1,664 items) - Historical documents, narratives
- internet-archive-science (1,619 items) - Scientific papers, research
- internet-archive-tech (1,644 items) - Technology history, computing
- internet-archive-books (1,618 items) - Digital books, literature

Author: Claude Code
Version: 1.0.0
Target: Creative professionals (20s-30s) seeking quality long-form content
"""

import boto3
import requests
import json
import re
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Tuple, Any, Optional
from urllib.parse import urlparse, parse_qs
from dataclasses import dataclass
import statistics
import time

# Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

@dataclass
class ArchiveQualityMetrics:
    """Quality metrics for Internet Archive content"""
    url: str
    title: str
    identifier: str
    collection: str
    mediatype: str
    downloads: int
    item_size: int
    language: str
    subject_tags: List[str]
    description_quality: int  # 1-10
    relevance_score: int     # 1-10
    accessibility_score: int # 1-10
    cultural_value: int      # 1-10
    overall_quality: float
    recommended_action: str
    filter_reasons: List[str]

# Quality filtering rules for each collection
ARCHIVE_QUALITY_RULES = {
    "internet-archive-culture": {
        "description": "Arts, literature, and cultural content curation",
        "min_downloads": 100,
        "preferred_mediatypes": ["texts", "movies", "audio", "image"],
        "quality_keywords": [
            "art", "literature", "cultural", "museum", "gallery", "exhibition",
            "poetry", "novel", "classic", "masterpiece", "renowned", "significant",
            "documentary", "interview", "performance", "concert", "opera"
        ],
        "exclude_keywords": [
            "amateur", "personal", "home video", "test", "sample",
            "low quality", "poor audio", "damaged", "incomplete"
        ],
        "language_preferences": ["english", "multiple", "multilingual"],
        "min_description_length": 50,
        "target_subjects": [
            "art", "literature", "music", "theater", "dance", "film",
            "photography", "sculpture", "painting", "poetry", "fiction"
        ]
    },
    "internet-archive-art": {
        "description": "Visual arts and artistic content curation",
        "min_downloads": 50,
        "preferred_mediatypes": ["image", "texts", "movies"],
        "quality_keywords": [
            "painting", "sculpture", "photography", "drawing", "print",
            "exhibition", "gallery", "museum", "artist", "artwork",
            "masterpiece", "collection", "portfolio", "catalog"
        ],
        "exclude_keywords": [
            "amateur", "sketch", "doodle", "personal collection", "family photos",
            "blurry", "poor quality", "damaged scan", "incomplete"
        ],
        "language_preferences": ["english", "multiple", "visual"],
        "min_description_length": 30,
        "target_subjects": [
            "art", "painting", "sculpture", "photography", "drawing",
            "printmaking", "installation", "conceptual art", "abstract art"
        ]
    },
    "internet-archive-history": {
        "description": "Historical documents and narratives",
        "min_downloads": 200,
        "preferred_mediatypes": ["texts", "movies", "audio"],
        "quality_keywords": [
            "historical", "primary source", "archive", "document", "memoir",
            "biography", "chronicle", "account", "witness", "testimony",
            "significant", "important", "landmark", "turning point"
        ],
        "exclude_keywords": [
            "conspiracy", "unverified", "speculation", "rumors",
            "personal opinion", "blog post", "amateur historian"
        ],
        "language_preferences": ["english"],
        "min_description_length": 100,
        "target_subjects": [
            "history", "biography", "memoir", "war", "revolution",
            "social history", "political history", "cultural history"
        ]
    },
    "internet-archive-science": {
        "description": "Scientific research and educational content",
        "min_downloads": 300,
        "preferred_mediatypes": ["texts", "data"],
        "quality_keywords": [
            "research", "study", "analysis", "peer-reviewed", "journal",
            "scientific", "experiment", "methodology", "findings", "discovery",
            "published", "academic", "university", "institute", "laboratory"
        ],
        "exclude_keywords": [
            "pseudoscience", "unproven", "alternative medicine", "conspiracy",
            "debunked", "speculation", "theory" # unless "scientific theory"
        ],
        "language_preferences": ["english"],
        "min_description_length": 80,
        "target_subjects": [
            "science", "research", "physics", "chemistry", "biology",
            "medicine", "technology", "engineering", "mathematics"
        ]
    },
    "internet-archive-tech": {
        "description": "Technology history and computing content",
        "min_downloads": 150,
        "preferred_mediatypes": ["texts", "software", "movies"],
        "quality_keywords": [
            "computer", "software", "technology", "programming", "innovation",
            "historical", "development", "breakthrough", "influential",
            "documentation", "manual", "guide", "technical", "engineering"
        ],
        "exclude_keywords": [
            "pirated", "cracked", "illegal", "virus", "malware",
            "amateur", "hobby project", "incomplete", "broken"
        ],
        "language_preferences": ["english"],
        "min_description_length": 60,
        "target_subjects": [
            "computer science", "software", "hardware", "programming",
            "internet", "computing history", "technology"
        ]
    },
    "internet-archive-books": {
        "description": "Digital books and literature",
        "min_downloads": 500,
        "preferred_mediatypes": ["texts"],
        "quality_keywords": [
            "classic", "literature", "novel", "poetry", "acclaimed",
            "award-winning", "bestseller", "significant", "important",
            "educational", "textbook", "reference", "scholarly"
        ],
        "exclude_keywords": [
            "fanfiction", "amateur", "self-published", "vanity press",
            "poor scan", "incomplete", "damaged", "OCR errors"
        ],
        "language_preferences": ["english"],
        "min_description_length": 100,
        "target_subjects": [
            "literature", "fiction", "poetry", "drama", "classics",
            "philosophy", "reference", "education", "textbook"
        ]
    }
}

class InternetArchiveFilter:
    """Advanced filtering system for Internet Archive content"""

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

        # Internet Archive API
        self.ia_base_url = "https://archive.org"

    def get_archive_items(self, source: str, limit: int = 500) -> List[Dict[str, Any]]:
        """Get Internet Archive items from database"""
        try:
            response = self.dynamodb.query(
                TableName=TABLE_NAME,
                IndexName='source-status-index',
                KeyConditionExpression='source = :source',
                ExpressionAttributeValues={':source': {'S': source}},
                Limit=limit
            )

            items = response.get('Items', [])

            # Handle pagination
            while 'LastEvaluatedKey' in response and len(items) < limit:
                response = self.dynamodb.query(
                    TableName=TABLE_NAME,
                    IndexName='source-status-index',
                    KeyConditionExpression='source = :source',
                    ExpressionAttributeValues={':source': {'S': source}},
                    ExclusiveStartKey=response['LastEvaluatedKey'],
                    Limit=limit - len(items)
                )
                items.extend(response.get('Items', []))

            return items

        except Exception as e:
            print(f"❌ Error fetching {source}: {e}")
            return []

    def get_item_metadata_from_ia(self, identifier: str) -> Dict[str, Any]:
        """Fetch additional metadata from Internet Archive API"""
        try:
            metadata_url = f"{self.ia_base_url}/metadata/{identifier}"
            response = requests.get(metadata_url, timeout=10)

            if response.status_code == 200:
                return response.json()
            else:
                return {}

        except Exception as e:
            print(f"❌ Error fetching IA metadata for {identifier}: {e}")
            return {}

    def extract_identifier_from_url(self, url: str) -> str:
        """Extract Internet Archive identifier from URL"""
        try:
            # Handle different IA URL formats
            if '/details/' in url:
                return url.split('/details/')[-1].split('/')[0].split('?')[0]
            elif 'archive.org/' in url:
                parts = url.split('/')
                for i, part in enumerate(parts):
                    if part == 'archive.org' and i + 1 < len(parts):
                        return parts[i + 1]
            return ""
        except:
            return ""

    def analyze_item_quality(self, item: Dict[str, Any], rules: Dict[str, Any]) -> ArchiveQualityMetrics:
        """Perform comprehensive quality analysis on an Archive item"""
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', '')
        source = item.get('source', {}).get('S', '')

        # Extract identifier and get additional metadata
        identifier = self.extract_identifier_from_url(url)
        ia_metadata = {}

        if identifier:
            # Get additional metadata from IA (rate limited)
            time.sleep(0.5)  # Rate limiting
            ia_metadata = self.get_item_metadata_from_ia(identifier)

        # Extract basic information
        collection = source.replace('internet-archive-', '')
        mediatype = ia_metadata.get('metadata', {}).get('mediatype', 'unknown')
        downloads = int(ia_metadata.get('metadata', {}).get('downloads', 0))
        language = ia_metadata.get('metadata', {}).get('language', 'unknown')
        description = ia_metadata.get('metadata', {}).get('description', '')
        subjects = ia_metadata.get('metadata', {}).get('subject', [])

        if isinstance(subjects, str):
            subjects = [subjects]

        # Analyze quality dimensions
        description_quality = self._assess_description_quality(title, description, rules)
        relevance_score = self._assess_relevance(title, description, subjects, rules)
        accessibility_score = self._assess_accessibility(mediatype, language, downloads)
        cultural_value = self._assess_cultural_value(title, description, subjects, collection)

        # Calculate overall quality
        weights = {
            'description': 0.25,
            'relevance': 0.35,
            'accessibility': 0.20,
            'cultural': 0.20
        }

        overall_quality = (
            description_quality * weights['description'] +
            relevance_score * weights['relevance'] +
            accessibility_score * weights['accessibility'] +
            cultural_value * weights['cultural']
        )

        # Determine recommendation
        recommended_action, reasons = self._determine_action(
            overall_quality, downloads, relevance_score, rules
        )

        return ArchiveQualityMetrics(
            url=url,
            title=title,
            identifier=identifier,
            collection=collection,
            mediatype=mediatype,
            downloads=downloads,
            item_size=int(ia_metadata.get('server', {}).get('size', 0)),
            language=language,
            subject_tags=subjects,
            description_quality=description_quality,
            relevance_score=relevance_score,
            accessibility_score=accessibility_score,
            cultural_value=cultural_value,
            overall_quality=overall_quality,
            recommended_action=recommended_action,
            filter_reasons=reasons
        )

    def _assess_description_quality(self, title: str, description: str, rules: Dict[str, Any]) -> int:
        """Assess quality of title and description"""
        score = 5  # Base score

        title_lower = title.lower()
        desc_lower = description.lower()

        # Length assessment
        if len(description) >= rules.get('min_description_length', 50):
            score += 2
        elif len(description) < 20:
            score -= 2

        # Quality keywords
        quality_keywords = rules.get('quality_keywords', [])
        quality_matches = sum(1 for kw in quality_keywords if kw in title_lower or kw in desc_lower)
        score += min(3, quality_matches)

        # Exclude keywords (negative indicators)
        exclude_keywords = rules.get('exclude_keywords', [])
        exclude_matches = sum(1 for kw in exclude_keywords if kw in title_lower or kw in desc_lower)
        score -= min(4, exclude_matches * 2)

        # Title quality
        if len(title) > 10 and not title.isupper():
            score += 1
        if any(quality in title_lower for quality in ['complete', 'collection', 'archive']):
            score += 1

        return max(1, min(10, score))

    def _assess_relevance(self, title: str, description: str, subjects: List[str], rules: Dict[str, Any]) -> int:
        """Assess relevance to target audience"""
        score = 5  # Base score

        text = f"{title} {description}".lower()
        subjects_lower = [s.lower() for s in subjects]

        # Target subject matching
        target_subjects = rules.get('target_subjects', [])
        subject_matches = sum(1 for subj in target_subjects
                            if subj in text or any(subj in s for s in subjects_lower))
        score += min(4, subject_matches)

        # Creative professional relevance
        creative_keywords = [
            'design', 'art', 'creative', 'visual', 'aesthetic', 'inspiration',
            'portfolio', 'exhibition', 'gallery', 'museum', 'cultural'
        ]
        creative_matches = sum(1 for kw in creative_keywords if kw in text)
        if creative_matches >= 2:
            score += 2
        elif creative_matches >= 1:
            score += 1

        # Educational value
        educational_indicators = [
            'analysis', 'study', 'research', 'comprehensive', 'detailed',
            'historical', 'significant', 'important', 'landmark'
        ]
        educational_matches = sum(1 for indicator in educational_indicators if indicator in text)
        score += min(2, educational_matches)

        return max(1, min(10, score))

    def _assess_accessibility(self, mediatype: str, language: str, downloads: int) -> int:
        """Assess accessibility and usability"""
        score = 5  # Base score

        # Media type accessibility
        accessible_types = ['texts', 'image', 'audio']
        if mediatype in accessible_types:
            score += 2
        elif mediatype == 'movies':
            score += 1  # Videos can be good but require more bandwidth

        # Language accessibility
        if language.lower() in ['english', 'eng', 'en']:
            score += 2
        elif language in ['multiple', 'multilingual']:
            score += 1

        # Download popularity (indicator of accessibility/quality)
        if downloads > 10000:
            score += 3
        elif downloads > 1000:
            score += 2
        elif downloads > 100:
            score += 1
        elif downloads < 10:
            score -= 2

        return max(1, min(10, score))

    def _assess_cultural_value(self, title: str, description: str, subjects: List[str], collection: str) -> int:
        """Assess cultural and educational value"""
        score = 5  # Base score

        text = f"{title} {description} {' '.join(subjects)}".lower()

        # High-value indicators
        high_value_keywords = [
            'masterpiece', 'classic', 'renowned', 'acclaimed', 'significant',
            'important', 'influential', 'landmark', 'pioneering', 'groundbreaking',
            'award-winning', 'celebrated', 'notable', 'distinguished'
        ]
        high_value_matches = sum(1 for kw in high_value_keywords if kw in text)
        score += min(3, high_value_matches)

        # Institutional indicators
        institution_keywords = [
            'museum', 'university', 'library', 'institute', 'foundation',
            'academy', 'society', 'organization', 'government', 'official'
        ]
        institution_matches = sum(1 for kw in institution_keywords if kw in text)
        if institution_matches > 0:
            score += 2

        # Collection-specific bonuses
        if collection == 'culture' and any(cult in text for cult in ['art', 'literature', 'music']):
            score += 1
        elif collection == 'history' and any(hist in text for hist in ['historical', 'archive', 'primary']):
            score += 1
        elif collection == 'science' and any(sci in text for sci in ['research', 'study', 'scientific']):
            score += 1

        return max(1, min(10, score))

    def _determine_action(self, overall_quality: float, downloads: int,
                        relevance: int, rules: Dict[str, Any]) -> Tuple[str, List[str]]:
        """Determine filtering action based on quality metrics"""
        reasons = []

        # High quality items - keep active
        if overall_quality >= 8.0 and downloads >= rules.get('min_downloads', 100):
            return "KEEP_ACTIVE", ["High overall quality", "Good download metrics"]

        # Good quality items - keep active
        if overall_quality >= 6.5 and relevance >= 7:
            reasons.append("Good quality and relevance")
            return "KEEP_ACTIVE", reasons

        # Marginal items - review or downgrade
        if 5.0 <= overall_quality < 6.5:
            if downloads < rules.get('min_downloads', 100):
                reasons.append("Low download count")
            if relevance < 6:
                reasons.append("Low relevance score")
            return "REVIEW_NEEDED", reasons

        # Low quality items - deactivate
        if overall_quality < 5.0:
            reasons.append("Low overall quality score")
            if downloads < 50:
                reasons.append("Very low engagement")
            return "DEACTIVATE", reasons

        # Items that don't meet minimum standards
        if downloads < rules.get('min_downloads', 100) // 2:
            reasons.append("Downloads below threshold")
            return "DEACTIVATE", reasons

        return "KEEP_ACTIVE", ["Meets minimum criteria"]

    def filter_collection(self, collection_source: str, dry_run: bool = True) -> Dict[str, Any]:
        """Filter a specific Internet Archive collection"""
        print(f"\n🔍 FILTERING: {collection_source}")
        print("=" * 60)

        if collection_source not in ARCHIVE_QUALITY_RULES:
            print(f"❌ No filtering rules defined for {collection_source}")
            return {}

        rules = ARCHIVE_QUALITY_RULES[collection_source]
        print(f"🎯 Strategy: {rules['description']}")

        # Get items from database
        items = self.get_archive_items(collection_source, limit=1000)
        if not items:
            print(f"❌ No items found for {collection_source}")
            return {}

        print(f"📊 Analyzing {len(items)} items...")

        # Analyze each item
        analyzed_items = []
        for i, item in enumerate(items):
            if i % 50 == 0:
                print(f"  📈 Progress: {i}/{len(items)} items analyzed...")

            try:
                quality_metrics = self.analyze_item_quality(item, rules)
                analyzed_items.append(quality_metrics)
            except Exception as e:
                print(f"  ❌ Error analyzing item: {e}")

        # Generate statistics
        stats = self._generate_filter_stats(analyzed_items, collection_source)

        if not dry_run:
            # Execute filtering actions
            self._execute_filtering_actions(analyzed_items)

        return stats

    def _generate_filter_stats(self, analyzed_items: List[ArchiveQualityMetrics],
                             collection: str) -> Dict[str, Any]:
        """Generate comprehensive filtering statistics"""
        if not analyzed_items:
            return {}

        # Action counts
        actions = {}
        for item in analyzed_items:
            action = item.recommended_action
            actions[action] = actions.get(action, 0) + 1

        # Quality distribution
        quality_scores = [item.overall_quality for item in analyzed_items]
        quality_stats = {
            'mean': statistics.mean(quality_scores),
            'median': statistics.median(quality_scores),
            'min': min(quality_scores),
            'max': max(quality_scores)
        }

        # Top items to keep
        top_items = sorted([item for item in analyzed_items
                          if item.recommended_action == "KEEP_ACTIVE"],
                         key=lambda x: x.overall_quality, reverse=True)[:10]

        # Items to remove
        remove_items = sorted([item for item in analyzed_items
                             if item.recommended_action == "DEACTIVATE"],
                            key=lambda x: x.overall_quality)[:10]

        stats = {
            'collection': collection,
            'total_items': len(analyzed_items),
            'actions': actions,
            'quality_stats': quality_stats,
            'top_items': top_items,
            'remove_items': remove_items,
            'keep_percentage': actions.get('KEEP_ACTIVE', 0) / len(analyzed_items) * 100,
            'remove_percentage': actions.get('DEACTIVATE', 0) / len(analyzed_items) * 100
        }

        # Display results
        print(f"\n📊 FILTERING RESULTS:")
        print(f"  📈 Total items analyzed: {stats['total_items']}")
        print(f"  ✅ Keep active: {actions.get('KEEP_ACTIVE', 0)} ({stats['keep_percentage']:.1f}%)")
        print(f"  ⚠️  Review needed: {actions.get('REVIEW_NEEDED', 0)}")
        print(f"  🗑️  Deactivate: {actions.get('DEACTIVATE', 0)} ({stats['remove_percentage']:.1f}%)")
        print(f"  📊 Quality score: {quality_stats['mean']:.1f} ± {quality_stats['median']:.1f}")

        print(f"\n🏆 TOP 5 ITEMS TO KEEP:")
        for i, item in enumerate(top_items[:5]):
            print(f"  {i+1}. Quality: {item.overall_quality:.1f} | Downloads: {item.downloads}")
            print(f"     {item.title[:60]}...")

        print(f"\n🗑️ TOP 5 ITEMS TO REMOVE:")
        for i, item in enumerate(remove_items[:5]):
            print(f"  {i+1}. Quality: {item.overall_quality:.1f} | {item.filter_reasons[0] if item.filter_reasons else 'Low quality'}")
            print(f"     {item.title[:60]}...")

        return stats

    def _execute_filtering_actions(self, analyzed_items: List[ArchiveQualityMetrics]) -> Tuple[int, int]:
        """Execute the filtering actions on database items"""
        print(f"\n🚀 EXECUTING FILTERING ACTIONS...")

        success_count = 0
        error_count = 0

        for item in analyzed_items:
            try:
                if item.recommended_action == "DEACTIVATE":
                    # Mark as inactive
                    self.table.update_item(
                        Key={'url': item.url},
                        UpdateExpression='SET #status = :inactive, #is_active = :false, updatedAt = :timestamp',
                        ExpressionAttributeNames={
                            '#status': 'status',
                            '#is_active': 'isActive'
                        },
                        ExpressionAttributeValues={
                            ':inactive': 'inactive',
                            ':false': False,
                            ':timestamp': datetime.now(timezone.utc).isoformat()
                        }
                    )
                    success_count += 1

            except Exception as e:
                print(f"  ❌ Error updating {item.url}: {e}")
                error_count += 1

        print(f"✅ Filtering complete: {success_count} updated, {error_count} errors")
        return success_count, error_count

    def run_complete_filtering(self, collections: List[str] = None, dry_run: bool = True) -> Dict[str, Any]:
        """Run filtering on all or specified Internet Archive collections"""
        print("🤖 INTERNET ARCHIVE QUALITY FILTERING")
        print("=" * 70)

        if collections is None:
            collections = list(ARCHIVE_QUALITY_RULES.keys())

        print(f"🎯 Processing {len(collections)} collections")
        if dry_run:
            print("⚠️  DRY RUN MODE - No changes will be made to database")

        all_stats = {}
        total_items = 0
        total_kept = 0
        total_removed = 0

        for collection in collections:
            try:
                stats = self.filter_collection(collection, dry_run)
                if stats:
                    all_stats[collection] = stats
                    total_items += stats['total_items']
                    total_kept += stats['actions'].get('KEEP_ACTIVE', 0)
                    total_removed += stats['actions'].get('DEACTIVATE', 0)

            except Exception as e:
                print(f"❌ Error processing {collection}: {e}")

        # Overall summary
        print(f"\n📊 OVERALL FILTERING SUMMARY:")
        print("=" * 50)
        print(f"📈 Total items processed: {total_items}")
        print(f"✅ Total items kept: {total_kept} ({total_kept/total_items*100:.1f}%)")
        print(f"🗑️  Total items removed: {total_removed} ({total_removed/total_items*100:.1f}%)")

        return {
            'collections_processed': collections,
            'total_items': total_items,
            'total_kept': total_kept,
            'total_removed': total_removed,
            'collection_stats': all_stats,
            'dry_run': dry_run
        }

def main():
    """Main execution function"""
    filter_system = InternetArchiveFilter()

    print("🏛️ INTERNET ARCHIVE CONTENT QUALITY FILTER")
    print("=" * 60)
    print("Choose an option:")
    print("1. Analyze all collections (dry run)")
    print("2. Filter specific collection")
    print("3. Execute filtering on all collections")
    print("4. Show filtering rules")

    choice = input("\nEnter choice (1-4): ").strip()

    if choice == '1':
        filter_system.run_complete_filtering(dry_run=True)

    elif choice == '2':
        print("\nAvailable collections:")
        for i, collection in enumerate(ARCHIVE_QUALITY_RULES.keys(), 1):
            print(f"  {i}. {collection}")

        selection = input("\nEnter collection name: ").strip()
        if selection in ARCHIVE_QUALITY_RULES:
            dry_run = input("Dry run? (Y/n): ").strip().lower() != 'n'
            filter_system.filter_collection(selection, dry_run)
        else:
            print("❌ Invalid collection name")

    elif choice == '3':
        print("⚠️  This will modify your database!")
        confirm = input("Are you sure? (yes/NO): ").strip()
        if confirm.lower() == 'yes':
            filter_system.run_complete_filtering(dry_run=False)
        else:
            print("❌ Cancelled")

    elif choice == '4':
        print("\n📋 FILTERING RULES:")
        for collection, rules in ARCHIVE_QUALITY_RULES.items():
            print(f"\n{collection}:")
            print(f"  📝 {rules['description']}")
            print(f"  📊 Min downloads: {rules['min_downloads']}")
            print(f"  🎯 Media types: {', '.join(rules['preferred_mediatypes'])}")
            print(f"  📚 Target subjects: {len(rules['target_subjects'])} topics")

    else:
        print("❌ Invalid choice")

if __name__ == "__main__":
    main()