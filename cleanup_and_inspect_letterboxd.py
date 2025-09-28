#!/usr/bin/env python3
"""
1. Delete malformed IMDB URLs (search queries)
2. Inspect Letterboxd items for all available fields
"""

import boto3
import json
import re

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

def delete_malformed_urls():
    """Delete all IMDB search URLs (not proper movie pages)"""
    print("🗑️  CLEANING UP MALFORMED IMDB URLS")
    print("=" * 50)

    # Get all tmdb-to-imdb items
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='source-status-index',
        KeyConditionExpression='#source = :source',
        ExpressionAttributeNames={'#source': 'source'},
        ExpressionAttributeValues={':source': {'S': 'tmdb-to-imdb'}}
    )

    items = response.get('Items', [])
    deleted_count = 0
    malformed_urls = []

    for item in items:
        url = item.get('url', {}).get('S', '')

        # Check if it's a search URL (malformed)
        if 'imdb.com/find?' in url:
            malformed_urls.append(url)

            # Delete the item
            try:
                dynamodb.delete_item(
                    TableName=TABLE_NAME,
                    Key={'url': {'S': url}}
                )
                deleted_count += 1
                print(f"   🗑️  Deleted: {url}")
            except Exception as e:
                print(f"   ❌ Error deleting {url}: {e}")

    print(f"\n✅ Deleted {deleted_count} malformed URLs")
    return malformed_urls

def inspect_letterboxd_items():
    """Get 3 Letterboxd items and show ALL their fields"""
    print("\n📊 INSPECTING LETTERBOXD ITEMS")
    print("=" * 50)

    # Get letterboxd items
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='source-status-index',
        KeyConditionExpression='#source = :source',
        ExpressionAttributeNames={'#source': 'source'},
        ExpressionAttributeValues={':source': {'S': 'letterboxd'}},
        Limit=3
    )

    items = response.get('Items', [])

    if not items:
        print("❌ No letterboxd items found")
        return

    print(f"Found {len(items)} letterboxd items. Showing ALL fields:\n")

    for i, item in enumerate(items, 1):
        print(f"\n{'='*60}")
        print(f"📽️  MOVIE #{i}")
        print(f"{'='*60}")

        # Convert DynamoDB format to readable format
        readable_item = {}
        for key, value in item.items():
            # Extract the actual value from DynamoDB format
            if 'S' in value:  # String
                readable_item[key] = value['S']
            elif 'N' in value:  # Number
                readable_item[key] = value['N']
            elif 'BOOL' in value:  # Boolean
                readable_item[key] = value['BOOL']
            elif 'SS' in value:  # String Set (for tags)
                readable_item[key] = value['SS']
            elif 'L' in value:  # List
                readable_item[key] = [extract_value(v) for v in value['L']]
            elif 'M' in value:  # Map
                readable_item[key] = {k: extract_value(v) for k, v in value['M'].items()}

        # Display all fields
        for key, value in sorted(readable_item.items()):
            if key == 'url':
                print(f"🔗 {key}: {value}")
            elif key == 'title':
                print(f"🎬 {key}: {value}")
            elif key == 'tags':
                print(f"🏷️  {key}: {value}")
            elif key == 'bfCategory':
                print(f"📁 {key}: {value}")
            elif key == 'bfSubcategory':
                print(f"📂 {key}: {value}")
            else:
                # Truncate long text fields for display
                if isinstance(value, str) and len(value) > 100:
                    print(f"   {key}: {value[:100]}...")
                else:
                    print(f"   {key}: {value}")

    # Check for genre information
    print(f"\n📈 GENRE ANALYSIS:")
    genre_fields = ['tags', 'bfSubcategory', 'genre', 'genres']
    for field in genre_fields:
        has_field = any(field in item for item in items)
        if has_field:
            print(f"   ✅ Field '{field}' exists in some items")
        else:
            print(f"   ❌ Field '{field}' not found")

def extract_value(dynamo_value):
    """Helper to extract value from DynamoDB format"""
    if 'S' in dynamo_value:
        return dynamo_value['S']
    elif 'N' in dynamo_value:
        return dynamo_value['N']
    elif 'BOOL' in dynamo_value:
        return dynamo_value['BOOL']
    elif 'SS' in dynamo_value:
        return dynamo_value['SS']
    elif 'L' in dynamo_value:
        return [extract_value(v) for v in dynamo_value['L']]
    elif 'M' in dynamo_value:
        return {k: extract_value(v) for k, v in dynamo_value['M'].items()}
    return None

def main():
    """Main execution"""
    # First, delete malformed URLs
    malformed_urls = delete_malformed_urls()

    # Then inspect Letterboxd items
    inspect_letterboxd_items()

if __name__ == "__main__":
    main()