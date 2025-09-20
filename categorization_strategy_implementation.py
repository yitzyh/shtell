#!/usr/bin/env python3
"""
Categorization Strategy Implementation for BrowseForward
Implements the recommended categorization strategies based on analysis findings
"""

import boto3
import json
import re
from collections import defaultdict
from typing import List, Dict, Any

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

class CategorizationEngine:
    """Enhanced categorization system for BrowseForward content"""

    def __init__(self):
        self.dynamodb = dynamodb
        self.table_name = TABLE_NAME

        # Define categorization rules for each source
        self.categorization_rules = {
            'google-books-to-goodreads': {
                'primary_category': 'books',
                'subcategory_keywords': {
                    'fiction': ['novel', 'story', 'tales', 'fiction'],
                    'non-fiction': ['guide', 'history', 'biography', 'manual', 'handbook'],
                    'education': ['curriculum', 'textbook', 'guide', 'course', 'teaching'],
                    'philosophy': ['philosophy', 'cosmic', 'thought', 'ethics'],
                    'business': ['business', 'tourism', 'planning', 'development'],
                    'reference': ['catalogue', 'dictionary', 'encyclopedia', 'reference']
                }
            },

            'tmdb-to-imdb': {
                'primary_category': 'movies',
                'use_existing_subcategory': True,  # Already has genre-based subcategories
                'enhance_tags': ['imdb', 'movies', 'film']
            },

            'internet-archive-culture': {
                'primary_category': 'culture',
                'subcategory_keywords': {
                    'radio': ['radio', 'program', 'broadcast', 'benny', 'otr'],
                    'comedy': ['comedy', 'humor', 'funny', 'joke'],
                    'mystery': ['mystery', 'murder', 'detective', 'nero wolfe'],
                    'entertainment': ['show', 'entertainment', 'variety'],
                    'americana': ['american', 'americana', 'culture', 'tradition']
                }
            },

            'internet-archive-art': {
                'primary_category': 'art',
                'subcategory_keywords': {
                    'photography': ['photograph', 'albumen', 'silver print'],
                    'prints': ['print', 'block', 'lithograph'],
                    'european': ['europe', 'avignon', 'france', 'paris'],
                    'japanese': ['japan', 'yokohama', 'utagawa', 'japanese'],
                    'contemporary': ['locomotion', 'modern', 'experimental'],
                    'architecture': ['palais', 'palace', 'building', 'cathedral']
                }
            },

            'internet-archive-history': {
                'primary_category': 'history',
                'subcategory_keywords': {
                    'crafts': ['crochet', 'lace', 'making', 'needlework'],
                    'americana': ['americana', 'american', 'united states'],
                    'church': ['church', 'religious', 'st.', 'saint'],
                    'local': ['new york', 'cold spring', 'local history'],
                    'industrial': ['industry', 'manufacturing', 'trade']
                }
            },

            'internet-archive-books': {
                'primary_category': 'books',
                'subcategory_keywords': {
                    'mythology': ['myth', 'legend', 'folklore', 'japanese'],
                    'fiction': ['novel', 'story', 'negro race'],
                    'anthropology': ['igorot', 'culture', 'tribal', 'people'],
                    'academic': ['study', 'research', 'investigation']
                }
            },

            'internet-archive-tech': {
                'primary_category': 'technology',
                'subcategory_keywords': {
                    'magazines': ['magazine', 'asm', 'amstrad', 'pc player'],
                    'gaming': ['action', 'game', 'player', 'amstrad'],
                    'computing': ['computer', 'pc', 'software', 'hardware'],
                    'retro': ['1992', '1995', 'vintage', 'old']
                }
            },

            'internet-archive-science': {
                'primary_category': 'science',
                'subcategory_keywords': {
                    'space': ['apollo', 'nasa', 'moon', 'space', 'shuttle'],
                    'astronomy': ['earth', 'planet', 'celestial'],
                    'aerospace': ['flight', 'facility', 'wake shield'],
                    'exploration': ['rover', 'mission', 'onboard']
                }
            }
        }

    def categorize_source(self, source: str, limit: int = None) -> Dict[str, Any]:
        """Apply categorization strategy to a specific source"""
        print(f"\n🏷️  CATEGORIZING: {source}")
        print("=" * 60)

        if source not in self.categorization_rules:
            print(f"❌ No categorization rules defined for {source}")
            return {'error': 'No rules defined'}

        rules = self.categorization_rules[source]

        # Query items from source
        query_params = {
            'TableName': self.table_name,
            'IndexName': 'source-status-index',
            'KeyConditionExpression': '#source = :source',
            'ExpressionAttributeNames': {'#source': 'source'},
            'ExpressionAttributeValues': {':source': {'S': source}}
        }

        if limit:
            query_params['Limit'] = limit

        response = self.dynamodb.query(**query_params)
        items = response.get('Items', [])

        print(f"📊 Processing {len(items)} items from {source}")

        categorized_count = 0
        updated_count = 0
        subcategory_distribution = defaultdict(int)

        for item in items:
            url = item.get('url', {}).get('S', '')
            title = item.get('title', {}).get('S', '')
            current_category = item.get('bfCategory', {}).get('S', 'uncategorized')
            current_subcategory = item.get('bfSubcategory', {}).get('S', 'none')

            # Determine new categorization
            new_category = rules['primary_category']
            new_subcategory = self._determine_subcategory(title, rules)
            new_tags = self._generate_enhanced_tags(title, source, rules)

            # Track distribution
            subcategory_distribution[new_subcategory] += 1

            # Update if categorization changed
            if (current_category != new_category or
                current_subcategory != new_subcategory):

                self._update_item_categorization(url, new_category, new_subcategory, new_tags)
                updated_count += 1

                if updated_count <= 5:  # Show first 5 updates
                    print(f"   📝 Updated: {title[:50]}")
                    print(f"      Category: {current_category} → {new_category}")
                    print(f"      Subcategory: {current_subcategory} → {new_subcategory}")

            categorized_count += 1

        print(f"\n📈 CATEGORIZATION RESULTS:")
        print(f"   Items processed: {categorized_count}")
        print(f"   Items updated: {updated_count}")
        print(f"\n📊 SUBCATEGORY DISTRIBUTION:")
        for subcat, count in sorted(subcategory_distribution.items()):
            print(f"   {subcat:<20} {count:3d} items ({count/categorized_count*100:.1f}%)")

        return {
            'source': source,
            'processed': categorized_count,
            'updated': updated_count,
            'subcategory_distribution': dict(subcategory_distribution)
        }

    def _determine_subcategory(self, title: str, rules: Dict) -> str:
        """Determine appropriate subcategory based on title and rules"""
        if 'use_existing_subcategory' in rules:
            return 'existing'  # Keep current subcategory

        if 'subcategory_keywords' not in rules:
            return 'general'

        title_lower = title.lower()

        for subcategory, keywords in rules['subcategory_keywords'].items():
            for keyword in keywords:
                if keyword.lower() in title_lower:
                    return subcategory

        return 'general'

    def _generate_enhanced_tags(self, title: str, source: str, rules: Dict) -> List[str]:
        """Generate enhanced tags based on content and source"""
        tags = []

        # Add source-based tags
        if 'reddit' in source:
            tags.append('reddit')
            subreddit = source.replace('reddit-', '')
            tags.append(subreddit)
        elif 'archive' in source:
            tags.append('internet-archive')
            archive_type = source.replace('internet-archive-', '')
            tags.append(archive_type)
        elif 'tmdb' in source:
            tags.extend(['tmdb', 'imdb', 'movies'])
        elif 'goodreads' in source:
            tags.extend(['goodreads', 'books'])

        # Add content-based tags from title
        content_keywords = {
            'vintage': ['1990s', '1980s', 'retro', 'classic', 'vintage'],
            'educational': ['guide', 'curriculum', 'textbook', 'manual'],
            'american': ['american', 'usa', 'united states', 'new york'],
            'japanese': ['japan', 'japanese', 'tokyo', 'yokohama'],
            'technical': ['computer', 'software', 'programming', 'tech'],
            'creative': ['art', 'design', 'photography', 'craft']
        }

        title_lower = title.lower()
        for tag, keywords in content_keywords.items():
            if any(keyword in title_lower for keyword in keywords):
                tags.append(tag)

        # Add any enhancement tags from rules
        if 'enhance_tags' in rules:
            tags.extend(rules['enhance_tags'])

        return list(set(tags))[:8]  # Max 8 unique tags

    def _update_item_categorization(self, url: str, category: str, subcategory: str, tags: List[str]):
        """Update DynamoDB item with new categorization"""
        try:
            update_expression = "SET bfCategory = :category, bfSubcategory = :subcategory"
            expression_values = {
                ':category': {'S': category},
                ':subcategory': {'S': subcategory}
            }

            if tags:
                update_expression += ", tags = :tags"
                expression_values[':tags'] = {'SS': tags}

            self.dynamodb.update_item(
                TableName=self.table_name,
                Key={'url': {'S': url}},
                UpdateExpression=update_expression,
                ExpressionAttributeValues=expression_values
            )
        except Exception as e:
            print(f"   ⚠️  Error updating {url}: {e}")

    def analyze_current_categorization(self) -> Dict[str, Any]:
        """Analyze current categorization state across all sources"""
        print("\n📊 CURRENT CATEGORIZATION ANALYSIS")
        print("=" * 60)

        # Scan for category stats
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

        # Analyze categorization
        source_categories = defaultdict(lambda: defaultdict(int))
        category_counts = defaultdict(int)
        subcategory_counts = defaultdict(int)
        uncategorized_by_source = defaultdict(int)

        for item in items:
            source = item.get('source', {}).get('S', 'unknown')
            category = item.get('bfCategory', {}).get('S', 'uncategorized')
            subcategory = item.get('bfSubcategory', {}).get('S', 'none')

            source_categories[source][category] += 1
            category_counts[category] += 1
            subcategory_counts[subcategory] += 1

            if category == 'uncategorized':
                uncategorized_by_source[source] += 1

        print(f"📈 OVERALL CATEGORIZATION STATUS:")
        print(f"   Total items: {len(items):,}")
        print(f"   Uncategorized items: {category_counts['uncategorized']:,} ({category_counts['uncategorized']/len(items)*100:.1f}%)")

        print(f"\n🏷️  TOP CATEGORIES:")
        for category, count in sorted(category_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"   {category:<20} {count:,} items")

        print(f"\n📂 SOURCES NEEDING CATEGORIZATION:")
        for source, count in sorted(uncategorized_by_source.items(), key=lambda x: x[1], reverse=True)[:10]:
            if count > 0:
                total_in_source = sum(source_categories[source].values())
                print(f"   {source:<35} {count:,}/{total_in_source:,} uncategorized ({count/total_in_source*100:.1f}%)")

        return {
            'total_items': len(items),
            'category_distribution': dict(category_counts),
            'uncategorized_by_source': dict(uncategorized_by_source),
            'source_categories': dict(source_categories)
        }

def main():
    """Main execution function"""
    print("🏷️  BROWSEFORWARD CATEGORIZATION ENGINE")
    print("=" * 80)

    engine = CategorizationEngine()

    # Analyze current state
    engine.analyze_current_categorization()

    # Apply categorization to specific sources
    sources_to_categorize = [
        'google-books-to-goodreads',
        'internet-archive-culture',
        'internet-archive-art',
        'internet-archive-history',
        'internet-archive-books',
        'internet-archive-tech',
        'internet-archive-science'
    ]

    print(f"\n🔧 APPLYING CATEGORIZATION STRATEGIES:")
    print("=" * 60)

    results = {}
    for source in sources_to_categorize:
        try:
            result = engine.categorize_source(source, limit=50)  # Limit for testing
            results[source] = result
        except Exception as e:
            print(f"❌ Error categorizing {source}: {e}")

    print(f"\n✅ CATEGORIZATION COMPLETE")
    print("=" * 80)

    return results

if __name__ == "__main__":
    main()