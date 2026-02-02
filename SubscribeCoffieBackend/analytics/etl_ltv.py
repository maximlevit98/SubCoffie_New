#!/usr/bin/env python3
"""ETL script for customer lifetime value (LTV) analysis."""

import logging
import sys
from datetime import datetime
from db_utils import call_rpc_function, execute_query
from config import LOGS_DIR, LOG_FORMAT, LOG_LEVEL, COHORT_MONTHS_BACK

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOGS_DIR / 'ltv.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def refresh_ltv_analytics(months_back: int = COHORT_MONTHS_BACK) -> bool:
    """
    Refresh LTV analytics by calling the database function.
    
    Args:
        months_back: Number of months to analyze
        
    Returns:
        True if successful, False otherwise
    """
    logger.info(f"Starting LTV analytics refresh (months_back={months_back})")
    start_time = datetime.now()
    
    try:
        # Call the RPC function that calculates LTV
        result = call_rpc_function('calculate_customer_ltv', {'months_back': months_back})
        
        if not result:
            logger.warning("No LTV data returned")
            return False
        
        logger.info(f"LTV calculated for {len(result)} customers")
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"LTV analytics completed in {duration:.2f} seconds")
        
        return True
        
    except Exception as e:
        logger.error(f"Error refreshing LTV analytics: {e}", exc_info=True)
        return False


def get_ltv_summary() -> dict:
    """
    Get summary statistics for LTV analysis.
    
    Returns:
        Dict with LTV summary statistics
    """
    logger.info("Generating LTV summary")
    
    query = """
        WITH ltv_data AS (
            SELECT * FROM calculate_customer_ltv(12)
        )
        SELECT 
            COUNT(*) as total_customers,
            ROUND(AVG(total_spent), 2) as avg_total_spent,
            ROUND(AVG(avg_order_value), 2) as avg_order_value,
            ROUND(AVG(predicted_annual_revenue), 2) as avg_predicted_annual,
            COUNT(*) FILTER (WHERE customer_segment = 'vip') as vip_count,
            COUNT(*) FILTER (WHERE customer_segment = 'high_value') as high_value_count,
            COUNT(*) FILTER (WHERE customer_segment = 'medium_value') as medium_value_count,
            COUNT(*) FILTER (WHERE order_frequency_segment = 'frequent') as frequent_count,
            COUNT(*) FILTER (WHERE order_frequency_segment = 'regular') as regular_count,
            COUNT(*) FILTER (WHERE order_frequency_segment = 'new') as new_count
        FROM ltv_data;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            summary = result[0]
            logger.info(f"LTV Summary:")
            logger.info(f"  - Total customers: {summary['total_customers']}")
            logger.info(f"  - Avg total spent: ₽{summary['avg_total_spent']}")
            logger.info(f"  - Avg order value: ₽{summary['avg_order_value']}")
            logger.info(f"  - Avg predicted annual: ₽{summary['avg_predicted_annual']}")
            logger.info(f"  - VIP customers: {summary['vip_count']}")
            logger.info(f"  - High value: {summary['high_value_count']}")
            logger.info(f"  - Medium value: {summary['medium_value_count']}")
            logger.info(f"  - Frequent buyers: {summary['frequent_count']}")
            logger.info(f"  - Regular buyers: {summary['regular_count']}")
            logger.info(f"  - New customers: {summary['new_count']}")
            return summary
        return {}
        
    except Exception as e:
        logger.error(f"Error getting LTV summary: {e}")
        return {}


def get_top_customers(limit: int = 20, segment: str = 'vip') -> list:
    """
    Get top customers by LTV.
    
    Args:
        limit: Number of customers to return
        segment: Customer segment filter
        
    Returns:
        List of top customers
    """
    logger.info(f"Getting top {limit} customers (segment: {segment})")
    
    query = """
        WITH ltv_data AS (
            SELECT * FROM calculate_customer_ltv(12)
        )
        SELECT 
            customer_phone,
            total_spent,
            total_orders,
            avg_order_value,
            predicted_annual_revenue,
            customer_segment,
            order_frequency_segment,
            days_since_first_order
        FROM ltv_data
        WHERE customer_segment = %s
        ORDER BY total_spent DESC
        LIMIT %s;
    """
    
    try:
        result = execute_query(query, (segment, limit))
        
        if result:
            logger.info(f"Found {len(result)} {segment} customers:")
            for i, customer in enumerate(result[:5], 1):  # Log first 5
                logger.info(
                    f"  {i}. Phone: {customer['customer_phone'][:8]}***, "
                    f"Spent: ₽{customer['total_spent']}, "
                    f"Orders: {customer['total_orders']}, "
                    f"Predicted Annual: ₽{customer['predicted_annual_revenue']:.0f}"
                )
        
        return result if result else []
        
    except Exception as e:
        logger.error(f"Error getting top customers: {e}")
        return []


def get_ltv_distribution() -> dict:
    """
    Get distribution of customers across LTV segments.
    
    Returns:
        Dict with distribution statistics
    """
    logger.info("Analyzing LTV distribution")
    
    query = """
        WITH ltv_data AS (
            SELECT * FROM calculate_customer_ltv(12)
        )
        SELECT 
            customer_segment,
            COUNT(*) as count,
            ROUND(AVG(total_spent), 2) as avg_spent,
            ROUND(SUM(total_spent), 2) as total_revenue,
            ROUND(AVG(predicted_annual_revenue), 2) as avg_predicted_annual
        FROM ltv_data
        GROUP BY customer_segment
        ORDER BY avg_spent DESC;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info("LTV Distribution by Segment:")
            for row in result:
                logger.info(
                    f"  - {row['customer_segment']}: {row['count']} customers, "
                    f"Avg spent: ₽{row['avg_spent']}, "
                    f"Total revenue: ₽{row['total_revenue']}"
                )
        
        return result if result else {}
        
    except Exception as e:
        logger.error(f"Error analyzing LTV distribution: {e}")
        return {}


def identify_upgrading_customers() -> list:
    """
    Identify customers who could be upgraded to higher segments.
    
    Returns:
        List of potential upgrade candidates
    """
    logger.info("Identifying upgrade candidates")
    
    query = """
        WITH ltv_data AS (
            SELECT * FROM calculate_customer_ltv(12)
        )
        SELECT 
            customer_phone,
            total_spent,
            total_orders,
            customer_segment,
            CASE 
                WHEN customer_segment = 'medium_value' AND total_orders >= 8 THEN 'high_value'
                WHEN customer_segment = 'high_value' AND total_orders >= 12 THEN 'vip'
                ELSE NULL
            END as potential_upgrade
        FROM ltv_data
        WHERE (customer_segment = 'medium_value' AND total_orders >= 8)
           OR (customer_segment = 'high_value' AND total_orders >= 12)
        ORDER BY total_spent DESC
        LIMIT 50;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info(f"Found {len(result)} upgrade candidates:")
            for customer in result[:5]:
                logger.info(
                    f"  - {customer['customer_phone'][:8]}***: "
                    f"{customer['customer_segment']} → {customer['potential_upgrade']} "
                    f"(₽{customer['total_spent']}, {customer['total_orders']} orders)"
                )
        
        return result if result else []
        
    except Exception as e:
        logger.error(f"Error identifying upgrade candidates: {e}")
        return []


def main():
    """Main ETL process for LTV analysis."""
    logger.info("=" * 80)
    logger.info("Starting LTV Analysis ETL")
    logger.info("=" * 80)
    
    success = refresh_ltv_analytics()
    
    if success:
        get_ltv_summary()
        get_top_customers(limit=20, segment='vip')
        get_ltv_distribution()
        identify_upgrading_customers()
        logger.info("LTV ETL completed successfully")
        sys.exit(0)
    else:
        logger.error("LTV ETL failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
