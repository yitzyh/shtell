#!/usr/bin/env python3
"""
Convert IMDB URLs to Letterboxd URLs for tmdb-to-imdb source
"""

import boto3
import re
import requests
import time
from urllib.parse import urlparse, quote

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

def extract_imdb_id(url):
    """Extract IMDB ID from URL like https://www.imdb.com/title/tt1517451/"""
    match = re.search(r'imdb\.com/title/(tt\d+)', url)
    return match.group(1) if match else None

def title_to_letterboxd_slug(title):
    """Convert movie title to Letterboxd URL slug"""
    # Basic slug conversion (lowercase, replace spaces/special chars with hyphens)
    slug = title.lower()
    slug = re.sub(r'[^\w\s-]', '', slug)  # Remove special chars except spaces and hyphens
    slug = re.sub(r'[-\s]+', '-', slug)   # Replace spaces and multiple hyphens with single hyphen
    slug = slug.strip('-')                # Remove leading/trailing hyphens
    return slug

def get_letterboxd_url_from_title(title, year=None):
    """Convert movie title to Letterboxd URL"""
    slug = title_to_letterboxd_slug(title)

    # Add year if available for disambiguation
    if year:
        return f"https://letterboxd.com/film/{slug}-{year}/"
    else:
        return f"https://letterboxd.com/film/{slug}/"

def get_tmdb_imdb_items():
    """Get all items from tmdb-to-imdb source"""
    print("📋 Fetching tmdb-to-imdb items...")

    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='source-status-index',
        KeyConditionExpression='#source = :source',
        ExpressionAttributeNames={'#source': 'source'},
        ExpressionAttributeValues={':source': {'S': 'tmdb-to-imdb'}}
    )

    items = response.get('Items', [])
    print(f"Found {len(items)} items")
    return items

def update_url_to_letterboxd(old_url, new_url, title):
    """Update item URL from IMDB to Letterboxd"""
    try:
        # First, get the item to preserve other fields
        response = dynamodb.get_item(
            TableName=TABLE_NAME,
            Key={'url': {'S': old_url}}
        )

        if 'Item' not in response:
            print(f"   ⚠️  Item not found: {old_url}")
            return False

        item = response['Item']

        # Delete old item
        dynamodb.delete_item(
            TableName=TABLE_NAME,
            Key={'url': {'S': old_url}}
        )

        # Create new item with updated URL and source
        item['url'] = {'S': new_url}
        item['source'] = {'S': 'letterboxd'}  # Update source

        # Add update timestamp
        item['updatedAt'] = {'S': time.strftime('%Y-%m-%d %H:%M:%S')}

        # Put new item
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item=item
        )

        return True

    except Exception as e:
        print(f"   ❌ Error updating {old_url}: {e}")
        return False

def main():
    """Main conversion process"""
    print("🎬 IMDB → LETTERBOXD CONVERSION")
    print("=" * 50)

    # Get all tmdb-to-imdb items
    items = get_tmdb_imdb_items()

    converted_count = 0
    skipped_count = 0
    error_count = 0

    print(f"\n🔄 Converting {len(items)} IMDB URLs to Letterboxd...")

    for i, item in enumerate(items, 1):
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', '')

        # Extract IMDB ID
        imdb_id = extract_imdb_id(url)

        if not imdb_id:
            print(f"{i:4d}. ⚠️  No IMDB ID found in: {url}")
            skipped_count += 1
            continue

        if not title:
            print(f"{i:4d}. ⚠️  No title found for: {url}")
            skipped_count += 1
            continue

        # Generate Letterboxd URL
        letterboxd_url = get_letterboxd_url_from_title(title)

        # Update in database
        success = update_url_to_letterboxd(url, letterboxd_url, title)

        if success:
            converted_count += 1
            print(f"{i:4d}. ✅ {title[:40]}")
            print(f"      {url}")
            print(f"   → {letterboxd_url}")
        else:
            error_count += 1

        # Progress update every 100 items
        if i % 100 == 0:
            print(f"\n📊 Progress: {i}/{len(items)} processed")
            print(f"   ✅ Converted: {converted_count}")
            print(f"   ⚠️  Skipped: {skipped_count}")
            print(f"   ❌ Errors: {error_count}\n")

    print(f"\n🎯 CONVERSION COMPLETE")
    print(f"   Total items: {len(items)}")
    print(f"   ✅ Successfully converted: {converted_count}")
    print(f"   ⚠️  Skipped: {skipped_count}")
    print(f"   ❌ Errors: {error_count}")

if __name__ == "__main__":
    main()