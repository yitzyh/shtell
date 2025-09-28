#!/usr/bin/env python3
"""
Test why webgames category isn't appearing in the API
Let's verify the data structure and query logic
"""

import boto3
from boto3.dynamodb.conditions import Key, Attr
from collections import defaultdict

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('webpages')

print("🔍 DEBUGGING: Why webgames category isn't appearing")
print("=" * 60)

# Test 1: Check if webgames items actually have the correct structure
print("\n📋 TEST 1: Checking webgames data structure...")
try:
    response = table.scan(
        FilterExpression=Attr('bfCategory').eq('webgames'),
        Limit=5
    )

    print(f"Found {len(response['Items'])} webgames items (showing first 5)")
    for item in response['Items']:
        print(f"\n  ID: {item.get('id', 'N/A')}")
        print(f"  bfCategory: {item.get('bfCategory', 'MISSING')}")
        print(f"  status: {item.get('status', 'MISSING')}")
        print(f"  title: {item.get('title', 'N/A')[:50]}...")

except Exception as e:
    print(f"❌ Error: {e}")

# Test 2: Count active vs inactive webgames
print("\n📊 TEST 2: Counting webgames by status...")
try:
    # Get ALL webgames
    webgames = []
    last_key = None

    while True:
        if last_key:
            response = table.scan(
                FilterExpression=Attr('bfCategory').eq('webgames'),
                ExclusiveStartKey=last_key
            )
        else:
            response = table.scan(
                FilterExpression=Attr('bfCategory').eq('webgames')
            )

        webgames.extend(response['Items'])
        last_key = response.get('LastEvaluatedKey')

        if not last_key:
            break

    status_count = defaultdict(int)
    for game in webgames:
        status = game.get('status', 'no_status')
        status_count[status] += 1

    print(f"Total webgames with bfCategory='webgames': {len(webgames)}")
    for status, count in sorted(status_count.items()):
        print(f"  - {status}: {count}")

except Exception as e:
    print(f"❌ Error: {e}")

# Test 3: Check the exact query the API should be using
print("\n🔍 TEST 3: Simulating API query (bfCategory exists AND status='active')...")
try:
    categories_found = set()
    last_key = None
    total_items = 0

    while True:
        if last_key:
            response = table.scan(
                FilterExpression=Attr('bfCategory').exists() & Attr('status').eq('active'),
                ProjectionExpression='bfCategory',
                ExclusiveStartKey=last_key
            )
        else:
            response = table.scan(
                FilterExpression=Attr('bfCategory').exists() & Attr('status').eq('active'),
                ProjectionExpression='bfCategory'
            )

        for item in response['Items']:
            if 'bfCategory' in item:
                categories_found.add(item['bfCategory'])
                total_items += 1

        last_key = response.get('LastEvaluatedKey')

        if not last_key:
            break

    print(f"Scanned {total_items} active items with bfCategory")
    print(f"Found {len(categories_found)} distinct categories:")
    for cat in sorted(categories_found):
        print(f"  - {cat}")

    if 'webgames' not in categories_found:
        print("\n⚠️ WARNING: 'webgames' NOT found in active categories!")
    else:
        print("\n✅ 'webgames' IS in the active categories list")

except Exception as e:
    print(f"❌ Error: {e}")

# Test 4: Check if there's a case sensitivity issue
print("\n🔤 TEST 4: Checking for case sensitivity issues...")
try:
    response = table.scan(
        FilterExpression=Attr('status').eq('active'),
        ProjectionExpression='bfCategory',
        Limit=500
    )

    category_variations = defaultdict(int)
    for item in response['Items']:
        if 'bfCategory' in item:
            cat = item['bfCategory']
            if 'game' in cat.lower():
                category_variations[cat] += 1

    if category_variations:
        print("Found game-related categories:")
        for cat, count in category_variations.items():
            print(f"  - '{cat}': {count} items")
    else:
        print("No game-related categories found in active items")

except Exception as e:
    print(f"❌ Error: {e}")

# Test 5: Direct query for active webgames
print("\n🎮 TEST 5: Direct query for active webgames...")
try:
    response = table.scan(
        FilterExpression=Attr('bfCategory').eq('webgames') & Attr('status').eq('active'),
        Limit=10
    )

    print(f"Found {len(response['Items'])} active webgames (showing up to 10)")

    if response['Items']:
        for item in response['Items'][:3]:
            print(f"\n  Title: {item.get('title', 'N/A')[:60]}...")
            print(f"  URL: {item.get('url', 'N/A')[:60]}...")
            print(f"  Status: {item.get('status', 'N/A')}")
            print(f"  bfCategory: {item.get('bfCategory', 'N/A')}")
    else:
        print("❌ NO active webgames found!")
        print("\nLet's check what status values webgames actually have...")

        # Check non-active webgames
        response2 = table.scan(
            FilterExpression=Attr('bfCategory').eq('webgames'),
            Limit=10
        )

        if response2['Items']:
            print(f"\nFound {len(response2['Items'])} webgames (any status):")
            for item in response2['Items'][:3]:
                print(f"  - {item.get('title', 'N/A')[:40]}: status='{item.get('status', 'NONE')}'")

except Exception as e:
    print(f"❌ Error: {e}")

print("\n" + "=" * 60)
print("DIAGNOSIS COMPLETE")
print("=" * 60)