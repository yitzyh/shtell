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
    
    print("🔧 PROCESSING USER FEEDBACK ON TOP 10")
    print("=" * 50)
    
    # Top 10 URLs from previous analysis
    top_10_urls = [
        "http://lichess.org/",                                                           # 1 - mark active
        "http://gamejolt.com/games/puzzle/lexicopolis-a-b-city/14954/",                 # 2 - delete
        "http://lichess.org",                                                            # 3 - (not mentioned, keep as is)
        "http://www.eyezmaze.com/eyezblog_en/blog/2009/06/grow_ver3_remake.html",       # 4 - keep desktopOnly
        "http://en.lichess.org/jhfraiofaioyhviozafop",                                  # 5 - (not mentioned, keep as is)
        "http://www.eyezmaze.com/eyezblog_en/blog/2013/03/grow_maze_game.html",         # 6 - (not mentioned, keep as is)
        "http://www.lukethompsondesign.com/games/planethopper/",                        # 7 - delete
        "http://www.newcave.com/game/?id=3500",                                         # 8 - delete
        "http://www.eyezmaze.com/eyezblog_en/blog/2005/09/grow_cube.html#monster",      # 9 - (not mentioned, keep as is)
        "http://www.newcave.com/game/soul-searchin"                                     # 10 - (not mentioned, keep as is)
    ]
    
    actions = [
        (1, "active", "mark active"),
        (2, "delete", "delete"),
        (4, "desktopOnly", "keep desktopOnly"), 
        (7, "delete", "delete"),
        (8, "delete", "delete")
    ]
    
    success_count = 0
    
    for game_num, action, description in actions:
        url = top_10_urls[game_num - 1]
        print(f"\n🎯 Game #{game_num}: {description}")
        print(f"   URL: {url}")
        
        try:
            if action == "active":
                # Mark as active
                response = dynamodb.update_item(
                    TableName=TABLE_NAME,
                    Key={'url': {'S': url}},
                    UpdateExpression='SET #status = :active',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={':active': {'S': 'active'}},
                    ReturnValues='ALL_NEW'
                )
                title = response['Attributes'].get('title', {}).get('S', 'Unknown')[:40]
                print(f"   ✅ Marked ACTIVE: {title}")
                
            elif action == "delete":
                # Delete the item
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
                    print(f"   🗑️  DELETED: {title}")
                else:
                    print(f"   ⚠️  Item not found for deletion")
                    
            elif action == "desktopOnly":
                # Already desktopOnly, just confirm
                response = dynamodb.get_item(
                    TableName=TABLE_NAME,
                    Key={'url': {'S': url}}
                )
                
                if 'Item' in response:
                    title = response['Item'].get('title', {}).get('S', 'Unknown')[:40]
                    status = response['Item'].get('status', {}).get('S', 'unknown')
                    print(f"   ✅ Kept as {status}: {title}")
                else:
                    print(f"   ⚠️  Item not found")
            
            success_count += 1
            
        except Exception as e:
            print(f"   ❌ ERROR: {e}")
    
    print(f"\n📊 FEEDBACK PROCESSING COMPLETE:")
    print(f"   ✅ Successfully processed: {success_count}/{len(actions)} actions")
    
    # Check current active count
    try:
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
        print(f"   🟢 Current active webgames: {active_count}")
        
    except Exception as e:
        print(f"   ⚠️  Could not check active count: {e}")
    
    print(f"\n✨ Ready to find next 10 candidates!")

if __name__ == "__main__":
    main()