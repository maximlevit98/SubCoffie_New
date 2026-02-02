#!/bin/bash

# Analytics ETL Runner Script
# This script runs the analytics ETL processes and handles errors

set -e  # Exit on error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANALYTICS_DIR="$PROJECT_ROOT/analytics"
LOG_DIR="$ANALYTICS_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Main log file
MAIN_LOG="$LOG_DIR/run_etl_${TIMESTAMP}.log"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAIN_LOG"
}

# Function to send alert (optional - requires email configuration)
send_alert() {
    local subject="$1"
    local message="$2"
    
    # Uncomment and configure if you want email alerts
    # if [ -n "$ALERT_EMAIL" ]; then
    #     echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    # fi
    
    log "ALERT: $subject - $message"
}

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    log "ERROR: Python 3 is not installed"
    exit 1
fi

# Check if analytics directory exists
if [ ! -d "$ANALYTICS_DIR" ]; then
    log "ERROR: Analytics directory not found at $ANALYTICS_DIR"
    exit 1
fi

# Change to analytics directory
cd "$ANALYTICS_DIR"

# Load environment variables if .env exists
if [ -f ".env" ]; then
    log "Loading environment variables from .env"
    set -a
    source .env
    set +a
else
    log "WARNING: .env file not found. Using system environment variables."
fi

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    log "Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    log "Installing dependencies..."
    pip install --quiet -r requirements.txt
else
    source venv/bin/activate
fi

# Run ETL processes
log "========================================="
log "Starting Analytics ETL Pipeline"
log "========================================="

# Default: run all ETL processes
ETL_MODE=${1:-all}

case $ETL_MODE in
    all)
        log "Running all ETL processes..."
        if python3 etl_aggregate.py --all 2>&1 | tee -a "$MAIN_LOG"; then
            log "✓ All ETL processes completed successfully"
            exit 0
        else
            log "✗ Some ETL processes failed"
            send_alert "Analytics ETL Failed" "One or more ETL processes failed. Check logs at $MAIN_LOG"
            exit 1
        fi
        ;;
    cohort)
        log "Running cohort analysis..."
        python3 etl_cohort.py 2>&1 | tee -a "$MAIN_LOG"
        ;;
    churn)
        log "Running churn risk analysis..."
        python3 etl_churn.py 2>&1 | tee -a "$MAIN_LOG"
        ;;
    funnel)
        log "Running funnel analysis..."
        python3 etl_funnel.py 2>&1 | tee -a "$MAIN_LOG"
        ;;
    ltv)
        log "Running LTV analysis..."
        python3 etl_ltv.py 2>&1 | tee -a "$MAIN_LOG"
        ;;
    rfm)
        log "Running RFM segmentation..."
        python3 etl_rfm.py 2>&1 | tee -a "$MAIN_LOG"
        ;;
    export)
        log "Exporting analytics data..."
        python3 export_data.py --all 2>&1 | tee -a "$MAIN_LOG"
        ;;
    *)
        log "ERROR: Unknown ETL mode: $ETL_MODE"
        log "Usage: $0 [all|cohort|churn|funnel|ltv|rfm|export]"
        exit 1
        ;;
esac

log "========================================="
log "ETL Pipeline completed"
log "Log saved to: $MAIN_LOG"
log "========================================="
