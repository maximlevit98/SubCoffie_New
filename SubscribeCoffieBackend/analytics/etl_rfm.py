#!/usr/bin/env python3
"""ETL script for RFM (Recency, Frequency, Monetary) segmentation analysis."""

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
        logging.FileHandler(LOGS_DIR / 'rfm.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def refresh_rfm_analytics() -> bool:
    """
    Refresh RFM analytics by calling the database function.
    
    Returns:
        True if successful, False otherwise
    """
    logger.info("Starting RFM segmentation refresh")
    start_time = datetime.now()
    
    try:
        # Call the RPC function that calculates RFM segments
        result = call_rpc_function('calculate_rfm_segments')
        
        if not result:
            logger.warning("No RFM data returned")
            return False
        
        logger.info(f"RFM segmentation calculated for {len(result)} customers")
        
        duration = (datetime.now() - start_time).total_seconds()
        logger.info(f"RFM analytics completed in {duration:.2f} seconds")
        
        return True
        
    except Exception as e:
        logger.error(f"Error refreshing RFM analytics: {e}", exc_info=True)
        return False


def get_rfm_summary() -> dict:
    """
    Get summary statistics for RFM analysis.
    
    Returns:
        Dict with RFM summary statistics
    """
    logger.info("Generating RFM summary")
    
    query = """
        WITH rfm_data AS (
            SELECT * FROM calculate_rfm_segments()
        )
        SELECT 
            rfm_segment,
            COUNT(*) as customer_count,
            ROUND(AVG(recency_days), 1) as avg_recency,
            ROUND(AVG(frequency), 1) as avg_frequency,
            ROUND(AVG(monetary), 2) as avg_monetary,
            ROUND(SUM(monetary), 2) as total_revenue,
            ROUND(AVG(r_score), 1) as avg_r_score,
            ROUND(AVG(f_score), 1) as avg_f_score,
            ROUND(AVG(m_score), 1) as avg_m_score
        FROM rfm_data
        GROUP BY rfm_segment
        ORDER BY total_revenue DESC;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info(f"RFM Segment Distribution:")
            total_customers = sum(row['customer_count'] for row in result)
            total_revenue = sum(row['total_revenue'] for row in result)
            
            for row in result:
                pct_customers = (row['customer_count'] / total_customers * 100) if total_customers > 0 else 0
                pct_revenue = (row['total_revenue'] / total_revenue * 100) if total_revenue > 0 else 0
                
                logger.info(
                    f"  - {row['rfm_segment']}: {row['customer_count']} customers ({pct_customers:.1f}%), "
                    f"₽{row['total_revenue']} revenue ({pct_revenue:.1f}%)"
                )
                logger.info(
                    f"    Avg: R={row['avg_recency']:.0f} days, "
                    f"F={row['avg_frequency']:.1f} orders, "
                    f"M=₽{row['avg_monetary']}"
                )
            
            return result
        return {}
        
    except Exception as e:
        logger.error(f"Error getting RFM summary: {e}")
        return {}


def get_segment_customers(segment: str, limit: int = 10) -> list:
    """
    Get customers in a specific RFM segment.
    
    Args:
        segment: RFM segment name
        limit: Number of customers to return
        
    Returns:
        List of customers in segment
    """
    logger.info(f"Getting {limit} customers from '{segment}' segment")
    
    query = """
        WITH rfm_data AS (
            SELECT * FROM calculate_rfm_segments()
        )
        SELECT 
            customer_phone,
            recency_days,
            frequency,
            monetary,
            r_score,
            f_score,
            m_score,
            segment_description
        FROM rfm_data
        WHERE rfm_segment = %s
        ORDER BY monetary DESC
        LIMIT %s;
    """
    
    try:
        result = execute_query(query, (segment, limit))
        
        if result:
            logger.info(f"Found {len(result)} customers in '{segment}' segment:")
            for i, customer in enumerate(result[:5], 1):
                logger.info(
                    f"  {i}. Phone: {customer['customer_phone'][:8]}***, "
                    f"R={customer['recency_days']} days, "
                    f"F={customer['frequency']} orders, "
                    f"M=₽{customer['monetary']}"
                )
        
        return result if result else []
        
    except Exception as e:
        logger.error(f"Error getting segment customers: {e}")
        return []


def identify_high_priority_segments() -> dict:
    """
    Identify segments that need immediate attention.
    
    Returns:
        Dict with high-priority segments and actions
    """
    logger.info("Identifying high-priority segments")
    
    priority_segments = {
        'champions': {
            'action': 'Reward & retain',
            'priority': 'High',
            'description': 'Your best customers - keep them engaged'
        },
        'at_risk': {
            'action': 'Win-back campaign',
            'priority': 'Critical',
            'description': 'Valuable customers who are becoming inactive'
        },
        'cant_lose_them': {
            'action': 'Urgent intervention',
            'priority': 'Critical',
            'description': 'High-value customers who haven\'t returned'
        },
        'promising': {
            'action': 'Nurture & convert',
            'priority': 'Medium',
            'description': 'Recent customers with potential'
        },
        'need_attention': {
            'action': 'Re-engagement campaign',
            'priority': 'Medium',
            'description': 'Becoming inactive, need encouragement'
        }
    }
    
    query = """
        WITH rfm_data AS (
            SELECT * FROM calculate_rfm_segments()
        )
        SELECT 
            rfm_segment,
            COUNT(*) as count,
            ROUND(SUM(monetary), 2) as total_value
        FROM rfm_data
        WHERE rfm_segment IN ('champions', 'at_risk', 'cant_lose_them', 'promising', 'need_attention')
        GROUP BY rfm_segment;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info("High-Priority Segments:")
            for row in result:
                segment = row['rfm_segment']
                if segment in priority_segments:
                    info = priority_segments[segment]
                    logger.info(
                        f"  - {segment} ({info['priority']} priority): {row['count']} customers, "
                        f"₽{row['total_value']} value"
                    )
                    logger.info(f"    Action: {info['action']}")
                    logger.info(f"    Why: {info['description']}")
        
        return result if result else {}
        
    except Exception as e:
        logger.error(f"Error identifying priority segments: {e}")
        return {}


def get_segment_transitions() -> dict:
    """
    Analyze how customers move between segments over time.
    
    Returns:
        Dict with transition statistics
    """
    logger.info("Analyzing segment transitions")
    
    # This would require historical RFM data, which we don't have yet
    # For now, we'll identify customers close to transitioning
    
    query = """
        WITH rfm_data AS (
            SELECT * FROM calculate_rfm_segments()
        )
        SELECT 
            rfm_segment,
            COUNT(*) FILTER (WHERE r_score >= 4) as high_recency_count,
            COUNT(*) FILTER (WHERE f_score >= 4) as high_frequency_count,
            COUNT(*) FILTER (WHERE m_score >= 4) as high_monetary_count,
            COUNT(*) FILTER (WHERE r_score <= 2) as low_recency_count,
            COUNT(*) FILTER (WHERE f_score <= 2) as low_frequency_count,
            COUNT(*) FILTER (WHERE m_score <= 2) as low_monetary_count
        FROM rfm_data
        GROUP BY rfm_segment;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info("Segment Health Indicators:")
            for row in result:
                logger.info(f"  - {row['rfm_segment']}:")
                logger.info(
                    f"    Strong: R={row['high_recency_count']}, "
                    f"F={row['high_frequency_count']}, "
                    f"M={row['high_monetary_count']}"
                )
                logger.info(
                    f"    Weak: R={row['low_recency_count']}, "
                    f"F={row['low_frequency_count']}, "
                    f"M={row['low_monetary_count']}"
                )
        
        return result if result else {}
        
    except Exception as e:
        logger.error(f"Error analyzing segment transitions: {e}")
        return {}


def generate_marketing_recommendations() -> dict:
    """
    Generate marketing campaign recommendations based on RFM segments.
    
    Returns:
        Dict with recommendations per segment
    """
    logger.info("Generating marketing recommendations")
    
    recommendations = {
        'champions': 'VIP program, early access to new products, exclusive events',
        'loyal_customers': 'Loyalty rewards, referral program, upsell premium products',
        'big_spenders': 'Premium experiences, exclusive offerings, high-value bundles',
        'promising': 'Onboarding series, product education, small incentives',
        'potential_loyalists': 'Frequency rewards, habit-building campaigns',
        'new_customers': 'Welcome series, first purchase incentives, product guides',
        'at_risk': 'Win-back discounts, \"We miss you\" campaigns, feedback surveys',
        'need_attention': 'Re-engagement emails, limited-time offers, new product announcements',
        'cant_lose_them': 'Urgent personalized outreach, special recovery offers, account manager',
        'lost': 'Dormant customer reactivation, deep discounts, \"What went wrong\" survey'
    }
    
    query = """
        WITH rfm_data AS (
            SELECT * FROM calculate_rfm_segments()
        )
        SELECT 
            rfm_segment,
            COUNT(*) as customer_count
        FROM rfm_data
        GROUP BY rfm_segment
        HAVING COUNT(*) > 0
        ORDER BY customer_count DESC;
    """
    
    try:
        result = execute_query(query)
        
        if result:
            logger.info("Marketing Campaign Recommendations:")
            for row in result:
                segment = row['rfm_segment']
                if segment in recommendations:
                    logger.info(
                        f"  - {segment} ({row['customer_count']} customers):"
                    )
                    logger.info(f"    Campaign: {recommendations[segment]}")
        
        return recommendations
        
    except Exception as e:
        logger.error(f"Error generating recommendations: {e}")
        return {}


def main():
    """Main ETL process for RFM analysis."""
    logger.info("=" * 80)
    logger.info("Starting RFM Segmentation ETL")
    logger.info("=" * 80)
    
    success = refresh_rfm_analytics()
    
    if success:
        get_rfm_summary()
        identify_high_priority_segments()
        get_segment_customers('champions', limit=10)
        get_segment_transitions()
        generate_marketing_recommendations()
        logger.info("RFM ETL completed successfully")
        sys.exit(0)
    else:
        logger.error("RFM ETL failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
