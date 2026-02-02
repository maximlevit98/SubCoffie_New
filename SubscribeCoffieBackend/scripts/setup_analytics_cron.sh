#!/bin/bash

# Setup Cron Jobs for Analytics ETL
# This script creates cron jobs for automated analytics processing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ETL_SCRIPT="$SCRIPT_DIR/run_analytics_etl.sh"

echo "========================================="
echo "Analytics Cron Setup"
echo "========================================="

# Check if ETL script exists and is executable
if [ ! -f "$ETL_SCRIPT" ]; then
    echo "ERROR: ETL script not found at $ETL_SCRIPT"
    exit 1
fi

# Make ETL script executable
chmod +x "$ETL_SCRIPT"

echo "Setting up cron jobs for analytics ETL..."
echo ""
echo "Recommended schedule:"
echo "  - Cohort analysis: Daily at 2:00 AM"
echo "  - Churn risk: Daily at 3:00 AM"
echo "  - Funnel analysis: Daily at 3:30 AM"
echo "  - LTV analysis: Daily at 4:00 AM"
echo "  - RFM segmentation: Daily at 4:30 AM"
echo "  - Full pipeline: Daily at 5:00 AM"
echo "  - Data export: Weekly on Monday at 6:00 AM"
echo ""

# Create temporary cron file
CRON_FILE=$(mktemp)

# Get current crontab
crontab -l > "$CRON_FILE" 2>/dev/null || true

# Check if analytics jobs already exist
if grep -q "Analytics ETL" "$CRON_FILE"; then
    echo "WARNING: Analytics cron jobs already exist."
    echo "Please review and update manually with: crontab -e"
    rm "$CRON_FILE"
    exit 0
fi

# Add header
echo "" >> "$CRON_FILE"
echo "# Analytics ETL - Auto-generated on $(date)" >> "$CRON_FILE"
echo "" >> "$CRON_FILE"

# Add cron jobs
cat >> "$CRON_FILE" << EOF
# Run cohort analysis daily at 2 AM
0 2 * * * $ETL_SCRIPT cohort >> $PROJECT_ROOT/analytics/logs/cron_cohort.log 2>&1

# Run churn risk analysis daily at 3 AM
0 3 * * * $ETL_SCRIPT churn >> $PROJECT_ROOT/analytics/logs/cron_churn.log 2>&1

# Run funnel analysis daily at 3:30 AM
30 3 * * * $ETL_SCRIPT funnel >> $PROJECT_ROOT/analytics/logs/cron_funnel.log 2>&1

# Run LTV analysis daily at 4 AM
0 4 * * * $ETL_SCRIPT ltv >> $PROJECT_ROOT/analytics/logs/cron_ltv.log 2>&1

# Run RFM segmentation daily at 4:30 AM
30 4 * * * $ETL_SCRIPT rfm >> $PROJECT_ROOT/analytics/logs/cron_rfm.log 2>&1

# Run full ETL pipeline daily at 5 AM (backup/verification)
0 5 * * * $ETL_SCRIPT all >> $PROJECT_ROOT/analytics/logs/cron_full.log 2>&1

# Export data weekly on Monday at 6 AM
0 6 * * 1 $ETL_SCRIPT export >> $PROJECT_ROOT/analytics/logs/cron_export.log 2>&1
EOF

# Install new crontab
crontab "$CRON_FILE"
rm "$CRON_FILE"

echo ""
echo "✓ Cron jobs installed successfully!"
echo ""
echo "To view your cron jobs:"
echo "  crontab -l"
echo ""
echo "To edit cron jobs:"
echo "  crontab -e"
echo ""
echo "To remove analytics cron jobs:"
echo "  crontab -l | grep -v 'Analytics ETL' | grep -v '$ETL_SCRIPT' | crontab -"
echo ""
echo "Logs will be saved to:"
echo "  $PROJECT_ROOT/analytics/logs/cron_*.log"
echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
