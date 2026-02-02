"""Configuration for analytics ETL scripts."""

import os
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables
load_dotenv()

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
DATABASE_URL = os.getenv('DATABASE_URL')

# Validate required environment variables
if not all([SUPABASE_URL, SUPABASE_SERVICE_KEY, DATABASE_URL]):
    raise ValueError(
        "Missing required environment variables. Please set:\n"
        "  - SUPABASE_URL\n"
        "  - SUPABASE_SERVICE_KEY\n"
        "  - DATABASE_URL"
    )

# Directories
BASE_DIR = Path(__file__).parent
LOGS_DIR = BASE_DIR / 'logs'
EXPORTS_DIR = BASE_DIR / 'exports'

# Create directories if they don't exist
LOGS_DIR.mkdir(exist_ok=True)
EXPORTS_DIR.mkdir(exist_ok=True)

# Logging configuration
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# ETL configuration
BATCH_SIZE = int(os.getenv('BATCH_SIZE', '1000'))
MAX_RETRIES = int(os.getenv('MAX_RETRIES', '3'))
RETRY_DELAY = int(os.getenv('RETRY_DELAY', '5'))  # seconds

# Analytics configuration
COHORT_MONTHS_BACK = int(os.getenv('COHORT_MONTHS_BACK', '12'))
CHURN_THRESHOLD_DAYS = int(os.getenv('CHURN_THRESHOLD_DAYS', '30'))
