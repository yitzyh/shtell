#!/usr/bin/env python3
"""
Fix Vercel Categories API - Demonstration Script
Shows the correct way to query all categories from DynamoDB
"""

import boto3
import json
from collections import defaultdict

# AWS Configuration (same as in bf_db_agent.py)
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

def get_all_categories_with_active_content():
    """
    Get all distinct categories that have active content
    This is what the Vercel API should be doing instead of hardcoding 5 categories
    """
    print("🔍 Querying DynamoDB for all categories with active content...")

    try:
        # Use the category-status-index GSI to efficiently get all categories with active content
        # Query for each status type to ensure we get all categories
        all_categories = set()

        # Query for active items across all categories using GSI
        paginator = dynamodb.get_paginator('scan')
        page_iterator = paginator.paginate(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            FilterExpression='attribute_exists(bfCategory) AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': {'S': 'active'}},
            ProjectionExpression='bfCategory'
        )

        for page in page_iterator:
            for item in page.get('Items', []):
                bf_category = item.get('bfCategory', {}).get('S')
                if bf_category:
                    all_categories.add(bf_category)

        # Also check for any categories that might have inactive but valid content
        # This ensures we don't miss categories that might temporarily have no active content
        page_iterator = paginator.paginate(
            TableName=TABLE_NAME,
            FilterExpression='attribute_exists(bfCategory)',
            ProjectionExpression='bfCategory'
        )

        for page in page_iterator:
            for item in page.get('Items', []):
                bf_category = item.get('bfCategory', {}).get('S')
                if bf_category:
                    all_categories.add(bf_category)

        categories_list = sorted(list(all_categories))

        print(f"✅ Found {len(categories_list)} categories:")
        for category in categories_list:
            print(f"   - {category}")

        return categories_list

    except Exception as e:
        print(f"❌ Error querying categories: {e}")
        return []

def get_categories_with_counts():
    """
    Get categories with their active item counts
    """
    print("\n📊 Getting category counts...")

    try:
        category_counts = defaultdict(int)

        # Scan for active items only
        paginator = dynamodb.get_paginator('scan')
        page_iterator = paginator.paginate(
            TableName=TABLE_NAME,
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

        print("Category counts (active content only):")
        for category, count in sorted(category_counts.items()):
            print(f"   {category:<15} {count:,} items")

        return dict(category_counts)

    except Exception as e:
        print(f"❌ Error getting category counts: {e}")
        return {}

def demonstrate_correct_api_response():
    """
    Show what the Vercel API should return
    """
    categories = get_all_categories_with_active_content()
    category_counts = get_categories_with_counts()

    # This is what the API should return
    correct_response = {
        "categories": categories
    }

    print(f"\n🎯 CORRECT API RESPONSE:")
    print("=" * 50)
    print(json.dumps(correct_response, indent=2))

    print(f"\n📝 CURRENT ISSUE:")
    print("=" * 50)
    current_hardcoded = ["books", "food", "movies", "technology", "wikipedia"]
    missing_categories = set(categories) - set(current_hardcoded)

    print(f"Current API returns: {current_hardcoded}")
    print(f"Missing categories: {list(missing_categories)}")
    print(f"Missing webgames? {'YES' if 'webgames' in missing_categories else 'NO'}")

    return correct_response

if __name__ == "__main__":
    print("🚀 VERCEL CATEGORIES API FIX DEMONSTRATION")
    print("=" * 60)

    result = demonstrate_correct_api_response()

    print(f"\n💡 SOLUTION:")
    print("=" * 50)
    print("The Vercel API backend should:")
    print("1. Query DynamoDB using the category-status-index GSI")
    print("2. Get all distinct bfCategory values where status='active'")
    print("3. Return the complete list instead of hardcoded categories")
    print("4. Consider caching the result with a reasonable TTL (e.g., 1 hour)")

    print(f"\n📋 IMPLEMENTATION NEEDED:")
    print("=" * 50)
    print("Replace the hardcoded categories array in the Vercel API with:")
    print("- DynamoDB scan/query to get all distinct bfCategory values")
    print("- Filter for items with status='active'")
    print("- Return sorted list of categories")