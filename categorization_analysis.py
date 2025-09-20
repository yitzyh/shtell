#!/usr/bin/env python3
"""
Categorization Analysis for BrowseForward Sources
Samples content from different sources to recommend categorization strategies
"""

import boto3
import json
import random
from collections import defaultdict

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

def sample_source_content(source: str, sample_size: int = 5):
    """Sample random content from a specific source"""
    print(f"\n🔍 SAMPLING: {source}")
    print("=" * 60)

    # Query items from source
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='source-status-index',
        KeyConditionExpression='#source = :source',
        ExpressionAttributeNames={'#source': 'source'},
        ExpressionAttributeValues={':source': {'S': source}}
    )

    items = response.get('Items', [])

    if not items:
        print(f"❌ No items found for source: {source}")
        return []

    print(f"📊 Total items in {source}: {len(items)}")

    # Sample random items
    sample_items = random.sample(items, min(sample_size, len(items)))

    samples = []
    for i, item in enumerate(sample_items, 1):
        url = item.get('url', {}).get('S', 'No URL')
        title = item.get('title', {}).get('S', 'No Title')
        category = item.get('bfCategory', {}).get('S', 'uncategorized')
        subcategory = item.get('bfSubcategory', {}).get('S', 'none')
        tags = item.get('tags', {}).get('SS', [])

        # Extract additional metadata if available
        genre = item.get('genre', {}).get('S', 'none')
        year = item.get('year', {}).get('S', 'none')
        director = item.get('director', {}).get('S', 'none')
        imdb_rating = item.get('imdbRating', {}).get('S', 'none')

        sample_data = {
            'url': url,
            'title': title,
            'category': category,
            'subcategory': subcategory,
            'tags': tags,
            'genre': genre,
            'year': year,
            'director': director,
            'imdb_rating': imdb_rating
        }

        samples.append(sample_data)

        print(f"\n{i}. TITLE: {title}")
        print(f"   URL: {url}")
        print(f"   Category: {category}")
        print(f"   Subcategory: {subcategory}")
        if tags:
            print(f"   Tags: {', '.join(tags)}")
        if genre != 'none':
            print(f"   Genre: {genre}")
        if year != 'none':
            print(f"   Year: {year}")
        if director != 'none':
            print(f"   Director: {director}")
        if imdb_rating != 'none':
            print(f"   IMDB Rating: {imdb_rating}")

    return samples

def analyze_tmdb_structure():
    """Analyze TMDB source to understand existing metadata structure"""
    print(f"\n🎬 ANALYZING TMDB DATA STRUCTURE")
    print("=" * 60)

    # Query TMDB items
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='source-status-index',
        KeyConditionExpression='#source = :source',
        ExpressionAttributeNames={'#source': 'source'},
        ExpressionAttributeValues={':source': {'S': 'tmdb-to-imdb'}},
        Limit=10
    )

    items = response.get('Items', [])

    if not items:
        print("❌ No TMDB items found")
        return

    print(f"📊 Found {len(items)} TMDB items to analyze")

    # Analyze metadata fields
    field_counts = defaultdict(int)
    genre_examples = set()

    for item in items:
        for key in item.keys():
            field_counts[key] += 1

        # Collect genre examples
        genre = item.get('genre', {}).get('S', '')
        if genre and genre != 'none':
            genre_examples.add(genre)

    print("\n📋 AVAILABLE METADATA FIELDS:")
    for field, count in sorted(field_counts.items()):
        print(f"   {field:<20} {count}/{len(items)} items")

    if genre_examples:
        print(f"\n🎭 GENRE EXAMPLES:")
        for genre in sorted(list(genre_examples)[:10]):
            print(f"   • {genre}")

    # Sample a few items for detailed view
    print(f"\n🎬 SAMPLE TMDB ITEMS:")
    sample_items = random.sample(items, min(3, len(items)))

    for i, item in enumerate(sample_items, 1):
        title = item.get('title', {}).get('S', 'No Title')
        url = item.get('url', {}).get('S', 'No URL')
        genre = item.get('genre', {}).get('S', 'none')
        year = item.get('year', {}).get('S', 'none')
        director = item.get('director', {}).get('S', 'none')
        imdb_rating = item.get('imdbRating', {}).get('S', 'none')
        category = item.get('bfCategory', {}).get('S', 'uncategorized')
        subcategory = item.get('bfSubcategory', {}).get('S', 'none')

        print(f"\n{i}. {title}")
        print(f"   URL: {url}")
        print(f"   Current Category: {category}")
        print(f"   Current Subcategory: {subcategory}")
        print(f"   Genre: {genre}")
        print(f"   Year: {year}")
        print(f"   Director: {director}")
        print(f"   IMDB Rating: {imdb_rating}")

def generate_categorization_recommendations():
    """Generate recommendations for categorization strategies"""
    print(f"\n💡 CATEGORIZATION STRATEGY RECOMMENDATIONS")
    print("=" * 80)

    recommendations = {
        'google-books-to-goodreads': {
            'strategy': 'Genre-based subcategories',
            'category': 'books',
            'subcategory_approach': 'Use book genres (fiction, non-fiction, biography, etc.)',
            'tags_approach': 'Author names, publication year, topics',
            'rationale': 'Books have clear genre classifications that users understand'
        },

        'tmdb-to-imdb': {
            'strategy': 'Movie genre subcategories',
            'category': 'movies',
            'subcategory_approach': 'Use existing genre field as bfSubcategory',
            'tags_approach': 'Director, year, actors, keywords',
            'rationale': 'TMDB already provides rich genre metadata - leverage existing structure'
        },

        'internet-archive-culture': {
            'strategy': 'Cultural topic subcategories',
            'category': 'culture',
            'subcategory_approach': 'anthropology, sociology, traditions, festivals',
            'tags_approach': 'Geographic regions, time periods, cultural groups',
            'rationale': 'Cultural content spans many topics - need broad but meaningful groupings'
        },

        'internet-archive-art': {
            'strategy': 'Art medium/movement subcategories',
            'category': 'art',
            'subcategory_approach': 'painting, sculpture, photography, modern, classical',
            'tags_approach': 'Artist names, art movements, time periods, mediums',
            'rationale': 'Art has established categorization by medium and historical movement'
        },

        'internet-archive-history': {
            'strategy': 'Historical period subcategories',
            'category': 'history',
            'subcategory_approach': 'ancient, medieval, modern, contemporary, war, politics',
            'tags_approach': 'Specific dates, locations, historical figures, events',
            'rationale': 'Historical content naturally groups by time periods and themes'
        },

        'internet-archive-books': {
            'strategy': 'Same as google-books approach',
            'category': 'books',
            'subcategory_approach': 'fiction, non-fiction, reference, academic',
            'tags_approach': 'Subject areas, publication info, difficulty level',
            'rationale': 'Consistent book categorization across all book sources'
        },

        'internet-archive-tech': {
            'strategy': 'Technology domain subcategories',
            'category': 'technology',
            'subcategory_approach': 'programming, hardware, software, ai, networking',
            'tags_approach': 'Programming languages, tech companies, specific technologies',
            'rationale': 'Tech content has clear domain boundaries that users recognize'
        },

        'internet-archive-science': {
            'strategy': 'Scientific discipline subcategories',
            'category': 'science',
            'subcategory_approach': 'physics, chemistry, biology, astronomy, medicine',
            'tags_approach': 'Research topics, methodologies, applications',
            'rationale': 'Science naturally divides by academic disciplines'
        }
    }

    for source, rec in recommendations.items():
        print(f"\n📚 {source.upper()}")
        print(f"   🏷️  Primary Category: {rec['category']}")
        print(f"   📂 Subcategory Strategy: {rec['subcategory_approach']}")
        print(f"   🏷️  Tags Strategy: {rec['tags_approach']}")
        print(f"   💭 Rationale: {rec['rationale']}")

    print(f"\n🔧 IMPLEMENTATION GUIDELINES:")
    print("   1. Use bfSubcategory for the primary classification (genre, medium, discipline)")
    print("   2. Use tags for specific details (names, dates, keywords)")
    print("   3. Keep subcategories broad enough to be useful for browsing")
    print("   4. Ensure consistency within each content type")
    print("   5. Consider user mental models - use familiar categorization schemes")

def main():
    """Main analysis function"""
    print("🔍 BROWSEFORWARD CATEGORIZATION ANALYSIS")
    print("=" * 80)

    # Sample content from specified sources
    sources_to_sample = [
        ('google-books-to-goodreads', 5),
        ('internet-archive-culture', 3),
        ('internet-archive-art', 3),
        ('internet-archive-history', 3),
        ('internet-archive-books', 3),
        ('internet-archive-tech', 3),
        ('internet-archive-science', 3)
    ]

    all_samples = {}

    for source, sample_size in sources_to_sample:
        try:
            samples = sample_source_content(source, sample_size)
            all_samples[source] = samples
        except Exception as e:
            print(f"❌ Error sampling {source}: {e}")

    # Analyze TMDB structure specifically
    try:
        analyze_tmdb_structure()
    except Exception as e:
        print(f"❌ Error analyzing TMDB: {e}")

    # Generate recommendations
    generate_categorization_recommendations()

    print(f"\n✅ ANALYSIS COMPLETE")
    print("=" * 80)

if __name__ == "__main__":
    main()