#!/usr/bin/env python3
"""ETL script for cohort analysis."""

import logging
import sys
from datetime import datetime
from db_utils import call_rpc_function, execute_query, vacuum_analyze
from config import LOGS_DIR, LOG_FORMAT, LOG_LEVEL, COHORT_MONTHS_BACK

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOGS_DIR / 'cohort.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def refresh_cohort_analytics(months_back: int = COHORT_MONTHS_BACK) -> bool:
    """
    Refresh cohort analytics by calling the database function.
    
    Args:
        months_back: Number of months to analyze
        
    Returns:
        True if successful, False otherwise
    """
    logger.info(f"Starting cohort analytics refresh (months_back={months_back})")
    start_time = datetime.now()
    
    try:
        # Call the RPC function that refreshes cohort data
        result = call_rpc_function('refresh_cohort_analytics')
        
        # Get statistics
        query = """
            SELECT 
                COUNT(*) as total_cohorts,
                COUNT(DISTINCT cohort_month) as unique_months,
                MAX(updated_at) as last_updated
            FROM cohort_analytics;
        """
        stats = execute_query(query)
        
        if stats:
            logger.info(f"Cohort analytics refreshed successfully:")
            logger.info(f"  - Total cohorts: {stats[0]['total_cohorts']}")
            logger.info(f"  - Unique months: {stats[0]['unique_months']}")
            logger.info(f"  - Last updated: {stats[0]['last_updated']}")
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"Cohort analytics completed in {duration:.2f} seconds")
        
        # Run VACUUM ANALYZE to optimize table
        vacuum_analyze('cohort_analytics')
        
        return True
        
    except Exception as e:
        logger.error(f"Error refreshing cohort analytics: {e}", exc_info=True)
        return False


def get_cohort_summary() -> dict:
    """
    Get summary statistics for cohort analysis.
    
    Returns:
        Dict with cohort summary statistics
    """
    logger.info("Generating cohort summary")
    
    query = """
        WITH latest_cohort AS (
            SELECT * FROM cohort_analytics
            WHERE cohort_month = (SELECT MAX(cohort_month) FROM cohort_analytics)
        )
        SELECT 
            cohort_month,
            users_count,
            SUM(active_users) as total_active,
            AVG(retention_rate) as avg_retention,
            SUM(total_revenue) as total_revenue
        FROM latest_cohort
        GROUP BY cohort_month, users_count;
    """
    
    try:
        result = execute_query(query)
        if result:
            summary = result[0]
            logger.info(f"Latest cohort ({summary['cohort_month']}):")
            logger.info(f"  - Initial users: {summary['users_count']}")
            logger.info(f"  - Avg retention: {summary['avg_retention']:.2f}%")
            logger.info(f"  - Total revenue: {summary['total_revenue']}")
            return summary
        return {}
    except Exception as e:
        logger.error(f"Error getting cohort summary: {e}")
        return {}


def main():
    """Main ETL process for cohort analysis."""
    logger.info("=" * 80)
    logger.info("Starting Cohort Analysis ETL")
    logger.info("=" * 80)
    
    success = refresh_cohort_analytics()
    
    if success:
        get_cohort_summary()
        logger.info("Cohort ETL completed successfully")
        sys.exit(0)
    else:
        logger.error("Cohort ETL failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
