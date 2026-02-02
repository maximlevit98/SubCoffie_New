#!/usr/bin/env python3
"""ETL script for conversion funnel analysis."""

import logging
import sys
from datetime import datetime
from db_utils import call_rpc_function, execute_query
from config import LOGS_DIR, LOG_FORMAT, LOG_LEVEL

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOGS_DIR / 'funnel.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def refresh_funnel_analytics() -> bool:
    """
    Refresh funnel analytics by calling the database function.
    
    Returns:
        True if successful, False otherwise
    """
    logger.info("Starting funnel analytics refresh")
    start_time = datetime.now()
    
    try:
        # Call the RPC function that calculates funnel metrics
        result = call_rpc_function('calculate_conversion_funnel')
        
        if result:
            logger.info(f"Funnel analytics calculated successfully:")
            for step in result:
                logger.info(
                    f"  Step {step['step_number']}: {step['step_name']} - "
                    f"{step['user_count']} users "
                    f"({step['conversion_from_previous']:.1f}% from previous, "
                    f"{step['conversion_from_start']:.1f}% from start)"
                )
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"Funnel analytics completed in {duration:.2f} seconds")
        
        return True
        
    except Exception as e:
        logger.error(f"Error refreshing funnel analytics: {e}", exc_info=True)
        return False


def get_funnel_bottlenecks(threshold: float = 50.0) -> list:
    """
    Identify funnel steps with low conversion rates.
    
    Args:
        threshold: Minimum acceptable conversion rate (%)
        
    Returns:
        List of bottleneck steps
    """
    logger.info(f"Identifying funnel bottlenecks (threshold: {threshold}%)")
    
    try:
        result = call_rpc_function('calculate_conversion_funnel')
        
        if not result:
            logger.warning("No funnel data available")
            return []
        
        bottlenecks = [
            step for step in result 
            if step['conversion_from_previous'] < threshold and step['step_number'] > 1
        ]
        
        if bottlenecks:
            logger.warning(f"Found {len(bottlenecks)} bottleneck step(s):")
            for step in bottlenecks:
                logger.warning(
                    f"  - {step['step_name']}: {step['conversion_from_previous']:.1f}% "
                    f"(below {threshold}% threshold)"
                )
        else:
            logger.info("No bottlenecks found - funnel is performing well!")
        
        return bottlenecks
        
    except Exception as e:
        logger.error(f"Error identifying bottlenecks: {e}")
        return []


def get_funnel_summary() -> dict:
    """
    Get overall funnel performance summary.
    
    Returns:
        Dict with funnel summary statistics
    """
    logger.info("Generating funnel summary")
    
    try:
        result = call_rpc_function('calculate_conversion_funnel')
        
        if not result:
            return {}
        
        # Calculate overall conversion rate (first step to last step)
        first_step = result[0]
        last_step = result[-1]
        overall_conversion = (last_step['user_count'] / first_step['user_count'] * 100) if first_step['user_count'] > 0 else 0
        
        # Find step with worst conversion
        worst_step = min(
            [s for s in result if s['step_number'] > 1],
            key=lambda x: x['conversion_from_previous']
        )
        
        summary = {
            'total_steps': len(result),
            'starting_users': first_step['user_count'],
            'completing_users': last_step['user_count'],
            'overall_conversion': overall_conversion,
            'worst_step': worst_step['step_name'],
            'worst_step_conversion': worst_step['conversion_from_previous']
        }
        
        logger.info("Funnel Summary:")
        logger.info(f"  - Starting users: {summary['starting_users']}")
        logger.info(f"  - Completing users: {summary['completing_users']}")
        logger.info(f"  - Overall conversion: {summary['overall_conversion']:.1f}%")
        logger.info(f"  - Weakest step: {summary['worst_step']} ({summary['worst_step_conversion']:.1f}%)")
        
        return summary
        
    except Exception as e:
        logger.error(f"Error generating funnel summary: {e}")
        return {}


def get_time_based_funnel_stats() -> dict:
    """
    Get average time between funnel steps.
    
    Returns:
        Dict with timing statistics
    """
    logger.info("Analyzing funnel timing")
    
    query = """
        WITH step_times AS (
            SELECT 
                step_name,
                AVG(EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (PARTITION BY user_phone ORDER BY created_at))) / 60) as avg_minutes
            FROM funnel_events
            WHERE created_at >= NOW() - INTERVAL '7 days'
            GROUP BY step_name
        )
        SELECT * FROM step_times
        WHERE avg_minutes IS NOT NULL
        ORDER BY avg_minutes DESC;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info("Average time between steps:")
            for row in result:
                logger.info(f"  - After {row['step_name']}: {row['avg_minutes']:.1f} minutes")
        
        return result if result else {}
        
    except Exception as e:
        logger.error(f"Error analyzing funnel timing: {e}")
        return {}


def main():
    """Main ETL process for funnel analysis."""
    logger.info("=" * 80)
    logger.info("Starting Funnel Analysis ETL")
    logger.info("=" * 80)
    
    success = refresh_funnel_analytics()
    
    if success:
        get_funnel_summary()
        get_funnel_bottlenecks(threshold=50.0)
        get_time_based_funnel_stats()
        logger.info("Funnel ETL completed successfully")
        sys.exit(0)
    else:
        logger.error("Funnel ETL failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
