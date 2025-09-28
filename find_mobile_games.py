#!/usr/bin/env python3
"""
Find 3 most mobile-friendly games from each status category
"""

import boto3
from urllib.parse import urlparse
import re

# AWS Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

# Initialize DynamoDB client
dynamodb = boto3.client(
    'dynamodb',
    region_name=REGION,
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY
)

def score_mobile_compatibility(url: str, title: str) -> int:
    """Score mobile compatibility (0-100)"""
    score = 50

    # Parse domain
    domain = urlparse(url).netloc.lower()

    # Mobile-friendly domains
    mobile_friendly_domains = [
        'lichess.org', 'chess.com', 'eyezmaze.com',
        'gamejolt.com', 'koalabeast.com', 'choiceofgames.com',
        'itch.io', 'poki.com', 'crazygames.com'
    ]

    if any(friendly in domain for friendly in mobile_friendly_domains):
        score += 30

    # Check title/URL for mobile indicators
    mobile_keywords = [
        'puzzle', 'chess', 'card', 'simple', 'tap', 'click', 'touch',
        'casual', 'brain', 'logic', 'match', 'word', 'trivia', 'quiz'
    ]

    desktop_keywords = [
        'fps', 'mmo', 'keyboard', 'wasd', 'flash', 'unity', 'download',
        'shooter', 'strategy', 'rts', 'complex', 'hardcore'
    ]

    title_lower = title.lower()
    url_lower = url.lower()

    for keyword in mobile_keywords:
        if keyword in title_lower or keyword in url_lower:
            score += 8

    for keyword in desktop_keywords:
        if keyword in title_lower or keyword in url_lower:
            score -= 15

    # Bonus for short, simple titles
    if len(title.split()) <= 3:
        score += 10

    # Penalty for complex descriptions
    if len(title) > 100:
        score -= 10

    return max(0, min(100, score))

def find_best_mobile_games():
    """Find top 3 mobile-friendly games from each status"""
    print("🔍 FINDING BEST MOBILE GAMES BY STATUS")
    print("=" * 60)

    # Query all webgames
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :category',
        ExpressionAttributeValues={':category': {'S': 'webgames'}}
    )

    items = response.get('Items', [])

    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category',
            ExpressionAttributeValues={':category': {'S': 'webgames'}},
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        items.extend(response.get('Items', []))

    # Organize by status and score
    status_games = {
        'active': [],
        'desktopOnly': [],
        'inactive': []
    }

    for item in items:
        status = item.get('status', {}).get('S', 'unknown')
        if status not in status_games:
            continue

        title = item.get('title', {}).get('S', '')
        url = item.get('url', {}).get('S', '')

        # Score mobile compatibility
        mobile_score = score_mobile_compatibility(url, title)

        status_games[status].append({
            'title': title,
            'url': url,
            'mobile_score': mobile_score,
            'domain': urlparse(url).netloc
        })

    # Sort each status by mobile score and get top 3
    for status in status_games:
        status_games[status].sort(key=lambda x: x['mobile_score'], reverse=True)
        status_games[status] = status_games[status][:3]

    # Display results
    for status, games in status_games.items():
        print(f"\n🎯 TOP 3 MOBILE-FRIENDLY {status.upper()} GAMES:")
        print("-" * 50)

        for i, game in enumerate(games, 1):
            print(f"{i}. Score {game['mobile_score']:3d} | {game['title'][:50]}")
            print(f"   Domain: {game['domain']}")
            print(f"   URL: {game['url']}")
            print()

    return status_games

if __name__ == "__main__":
    find_best_mobile_games()