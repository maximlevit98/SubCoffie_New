#!/usr/bin/env python3
"""Main ETL aggregation script that runs all analytics processes."""

import logging
import sys
import argparse
from datetime import datetime
from db_utils import vacuum_analyze
from config import LOGS_DIR, LOG_FORMAT, LOG_LEVEL

# Import individual ETL modules
import etl_cohort
import etl_churn
import etl_funnel
import etl_ltv
import etl_rfm

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOGS_DIR / 'etl.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def run_all_etl_processes():
    """Run all ETL processes in sequence."""
    logger.info("=" * 80)
    logger.info("Starting Full Analytics ETL Pipeline")
    logger.info("=" * 80)
    
    start_time = datetime.now()
    results = {
        'cohort': False,
        'churn': False,
        'funnel': False,
        'ltv': False,
        'rfm': False,
    }
    
    # Run cohort analysis
    logger.info("\n" + "=" * 80)
    logger.info("Step 1/5: Cohort Analysis")
    logger.info("=" * 80)
    try:
        results['cohort'] = etl_cohort.refresh_cohort_analytics()
        if results['cohort']:
            etl_cohort.get_cohort_summary()
    except Exception as e:
        logger.error(f"Cohort analysis failed: {e}", exc_info=True)
    
    # Run churn risk analysis
    logger.info("\n" + "=" * 80)
    logger.info("Step 2/5: Churn Risk Analysis")
    logger.info("=" * 80)
    try:
        results['churn'] = etl_churn.refresh_churn_risk()
        if results['churn']:
            etl_churn.get_high_risk_users(limit=10)
            etl_churn.get_churn_trends()
    except Exception as e:
        logger.error(f"Churn risk analysis failed: {e}", exc_info=True)
    
    # Run funnel analysis
    logger.info("\n" + "=" * 80)
    logger.info("Step 3/5: Conversion Funnel Analysis")
    logger.info("=" * 80)
    try:
        results['funnel'] = etl_funnel.refresh_funnel_analytics()
        if results['funnel']:
            etl_funnel.get_funnel_summary()
            etl_funnel.get_funnel_bottlenecks()
    except Exception as e:
        logger.error(f"Funnel analysis failed: {e}", exc_info=True)
    
    # Run LTV analysis
    logger.info("\n" + "=" * 80)
    logger.info("Step 4/5: Customer Lifetime Value Analysis")
    logger.info("=" * 80)
    try:
        results['ltv'] = etl_ltv.refresh_ltv_analytics()
        if results['ltv']:
            etl_ltv.get_ltv_summary()
            etl_ltv.get_ltv_distribution()
    except Exception as e:
        logger.error(f"LTV analysis failed: {e}", exc_info=True)
    
    # Run RFM segmentation
    logger.info("\n" + "=" * 80)
    logger.info("Step 5/5: RFM Segmentation")
    logger.info("=" * 80)
    try:
        results['rfm'] = etl_rfm.refresh_rfm_analytics()
        if results['rfm']:
            etl_rfm.get_rfm_summary()
            etl_rfm.identify_high_priority_segments()
    except Exception as e:
        logger.error(f"RFM segmentation failed: {e}", exc_info=True)
    
    # Summary
    duration = (datetime.now() - start_time).total_seconds()
    logger.info("\n" + "=" * 80)
    logger.info("ETL Pipeline Summary")
    logger.info("=" * 80)
    logger.info(f"Cohort Analysis: {'✓ Success' if results['cohort'] else '✗ Failed'}")
    logger.info(f"Churn Risk Analysis: {'✓ Success' if results['churn'] else '✗ Failed'}")
    logger.info(f"Funnel Analysis: {'✓ Success' if results['funnel'] else '✗ Failed'}")
    logger.info(f"LTV Analysis: {'✓ Success' if results['ltv'] else '✗ Failed'}")
    logger.info(f"RFM Segmentation: {'✓ Success' if results['rfm'] else '✗ Failed'}")
    logger.info(f"Total duration: {duration:.2f} seconds")
    
    # Run VACUUM ANALYZE on entire database
    try:
        logger.info("Running VACUUM ANALYZE on database...")
        vacuum_analyze()
    except Exception as e:
        logger.warning(f"VACUUM ANALYZE failed: {e}")
    
    # Return success if all processes completed
    all_success = all(results.values())
    if all_success:
        logger.info("\n✓ All ETL processes completed successfully")
    else:
        logger.error("\n✗ Some ETL processes failed")
    
    return all_success


def main():
    """Main entry point with command-line argument parsing."""
    parser = argparse.ArgumentParser(
        description='Run analytics ETL processes'
    )
    parser.add_argument(
        '--cohort',
        action='store_true',
        help='Run only cohort analysis'
    )
    parser.add_argument(
        '--churn',
        action='store_true',
        help='Run only churn risk analysis'
    )
    parser.add_argument(
        '--funnel',
        action='store_true',
        help='Run only funnel analysis'
    )
    parser.add_argument(
        '--ltv',
        action='store_true',
        help='Run only LTV analysis'
    )
    parser.add_argument(
        '--rfm',
        action='store_true',
        help='Run only RFM segmentation'
    )
    parser.add_argument(
        '--all',
        action='store_true',
        help='Run all ETL processes (default)'
    )
    
    args = parser.parse_args()
    
    # Default to --all if no specific flag is provided
    if not (args.cohort or args.churn or args.funnel or args.ltv or args.rfm):
        args.all = True
    
    success = True
    
    if args.all:
        success = run_all_etl_processes()
    else:
        if args.cohort:
            logger.info("Running cohort analysis only")
            success = etl_cohort.refresh_cohort_analytics() and success
            
        if args.churn:
            logger.info("Running churn risk analysis only")
            success = etl_churn.refresh_churn_risk() and success
            
        if args.funnel:
            logger.info("Running funnel analysis only")
            success = etl_funnel.refresh_funnel_analytics() and success
            
        if args.ltv:
            logger.info("Running LTV analysis only")
            success = etl_ltv.refresh_ltv_analytics() and success
            
        if args.rfm:
            logger.info("Running RFM segmentation only")
            success = etl_rfm.refresh_rfm_analytics() and success
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
