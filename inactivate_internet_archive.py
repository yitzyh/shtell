#!/usr/bin/env python3
"""
Quick script to inactivate ALL internet-archive sources
"""

import boto3
import sys

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

def find_all_internet_archive_sources():
    """Find all sources that start with internet-archive"""
    print("🔍 Scanning for all internet-archive sources...")

    sources = set()
    response = dynamodb.scan(
        TableName=TABLE_NAME,
        ProjectionExpression='#source',
        ExpressionAttributeNames={'#source': 'source'}
    )

    for item in response.get('Items', []):
        source = item.get('source', {}).get('S', '')
        if source.startswith('internet-archive'):
            sources.add(source)

    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.scan(
            TableName=TABLE_NAME,
            ProjectionExpression='#source',
            ExpressionAttributeNames={'#source': 'source'},
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        for item in response.get('Items', []):
            source = item.get('source', {}).get('S', '')
            if source.startswith('internet-archive'):
                sources.add(source)

    return sorted(list(sources))

def inactivate_source(source_name):
    """Mark all items from a source as inactive"""
    print(f"⏳ Processing {source_name}...")

    # Query all items from this source
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='source-status-index',
        KeyConditionExpression='#source = :source',
        ExpressionAttributeNames={'#source': 'source'},
        ExpressionAttributeValues={':source': {'S': source_name}}
    )

    items = response.get('Items', [])
    updated_count = 0

    for item in items:
        url = item.get('url', {}).get('S', '')

        # Mark as inactive
        try:
            dynamodb.update_item(
                TableName=TABLE_NAME,
                Key={'url': {'S': url}},
                UpdateExpression='SET isActive = :inactive, #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':inactive': {'BOOL': False},
                    ':status': {'S': 'inactive'}
                }
            )
            updated_count += 1
        except Exception as e:
            print(f"   ⚠️  Error updating {url}: {e}")

    print(f"   ✅ Marked {updated_count} items as inactive")
    return updated_count

def main():
    """Main execution"""
    print("🗂️  INTERNET ARCHIVE CLEANUP")
    print("=" * 50)

    # Find all internet-archive sources
    sources = find_all_internet_archive_sources()

    print(f"\n📋 Found {len(sources)} internet-archive sources:")
    for source in sources:
        print(f"   • {source}")

    print(f"\n🚫 Marking ALL internet-archive content as INACTIVE...")

    total_inactivated = 0
    for source in sources:
        count = inactivate_source(source)
        total_inactivated += count

    print(f"\n✅ COMPLETE: {total_inactivated} total items marked as inactive")
    print(f"📊 Processed {len(sources)} internet-archive sources")

if __name__ == "__main__":
    main()