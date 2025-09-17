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
    
    print("🔧 PROCESSING BATCH FEEDBACK ON TOP 9")
    print("=" * 50)
    
    # Top 9 URLs from pattern analysis
    candidate_urls = [
        "http://adarkroom.doublespeakgames.com/",           # 1 - desktopOnly
        "http://montoyaindustries.com/nomorekings/",        # 2 - active
        "http://lichess.org",                               # 3 - active (duplicate, handle separately)
        "https://drinkouts.com",                            # 4 - delete
        "https://www.choiceofgames.com/dragon/",           # 5 - active
        "http://iplayif.com/?story=http%3A%2F%2Fwww.ifarchive.org%2Fif-archive%2Fgames%2Fzcode%2Fzdungeon.z5", # 6 - delete
        "https://hexaknot.com",                            # 7 - active
        "https://ncase.me/trust/",                         # 8 - active
        "http://damn.dog/"                                 # 9 - active
    ]
    
    # Actions to perform
    mark_active = [9, 8, 7, 5, 3, 2]  # indices (1-based)
    delete_items = [6, 4]              # indices (1-based)
    mark_desktop = [1]                 # indices (1-based)
    
    print("\n🟢 MARKING GAMES AS ACTIVE")
    print("-" * 30)
    
    active_count = 0
    for idx in mark_active:
        url = candidate_urls[idx - 1]
        
        # Special handling for #3 (lichess) - it's already active, just confirm
        if idx == 3:
            print(f"   #{idx}. Lichess already active - skipping")
            continue
            
        try:
            response = dynamodb.update_item(
                TableName=TABLE_NAME,
                Key={'url': {'S': url}},
                UpdateExpression='SET #status = :active',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':active': {'S': 'active'}},
                ReturnValues='ALL_NEW'
            )
            
            title = response['Attributes'].get('title', {}).get('S', 'Unknown')[:40]
            print(f"   ✅ #{idx}. Marked ACTIVE: {title}")
            active_count += 1
            
        except Exception as e:
            print(f"   ❌ #{idx}. Error marking active: {e}")
    
    print("\n🗑️  DELETING GAMES")
    print("-" * 20)
    
    deleted_count = 0
    for idx in delete_items:
        url = candidate_urls[idx - 1]
        
        try:
            # Get title first
            response = dynamodb.get_item(
                TableName=TABLE_NAME,
                Key={'url': {'S': url}}
            )
            
            if 'Item' in response:
                title = response['Item'].get('title', {}).get('S', 'Unknown')[:40]
                
                dynamodb.delete_item(
                    TableName=TABLE_NAME,
                    Key={'url': {'S': url}}
                )
                print(f"   ✅ #{idx}. DELETED: {title}")
                deleted_count += 1
            else:
                print(f"   ⚠️  #{idx}. Not found in database")
                
        except Exception as e:
            print(f"   ❌ #{idx}. Error deleting: {e}")
    
    print("\n🖥️  MARKING AS DESKTOP ONLY")
    print("-" * 30)
    
    desktop_count = 0
    for idx in mark_desktop:
        url = candidate_urls[idx - 1]
        
        try:
            # Check if it exists first
            response = dynamodb.get_item(
                TableName=TABLE_NAME,
                Key={'url': {'S': url}}
            )
            
            if 'Item' in response:
                title = response['Item'].get('title', {}).get('S', 'Unknown')[:40]
                status = response['Item'].get('status', {}).get('S', 'unknown')
                print(f"   ✅ #{idx}. Already {status}: {title}")
            else:
                print(f"   ⚠️  #{idx}. Not found in database")
                
        except Exception as e:
            print(f"   ❌ #{idx}. Error checking: {e}")
    
    # Generate updated stats
    print("\n📊 UPDATED WEBGAMES STATUS STATS")
    print("=" * 50)
    
    try:
        # Count active
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
        active_total = response.get('Count', 0)
        
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
            active_total += response.get('Count', 0)
        
        # Count desktopOnly
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
        desktop_total = response.get('Count', 0)
        
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
            desktop_total += response.get('Count', 0)
        
        # Count inactive
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'},
                ':status': {'S': 'inactive'}
            }
        )
        inactive_total = response.get('Count', 0)
        
        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = dynamodb.query(
                TableName=TABLE_NAME,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': {'S': 'webgames'},
                    ':status': {'S': 'inactive'}
                },
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            inactive_total += response.get('Count', 0)
        
        total_webgames = active_total + desktop_total + inactive_total
        
        print(f"🟢 ACTIVE:      {active_total}")
        print(f"🖥️  DESKTOP ONLY: {desktop_total}")
        print(f"🔴 INACTIVE:    {inactive_total}")
        print(f"📊 TOTAL:       {total_webgames}")
        
        print(f"\n📈 CHANGES MADE:")
        print(f"   ✅ Marked {active_count} games as active")
        print(f"   🗑️  Deleted {deleted_count} games")
        
        # List current active games
        if active_total > 0:
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
            
            print(f"\n🎮 CURRENT ACTIVE WEBGAMES ({active_total}):")
            for i, item in enumerate(response.get('Items', [])):
                title = item.get('title', {}).get('S', 'Unknown')[:50]
                print(f"   {i+1}. {title}")
        
    except Exception as e:
        print(f"❌ Error generating stats: {e}")
    
    print("\n" + "=" * 50)
    print("✨ BATCH FEEDBACK PROCESSING COMPLETE!")

if __name__ == "__main__":
    main()