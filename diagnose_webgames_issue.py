#!/usr/bin/env python3
"""
Deep diagnosis of webgames data issue
Why does Test 2 find 23 active but Test 5 finds 0?
"""

import boto3
from boto3.dynamodb.conditions import Attr
import json

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('webpages')

print("🔬 DEEP DIAGNOSIS: Webgames Data Structure Issue")
print("=" * 60)

# First, let's see EXACTLY what the data looks like
print("\n1️⃣ EXAMINING RAW WEBGAMES DATA...")
print("-" * 40)

try:
    # Get a sample of webgames
    response = table.scan(
        FilterExpression=Attr('bfCategory').eq('webgames'),
        Limit=5
    )

    if response['Items']:
        print(f"Sample webgames items (first {len(response['Items'])}):\n")

        for i, item in enumerate(response['Items'], 1):
            print(f"Item {i}:")
            print(f"  ID: {item.get('id', 'MISSING')}")
            print(f"  bfCategory: '{item.get('bfCategory', 'MISSING')}'")
            print(f"  status: '{item.get('status', 'MISSING')}'")

            # Check for any weird characters or spaces
            status = item.get('status', '')
            bf_cat = item.get('bfCategory', '')

            print(f"  status length: {len(status)}")
            print(f"  status repr: {repr(status)}")
            print(f"  bfCategory length: {len(bf_cat)}")
            print(f"  bfCategory repr: {repr(bf_cat)}")

            # Check all fields
            print(f"  All fields: {list(item.keys())[:10]}...")
            print()
    else:
        print("❌ No webgames found with bfCategory='webgames'")

except Exception as e:
    print(f"Error: {e}")

# Now check for active status specifically
print("\n2️⃣ LOOKING FOR 'active' STATUS IN WEBGAMES...")
print("-" * 40)

try:
    # Get webgames that claim to be active
    active_count = 0
    inactive_count = 0
    other_status = {}

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

        for item in response['Items']:
            status = item.get('status', 'NO_STATUS')

            # Check exact status value
            if status == 'active':
                active_count += 1
                if active_count <= 3:
                    print(f"✅ Found active webgame: {item.get('title', 'N/A')[:50]}")
                    print(f"   ID: {item.get('id')}")
                    print(f"   status: '{status}' (repr: {repr(status)})")
            elif status == 'inactive':
                inactive_count += 1
            else:
                other_status[status] = other_status.get(status, 0) + 1

        last_key = response.get('LastEvaluatedKey')
        if not last_key:
            break

    print(f"\nStatus summary for webgames:")
    print(f"  active: {active_count}")
    print(f"  inactive: {inactive_count}")
    for status, count in sorted(other_status.items()):
        print(f"  {status}: {count}")

except Exception as e:
    print(f"Error: {e}")

# Let's try different query approaches
print("\n3️⃣ TESTING DIFFERENT QUERY APPROACHES...")
print("-" * 40)

try:
    # Approach 1: Two separate filters combined
    print("Approach 1: Attr('bfCategory').eq('webgames') & Attr('status').eq('active')")
    response1 = table.scan(
        FilterExpression=Attr('bfCategory').eq('webgames') & Attr('status').eq('active'),
        Limit=5
    )
    print(f"  Found: {len(response1['Items'])} items")

    # Approach 2: Check for existence first
    print("\nApproach 2: With attribute_exists checks")
    response2 = table.scan(
        FilterExpression=(
            Attr('bfCategory').exists() &
            Attr('status').exists() &
            Attr('bfCategory').eq('webgames') &
            Attr('status').eq('active')
        ),
        Limit=5
    )
    print(f"  Found: {len(response2['Items'])} items")

    # Approach 3: Just look for ANY item with both fields
    print("\nApproach 3: Any item with bfCategory='webgames' (no status filter)")
    response3 = table.scan(
        FilterExpression=Attr('bfCategory').eq('webgames'),
        Limit=20
    )

    status_values = set()
    for item in response3['Items']:
        status_values.add(item.get('status', 'NO_STATUS'))

    print(f"  Found {len(response3['Items'])} items")
    print(f"  Unique status values found: {sorted(status_values)}")

except Exception as e:
    print(f"Error: {e}")

# Final check: Look at the actual values
print("\n4️⃣ CHECKING ACTUAL STATUS VALUES...")
print("-" * 40)

try:
    # Get items that have 'active' in status field anywhere
    response = table.scan(
        FilterExpression=Attr('status').contains('active'),
        Limit=10
    )

    print(f"Items with 'active' anywhere in status field: {len(response['Items'])}")

    categories_with_active = set()
    for item in response['Items']:
        if 'bfCategory' in item:
            categories_with_active.add(item['bfCategory'])

    print(f"Categories with 'active' status: {sorted(categories_with_active)}")

    # Now check if webgames is among them
    if 'webgames' in categories_with_active:
        print("✅ webgames DOES have items with 'active' in status")
    else:
        print("❌ webgames does NOT have items with 'active' in status")

except Exception as e:
    print(f"Error: {e}")

print("\n" + "=" * 60)
print("DIAGNOSIS COMPLETE")
print("=" * 60)