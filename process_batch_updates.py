#!/usr/bin/env python3
import boto3
from urllib.parse import urlparse

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
    
    print("🔧 PROCESSING BATCH UPDATES")
    print("=" * 50)
    
    # URLs from the candidate list (mapped to our previous top 10)
    candidate_urls = [
        "http://lichess.org",                                                            # 1 - keep as is
        "http://www.eyezmaze.com/eyezblog_en/blog/2009/06/grow_ver3_remake.html",       # 2 - delete
        "http://en.lichess.org/jhfraiofaioyhviozafop",                                  # 3 - delete
        "http://www.eyezmaze.com/eyezblog_en/blog/2013/03/grow_maze_game.html",         # 4 - delete
        "http://www.eyezmaze.com/eyezblog_en/blog/2005/09/grow_cube.html#monster",      # 5 - mark active (Choice of Zombies)
        "http://www.newcave.com/game/soul-searchin",                                    # 6 - keep as is
        "http://www.foddy.net/GIRP.html",                                               # 7 - delete
        "http://www.onemorelevel.com/game/where_is_cat",                                # 8 - keep as is
        "https://www.choiceofgames.com/zombies/?obama",                                 # 9 - this is actually #5 to mark active
        "http://www.lukethompsondesign.com/games/typetrain/"                            # 10 - keep as is
    ]
    
    # Actions to perform
    delete_urls = [
        candidate_urls[1],  # #2 - eyezmaze grow v3
        candidate_urls[2],  # #3 - chesspursuit  
        candidate_urls[3],  # #4 - eyezmaze grow maze
        candidate_urls[6],  # #7 - foddy.net GIRP
    ]
    
    mark_active_url = candidate_urls[8]  # #9 - Choice of Zombies (this is actually #5)
    
    # Step 1: Delete specified URLs
    print(f"\n🗑️  STEP 1: Deleting specified URLs")
    print("-" * 40)
    
    deleted_count = 0
    for url in delete_urls:
        try:
            # Get title first for confirmation
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
                print(f"   ⚠️  Not found: {url}")
                
        except Exception as e:
            print(f"   ❌ Error deleting {url}: {e}")
    
    # Step 2: Mark Choice of Zombies as active
    print(f"\n🟢 STEP 2: Marking Choice of Zombies as active")
    print("-" * 40)
    
    try:
        response = dynamodb.update_item(
            TableName=TABLE_NAME,
            Key={'url': {'S': mark_active_url}},
            UpdateExpression='SET #status = :active',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':active': {'S': 'active'}},
            ReturnValues='ALL_NEW'
        )
        
        title = response['Attributes'].get('title', {}).get('S', 'Unknown')
        print(f"   ✅ Marked ACTIVE: {title}")
        
    except Exception as e:
        print(f"   ❌ Error marking active: {e}")
    
    # Step 3: Add new eyezmaze game
    print(f"\n➕ STEP 3: Adding new eyezmaze game")
    print("-" * 40)
    
    new_game_url = "https://www.eyezmaze.com/game/tontoko_family.html"
    new_game_title = "Tontoko Family - EyezMaze Game"
    
    try:
        # Add the new item
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item={
                'url': {'S': new_game_url},
                'title': {'S': new_game_title},
                'bfCategory': {'S': 'webgames'},
                'status': {'S': 'active'},
                'domain': {'S': 'www.eyezmaze.com'},
                'source': {'S': 'manual_addition'}
            }
        )
        print(f"   ✅ ADDED: {new_game_title}")
        
    except Exception as e:
        print(f"   ❌ Error adding new game: {e}")
    
    # Step 4: Delete all other eyezmaze URLs
    print(f"\n🗑️  STEP 4: Deleting all other eyezmaze URLs")
    print("-" * 40)
    
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
    
    # Find eyezmaze URLs (excluding the new one)
    eyezmaze_urls = []
    for item in all_games:
        url = item.get('url', {}).get('S', '')
        if 'eyezmaze.com' in url.lower() and url != new_game_url:
            eyezmaze_urls.append(item)
    
    print(f"   Found {len(eyezmaze_urls)} other eyezmaze games to delete")
    
    deleted_eyezmaze = 0
    for item in eyezmaze_urls:
        try:
            url = item.get('url', {}).get('S', '')
            title = item.get('title', {}).get('S', 'Unknown')[:40]
            
            dynamodb.delete_item(
                TableName=TABLE_NAME,
                Key={'url': {'S': url}}
            )
            print(f"   🗑️  DELETED: {title}")
            deleted_eyezmaze += 1
            
        except Exception as e:
            print(f"   ❌ Error deleting eyezmaze game: {e}")
    
    # Step 5: Generate stats
    print(f"\n📊 STEP 5: Generating new webgames stats")
    print("-" * 40)
    
    try:
        # Count active webgames
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
            active_count += response.get('Count', 0)
        
        # Count desktopOnly webgames
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
        
        # Count inactive webgames
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
            inactive_count += response.get('Count', 0)
        
        total_webgames = active_count + desktop_count + inactive_count
        
        print(f"\n📊 WEBGAMES CATEGORY STATS:")
        print(f"   🟢 Active:      {active_count}")
        print(f"   🖥️  desktopOnly: {desktop_count}")
        print(f"   🔴 Inactive:    {inactive_count}")
        print(f"   📊 Total:       {total_webgames}")
        
        if active_count > 0:
            # Show active games
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
            
            print(f"\n🎮 ACTIVE WEBGAMES:")
            for i, item in enumerate(response.get('Items', [])):
                title = item.get('title', {}).get('S', 'Unknown')[:50]
                url = item.get('url', {}).get('S', '')[:60]
                print(f"   {i+1}. {title}")
                print(f"      {url}")
        
    except Exception as e:
        print(f"   ❌ Error generating stats: {e}")
    
    print(f"\n" + "=" * 50)
    print("✨ BATCH UPDATE COMPLETE!")
    print(f"📊 Summary:")
    print(f"   🗑️  Deleted {deleted_count + deleted_eyezmaze} games total")
    print(f"   ✅ Added 1 new eyezmaze game")
    print(f"   🟢 Marked 1 game as active")

if __name__ == "__main__":
    main()