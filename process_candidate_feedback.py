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
    
    print("🔧 PROCESSING CANDIDATE FEEDBACK")
    print("=" * 50)
    
    # URLs from the top 5 candidates
    candidate_urls = {
        1: "http://www.newcave.com/game/soul-searchin",           # delete
        2: "http://www.onemorelevel.com/game/where_is_cat",       # delete  
        3: "http://www.lukethompsondesign.com/games/typetrain/",  # delete
        4: "http://tagpro.koalabeast.com/",                       # keep desktopOnly
        5: "http://www.ferryhalim.com/orisinal/g3/bells.htm"      # delete
    }
    
    # Also check for duplicate URLs (same domains)
    domain_patterns = {
        1: "newcave.com",
        2: "onemorelevel.com",
        3: "lukethompsondesign.com",
        5: "ferryhalim.com"
    }
    
    # Step 1: Delete #1, #2, #3, #5 and any duplicates
    print("\n🗑️  DELETING CANDIDATES #1, #2, #3, #5 AND DUPLICATES")
    print("-" * 40)
    
    delete_urls = [candidate_urls[1], candidate_urls[2], candidate_urls[3], candidate_urls[5]]
    deleted_count = 0
    
    # First delete the specific URLs
    for url in delete_urls:
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
                print(f"   ✅ DELETED: {title}")
                deleted_count += 1
            else:
                print(f"   ⚠️  Not found: {url[:50]}")
                
        except Exception as e:
            print(f"   ❌ Error deleting {url[:50]}: {e}")
    
    # Now check for any other webpages with same domains
    print("\n🔍 Checking for duplicate domain entries...")
    
    # Get all webgames
    response = dynamodb.scan(
        TableName=TABLE_NAME,
        FilterExpression='bfCategory = :category',
        ExpressionAttributeValues={':category': {'S': 'webgames'}}
    )
    
    all_games = response.get('Items', [])
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.scan(
            TableName=TABLE_NAME,
            FilterExpression='bfCategory = :category',
            ExpressionAttributeValues={':category': {'S': 'webgames'}},
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        all_games.extend(response.get('Items', []))
    
    # Find and delete any remaining games from these domains
    for domain_num, domain in domain_patterns.items():
        domain_games = []
        for item in all_games:
            url = item.get('url', {}).get('S', '')
            if domain in url.lower():
                domain_games.append(item)
        
        if domain_games:
            print(f"\n   Found {len(domain_games)} more {domain} games to delete:")
            for game in domain_games:
                try:
                    url = game.get('url', {}).get('S', '')
                    title = game.get('title', {}).get('S', 'Unknown')[:40]
                    
                    dynamodb.delete_item(
                        TableName=TABLE_NAME,
                        Key={'url': {'S': url}}
                    )
                    print(f"      🗑️  DELETED: {title}")
                    deleted_count += 1
                    
                except Exception as e:
                    print(f"      ❌ Error deleting: {e}")
    
    # Step 2: Keep #4 as desktopOnly (it already is, just confirm)
    print("\n🖥️  KEEPING #4 AS desktopOnly")
    print("-" * 40)
    
    try:
        response = dynamodb.get_item(
            TableName=TABLE_NAME,
            Key={'url': {'S': candidate_urls[4]}}
        )
        
        if 'Item' in response:
            title = response['Item'].get('title', {}).get('S', 'Unknown')[:40]
            status = response['Item'].get('status', {}).get('S', 'unknown')
            print(f"   ✅ Confirmed: {title}")
            print(f"      Status: {status}")
        else:
            print(f"   ⚠️  Not found: {candidate_urls[4][:50]}")
            
    except Exception as e:
        print(f"   ❌ Error checking status: {e}")
    
    # Step 3: Generate updated stats
    print("\n📊 UPDATED WEBGAMES STATS")
    print("-" * 40)
    
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
        active_count = response.get('Count', 0)
        
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
        desktop_count = response.get('Count', 0)
        
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
        inactive_count = response.get('Count', 0)
        
        total_webgames = active_count + desktop_count + inactive_count
        
        print(f"   🟢 Active:      {active_count}")
        print(f"   🖥️  desktopOnly: {desktop_count}")
        print(f"   🔴 Inactive:    {inactive_count}")
        print(f"   📊 Total:       {total_webgames}")
        
        if active_count > 0:
            # List active games
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
            
            print("\n🎮 ACTIVE WEBGAMES:")
            for i, item in enumerate(response.get('Items', [])):
                title = item.get('title', {}).get('S', 'Unknown')[:50]
                print(f"   {i+1}. {title}")
        
    except Exception as e:
        print(f"   ❌ Error generating stats: {e}")
    
    print("\n" + "=" * 50)
    print("✨ FEEDBACK PROCESSING COMPLETE!")
    print(f"   🗑️  Deleted {deleted_count} games total")

if __name__ == "__main__":
    main()