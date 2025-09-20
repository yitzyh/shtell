#!/usr/bin/env python3
"""
List all unique bfCategories in the DynamoDB webpages table
"""

import boto3
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

def list_all_categories():
    """List all unique bfCategories with counts"""
    print("🔍 Fetching all bfCategories from database...")
    print("=" * 60)

    # Dictionary to store category counts
    category_counts = defaultdict(int)
    all_categories = set()

    # Scan table to get all unique categories
    # Note: We need to scan because GSI doesn't give us unique partition keys directly
    paginator = dynamodb.get_paginator('scan')
    page_iterator = paginator.paginate(
        TableName=TABLE_NAME,
        ProjectionExpression='bfCategory, #status',
        ExpressionAttributeNames={'#status': 'status'}
    )

    total_items = 0
    for page in page_iterator:
        items = page.get('Items', [])
        total_items += len(items)

        for item in items:
            if 'bfCategory' in item and 'S' in item['bfCategory']:
                category = item['bfCategory']['S']
                if category:  # Only count non-empty categories
                    all_categories.add(category)

                    # Count by status
                    status = item.get('status', {}).get('S', 'unknown')
                    category_counts[f"{category}:{status}"] += 1

        print(f"  Processed {total_items} items...", end='\r')

    print(f"\n✅ Scanned {total_items} total items\n")

    # Sort categories and display
    sorted_categories = sorted(all_categories)

    print(f"📊 FOUND {len(sorted_categories)} UNIQUE CATEGORIES:")
    print("=" * 60)

    for category in sorted_categories:
        # Count active and inactive for this category
        active_count = category_counts.get(f"{category}:active", 0)
        inactive_count = category_counts.get(f"{category}:inactive", 0)
        total_count = active_count + inactive_count

        # Display with counts
        print(f"\n📁 {category}")
        print(f"   Total: {total_count:,} items")
        print(f"   ✅ Active: {active_count:,}")
        print(f"   ❌ Inactive: {inactive_count:,}")

        if total_count > 0:
            active_percent = (active_count / total_count) * 100
            print(f"   📈 Active rate: {active_percent:.1f}%")

    # Summary
    print("\n" + "=" * 60)
    print("📋 SUMMARY:")
    print(f"   Total categories: {len(sorted_categories)}")
    print(f"   Total items: {total_items:,}")

    # Show categories as a list for easy copying
    print("\n📝 CATEGORY LIST (for API testing):")
    print(sorted_categories)

    return sorted_categories

if __name__ == "__main__":
    list_all_categories()