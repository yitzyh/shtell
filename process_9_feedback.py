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
    
    print("🔧 PROCESSING FEEDBACK ON 9 CANDIDATES")
    print("=" * 50)
    
    # URLs from the 9 candidates
    candidate_urls = [
        "http://dotowheel.com",                             # 1 - delete
        "https://basketball.frvr.com",                      # 2 - active
        "https://boltkey.cz/yh20c/",                        # 3 - inactive
        "http://jdgmiles.github.io/Don-t-Make-a-Box/",     # 4 - delete
        "http://gameaboutsquares.com",                      # 5 - active
        "http://www.kingdomofloathing.com",                 # 6 - active
        "http://ludomancy.com/games/today.html",            # 7 - delete
        "http://zlap.io",                                   # 8 - active
        "https://rob1221.itch.io/chessformer"               # 9 - active
    ]
    
    # Step 1: Delete games 1, 4, 7
    print("\n🗑️  DELETING GAMES #1, #4, #7")
    print("-" * 30)
    
    delete_indices = [1, 4, 7]
    deleted_count = 0
    
    for idx in delete_indices:
        url = candidate_urls[idx - 1]
        
        try:
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
                print(f"   ⚠️  #{idx}. Not found: {url}")
                
        except Exception as e:
            print(f"   ❌ #{idx}. Error deleting: {e}")
    
    # Step 2: Mark games 2, 5, 6, 8, 9 as active
    print("\n🟢 MARKING GAMES #2, #5, #6, #8, #9 AS ACTIVE")
    print("-" * 40)
    
    active_indices = [2, 5, 6, 8, 9]
    activated_count = 0
    
    for idx in active_indices:
        url = candidate_urls[idx - 1]
        
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
            activated_count += 1
            
        except Exception as e:
            print(f"   ❌ #{idx}. Error marking active: {e}")
    
    # Step 3: Mark game 3 as inactive
    print("\n🔴 MARKING GAME #3 AS INACTIVE")
    print("-" * 30)
    
    url = candidate_urls[2]  # index 3 -> array index 2
    
    try:
        response = dynamodb.update_item(
            TableName=TABLE_NAME,
            Key={'url': {'S': url}},
            UpdateExpression='SET #status = :inactive',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':inactive': {'S': 'inactive'}},
            ReturnValues='ALL_NEW'
        )
        
        title = response['Attributes'].get('title', {}).get('S', 'Unknown')[:40]
        print(f"   ✅ #3. Marked INACTIVE: {title}")
        
    except Exception as e:
        print(f"   ❌ #3. Error marking inactive: {e}")
    
    # Step 4: Generate updated stats
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
        
        print(f"🟢 ACTIVE:       {active_total}")
        print(f"🖥️  DESKTOP ONLY: {desktop_total}")
        print(f"🔴 INACTIVE:     {inactive_total}")
        print(f"📊 TOTAL:        {total_webgames}")
        
        print(f"\n📈 CHANGES MADE:")
        print(f"   ✅ Activated {activated_count} games")
        print(f"   🗑️  Deleted {deleted_count} games")
        print(f"   🔴 Marked 1 game inactive")
        
        # List current active games
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
    print("✨ FEEDBACK PROCESSING COMPLETE!")

if __name__ == "__main__":
    main()