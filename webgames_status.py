#!/usr/bin/env python3
"""
Check status distribution of all webgames in the database
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

def check_webgames_status():
    """Check status distribution of all webgames"""
    print("🎮 WEBGAMES STATUS ANALYSIS")
    print("=" * 60)

    # Query all webgames using category-status-index
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :category',
        ExpressionAttributeValues={':category': {'S': 'webgames'}}
    )

    items = response.get('Items', [])

    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category',
            ExpressionAttributeValues={':category': {'S': 'webgames'}},
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        items.extend(response.get('Items', []))

    print(f"📊 Total webgames found: {len(items)}")
    print()

    # Analyze status distribution
    status_counts = defaultdict(int)
    mobile_friendly_counts = defaultdict(int)

    for item in items:
        # Status
        status = item.get('status', {}).get('S', 'unknown')
        status_counts[status] += 1

        # Mobile friendly flag
        mobile_friendly = item.get('mobileFriendly', {}).get('BOOL', None)
        if mobile_friendly is not None:
            mobile_key = 'mobile-friendly' if mobile_friendly else 'desktop-only'
            mobile_friendly_counts[mobile_key] += 1
        else:
            mobile_friendly_counts['unknown'] += 1

    # Display status breakdown
    print("📈 STATUS BREAKDOWN:")
    print("-" * 30)
    for status, count in sorted(status_counts.items()):
        percentage = (count / len(items)) * 100
        print(f"   {status:<15} {count:4d} ({percentage:5.1f}%)")

    print()
    print("📱 MOBILE COMPATIBILITY:")
    print("-" * 30)
    for mobile_type, count in sorted(mobile_friendly_counts.items()):
        percentage = (count / len(items)) * 100
        print(f"   {mobile_type:<15} {count:4d} ({percentage:5.1f}%)")

    # Show some examples of each status
    print()
    print("🔍 SAMPLE GAMES BY STATUS:")
    print("-" * 40)

    status_examples = defaultdict(list)
    for item in items:
        status = item.get('status', {}).get('S', 'unknown')
        title = item.get('title', {}).get('S', 'No Title')[:50]
        url = item.get('url', {}).get('S', '')
        mobile = item.get('mobileFriendly', {}).get('BOOL', None)

        if len(status_examples[status]) < 3:  # Only show 3 examples per status
            status_examples[status].append({
                'title': title,
                'url': url,
                'mobile': mobile
            })

    for status, examples in status_examples.items():
        print(f"\n🎯 {status.upper()} GAMES:")
        for i, game in enumerate(examples, 1):
            mobile_icon = "📱" if game['mobile'] else "🖥️" if game['mobile'] is False else "❓"
            print(f"   {i}. {mobile_icon} {game['title']}")
            print(f"      {game['url']}")

    return {
        'total': len(items),
        'status_distribution': dict(status_counts),
        'mobile_distribution': dict(mobile_friendly_counts)
    }

if __name__ == "__main__":
    check_webgames_status()