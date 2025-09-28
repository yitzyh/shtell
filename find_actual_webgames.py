#!/usr/bin/env python3
"""
Find the actual webgames in the database
They exist but don't have bfCategory set
"""

import boto3
from boto3.dynamodb.conditions import Attr

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('webpages')

print("🎮 FINDING ACTUAL WEBGAMES IN DATABASE")
print("=" * 60)

# Look for items with 'webgames' in the ID or source field
print("\n1️⃣ Items with 'webgames' in ID or source field:")
print("-" * 40)

try:
    response = table.scan(
        FilterExpression=Attr('id').contains('webgames') | Attr('source').contains('webgames'),
        Limit=10
    )

    print(f"Found {len(response['Items'])} items with 'webgames' in ID/source\n")

    for item in response['Items'][:5]:
        print(f"ID: {item.get('id', 'N/A')}")
        print(f"  title: {item.get('title', 'N/A')[:50]}...")
        print(f"  status: {item.get('status', 'MISSING')}")
        print(f"  bfCategory: {item.get('bfCategory', 'NOT SET')}")
        print(f"  category: {item.get('category', 'NOT SET')}")
        print(f"  source: {item.get('source', 'NOT SET')}")
        print()

except Exception as e:
    print(f"Error: {e}")

# Count how many have bfCategory set
print("\n2️⃣ Checking bfCategory field for webgames:")
print("-" * 40)

try:
    # Get all items with webgames in ID
    webgames_items = []
    last_key = None

    while True:
        if last_key:
            response = table.scan(
                FilterExpression=Attr('id').contains('webgames'),
                ExclusiveStartKey=last_key
            )
        else:
            response = table.scan(
                FilterExpression=Attr('id').contains('webgames')
            )

        webgames_items.extend(response['Items'])
        last_key = response.get('LastEvaluatedKey')

        if not last_key:
            break

    print(f"Total items with 'webgames' in ID: {len(webgames_items)}")

    # Analyze bfCategory field
    has_bf_category = 0
    bf_category_values = {}
    status_counts = {}

    for item in webgames_items:
        # Check bfCategory
        bf_cat = item.get('bfCategory', None)
        if bf_cat:
            has_bf_category += 1
            bf_category_values[bf_cat] = bf_category_values.get(bf_cat, 0) + 1

        # Count status
        status = item.get('status', 'NO_STATUS')
        status_counts[status] = status_counts.get(status, 0) + 1

    print(f"Items WITH bfCategory set: {has_bf_category}")
    print(f"Items WITHOUT bfCategory: {len(webgames_items) - has_bf_category}")

    if bf_category_values:
        print(f"\nbfCategory values found:")
        for cat, count in bf_category_values.items():
            print(f"  '{cat}': {count} items")
    else:
        print("\n❌ NONE of the webgames have bfCategory set!")

    print(f"\nStatus distribution:")
    for status, count in sorted(status_counts.items()):
        print(f"  {status}: {count}")

except Exception as e:
    print(f"Error: {e}")

# Check if there's a different field being used
print("\n3️⃣ Checking other category fields:")
print("-" * 40)

try:
    sample_game = None
    for item in webgames_items[:1]:
        sample_game = item
        print(f"Sample webgame item fields:")
        for key in sorted(item.keys()):
            value = str(item[key])[:100]
            print(f"  {key}: {value}...")

except Exception as e:
    print(f"Error: {e}")

print("\n" + "=" * 60)
print("SOLUTION: The webgames items exist but don't have bfCategory='webgames' set!")
print("They need to be updated to add the bfCategory field.")
print("=" * 60)