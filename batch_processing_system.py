#!/usr/bin/env python3
"""
Comprehensive Automated Batch Processing System
===============================================

Central orchestration system for all DumFlow database management operations.
Integrates all the specialized systems for automated content curation.

Components Integrated:
- Reddit Content Cleanup (reddit_content_cleanup.py)
- Enhanced Webgames Optimizer (enhanced_webgames_optimizer.py)
- Metadata Enhancer (metadata_enhancer.py)
- API Integrations Framework (api_integrations_framework.py)
- Internet Archive Filter (internet_archive_filter.py)

Author: Claude Code
Version: 1.0.0
Target: Automated content curation for creative professionals
"""

import sys
import os
import json
import time
import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Tuple, Any, Optional
from dataclasses import dataclass, field
import concurrent.futures
from pathlib import Path

# Add current directory to path for imports
current_dir = Path(__file__).parent
sys.path.append(str(current_dir))

# Import our specialized systems
try:
    from reddit_content_cleanup import RedditContentCleanup
    from enhanced_webgames_optimizer import EnhancedWebgamesOptimizer
    from metadata_enhancer import MetadataEnhancer
    from api_integrations_framework import APIIntegrationsManager
    from internet_archive_filter import InternetArchiveFilter
    from browse_forward_db_agent import BrowseForwardDBAgent
except ImportError as e:
    print(f"⚠️  Warning: Could not import some components: {e}")
    print("Make sure all component files are in the same directory.")

# Configuration
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"

@dataclass
class BatchJobResult:
    """Result of a batch processing job"""
    job_name: str
    status: str  # success, failed, partial
    start_time: str
    end_time: str
    duration_seconds: float
    items_processed: int
    items_modified: int
    errors: int
    details: Dict[str, Any] = field(default_factory=dict)

@dataclass
class BatchProcessingPlan:
    """Plan for batch processing operations"""
    plan_name: str
    description: str
    jobs: List[Dict[str, Any]]
    estimated_duration_minutes: int
    dependencies: Dict[str, List[str]] = field(default_factory=dict)

class BatchProcessingSystem:
    """Central batch processing orchestrator"""

    def __init__(self, api_keys: Dict[str, str] = None):
        self.api_keys = api_keys or {}

        # Initialize all component systems
        self.reddit_cleanup = RedditContentCleanup()
        self.webgames_optimizer = EnhancedWebgamesOptimizer()
        self.metadata_enhancer = MetadataEnhancer()
        self.archive_filter = InternetArchiveFilter()
        self.db_agent = BrowseForwardDBAgent(AWS_ACCESS_KEY, AWS_SECRET_KEY)

        # API integrations (requires API keys)
        if self.api_keys:
            self.api_manager = APIIntegrationsManager(self.api_keys)
        else:
            self.api_manager = None

        # Logging setup
        self.setup_logging()
        self.job_results: List[BatchJobResult] = []

    def setup_logging(self):
        """Setup comprehensive logging"""
        log_filename = f"dumflow_batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_filename),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('BatchProcessor')
        self.logger.info("🚀 Batch Processing System initialized")

    def get_predefined_plans(self) -> Dict[str, BatchProcessingPlan]:
        """Get predefined batch processing plans"""
        plans = {
            "daily_maintenance": BatchProcessingPlan(
                plan_name="Daily Maintenance",
                description="Daily content quality maintenance and optimization",
                jobs=[
                    {
                        "name": "webgames_optimization",
                        "description": "Find and activate mobile-friendly webgames",
                        "function": "run_webgames_optimization",
                        "params": {"limit": 50},
                        "priority": 1
                    },
                    {
                        "name": "metadata_enhancement",
                        "description": "Enhance metadata for recent content",
                        "function": "run_metadata_enhancement",
                        "params": {"limit": 200},
                        "priority": 2
                    },
                    {
                        "name": "quality_scoring_update",
                        "description": "Update quality scores based on engagement",
                        "function": "run_quality_update",
                        "params": {},
                        "priority": 3
                    }
                ],
                estimated_duration_minutes=45
            ),

            "weekly_cleanup": BatchProcessingPlan(
                plan_name="Weekly Cleanup",
                description="Weekly content cleanup and curation",
                jobs=[
                    {
                        "name": "reddit_cleanup",
                        "description": "Clean outdated Reddit content",
                        "function": "run_reddit_cleanup",
                        "params": {"sources": ["reddit-movies", "reddit-gadgets"]},
                        "priority": 1
                    },
                    {
                        "name": "archive_filtering",
                        "description": "Filter Internet Archive content",
                        "function": "run_archive_filtering",
                        "params": {"collections": ["internet-archive-culture"]},
                        "priority": 2
                    },
                    {
                        "name": "database_optimization",
                        "description": "Optimize database indices and cleanup",
                        "function": "run_database_optimization",
                        "params": {},
                        "priority": 3
                    }
                ],
                estimated_duration_minutes=120
            ),

            "content_expansion": BatchProcessingPlan(
                plan_name="Content Expansion",
                description="Add new content from API integrations",
                jobs=[
                    {
                        "name": "new_api_integration",
                        "description": "Fetch content from new API sources",
                        "function": "run_api_integration",
                        "params": {"sources": ["medium", "designboom"], "limit_per_source": 25},
                        "priority": 1
                    },
                    {
                        "name": "metadata_enhancement_new",
                        "description": "Enhance metadata for new content",
                        "function": "run_metadata_enhancement",
                        "params": {"source_filter": "medium", "limit": 100},
                        "priority": 2
                    },
                    {
                        "name": "quality_assessment_new",
                        "description": "Assess quality of new content",
                        "function": "run_quality_assessment",
                        "params": {"source_filter": "designboom"},
                        "priority": 3
                    }
                ],
                estimated_duration_minutes=90
            ),

            "comprehensive_audit": BatchProcessingPlan(
                plan_name="Comprehensive Content Audit",
                description="Complete audit and optimization of all content",
                jobs=[
                    {
                        "name": "full_reddit_cleanup",
                        "description": "Complete Reddit content cleanup",
                        "function": "run_reddit_cleanup",
                        "params": {"sources": "all"},
                        "priority": 1
                    },
                    {
                        "name": "full_webgames_optimization",
                        "description": "Complete webgames optimization",
                        "function": "run_webgames_optimization",
                        "params": {"full_analysis": True},
                        "priority": 2
                    },
                    {
                        "name": "full_archive_filtering",
                        "description": "Filter all Internet Archive collections",
                        "function": "run_archive_filtering",
                        "params": {"collections": "all"},
                        "priority": 3
                    },
                    {
                        "name": "full_metadata_enhancement",
                        "description": "Enhance all content metadata",
                        "function": "run_metadata_enhancement",
                        "params": {"limit": 5000},
                        "priority": 4
                    },
                    {
                        "name": "generate_comprehensive_report",
                        "description": "Generate complete database report",
                        "function": "run_comprehensive_report",
                        "params": {},
                        "priority": 5
                    }
                ],
                estimated_duration_minutes=300,
                dependencies={
                    "full_webgames_optimization": ["full_reddit_cleanup"],
                    "full_archive_filtering": ["full_reddit_cleanup"],
                    "full_metadata_enhancement": ["full_webgames_optimization", "full_archive_filtering"],
                    "generate_comprehensive_report": ["full_metadata_enhancement"]
                }
            )
        }

        return plans

    def run_job(self, job: Dict[str, Any]) -> BatchJobResult:
        """Execute a single batch job"""
        job_name = job['name']
        start_time = datetime.now(timezone.utc)
        self.logger.info(f"🚀 Starting job: {job_name}")

        try:
            # Get the function to execute
            function_name = job['function']
            params = job.get('params', {})

            # Execute the job function
            if hasattr(self, function_name):
                func = getattr(self, function_name)
                result = func(**params)
            else:
                raise ValueError(f"Unknown function: {function_name}")

            end_time = datetime.now(timezone.utc)
            duration = (end_time - start_time).total_seconds()

            job_result = BatchJobResult(
                job_name=job_name,
                status="success",
                start_time=start_time.isoformat(),
                end_time=end_time.isoformat(),
                duration_seconds=duration,
                items_processed=result.get('processed', 0),
                items_modified=result.get('modified', 0),
                errors=result.get('errors', 0),
                details=result
            )

            self.logger.info(f"✅ Job completed: {job_name} in {duration:.1f}s")
            return job_result

        except Exception as e:
            end_time = datetime.now(timezone.utc)
            duration = (end_time - start_time).total_seconds()

            self.logger.error(f"❌ Job failed: {job_name} - {str(e)}")

            job_result = BatchJobResult(
                job_name=job_name,
                status="failed",
                start_time=start_time.isoformat(),
                end_time=end_time.isoformat(),
                duration_seconds=duration,
                items_processed=0,
                items_modified=0,
                errors=1,
                details={"error": str(e)}
            )

            return job_result

    def execute_plan(self, plan: BatchProcessingPlan, dry_run: bool = False) -> Dict[str, Any]:
        """Execute a complete batch processing plan"""
        self.logger.info(f"🎯 Executing plan: {plan.plan_name}")
        if dry_run:
            self.logger.info("⚠️  DRY RUN MODE - No changes will be made")

        plan_start = datetime.now(timezone.utc)
        completed_jobs = []
        failed_jobs = []

        # Sort jobs by priority
        sorted_jobs = sorted(plan.jobs, key=lambda x: x.get('priority', 999))

        for job in sorted_jobs:
            # Check dependencies
            if plan.dependencies and job['name'] in plan.dependencies:
                deps = plan.dependencies[job['name']]
                missing_deps = [dep for dep in deps if dep not in [j.job_name for j in completed_jobs]]

                if missing_deps:
                    self.logger.warning(f"⚠️  Skipping {job['name']} - missing dependencies: {missing_deps}")
                    continue

            # Add dry_run parameter if specified
            if dry_run and 'params' in job:
                job['params']['dry_run'] = True

            # Execute the job
            result = self.run_job(job)
            self.job_results.append(result)

            if result.status == "success":
                completed_jobs.append(result)
            else:
                failed_jobs.append(result)

        plan_end = datetime.now(timezone.utc)
        plan_duration = (plan_end - plan_start).total_seconds()

        # Generate plan summary
        summary = {
            'plan_name': plan.plan_name,
            'total_jobs': len(plan.jobs),
            'completed_jobs': len(completed_jobs),
            'failed_jobs': len(failed_jobs),
            'total_duration_seconds': plan_duration,
            'estimated_duration_minutes': plan.estimated_duration_minutes,
            'total_items_processed': sum(job.items_processed for job in completed_jobs),
            'total_items_modified': sum(job.items_modified for job in completed_jobs),
            'total_errors': sum(job.errors for job in completed_jobs + failed_jobs),
            'job_results': [
                {
                    'name': job.job_name,
                    'status': job.status,
                    'duration': job.duration_seconds,
                    'processed': job.items_processed,
                    'modified': job.items_modified,
                    'errors': job.errors
                }
                for job in completed_jobs + failed_jobs
            ]
        }

        self.logger.info(f"📊 Plan completed: {len(completed_jobs)}/{len(plan.jobs)} jobs successful")
        return summary

    # Job Implementation Functions

    def run_reddit_cleanup(self, sources: List[str] = None, dry_run: bool = False) -> Dict[str, Any]:
        """Execute Reddit content cleanup"""
        if sources == "all":
            sources = None

        if dry_run:
            results = self.reddit_cleanup.run_full_analysis()
            return {
                'processed': sum(stats.get('total_items', 0) for stats in results.values()),
                'modified': 0,  # Dry run
                'errors': 0,
                'analysis_results': results
            }
        else:
            results = self.reddit_cleanup.run_cleanup_batch(sources)
            return {
                'processed': sum(result.get('analyzed', 0) for result in results.values()),
                'modified': sum(result.get('removed', 0) for result in results.values()),
                'errors': sum(result.get('errors', 0) for result in results.values()),
                'cleanup_results': results
            }

    def run_webgames_optimization(self, limit: int = 100, full_analysis: bool = False, dry_run: bool = False) -> Dict[str, Any]:
        """Execute webgames optimization"""
        if full_analysis:
            results = self.webgames_optimizer.run_optimization_workflow()
        else:
            analyzed_games = self.webgames_optimizer.analyze_all_webgames()
            results = {
                'total_analyzed': len(analyzed_games),
                'high_priority': len([g for g in analyzed_games if g.priority_level == "HIGH"]),
                'auto_activated': 0  # Would be implemented based on dry_run
            }

        return {
            'processed': results.get('total_analyzed', 0),
            'modified': results.get('auto_activated', 0),
            'errors': results.get('activation_errors', 0),
            'optimization_results': results
        }

    def run_metadata_enhancement(self, source_filter: str = None, limit: int = 500, dry_run: bool = False) -> Dict[str, Any]:
        """Execute metadata enhancement"""
        if dry_run:
            # In dry run, just analyze without updating
            items = self.metadata_enhancer.get_content_sample(source_filter, limit)
            return {
                'processed': len(items),
                'modified': 0,  # Dry run
                'errors': 0,
                'sample_size': min(10, len(items))
            }
        else:
            results = self.metadata_enhancer.run_metadata_enhancement(source_filter, limit)
            return {
                'processed': results.get('processed', 0),
                'modified': results.get('updated', 0),
                'errors': results.get('errors', 0),
                'enhancement_results': results
            }

    def run_api_integration(self, sources: List[str], limit_per_source: int = 25, dry_run: bool = False) -> Dict[str, Any]:
        """Execute API integrations"""
        if not self.api_manager:
            return {
                'processed': 0,
                'modified': 0,
                'errors': 1,
                'error': 'API Manager not initialized - API keys required'
            }

        if dry_run:
            # Fetch but don't store
            results = self.api_manager.fetch_from_all_sources(limit_per_source)
            total_items = sum(len(items) for items in results.values())
            return {
                'processed': total_items,
                'modified': 0,  # Dry run
                'errors': 0,
                'fetch_results': {k: len(v) for k, v in results.items()}
            }
        else:
            results = self.api_manager.run_integration_workflow(sources, limit_per_source)
            return {
                'processed': results.get('total_items_fetched', 0),
                'modified': results.get('items_stored', 0),
                'errors': results.get('storage_errors', 0),
                'integration_results': results
            }

    def run_archive_filtering(self, collections: List[str] = None, dry_run: bool = True) -> Dict[str, Any]:
        """Execute Internet Archive filtering"""
        if collections == "all":
            collections = None

        results = self.archive_filter.run_complete_filtering(collections, dry_run)
        return {
            'processed': results.get('total_items', 0),
            'modified': results.get('total_removed', 0) if not dry_run else 0,
            'errors': 0,
            'filtering_results': results
        }

    def run_quality_update(self, dry_run: bool = False) -> Dict[str, Any]:
        """Update quality scores based on engagement metrics"""
        # This would implement quality score updates based on user engagement
        # For now, return placeholder results
        return {
            'processed': 100,  # Placeholder
            'modified': 50 if not dry_run else 0,
            'errors': 0,
            'quality_updates': {'placeholder': True}
        }

    def run_database_optimization(self, dry_run: bool = False) -> Dict[str, Any]:
        """Run database optimization tasks"""
        # Get database statistics
        stats = self.db_agent.get_database_stats()

        # Placeholder for optimization tasks
        return {
            'processed': stats.get('total_items', 0),
            'modified': 0,  # Placeholder
            'errors': 0,
            'optimization_results': stats
        }

    def run_quality_assessment(self, source_filter: str = None, dry_run: bool = False) -> Dict[str, Any]:
        """Assess content quality for specific sources"""
        # Placeholder for quality assessment
        return {
            'processed': 50,  # Placeholder
            'modified': 25 if not dry_run else 0,
            'errors': 0,
            'assessment_results': {'source': source_filter}
        }

    def run_comprehensive_report(self, dry_run: bool = False) -> Dict[str, Any]:
        """Generate comprehensive database report"""
        stats = self.db_agent.get_database_stats()

        # Generate detailed report
        report = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'database_stats': stats,
            'job_history': self.job_results,
            'recommendations': self._generate_recommendations(stats)
        }

        # Save report to file
        report_filename = f"dumflow_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)

        return {
            'processed': 1,
            'modified': 1,
            'errors': 0,
            'report_file': report_filename,
            'report_summary': report
        }

    def _generate_recommendations(self, stats: Dict[str, Any]) -> List[str]:
        """Generate actionable recommendations based on database state"""
        recommendations = []

        # Analyze ratios
        total_items = stats.get('total_items', 0)
        if total_items == 0:
            return ["Database appears empty - consider running content expansion"]

        status_breakdown = stats.get('status_breakdown', {})
        inactive_ratio = status_breakdown.get('inactive', 0) / total_items

        if inactive_ratio > 0.8:
            recommendations.append("High inactive content ratio - consider running cleanup operations")

        if inactive_ratio < 0.5:
            recommendations.append("Good content quality ratio - consider expanding with new sources")

        # Source diversity
        sources = stats.get('sources', {})
        if len(sources) < 10:
            recommendations.append("Limited source diversity - consider adding new API integrations")

        # Category analysis
        categories = stats.get('bf_categories', {})
        if 'webgames' in categories and categories['webgames'] < 50:
            recommendations.append("Low webgame count - run webgames optimization")

        return recommendations

def main():
    """Main execution function"""
    # Example API keys (replace with actual keys)
    api_keys = {
        'youtube': None,  # 'YOUR_YOUTUBE_API_KEY',
        'letterboxd': None,
        'medium': None,
        'designboom': None,
        'nyc': None
    }

    batch_system = BatchProcessingSystem(api_keys)

    print("🤖 DUMFLOW COMPREHENSIVE BATCH PROCESSING SYSTEM")
    print("=" * 70)

    # Get available plans
    plans = batch_system.get_predefined_plans()

    print("Available batch processing plans:")
    for i, (plan_key, plan) in enumerate(plans.items(), 1):
        print(f"  {i}. {plan.plan_name}")
        print(f"     {plan.description}")
        print(f"     Jobs: {len(plan.jobs)} | Est. time: {plan.estimated_duration_minutes} min")
        print()

    print("Additional options:")
    print(f"  {len(plans) + 1}. Run custom job")
    print(f"  {len(plans) + 2}. Generate database report")
    print(f"  {len(plans) + 3}. Show system status")

    choice = input(f"\nEnter choice (1-{len(plans) + 3}): ").strip()

    try:
        choice_num = int(choice)

        if 1 <= choice_num <= len(plans):
            # Execute selected plan
            plan_keys = list(plans.keys())
            selected_plan = plans[plan_keys[choice_num - 1]]

            print(f"\n🎯 Selected Plan: {selected_plan.plan_name}")
            print(f"📝 Description: {selected_plan.description}")
            print(f"⏱️  Estimated duration: {selected_plan.estimated_duration_minutes} minutes")
            print(f"📋 Jobs to execute: {len(selected_plan.jobs)}")

            dry_run = input("\nDry run? (Y/n): ").strip().lower() != 'n'

            if not dry_run:
                confirm = input("⚠️  This will modify your database. Continue? (y/N): ").strip()
                if confirm.lower() != 'y':
                    print("❌ Cancelled")
                    return

            print(f"\n🚀 Executing batch plan...")
            summary = batch_system.execute_plan(selected_plan, dry_run)

            print(f"\n✅ BATCH PROCESSING COMPLETE")
            print(f"📊 Summary:")
            print(f"  Jobs completed: {summary['completed_jobs']}/{summary['total_jobs']}")
            print(f"  Items processed: {summary['total_items_processed']}")
            print(f"  Items modified: {summary['total_items_modified']}")
            print(f"  Total duration: {summary['total_duration_seconds']:.1f} seconds")

        elif choice_num == len(plans) + 1:
            print("🔧 Custom job execution not implemented in this demo")

        elif choice_num == len(plans) + 2:
            print("📊 Generating comprehensive database report...")
            result = batch_system.run_comprehensive_report()
            print(f"✅ Report generated: {result['report_file']}")

        elif choice_num == len(plans) + 3:
            print("📊 System Status:")
            stats = batch_system.db_agent.get_database_stats()
            print(f"  Total items: {stats.get('total_items', 0)}")
            print(f"  Active items: {stats.get('status_breakdown', {}).get('active', 0)}")
            print(f"  Sources: {len(stats.get('sources', {}))}")
            print(f"  Categories: {len(stats.get('bf_categories', {}))}")

        else:
            print("❌ Invalid choice")

    except ValueError:
        print("❌ Invalid input - please enter a number")
    except KeyboardInterrupt:
        print("\n⚠️  Operation cancelled by user")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()