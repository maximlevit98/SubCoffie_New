#!/usr/bin/env python3
"""ETL script for churn risk analysis."""

import logging
import sys
from datetime import datetime
from db_utils import call_rpc_function, execute_query, vacuum_analyze
from config import LOGS_DIR, LOG_FORMAT, LOG_LEVEL

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOGS_DIR / 'churn.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def refresh_churn_risk() -> bool:
    """
    Refresh churn risk data by calling the database function.
    
    Returns:
        True if successful, False otherwise
    """
    logger.info("Starting churn risk refresh")
    start_time = datetime.now()
    
    try:
        # Call the RPC function that refreshes churn risk data
        result = call_rpc_function('refresh_churn_risk')
        
        # Get statistics
        query = """
            SELECT 
                COUNT(*) as total_users,
                COUNT(*) FILTER (WHERE risk_level = 'critical') as critical_count,
                COUNT(*) FILTER (WHERE risk_level = 'high') as high_count,
                COUNT(*) FILTER (WHERE risk_level = 'medium') as medium_count,
                COUNT(*) FILTER (WHERE risk_level = 'low') as low_count,
                ROUND(AVG(risk_score), 2) as avg_risk_score,
                MAX(calculated_at) as last_calculated
            FROM user_churn_risk
            WHERE calculated_at::date = CURRENT_DATE;
        """
        stats = execute_query(query)
        
        if stats:
            s = stats[0]
            logger.info(f"Churn risk analysis completed:")
            logger.info(f"  - Total users analyzed: {s['total_users']}")
            logger.info(f"  - Critical risk: {s['critical_count']}")
            logger.info(f"  - High risk: {s['high_count']}")
            logger.info(f"  - Medium risk: {s['medium_count']}")
            logger.info(f"  - Low risk: {s['low_count']}")
            logger.info(f"  - Average risk score: {s['avg_risk_score']}")
            logger.info(f"  - Last calculated: {s['last_calculated']}")
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"Churn risk refresh completed in {duration:.2f} seconds")
        
        # Run VACUUM ANALYZE to optimize table
        vacuum_analyze('user_churn_risk')
        
        return True
        
    except Exception as e:
        logger.error(f"Error refreshing churn risk: {e}", exc_info=True)
        return False


def get_high_risk_users(limit: int = 10) -> list:
    """
    Get users with highest churn risk.
    
    Args:
        limit: Number of users to return
        
    Returns:
        List of high-risk users
    """
    logger.info(f"Getting top {limit} high-risk users")
    
    query = """
        SELECT 
            customer_phone,
            risk_score,
            risk_level,
            days_since_last_order,
            total_orders,
            total_spent
        FROM user_churn_risk
        WHERE calculated_at::date = CURRENT_DATE
        ORDER BY risk_score DESC
        LIMIT %s;
    """
    
    try:
        result = execute_query(query, (limit,))
        if result:
            logger.info(f"Found {len(result)} high-risk users:")
            for i, user in enumerate(result[:5], 1):  # Log first 5
                logger.info(
                    f"  {i}. Phone: {user['customer_phone'][:8]}***, "
                    f"Risk: {user['risk_score']} ({user['risk_level']}), "
                    f"Days since order: {user['days_since_last_order']}"
                )
        return result if result else []
    except Exception as e:
        logger.error(f"Error getting high-risk users: {e}")
        return []


def get_churn_trends() -> dict:
    """
    Get churn risk trends over time.
    
    Returns:
        Dict with trend statistics
    """
    logger.info("Analyzing churn trends")
    
    query = """
        SELECT 
            calculated_at::date as date,
            COUNT(*) as total_users,
            ROUND(AVG(risk_score), 2) as avg_risk_score,
            COUNT(*) FILTER (WHERE risk_level IN ('critical', 'high')) as at_risk_count
        FROM user_churn_risk
        WHERE calculated_at >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY calculated_at::date
        ORDER BY date DESC;
    """
    
    try:
        result = execute_query(query)
        if result:
            logger.info("Churn trends (last 7 days):")
            for row in result:
                logger.info(
                    f"  {row['date']}: Avg risk {row['avg_risk_score']}, "
                    f"At risk: {row['at_risk_count']}/{row['total_users']}"
                )
            return result
        return {}
    except Exception as e:
        logger.error(f"Error getting churn trends: {e}")
        return {}


def main():
    """Main ETL process for churn risk analysis."""
    logger.info("=" * 80)
    logger.info("Starting Churn Risk Analysis ETL")
    logger.info("=" * 80)
    
    success = refresh_churn_risk()
    
    if success:
        get_high_risk_users(limit=20)
        get_churn_trends()
        logger.info("Churn ETL completed successfully")
        sys.exit(0)
    else:
        logger.error("Churn ETL failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
