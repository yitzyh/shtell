#!/usr/bin/env python3
import boto3
from urllib.parse import urlparse

# AWS credentials
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

def analyze_mobile_patterns(url, title, domain):
    """Refined scoring based on observed patterns"""
    score = 0
    
    url_lower = url.lower()
    title_lower = title.lower()
    domain_lower = domain.lower()
    
    # Chess games work excellently
    if any(chess_term in title_lower or chess_term in url_lower 
           for chess_term in ['chess', 'lichess']):
        score += 15
    
    # Text-based/choice games work well
    if any(text_term in title_lower 
           for text_term in ['choice of', 'text', 'story', 'choose', 'decision', 'interactive fiction']):
        score += 12
    
    # Simple puzzle games work
    if any(puzzle_term in title_lower 
           for puzzle_term in ['puzzle', 'grow', 'tontoko', 'simple', 'minimal']):
        score += 10
    
    # Complex mechanics don't work
    if any(complex_term in title_lower 
           for complex_term in ['multiplayer', 'capture the flag', 'typing', 'platformer', 'climb']):
        score -= 8
    
    # Point-and-click can be problematic
    if any(click_term in title_lower 
           for click_term in ['point', 'click', 'where is', 'find the']):
        score -= 5
    
    # Art/atmospheric games can be hit or miss
    if any(art_term in title_lower 
           for art_term in ['atmospheric', 'artistic', 'beautiful', 'exploration']):
        score -= 3
    
    # Proven working domains
    proven_domains = ['lichess.org', 'choiceofgames.com', 'eyezmaze.com']
    if any(proven in domain_lower for proven in proven_domains):
        score += 8
    
    # Single-purpose game sites often work better
    if domain_lower.count('.') == 1 and len(domain_lower.split('.')[0]) <= 8:
        score += 3
    
    # Avoid complex gaming platforms
    if any(platform in domain_lower 
           for platform in ['gamejolt', 'itch.io', 'newgrounds']):
        score -= 6
    
    # Short, clear titles tend to work better
    if len(title) <= 25:
        score += 2
    
    # Avoid overly descriptive titles
    if len(title) > 60:
        score -= 2
    
    # Mobile-friendly keywords
    mobile_keywords = ['tap', 'swipe', 'touch', 'mobile', 'phone', 'simple']
    if any(keyword in title_lower or keyword in url_lower for keyword in mobile_keywords):
        score += 5
    
    return score

def main():
    dynamodb = boto3.client(
        'dynamodb',
        region_name=REGION,
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY
    )
    
    # Get desktopOnly games
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
    
    all_games = response.get('Items', [])
    
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
        all_games.extend(response.get('Items', []))
    
    # Score each game
    scored_games = []
    
    for item in all_games:
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', '')
        
        # Extract domain
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            if domain.startswith('www.'):
                domain = domain[4:]
        except:
            domain = 'unknown'
        
        score = analyze_mobile_patterns(url, title, domain)
        
        scored_games.append({
            'score': score,
            'url': url,
            'title': title
        })
    
    # Sort by score (highest first)
    scored_games.sort(key=lambda x: x['score'], reverse=True)
    
    # Skip the first 9 we already tested, get the next 9
    next_9 = scored_games[9:18]
    
    print("Next 9 mobile-friendly candidates:")
    for i, game in enumerate(next_9):
        print(f"{i+1}. {game['url']}")

if __name__ == "__main__":
    main()