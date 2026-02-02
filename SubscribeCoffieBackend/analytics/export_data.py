#!/usr/bin/env python3
"""Export analytics data to various formats for external BI tools."""

import logging
import sys
import argparse
from datetime import datetime
from pathlib import Path
import pandas as pd
from db_utils import execute_query, call_rpc_function
from config import LOGS_DIR, EXPORTS_DIR, LOG_FORMAT, LOG_LEVEL

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOGS_DIR / 'export.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def export_cohort_data(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export cohort analytics data."""
    logger.info(f"Exporting cohort data to {output_format}")
    
    query = "SELECT * FROM cohort_analytics ORDER BY cohort_month DESC, period_number;"
    data = execute_query(query)
    
    if not data:
        logger.warning("No cohort data to export")
        return None
    
    df = pd.DataFrame(data)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"cohort_analytics_{timestamp}"
    
    output_file = export_dataframe(df, filename, output_format, output_dir)
    logger.info(f"Cohort data exported: {output_file}")
    return output_file


def export_churn_data(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export churn risk data."""
    logger.info(f"Exporting churn risk data to {output_format}")
    
    query = """
        SELECT * FROM user_churn_risk 
        WHERE calculated_at::date = CURRENT_DATE
        ORDER BY risk_score DESC;
    """
    data = execute_query(query)
    
    if not data:
        logger.warning("No churn data to export")
        return None
    
    df = pd.DataFrame(data)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"churn_risk_{timestamp}"
    
    output_file = export_dataframe(df, filename, output_format, output_dir)
    logger.info(f"Churn data exported: {output_file}")
    return output_file


def export_ltv_data(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export LTV analysis data."""
    logger.info(f"Exporting LTV data to {output_format}")
    
    data = call_rpc_function('calculate_customer_ltv', {'months_back': 12})
    
    if not data:
        logger.warning("No LTV data to export")
        return None
    
    df = pd.DataFrame(data)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"customer_ltv_{timestamp}"
    
    output_file = export_dataframe(df, filename, output_format, output_dir)
    logger.info(f"LTV data exported: {output_file}")
    return output_file


def export_rfm_data(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export RFM segmentation data."""
    logger.info(f"Exporting RFM data to {output_format}")
    
    data = call_rpc_function('calculate_rfm_segments')
    
    if not data:
        logger.warning("No RFM data to export")
        return None
    
    df = pd.DataFrame(data)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"rfm_segments_{timestamp}"
    
    output_file = export_dataframe(df, filename, output_format, output_dir)
    logger.info(f"RFM data exported: {output_file}")
    return output_file


def export_funnel_data(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export conversion funnel data."""
    logger.info(f"Exporting funnel data to {output_format}")
    
    data = call_rpc_function('calculate_conversion_funnel')
    
    if not data:
        logger.warning("No funnel data to export")
        return None
    
    df = pd.DataFrame(data)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"conversion_funnel_{timestamp}"
    
    output_file = export_dataframe(df, filename, output_format, output_dir)
    logger.info(f"Funnel data exported: {output_file}")
    return output_file


def export_revenue_data(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export revenue analytics data."""
    logger.info(f"Exporting revenue data to {output_format}")
    
    # Get revenue breakdown for last 30 days
    data = call_rpc_function('get_revenue_breakdown', {
        'from_date': 'now() - interval \'30 days\'',
        'to_date': 'now()'
    })
    
    if not data:
        logger.warning("No revenue data to export")
        return None
    
    # Flatten JSON structure for CSV export
    if isinstance(data, list) and len(data) > 0:
        revenue_data = data[0]
        
        # Extract overview data
        overview_df = pd.json_normalize(revenue_data.get('overview', []))
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Export overview
        if not overview_df.empty:
            filename = f"revenue_overview_{timestamp}"
            output_file = export_dataframe(overview_df, filename, output_format, output_dir)
            logger.info(f"Revenue overview exported: {output_file}")
        
        # Export category breakdown
        category_data = revenue_data.get('by_category', [])
        if category_data:
            category_df = pd.json_normalize(category_data)
            filename = f"revenue_by_category_{timestamp}"
            output_file = export_dataframe(category_df, filename, output_format, output_dir)
            logger.info(f"Revenue by category exported: {output_file}")
        
        # Export hourly breakdown
        hourly_data = revenue_data.get('by_hour', [])
        if hourly_data:
            hourly_df = pd.json_normalize(hourly_data)
            filename = f"revenue_by_hour_{timestamp}"
            output_file = export_dataframe(hourly_df, filename, output_format, output_dir)
            logger.info(f"Revenue by hour exported: {output_file}")
        
        return output_file


def export_dataframe(
    df: pd.DataFrame, 
    filename: str, 
    output_format: str, 
    output_dir: Path
) -> Path:
    """
    Export a pandas DataFrame to specified format.
    
    Args:
        df: DataFrame to export
        filename: Base filename (without extension)
        output_format: Format (csv, json, parquet)
        output_dir: Output directory
        
    Returns:
        Path to exported file
    """
    output_dir.mkdir(exist_ok=True)
    
    if output_format == 'csv':
        output_file = output_dir / f"{filename}.csv"
        df.to_csv(output_file, index=False)
    elif output_format == 'json':
        output_file = output_dir / f"{filename}.json"
        df.to_json(output_file, orient='records', indent=2)
    elif output_format == 'parquet':
        output_file = output_dir / f"{filename}.parquet"
        df.to_parquet(output_file, index=False)
    else:
        raise ValueError(f"Unsupported format: {output_format}")
    
    return output_file


def export_all(output_format: str = 'csv', output_dir: Path = EXPORTS_DIR):
    """Export all analytics data."""
    logger.info("=" * 80)
    logger.info(f"Exporting all analytics data to {output_format}")
    logger.info("=" * 80)
    
    exports = {
        'cohort': export_cohort_data,
        'churn': export_churn_data,
        'ltv': export_ltv_data,
        'rfm': export_rfm_data,
        'funnel': export_funnel_data,
        'revenue': export_revenue_data,
    }
    
    results = {}
    for name, export_func in exports.items():
        try:
            logger.info(f"\nExporting {name} data...")
            output_file = export_func(output_format, output_dir)
            results[name] = output_file is not None
        except Exception as e:
            logger.error(f"Failed to export {name} data: {e}", exc_info=True)
            results[name] = False
    
    # Summary
    logger.info("\n" + "=" * 80)
    logger.info("Export Summary")
    logger.info("=" * 80)
    for name, success in results.items():
        status = "✓ Success" if success else "✗ Failed"
        logger.info(f"{name.capitalize()}: {status}")
    
    return all(results.values())


def main():
    """Main entry point with command-line argument parsing."""
    parser = argparse.ArgumentParser(
        description='Export analytics data to various formats'
    )
    parser.add_argument(
        '--format',
        choices=['csv', 'json', 'parquet'],
        default='csv',
        help='Output format (default: csv)'
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=EXPORTS_DIR,
        help=f'Output directory (default: {EXPORTS_DIR})'
    )
    parser.add_argument(
        '--cohort',
        action='store_true',
        help='Export only cohort data'
    )
    parser.add_argument(
        '--churn',
        action='store_true',
        help='Export only churn risk data'
    )
    parser.add_argument(
        '--ltv',
        action='store_true',
        help='Export only LTV data'
    )
    parser.add_argument(
        '--rfm',
        action='store_true',
        help='Export only RFM data'
    )
    parser.add_argument(
        '--revenue',
        action='store_true',
        help='Export only revenue data'
    )
    parser.add_argument(
        '--funnel',
        action='store_true',
        help='Export only funnel data'
    )
    parser.add_argument(
        '--all',
        action='store_true',
        help='Export all data (default)'
    )
    
    args = parser.parse_args()
    
    # Default to --all if no specific flag is provided
    if not (args.cohort or args.churn or args.ltv or args.rfm or args.revenue or args.funnel):
        args.all = True
    
    success = True
    
    if args.all:
        success = export_all(args.format, args.output)
    else:
        if args.cohort:
            export_cohort_data(args.format, args.output)
        if args.churn:
            export_churn_data(args.format, args.output)
        if args.ltv:
            export_ltv_data(args.format, args.output)
        if args.rfm:
            export_rfm_data(args.format, args.output)
        if args.funnel:
            export_funnel_data(args.format, args.output)
        if args.revenue:
            export_revenue_data(args.format, args.output)
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
