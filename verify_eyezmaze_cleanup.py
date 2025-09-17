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
    
    print("🔍 VERIFYING EYEZMAZE CLEANUP")
    print("=" * 40)
    
    # Check for any remaining eyezmaze games
    response = dynamodb.scan(
        TableName=TABLE_NAME,
        FilterExpression='contains(#url, :domain)',
        ExpressionAttributeNames={'#url': 'url'},
        ExpressionAttributeValues={':domain': {'S': 'eyezmaze.com'}}
    )
    
    eyezmaze_games = response.get('Items', [])
    
    print(f"Found {len(eyezmaze_games)} eyezmaze games:")
    for i, item in enumerate(eyezmaze_games):
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', 'Unknown')
        status = item.get('status', {}).get('S', 'unknown')
        print(f"  {i+1}. [{status}] {title}")
        print(f"     {url}")
    
    if len(eyezmaze_games) == 1:
        print("✅ Cleanup successful - only Tontoko Family remains")
    else:
        print(f"⚠️  Expected 1 eyezmaze game, found {len(eyezmaze_games)}")

if __name__ == "__main__":
    main()