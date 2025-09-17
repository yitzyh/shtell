#!/usr/bin/env python3
import boto3

# AWS credentials
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

def main():
    dynamodb = boto3.client(
        'dynamodb',
        region_name=REGION,
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY
    )
    
    print("📊 WEBGAMES STATUS SUMMARY")
    print("=" * 50)
    
    # Get all webgames (active and inactive)
    response = dynamodb.scan(
        TableName=TABLE_NAME,
        FilterExpression='bfCategory = :category',
        ExpressionAttributeValues={':category': {'S': 'webgames'}}
    )
    
    all_items = response.get('Items', [])
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.scan(
            TableName=TABLE_NAME,
            FilterExpression='bfCategory = :category',
            ExpressionAttributeValues={':category': {'S': 'webgames'}},
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        all_items.extend(response.get('Items', []))
    
    print(f"Total webgames in database: {len(all_items)}")
    
    # Count by status
    status_counts = {'active': 0, 'inactive': 0}
    
    for item in all_items:
        status = item.get('status', {}).get('S', 'unknown')
        if status in status_counts:
            status_counts[status] += 1
    
    print(f"\n📈 STATUS BREAKDOWN:")
    print(f"  🟢 Active games:   {status_counts['active']}")
    print(f"  🔴 Inactive games: {status_counts['inactive']}")
    
    # Calculate what we removed
    total_games = status_counts['active'] + status_counts['inactive']
    removed_games = status_counts['inactive']
    
    print(f"\n🔧 CLEANUP SUMMARY:")
    print(f"  📊 Games we marked inactive: {removed_games}")
    print(f"  📱 Games remaining active:   {status_counts['active']}")
    print(f"  📉 Removal percentage:       {removed_games/total_games*100:.1f}%")
    
    print(f"\n" + "=" * 50)
    print("✨ Status count complete!")

if __name__ == "__main__":
    main()