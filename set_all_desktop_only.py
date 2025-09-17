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
    
    print("🔧 SETTING ALL ACTIVE WEBGAMES TO 'desktopOnly'")
    print("=" * 60)
    
    # Query all active webgames using GSI
    print("📊 Querying active webgames...")
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :category AND #status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={
            ':category': {'S': 'webgames'},
            ':status': {'S': 'active'}
        }
    )
    
    all_active_games = response.get('Items', [])
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'},
                ':status': {'S': 'active'}
            },
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        all_active_games.extend(response.get('Items', []))
    
    print(f"Found {len(all_active_games)} active webgames to update")
    
    # Update each game to desktopOnly
    print(f"\n🔄 Updating games to 'desktopOnly' status...")
    updated_count = 0
    error_count = 0
    
    for i, item in enumerate(all_active_games):
        try:
            url_value = item['url']
            title = item.get('title', {}).get('S', 'Unknown')[:40]
            
            dynamodb.update_item(
                TableName=TABLE_NAME,
                Key={'url': url_value},
                UpdateExpression='SET #status = :desktop_only',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':desktop_only': {'S': 'desktopOnly'}}
            )
            
            updated_count += 1
            
            # Progress indicator every 50 updates
            if updated_count % 50 == 0:
                print(f"  ✅ Updated {updated_count}/{len(all_active_games)} games...")
            
        except Exception as e:
            error_count += 1
            print(f"  ❌ Error updating game {i+1}: {e}")
    
    print(f"\n📊 UPDATE COMPLETE:")
    print(f"  ✅ Successfully updated: {updated_count} games")
    print(f"  ❌ Errors: {error_count} games")
    
    # Verify the change
    print(f"\n🔍 Verifying changes...")
    
    # Check active count (should be 0)
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :category AND #status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={
            ':category': {'S': 'webgames'},
            ':status': {'S': 'active'}
        }
    )
    
    active_count = response.get('Count', 0)
    print(f"  🟢 Active webgames: {active_count} (should be 0)")
    
    # Check desktopOnly count (should be 310)
    try:
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'},
                ':status': {'S': 'desktopOnly'}
            }
        )
        
        desktop_count = response.get('Count', 0)
        
        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = dynamodb.query(
                TableName=TABLE_NAME,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': {'S': 'webgames'},
                    ':status': {'S': 'desktopOnly'}
                },
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            desktop_count += response.get('Count', 0)
        
        print(f"  🖥️  desktopOnly webgames: {desktop_count}")
        
    except Exception as e:
        print(f"  ⚠️  Could not query desktopOnly (GSI may need time to update): {e}")
    
    print(f"\n" + "=" * 60)
    print("✨ STATUS UPDATE COMPLETE!")
    print("📱 Your app will now show 0 webgames until you mark mobile-friendly ones as 'active'")
    print("🎯 Next step: Manually test games and mark good ones as status = 'active'")

if __name__ == "__main__":
    main()