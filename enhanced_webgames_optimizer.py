#!/usr/bin/env python3
"""
Enhanced Webgames Mobile Optimizer
=================================

Advanced webgames optimization system building on existing mobile-friendly detection.
Includes intelligent batch processing, detailed compatibility analysis, and automated testing recommendations.

Features:
- Enhanced mobile compatibility scoring
- Batch activation of mobile-friendly games
- Domain pattern analysis and learning
- Quality assessment integration
- Automated testing queue generation

Author: Claude Code
Version: 2.0.0
Based on: find_mobile_friendly_candidates.py
"""

import boto3
from urllib.parse import urlparse
import re
import json
from datetime import datetime, timezone
from typing import Dict, List, Tuple, Any, Optional
import requests
from dataclasses import dataclass
import statistics

# Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

@dataclass
class GameCompatibility:
    """Represents a webgame's mobile compatibility analysis"""
    url: str
    title: str
    domain: str
    compatibility_score: int
    quality_score: int
    composite_score: float
    reasons: List[str]
    red_flags: List[str]
    domain_confidence: float
    recommended_action: str
    priority_level: str
    test_notes: str

# Enhanced mobile-friendly domains with confidence scores
ENHANCED_MOBILE_DOMAINS = {
    # Chess and Strategy - High Confidence
    'lichess.org': {'confidence': 0.95, 'category': 'chess', 'notes': 'Excellent mobile chess platform'},
    'chess.com': {'confidence': 0.90, 'category': 'chess', 'notes': 'Major chess platform with mobile app'},

    # Puzzle Games - High Confidence
    'eyezmaze.com': {'confidence': 0.85, 'category': 'puzzle', 'notes': 'Japanese puzzle games, simple controls'},
    'ferryhalim.com': {'confidence': 0.80, 'category': 'artistic', 'notes': 'Simple artistic games'},
    'newcave.com': {'confidence': 0.75, 'category': 'simple', 'notes': 'Simple browser games'},

    # Game Platforms - Medium-High Confidence
    'gamejolt.com': {'confidence': 0.70, 'category': 'platform', 'notes': 'Mixed platform, many HTML5 games'},
    'jayisgames.com': {'confidence': 0.65, 'category': 'curator', 'notes': 'Game curator, usually mobile-friendly picks'},
    'onemorelevel.com': {'confidence': 0.70, 'category': 'simple', 'notes': 'Simple game collections'},

    # Specific Developer/Publisher Sites - Medium Confidence
    'koalabeast.com': {'confidence': 0.60, 'category': 'specific', 'notes': 'TagPro developer, mixed compatibility'},
    'foddy.net': {'confidence': 0.65, 'category': 'indie', 'notes': 'Bennett Foddy games, often simple'},
    'superhotgame.com': {'confidence': 0.60, 'category': 'specific', 'notes': 'Superhot demos, may require mouse'},
    'choiceofgames.com': {'confidence': 0.85, 'category': 'text', 'notes': 'Text-based choice games'},
    'lukethompsondesign.com': {'confidence': 0.70, 'category': 'design', 'notes': 'Design-focused games'},

    # Educational/Simple Game Sites
    'mathplayground.com': {'confidence': 0.80, 'category': 'educational', 'notes': 'Educational games'},
    'coolmathgames.com': {'confidence': 0.75, 'category': 'educational', 'notes': 'Educational games platform'},
    'primarygames.com': {'confidence': 0.80, 'category': 'educational', 'notes': 'Primary school games'},
}

# Enhanced mobile-friendly keywords with weights
MOBILE_KEYWORDS = {
    # Core Mobile Game Types (High Weight)
    'puzzle': 4, 'match': 4, 'tap': 5, 'click': 4, 'touch': 5,
    'solitaire': 5, 'chess': 5, 'card': 4, 'sudoku': 5,

    # Simple Interaction Games (High Weight)
    'simple': 3, 'easy': 3, 'casual': 4, 'zen': 4, 'minimalist': 4,
    'one-button': 5, 'single-tap': 5, 'swipe': 5,

    # Game Mechanics (Medium-High Weight)
    'avoid': 3, 'collect': 3, 'jump': 3, 'run': 2, 'platformer': 2,
    'tower defense': 3, 'incremental': 4, 'clicker': 4, 'idle': 4,

    # Content Types (Medium Weight)
    'word': 3, 'trivia': 4, 'quiz': 4, 'text': 3, 'story': 3,
    'choose': 3, 'decision': 3, 'adventure': 2, 'rpg': 1,

    # Time-based (Medium Weight)
    'short': 3, 'quick': 3, 'minute': 3, 'instant': 3,
}

# Enhanced desktop red flags with penalty weights
DESKTOP_PENALTIES = {
    # Strong Desktop Indicators (High Penalty)
    'multiplayer': 5, 'mmo': 6, 'fps': 6, 'first-person': 5,
    'rts': 5, 'real-time strategy': 5, 'complex': 4,

    # Input Method Requirements (High Penalty)
    'keyboard': 6, 'mouse': 5, 'wasd': 6, 'arrow keys': 5,
    'hotkeys': 5, 'right click': 6, 'drag and drop': 4,
    'shortcut': 4, 'ctrl': 5, 'alt': 5,

    # Technical Requirements (High Penalty)
    'download': 6, 'install': 6, 'exe': 6, 'windows': 4, 'mac': 4,
    'steam': 5, 'unity': 3, 'unreal': 4, 'webgl': 2,

    # Performance/Graphics (Medium Penalty)
    '3d': 2, 'graphics card': 4, 'performance': 3, 'memory': 3,
    'heavy': 4, 'intensive': 4, 'high-end': 4,

    # Platform Indicators (Medium Penalty)
    'itch.io': 3, 'github.io': 2, 'newgrounds': 2,
    'flash': 5, 'shockwave': 5, 'java applet': 6,
}

class EnhancedWebgamesOptimizer:
    """Advanced webgames optimization system"""

    def __init__(self):
        self.dynamodb = boto3.client(
            'dynamodb',
            region_name=REGION,
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY
        )

        self.table = boto3.resource(
            'dynamodb',
            region_name=REGION,
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY
        ).Table(TABLE_NAME)

        # Track domain learning
        self.domain_patterns = {}

    def get_webgames(self, status: str = "desktopOnly") -> List[Dict[str, Any]]:
        """Get webgames by status with enhanced data"""
        try:
            response = self.dynamodb.query(
                TableName=TABLE_NAME,
                IndexName='category-status-index',
                KeyConditionExpression='bfCategory = :category AND #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':category': {'S': 'webgames'},
                    ':status': {'S': status}
                },
                ProjectionExpression='#url, title, domain, upvotes, interactions, tags, qualityScore, createdDate',
                ExpressionAttributeNames={'#url': 'url'}
            )

            items = response.get('Items', [])

            # Handle pagination
            while 'LastEvaluatedKey' in response:
                response = self.dynamodb.query(
                    TableName=TABLE_NAME,
                    IndexName='category-status-index',
                    KeyConditionExpression='bfCategory = :category AND #status = :status',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':category': {'S': 'webgames'},
                        ':status': {'S': status}
                    },
                    ProjectionExpression='#url, title, domain, upvotes, interactions, tags, qualityScore, createdDate',
                    ExpressionAttributeNames={'#url': 'url'},
                    ExclusiveStartKey=response['LastEvaluatedKey']
                )
                items.extend(response.get('Items', []))

            return items

        except Exception as e:
            print(f"❌ Error fetching webgames: {e}")
            return []

    def extract_game_features(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Extract and normalize game features for analysis"""
        url = item.get('url', {}).get('S', '')
        title = item.get('title', {}).get('S', '')
        domain = item.get('domain', {}).get('S', '')

        # Extract domain if not provided
        if not domain:
            try:
                parsed = urlparse(url)
                domain = parsed.netloc.lower()
                if domain.startswith('www.'):
                    domain = domain[4:]
            except:
                domain = 'unknown'

        # Normalize text for analysis
        text_content = f"{title} {url}".lower()

        # Extract quality metrics
        upvotes = int(item.get('upvotes', {}).get('N', '0'))
        interactions = int(item.get('interactions', {}).get('N', '0'))
        quality_score = int(item.get('qualityScore', {}).get('N', '5'))

        # Extract tags
        tags = []
        if 'tags' in item and item['tags'].get('L'):
            tags = [tag.get('S', '') for tag in item['tags']['L']]

        return {
            'url': url,
            'title': title,
            'domain': domain,
            'text_content': text_content,
            'upvotes': upvotes,
            'interactions': interactions,
            'quality_score': quality_score,
            'tags': tags,
            'item': item
        }

    def calculate_enhanced_compatibility_score(self, features: Dict[str, Any]) -> GameCompatibility:
        """Calculate enhanced mobile compatibility with detailed analysis"""
        domain = features['domain']
        text_content = features['text_content']
        title = features['title']

        score = 0
        reasons = []
        red_flags = []
        domain_confidence = 0.0

        # Domain Analysis (Enhanced)
        if domain in ENHANCED_MOBILE_DOMAINS:
            domain_info = ENHANCED_MOBILE_DOMAINS[domain]
            domain_bonus = int(domain_info['confidence'] * 15)  # Up to 15 points
            score += domain_bonus
            domain_confidence = domain_info['confidence']
            reasons.append(f"✅ Known mobile domain: {domain} ({domain_info['category']}) +{domain_bonus}")
        else:
            # Pattern-based domain analysis
            domain_score, domain_reason = self._analyze_unknown_domain(domain)
            score += domain_score
            if domain_reason:
                reasons.append(domain_reason)

        # Mobile Keywords Analysis (Enhanced)
        keyword_score = 0
        found_keywords = []
        for keyword, weight in MOBILE_KEYWORDS.items():
            if keyword in text_content:
                keyword_score += weight
                found_keywords.append(f"{keyword}(+{weight})")

        if found_keywords:
            score += keyword_score
            reasons.append(f"✅ Mobile keywords: {', '.join(found_keywords[:3])} +{keyword_score}")

        # Desktop Red Flags Analysis (Enhanced)
        penalty_score = 0
        found_penalties = []
        for penalty, weight in DESKTOP_PENALTIES.items():
            if penalty in text_content:
                penalty_score += weight
                found_penalties.append(f"{penalty}(-{weight})")
                red_flags.append(penalty)

        if found_penalties:
            score -= penalty_score
            reasons.append(f"❌ Desktop indicators: {', '.join(found_penalties[:2])} -{penalty_score}")

        # Quality Integration
        quality_bonus = min(5, features['quality_score'] - 5)  # Quality scores above 5 give bonus
        if quality_bonus > 0:
            score += quality_bonus
            reasons.append(f"✅ Quality bonus: +{quality_bonus}")

        # Engagement Metrics
        if features['upvotes'] > 50:
            score += 2
            reasons.append("✅ High engagement: +2")
        elif features['upvotes'] > 20:
            score += 1
            reasons.append("✅ Good engagement: +1")

        # Title Length Analysis (shorter usually better for mobile)
        if len(title) <= 20:
            score += 2
            reasons.append("✅ Short title (mobile-friendly): +2")
        elif len(title) <= 40:
            score += 1
            reasons.append("✅ Moderate title length: +1")

        # Calculate composite score (combines compatibility and quality)
        composite_score = score * 0.7 + features['quality_score'] * 0.3

        # Determine recommendation and priority
        if score >= 12 and len(red_flags) == 0:
            recommended_action = "ACTIVATE_HIGH_PRIORITY"
            priority_level = "HIGH"
            test_notes = "Strong mobile candidate - activate immediately"
        elif score >= 8 and len(red_flags) <= 1:
            recommended_action = "TEST_RECOMMENDED"
            priority_level = "MEDIUM"
            test_notes = "Good mobile candidate - test on device"
        elif score >= 5 and len(red_flags) <= 2:
            recommended_action = "TEST_CONDITIONAL"
            priority_level = "LOW"
            test_notes = "Marginal candidate - test if time permits"
        else:
            recommended_action = "KEEP_DESKTOP_ONLY"
            priority_level = "NONE"
            test_notes = "Poor mobile candidate - keep desktop only"

        return GameCompatibility(
            url=features['url'],
            title=features['title'],
            domain=features['domain'],
            compatibility_score=score,
            quality_score=features['quality_score'],
            composite_score=composite_score,
            reasons=reasons,
            red_flags=red_flags,
            domain_confidence=domain_confidence,
            recommended_action=recommended_action,
            priority_level=priority_level,
            test_notes=test_notes
        )

    def _analyze_unknown_domain(self, domain: str) -> Tuple[int, str]:
        """Analyze unknown domains for mobile-friendliness patterns"""
        score = 0
        reason = ""

        # Simple domain name bonus
        if '.' in domain:
            domain_parts = domain.split('.')
            main_domain = domain_parts[0]

            # Short domain names often indicate simple games
            if len(main_domain) <= 6:
                score += 3
                reason = f"✅ Short domain name ({main_domain}): +3"
            elif len(main_domain) <= 10:
                score += 1
                reason = f"✅ Moderate domain length: +1"

        # Platform penalties
        if 'itch.io' in domain:
            score -= 4
            reason = "❌ Itch.io platform (often desktop): -4"
        elif 'github.io' in domain or 'github.com' in domain:
            score -= 2
            reason = "❌ GitHub hosting (often experimental): -2"
        elif 'newgrounds.com' in domain:
            score -= 3
            reason = "❌ Newgrounds (often Flash/desktop): -3"

        return score, reason

    def analyze_all_webgames(self) -> List[GameCompatibility]:
        """Perform comprehensive analysis of all desktopOnly webgames"""
        print("🎮 ENHANCED WEBGAMES MOBILE OPTIMIZATION")
        print("=" * 70)

        # Get all desktopOnly webgames
        games = self.get_webgames("desktopOnly")
        print(f"📊 Found {len(games)} desktopOnly webgames to analyze")

        if not games:
            print("❌ No desktopOnly webgames found")
            return []

        print("🧮 Performing enhanced compatibility analysis...")

        # Analyze each game
        analyzed_games = []
        for game in games:
            features = self.extract_game_features(game)
            compatibility = self.calculate_enhanced_compatibility_score(features)
            analyzed_games.append(compatibility)

        # Sort by composite score (best candidates first)
        analyzed_games.sort(key=lambda x: x.composite_score, reverse=True)

        # Generate statistics
        self._generate_analysis_report(analyzed_games)

        return analyzed_games

    def _generate_analysis_report(self, analyzed_games: List[GameCompatibility]) -> None:
        """Generate comprehensive analysis report"""
        print(f"\n📊 ENHANCED ANALYSIS RESULTS:")
        print("=" * 50)

        # Overall statistics
        total_games = len(analyzed_games)
        high_priority = len([g for g in analyzed_games if g.priority_level == "HIGH"])
        medium_priority = len([g for g in analyzed_games if g.priority_level == "MEDIUM"])
        low_priority = len([g for g in analyzed_games if g.priority_level == "LOW"])

        print(f"📈 Total games analyzed: {total_games}")
        print(f"🟢 High priority candidates: {high_priority}")
        print(f"🟡 Medium priority candidates: {medium_priority}")
        print(f"🟠 Low priority candidates: {low_priority}")
        print(f"🔴 Keep desktop only: {total_games - high_priority - medium_priority - low_priority}")

        # Score distribution
        scores = [g.compatibility_score for g in analyzed_games]
        if scores:
            print(f"\n📊 COMPATIBILITY SCORE DISTRIBUTION:")
            print(f"  Average: {statistics.mean(scores):.1f}")
            print(f"  Median: {statistics.median(scores):.1f}")
            print(f"  Range: {min(scores)} to {max(scores)}")

        # Top 10 candidates
        print(f"\n🏆 TOP 10 MOBILE CANDIDATES:")
        print("-" * 70)
        for i, game in enumerate(analyzed_games[:10]):
            print(f"\n{i+1:2d}. SCORE: {game.compatibility_score:2d} | QUALITY: {game.quality_score} | {game.priority_level}")
            print(f"    {game.domain}")
            print(f"    {game.title[:60]}")
            print(f"    📝 {game.test_notes}")
            if game.reasons:
                print(f"    🔍 {game.reasons[0]}")  # Show primary reason

        # Domain analysis
        self._analyze_domain_patterns(analyzed_games)

    def _analyze_domain_patterns(self, analyzed_games: List[GameCompatibility]) -> None:
        """Analyze domain patterns to learn new mobile-friendly domains"""
        print(f"\n🏗️  DOMAIN PATTERN ANALYSIS:")
        print("-" * 40)

        domain_stats = {}
        for game in analyzed_games:
            domain = game.domain
            if domain not in domain_stats:
                domain_stats[domain] = {
                    'games': [],
                    'avg_score': 0,
                    'high_candidates': 0
                }
            domain_stats[domain]['games'].append(game)
            if game.priority_level in ['HIGH', 'MEDIUM']:
                domain_stats[domain]['high_candidates'] += 1

        # Calculate domain averages
        for domain, stats in domain_stats.items():
            scores = [g.compatibility_score for g in stats['games']]
            stats['avg_score'] = statistics.mean(scores) if scores else 0
            stats['count'] = len(stats['games'])

        # Show promising new domains
        promising_domains = [
            (domain, stats) for domain, stats in domain_stats.items()
            if domain not in ENHANCED_MOBILE_DOMAINS
            and stats['avg_score'] >= 6
            and stats['high_candidates'] >= 1
        ]

        if promising_domains:
            promising_domains.sort(key=lambda x: x[1]['avg_score'], reverse=True)
            print(f"🔍 PROMISING NEW DOMAINS DISCOVERED:")
            for domain, stats in promising_domains[:5]:
                print(f"  {domain:25} | Avg: {stats['avg_score']:4.1f} | Games: {stats['count']} | Good: {stats['high_candidates']}")
        else:
            print("No new promising domains discovered")

    def create_testing_queue(self, analyzed_games: List[GameCompatibility], priority_filter: str = "HIGH") -> None:
        """Create prioritized testing queue for manual verification"""
        print(f"\n📝 CREATING TESTING QUEUE ({priority_filter} PRIORITY)")
        print("=" * 50)

        if priority_filter == "ALL":
            queue_games = [g for g in analyzed_games if g.priority_level != "NONE"]
        else:
            queue_games = [g for g in analyzed_games if g.priority_level == priority_filter]

        if not queue_games:
            print(f"❌ No games found with {priority_filter} priority")
            return

        filename = f"/Users/isaacherskowitz/Swift/_DumFlow/DumFlow/testing_queue_{priority_filter.lower()}.txt"

        with open(filename, 'w') as f:
            f.write(f"WEBGAMES TESTING QUEUE - {priority_filter} PRIORITY\n")
            f.write("=" * 60 + "\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total games to test: {len(queue_games)}\n\n")

            for i, game in enumerate(queue_games):
                f.write(f"{i+1:2d}. COMPATIBILITY: {game.compatibility_score:2d} | QUALITY: {game.quality_score}\n")
                f.write(f"    TITLE: {game.title}\n")
                f.write(f"    URL: {game.url}\n")
                f.write(f"    DOMAIN: {game.domain}\n")
                f.write(f"    TEST NOTES: {game.test_notes}\n")
                f.write(f"    PRIMARY REASON: {game.reasons[0] if game.reasons else 'N/A'}\n")
                if game.red_flags:
                    f.write(f"    ⚠️  RED FLAGS: {', '.join(game.red_flags[:2])}\n")
                f.write("\n    [ ] TESTED  [ ] MOBILE-FRIENDLY  [ ] ACTIVATE  [ ] REJECT\n")
                f.write("    NOTES: _________________________________________________\n\n")

        print(f"✅ Testing queue saved to: {filename}")
        print(f"📱 {len(queue_games)} games ready for mobile testing")

    def batch_activate_games(self, game_urls: List[str]) -> Tuple[int, int]:
        """Batch activate mobile-friendly webgames"""
        print(f"\n🚀 BATCH ACTIVATING {len(game_urls)} WEBGAMES")
        print("-" * 40)

        success_count = 0
        error_count = 0

        for url in game_urls:
            try:
                self.table.update_item(
                    Key={'url': url},
                    UpdateExpression='SET #status = :active, updatedAt = :timestamp',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':active': 'active',
                        ':timestamp': datetime.now(timezone.utc).isoformat()
                    }
                )
                success_count += 1
                print(f"  ✅ Activated: {url}")

            except Exception as e:
                error_count += 1
                print(f"  ❌ Error activating {url}: {e}")

        print(f"\n📊 BATCH ACTIVATION COMPLETE:")
        print(f"  ✅ Successfully activated: {success_count}")
        print(f"  ❌ Errors: {error_count}")

        return success_count, error_count

    def run_optimization_workflow(self) -> Dict[str, Any]:
        """Run complete optimization workflow"""
        print("🤖 RUNNING COMPLETE WEBGAMES OPTIMIZATION WORKFLOW")
        print("=" * 70)

        # Step 1: Analyze all webgames
        analyzed_games = self.analyze_all_webgames()

        if not analyzed_games:
            return {'error': 'No games to analyze'}

        # Step 2: Create testing queues
        self.create_testing_queue(analyzed_games, "HIGH")
        self.create_testing_queue(analyzed_games, "MEDIUM")

        # Step 3: Auto-activate highest confidence games
        high_confidence_games = [
            g for g in analyzed_games
            if g.compatibility_score >= 15
            and g.domain_confidence >= 0.8
            and len(g.red_flags) == 0
        ]

        if high_confidence_games:
            print(f"\n🚀 AUTO-ACTIVATING {len(high_confidence_games)} HIGH-CONFIDENCE GAMES")
            urls_to_activate = [g.url for g in high_confidence_games]
            activated, errors = self.batch_activate_games(urls_to_activate)
        else:
            activated, errors = 0, 0

        # Generate summary
        results = {
            'total_analyzed': len(analyzed_games),
            'high_priority': len([g for g in analyzed_games if g.priority_level == "HIGH"]),
            'medium_priority': len([g for g in analyzed_games if g.priority_level == "MEDIUM"]),
            'auto_activated': activated,
            'activation_errors': errors,
            'testing_queues_created': 2,
        }

        print(f"\n✅ OPTIMIZATION WORKFLOW COMPLETED")
        print(f"📊 Summary: {results}")

        return results

def main():
    """Main execution function"""
    optimizer = EnhancedWebgamesOptimizer()

    print("🎮 ENHANCED WEBGAMES MOBILE OPTIMIZER")
    print("=" * 50)
    print("Choose an option:")
    print("1. Run full optimization workflow")
    print("2. Analyze compatibility only")
    print("3. Create testing queue")
    print("4. Batch activate games (from URLs)")
    print("5. Show domain statistics")

    choice = input("\nEnter choice (1-5): ").strip()

    if choice == '1':
        optimizer.run_optimization_workflow()

    elif choice == '2':
        analyzed_games = optimizer.analyze_all_webgames()
        print(f"\n✅ Analysis complete. Found {len(analyzed_games)} games.")

    elif choice == '3':
        analyzed_games = optimizer.analyze_all_webgames()
        priority = input("\nEnter priority level (HIGH/MEDIUM/ALL): ").strip().upper()
        optimizer.create_testing_queue(analyzed_games, priority)

    elif choice == '4':
        urls_input = input("\nEnter game URLs (comma-separated): ").strip()
        if urls_input:
            urls = [url.strip() for url in urls_input.split(',')]
            optimizer.batch_activate_games(urls)
        else:
            print("❌ No URLs provided")

    elif choice == '5':
        print("\n📊 DOMAIN STATISTICS:")
        for domain, info in ENHANCED_MOBILE_DOMAINS.items():
            print(f"  {domain:20} | Confidence: {info['confidence']:4.2f} | Category: {info['category']}")

    else:
        print("❌ Invalid choice")

if __name__ == "__main__":
    main()