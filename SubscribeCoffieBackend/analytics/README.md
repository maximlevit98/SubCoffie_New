# Analytics ETL Scripts

This directory contains ETL (Extract, Transform, Load) scripts for advanced analytics and business intelligence.

## Overview

The analytics infrastructure includes:

1. **Cohort Analysis** - Track user retention over time
2. **Funnel Analysis** - Understand conversion rates at each step
3. **Churn Prediction** - Identify users at risk of churning
4. **LTV Calculation** - Calculate lifetime value of customers
5. **RFM Segmentation** - Segment customers by Recency, Frequency, Monetary value
6. **Revenue Analytics** - Deep dive into revenue patterns

## Setup

### Prerequisites

- Python 3.9+
- PostgreSQL access to Supabase
- Environment variables configured

### Installation

```bash
cd analytics
pip install -r requirements.txt
```

### Configuration

Create a `.env` file in the analytics directory:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_service_role_key
DATABASE_URL=postgresql://postgres:[password]@[host]:5432/postgres
```

## Scripts

### 1. `etl_cohort.py`
Refreshes cohort analytics data by calculating retention rates for user cohorts.

```bash
python etl_cohort.py
```

### 2. `etl_churn.py`
Calculates churn risk scores for all users based on their behavior patterns.

```bash
python etl_churn.py
```

### 3. `etl_funnel.py`
Analyzes conversion funnel and identifies bottlenecks in the user journey.

```bash
python etl_funnel.py
```

### 4. `etl_ltv.py`
Calculates customer lifetime value (LTV) and identifies high-value customer segments.

```bash
python etl_ltv.py
```

### 5. `etl_rfm.py`
Performs RFM (Recency, Frequency, Monetary) segmentation for targeted marketing.

```bash
python etl_rfm.py
```

### 6. `etl_aggregate.py`
Main aggregation script that runs all ETL processes.

```bash
python etl_aggregate.py --all
```

Options:
- `--cohort` - Run only cohort analysis
- `--churn` - Run only churn prediction
- `--funnel` - Run only funnel analysis
- `--ltv` - Run only LTV analysis
- `--rfm` - Run only RFM segmentation
- `--all` - Run all ETL processes (default)

### 7. `export_data.py`
Exports analytics data to various formats for external BI tools.

```bash
# Export to CSV
python export_data.py --format csv --output ./exports/

# Export to JSON
python export_data.py --format json --output ./exports/

# Export to Parquet (for data warehouse)
python export_data.py --format parquet --output ./exports/
```

Export options:
- `--cohort` - Export only cohort data
- `--churn` - Export only churn risk data
- `--ltv` - Export only LTV data
- `--rfm` - Export only RFM segments
- `--funnel` - Export only funnel data
- `--revenue` - Export only revenue data
- `--all` - Export all data (default)

## Scheduling

### Using Cron (Linux/Mac)

**Automated Setup:**
```bash
cd ../scripts
./setup_analytics_cron.sh
```

**Manual Setup:**

Add to crontab (`crontab -e`):

```cron
# Run cohort analysis daily at 2 AM
0 2 * * * cd /path/to/analytics && python etl_cohort.py >> logs/cohort.log 2>&1

# Run churn prediction daily at 3 AM
0 3 * * * cd /path/to/analytics && python etl_churn.py >> logs/churn.log 2>&1

# Run funnel analysis daily at 3:30 AM
30 3 * * * cd /path/to/analytics && python etl_funnel.py >> logs/funnel.log 2>&1

# Run LTV analysis daily at 4 AM
0 4 * * * cd /path/to/analytics && python etl_ltv.py >> logs/ltv.log 2>&1

# Run RFM segmentation daily at 4:30 AM
30 4 * * * cd /path/to/analytics && python etl_rfm.py >> logs/rfm.log 2>&1

# Run full pipeline daily at 5 AM (backup/verification)
0 5 * * * cd /path/to/analytics && python etl_aggregate.py --all >> logs/etl.log 2>&1

# Export data weekly on Monday at 6 AM
0 6 * * 1 cd /path/to/analytics && python export_data.py --all >> logs/export.log 2>&1
```

**Or use the wrapper script:**
```cron
0 5 * * * /path/to/scripts/run_analytics_etl.sh all >> /path/to/analytics/logs/cron.log 2>&1
```

### Using Supabase pg_cron

**Apply the pg_cron migration:**
```bash
cd ../supabase
supabase migration up 20260230000000_analytics_cron_jobs
```

**Verify jobs are scheduled:**
```sql
SELECT * FROM cron.job WHERE jobname LIKE '%analytics%';
```

**Check job execution history:**
```sql
SELECT * FROM cron.job_run_details 
WHERE jobname LIKE '%analytics%'
ORDER BY start_time DESC 
LIMIT 10;
```

**Monitor analytics freshness:**
```sql
SELECT * FROM check_analytics_freshness();
```

## Monitoring

Check logs in the `logs/` directory:

```bash
tail -f logs/etl.log
tail -f logs/cohort.log
tail -f logs/churn.log
```

## Data Warehouse Integration

### Metabase

1. Install Metabase (Docker recommended):
   ```bash
   docker run -d -p 3000:3000 --name metabase metabase/metabase
   ```

2. Connect to Supabase PostgreSQL database
3. Use the analytics views and functions as data sources
4. Create dashboards for:
   - Cohort retention heatmaps
   - Churn risk distribution
   - RFM segment analysis
   - Revenue breakdowns

### Apache Superset

1. Install Superset:
   ```bash
   pip install apache-superset
   superset db upgrade
   superset init
   ```

2. Connect to Supabase database
3. Import dashboard templates from `dashboards/superset/`

## API Endpoints

The analytics functions can be called via Supabase RPC:

```typescript
// Cohort retention
const { data } = await supabase.rpc('calculate_cohort_retention', { 
  months_back: 12 
});

// Churn risk
const { data } = await supabase.rpc('calculate_churn_risk');

// LTV analysis
const { data } = await supabase.rpc('calculate_customer_ltv', { 
  months_back: 12 
});

// RFM segments
const { data } = await supabase.rpc('calculate_rfm_segments');

// Revenue breakdown
const { data } = await supabase.rpc('get_revenue_breakdown', {
  cafe_id_param: 'uuid',
  from_date: '2024-01-01',
  to_date: '2024-12-31'
});

// Full analytics dashboard
const { data } = await supabase.rpc('get_analytics_dashboard', {
  cafe_id_param: 'uuid' // optional
});
```

## Performance Considerations

- Cohort and churn calculations can be CPU-intensive for large datasets
- Consider running ETL during off-peak hours
- Use the pre-aggregated tables (`cohort_analytics`, `user_churn_risk`) for dashboards
- Add indexes on frequently queried columns

## Troubleshooting

### Slow Queries

Check execution time:
```sql
EXPLAIN ANALYZE SELECT * FROM calculate_cohort_retention(12);
```

Add indexes if needed:
```sql
CREATE INDEX idx_orders_customer_created ON orders(customer_phone, created_at);
CREATE INDEX idx_orders_cafe_created ON orders(cafe_id, created_at);
```

### Missing Data

Ensure pg_cron is enabled and scheduled jobs are running:
```sql
SELECT * FROM cron.job;
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
```

### Permission Errors

Grant necessary permissions:
```sql
GRANT EXECUTE ON FUNCTION refresh_cohort_analytics TO service_role;
GRANT EXECUTE ON FUNCTION refresh_churn_risk TO service_role;
```

## Contributing

When adding new analytics:

1. Create SQL function in a new migration
2. Add corresponding ETL script if needed
3. Update this README with usage instructions
4. Add tests in `tests/` directory
