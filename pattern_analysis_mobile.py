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
    reasons = []
    
    url_lower = url.lower()
    title_lower = title.lower()
    domain_lower = domain.lower()
    
    # POSITIVE PATTERNS (from what worked)
    
    # Chess games work excellently
    if any(chess_term in title_lower or chess_term in url_lower 
           for chess_term in ['chess', 'lichess']):
        score += 15
        reasons.append("✅ Chess game (proven mobile-friendly)")
    
    # Text-based/choice games work well
    if any(text_term in title_lower 
           for text_term in ['choice of', 'text', 'story', 'choose', 'decision', 'interactive fiction']):
        score += 12
        reasons.append("✅ Text/choice game (mobile-friendly)")
    
    # Simple puzzle games work (like eyezmaze)
    if any(puzzle_term in title_lower 
           for puzzle_term in ['puzzle', 'grow', 'tontoko', 'simple', 'minimal']):
        score += 10
        reasons.append("✅ Simple puzzle game")
    
    # NEGATIVE PATTERNS (from what failed)
    
    # Complex mechanics don't work
    if any(complex_term in title_lower 
           for complex_term in ['multiplayer', 'capture the flag', 'typing', 'platformer', 'climb']):
        score -= 8
        reasons.append("❌ Complex mechanics (observed failures)")
    
    # Point-and-click can be problematic on mobile
    if any(click_term in title_lower 
           for click_term in ['point', 'click', 'where is', 'find the']):
        score -= 5
        reasons.append("❌ Point-and-click (observed failures)")
    
    # Art/atmospheric games can be hit or miss
    if any(art_term in title_lower 
           for art_term in ['atmospheric', 'artistic', 'beautiful', 'exploration']):
        score -= 3
        reasons.append("⚠️ Artistic/atmospheric (mixed results)")
    
    # REFINED DOMAIN SCORING
    
    # Proven working domains
    proven_domains = ['lichess.org', 'choiceofgames.com', 'eyezmaze.com']
    if any(proven in domain_lower for proven in proven_domains):
        score += 8
        reasons.append("✅ Proven mobile domain")
    
    # Single-purpose game sites often work better
    if domain_lower.count('.') == 1 and len(domain_lower.split('.')[0]) <= 8:
        score += 3
        reasons.append("✅ Simple domain")
    
    # Avoid complex gaming platforms
    if any(platform in domain_lower 
           for platform in ['gamejolt', 'itch.io', 'newgrounds']):
        score -= 6
        reasons.append("❌ Gaming platform (often desktop-focused)")
    
    # TITLE ANALYSIS
    
    # Short, clear titles tend to work better
    if len(title) <= 25:
        score += 2
        reasons.append("✅ Concise title")
    
    # Avoid overly descriptive titles (often complex games)
    if len(title) > 60:
        score -= 2
        reasons.append("❌ Long descriptive title")
    
    # Look for mobile-friendly keywords
    mobile_keywords = ['tap', 'swipe', 'touch', 'mobile', 'phone', 'simple']
    if any(keyword in title_lower or keyword in url_lower for keyword in mobile_keywords):
        score += 5
        reasons.append("✅ Mobile-specific keywords")
    
    return score, reasons

def main():
    dynamodb = boto3.client(
        'dynamodb',
        region_name=REGION,
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY
    )
    
    print("🔍 PATTERN ANALYSIS FOR MOBILE COMPATIBILITY")
    print("=" * 70)
    
    print("📊 WHAT WORKED:")
    print("✅ lichess.org chess games - Simple, universal, touch-friendly")
    print("✅ choiceofgames.com text games - Reading + simple choices") 
    print("✅ eyezmaze.com puzzle games - Minimal, tap-based interaction")
    print()
    print("📊 WHAT FAILED:")
    print("❌ Complex multiplayer (TagPro)")
    print("❌ Point-and-click games (Where Is Cat)")
    print("❌ Typing games (Type Train)")
    print("❌ Art/exploration games (Soul Searchin)")
    print("❌ Orisinal games (unexpected - usually mobile-friendly)")
    
    # Get desktopOnly games for analysis
    print(f"\n🔍 Analyzing {290} desktopOnly games with refined patterns...")
    
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
    
    # Score each game with refined patterns
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
        
        score, reasons = analyze_mobile_patterns(url, title, domain)
        
        scored_games.append({
            'score': score,
            'url': url,
            'title': title,
            'domain': domain,
            'reasons': reasons
        })
    
    # Sort by score (highest first)
    scored_games.sort(key=lambda x: x['score'], reverse=True)
    
    # Show top 9 candidates
    print(f"\n🎯 TOP 9 MOBILE-COMPATIBLE CANDIDATES (REFINED ANALYSIS):")
    print("=" * 70)
    
    for i, game in enumerate(scored_games[:9]):
        print(f"\n{i+1}. SCORE: {game['score']:2d} | {game['domain']}")
        print(f"   {game['title'][:60]}")
        print(f"   {game['url']}")
        for reason in game['reasons'][:2]:  # Show top 2 reasons
            print(f"   {reason}")
    
    # Show some context - next best candidates
    print(f"\n📊 NEXT BEST CANDIDATES (for context):")
    print("-" * 50)
    for i, game in enumerate(scored_games[9:15]):
        print(f"{i+10:2d}. Score {game['score']:2d} | {game['domain']:25} | {game['title'][:30]}")
    
    # Pattern summary
    print(f"\n📈 PATTERN INSIGHTS:")
    print("-" * 40)
    
    # Count by type
    chess_games = len([g for g in scored_games[:20] if 'chess' in g['title'].lower()])
    text_games = len([g for g in scored_games[:20] if any(t in g['title'].lower() for t in ['choice', 'text', 'story'])])
    simple_games = len([g for g in scored_games[:20] if 'simple' in g['title'].lower()])
    
    print(f"Top 20 candidates include:")
    print(f"  🔸 {chess_games} chess games")
    print(f"  🔸 {text_games} text/choice games") 
    print(f"  🔸 {simple_games} explicitly 'simple' games")
    
    print(f"\n" + "=" * 70)
    print("🎯 RECOMMENDED TESTING ORDER:")
    print("Test these 9 games in order - they follow successful patterns!")

if __name__ == "__main__":
    main()