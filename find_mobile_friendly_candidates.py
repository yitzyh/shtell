#!/usr/bin/env python3
import boto3
from urllib.parse import urlparse
import re

# AWS credentials
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

# Mobile-friendly indicators (based on domain and game type)
MOBILE_FRIENDLY_DOMAINS = [
    'lichess.org',           # Chess - perfect for mobile
    'chess.com',             # Chess
    'eyezmaze.com',          # Japanese puzzle games
    'jayisgames.com',        # Game review site with good curation
    'gamejolt.com',          # Already tested as mobile-friendly
    'koalabeast.com',        # TagPro - works on mobile
    'foddy.net',             # Bennett Foddy games often mobile-friendly
    'superhotgame.com',      # Superhot demos
    'choiceofgames.com',     # Text-based games
    'ferryhalim.com',        # Simple artistic games
    'onemorelevel.com',      # Puzzle games
    'newcave.com',           # Simple games
    'lukethompsondesign.com' # Design-focused games
]

# Mobile-friendly game type keywords
MOBILE_FRIENDLY_KEYWORDS = [
    'puzzle', 'chess', 'card', 'word', 'trivia', 'quiz', 'simple', 'tap', 'click',
    'sudoku', 'solitaire', 'match', 'tetris', 'tower defense', 'incremental',
    'clicker', 'idle', 'text', 'story', 'choose', 'decision', 'exploration',
    'platformer', 'jump', 'run', 'avoid', 'collect', 'minimalist', 'zen'
]

# Desktop-only red flags
DESKTOP_RED_FLAGS = [
    'multiplayer', 'mmo', 'fps', 'rts', 'strategy', 'complex', 'keyboard',
    'mouse', 'wasd', 'arrow keys', 'hotkeys', 'shortcut', 'right click',
    'download', 'install', 'exe', 'windows', 'mac', 'steam', 'unity',
    'webgl', '3d', 'heavy', 'performance', 'graphics card', 'memory'
]

def score_mobile_compatibility(url, title, domain):
    """Score a game's mobile compatibility (higher = more mobile-friendly)"""
    score = 0
    reasons = []
    
    url_lower = url.lower()
    title_lower = title.lower()
    domain_lower = domain.lower()
    
    # Domain scoring (high confidence)
    if any(friendly_domain in domain_lower for friendly_domain in MOBILE_FRIENDLY_DOMAINS):
        score += 10
        matching_domain = next(domain for domain in MOBILE_FRIENDLY_DOMAINS if domain in domain_lower)
        reasons.append(f"✅ Mobile-friendly domain: {matching_domain}")
    
    # Title/URL keyword scoring
    mobile_keywords_found = [kw for kw in MOBILE_FRIENDLY_KEYWORDS if kw in title_lower or kw in url_lower]
    if mobile_keywords_found:
        score += len(mobile_keywords_found) * 2
        reasons.append(f"✅ Mobile-friendly keywords: {', '.join(mobile_keywords_found[:3])}")
    
    # Red flag penalties
    red_flags_found = [flag for flag in DESKTOP_RED_FLAGS if flag in title_lower or flag in url_lower]
    if red_flags_found:
        score -= len(red_flags_found) * 3
        reasons.append(f"❌ Desktop red flags: {', '.join(red_flags_found[:2])}")
    
    # Simple domain bonus (single word domains often have simple games)
    if '.' in domain and len(domain.split('.')[0]) <= 8 and not any(x in domain for x in ['itch', 'github', 'deviantart']):
        score += 2
        reasons.append("✅ Simple domain name")
    
    # Penalize itch.io subdomains (mostly desktop games)
    if 'itch.io' in domain_lower:
        score -= 5
        reasons.append("❌ Itch.io platform (often desktop)")
    
    # Bonus for short, simple titles
    if len(title) <= 30 and not any(complex_word in title_lower for complex_word in ['simulator', 'management', 'strategy']):
        score += 1
        reasons.append("✅ Simple title")
    
    return score, reasons

def main():
    dynamodb = boto3.client(
        'dynamodb',
        region_name=REGION,
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY
    )
    
    print("🔍 FINDING MOBILE-FRIENDLY CANDIDATES")
    print("=" * 70)
    
    # Get all desktopOnly webgames
    print("📊 Querying desktopOnly webgames...")
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
    
    print(f"Found {len(all_games)} desktopOnly games to analyze")
    
    # Score each game
    print(f"\n🧮 Scoring mobile compatibility...")
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
        
        score, reasons = score_mobile_compatibility(url, title, domain)
        
        scored_games.append({
            'score': score,
            'url': url,
            'title': title,
            'domain': domain,
            'reasons': reasons,
            'item': item
        })
    
    # Sort by score (highest first)
    scored_games.sort(key=lambda x: x['score'], reverse=True)
    
    # Show top 10 candidates
    print(f"\n🎯 TOP 10 MOBILE-FRIENDLY CANDIDATES:")
    print("=" * 70)
    
    for i, game in enumerate(scored_games[:10]):
        print(f"\n{i+1:2d}. SCORE: {game['score']:2d} | {game['domain']}")
        print(f"    {game['title'][:60]}")
        print(f"    {game['url']}")
        for reason in game['reasons'][:2]:  # Show top 2 reasons
            print(f"    {reason}")
    
    # Show some context - next 10
    print(f"\n📊 NEXT 10 CANDIDATES (for context):")
    print("-" * 50)
    for i, game in enumerate(scored_games[10:20]):
        print(f"{i+11:2d}. Score {game['score']:2d} | {game['domain']:20} | {game['title'][:30]}")
    
    # Domain summary
    print(f"\n📈 MOBILE-FRIENDLY DOMAINS FOUND:")
    print("-" * 40)
    domain_scores = {}
    for game in scored_games:
        domain = game['domain']
        if domain not in domain_scores:
            domain_scores[domain] = []
        domain_scores[domain].append(game['score'])
    
    # Calculate average scores per domain
    domain_averages = []
    for domain, scores in domain_scores.items():
        avg_score = sum(scores) / len(scores)
        domain_averages.append((domain, avg_score, len(scores)))
    
    domain_averages.sort(key=lambda x: x[1], reverse=True)
    
    for domain, avg_score, count in domain_averages[:10]:
        print(f"{domain:25} Avg: {avg_score:4.1f} ({count} games)")
    
    # Save top 10 URLs for easy testing
    print(f"\n💾 Saving top 10 URLs for testing...")
    with open('/Users/isaacherskowitz/Swift/_DumFlow/DumFlow/top_10_mobile_candidates.txt', 'w') as f:
        for i, game in enumerate(scored_games[:10]):
            f.write(f"{i+1}. {game['title']}\n")
            f.write(f"   {game['url']}\n")
            f.write(f"   Score: {game['score']} | Domain: {game['domain']}\n\n")
    
    print(f"✅ Saved to top_10_mobile_candidates.txt")
    
    print(f"\n" + "=" * 70)
    print("🎯 READY FOR TESTING!")
    print("Test these top 10 games on your mobile device and mark good ones as 'active'")

if __name__ == "__main__":
    main()