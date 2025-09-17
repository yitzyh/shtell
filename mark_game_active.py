#!/usr/bin/env python3
import boto3
import sys

# AWS credentials
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

def mark_game_active(url):
    """Mark a specific game as active by URL"""
    dynamodb = boto3.client(
        'dynamodb',
        region_name=REGION,
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY
    )
    
    try:
        # Update the game status
        response = dynamodb.update_item(
            TableName=TABLE_NAME,
            Key={'url': {'S': url}},
            UpdateExpression='SET #status = :active',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':active': {'S': 'active'}},
            ReturnValues='ALL_NEW'
        )
        
        # Get the title for confirmation
        title = response['Attributes'].get('title', {}).get('S', 'Unknown')
        
        print(f"✅ SUCCESS: Marked as ACTIVE")
        print(f"   Title: {title}")
        print(f"   URL: {url}")
        
        return True
        
    except Exception as e:
        print(f"❌ ERROR: Could not mark game as active")
        print(f"   URL: {url}")
        print(f"   Error: {e}")
        return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 mark_game_active.py <game_url>")
        print("\nExample:")
        print("python3 mark_game_active.py http://lichess.org/")
        print("\nOr mark by number from top 10 list:")
        print("python3 mark_game_active.py 1")
        sys.exit(1)
    
    input_param = sys.argv[1]
    
    # Check if input is a number (referring to top 10 list)
    if input_param.isdigit():
        game_number = int(input_param)
        if 1 <= game_number <= 10:
            # Map numbers to URLs from our top 10 list
            top_10_urls = [
                "http://lichess.org/",
                "http://gamejolt.com/games/puzzle/lexicopolis-a-b-city/14954/",
                "http://lichess.org",
                "http://www.eyezmaze.com/eyezblog_en/blog/2009/06/grow_ver3_remake.html",
                "http://en.lichess.org/jhfraiofaioyhviozafop",
                "http://www.eyezmaze.com/eyezblog_en/blog/2013/03/grow_maze_game.html",
                "http://www.lukethompsondesign.com/games/planethopper/",
                "http://www.newcave.com/game/?id=3500",
                "http://www.eyezmaze.com/eyezblog_en/blog/2005/09/grow_cube.html#monster",
                "http://www.newcave.com/game/soul-searchin"
            ]
            
            url = top_10_urls[game_number - 1]
            print(f"🎯 Marking top 10 candidate #{game_number} as active...")
        else:
            print(f"❌ Invalid number. Please use 1-10 for top 10 candidates.")
            sys.exit(1)
    else:
        url = input_param
        print(f"🎯 Marking game as active...")
    
    success = mark_game_active(url)
    
    if success:
        # Show current active count
        dynamodb = boto3.client(
            'dynamodb',
            region_name=REGION,
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY
        )
        
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
            print(f"\n📊 Total active webgames: {active_count}")
            
        except:
            print(f"\n📊 Game marked active (count check failed)")
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()