# Advanced Analytics and BI Implementation Guide

## Overview

This document describes the advanced analytics and business intelligence infrastructure implemented for SubscribeCoffie. The system provides comprehensive analytics including cohort analysis, funnel tracking, churn prediction, LTV calculation, and RFM segmentation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Analytics Infrastructure                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  PostgreSQL DB  │  │  ETL Scripts     │  │  BI Tools      │ │
│  │                 │  │                  │  │                │ │
│  │  • Analytics    │←→│  • Cohort ETL    │←→│  • Metabase    │ │
│  │    Views        │  │  • Churn ETL     │  │  • Superset    │ │
│  │  • RPC          │  │  • Aggregation   │  │  • Exports     │ │
│  │    Functions    │  │  • Export        │  │                │ │
│  │  • Triggers     │  │                  │  │                │ │
│  └─────────────────┘  └──────────────────┘  └────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Admin Panel Analytics Dashboard                 ││
│  │  • Real-time Metrics  • Cohort Heatmaps  • Churn Alerts    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Database Schema

### 1. Cohort Analytics

**Table: `cohort_analytics`**
Stores pre-aggregated cohort retention data for fast dashboard queries.

```sql
- cohort_month: date          -- Month when cohort started
- period_number: int          -- Periods since first order (0, 1, 2, ...)
- users_count: int            -- Initial cohort size
- active_users: int           -- Users active in this period
- retention_rate: decimal     -- Percentage retained
- total_revenue: bigint       -- Revenue from this cohort in this period
- avg_revenue_per_user: decimal
```

**Function: `calculate_cohort_retention(months_back)`**
Calculates retention rates for user cohorts over time.

**Function: `refresh_cohort_analytics()`**
Updates the aggregated cohort_analytics table.

### 2. Funnel Analysis

**Table: `funnel_events`**
Tracks user journey through the conversion funnel.

```sql
- user_id: uuid
- customer_phone: text
- event_type: text            -- view_cafe, add_to_cart, checkout, payment, order_created, order_completed
- cafe_id: uuid
- order_id: uuid
- session_id: text
- metadata: jsonb
- created_at: timestamptz
```

**Function: `calculate_conversion_funnel(cafe_id, from_date, to_date)`**
Returns conversion rates at each funnel step.

**Automatic Tracking:**
Trigger `order_funnel_tracking` automatically creates funnel events when orders are created.

### 3. Churn Prediction

**Table: `user_churn_risk`**
Stores calculated churn risk scores for users.

```sql
- customer_phone: text
- risk_score: decimal         -- 0-100 risk score
- risk_level: text            -- low, medium, high, critical
- last_order_date: timestamptz
- days_since_last_order: int
- total_orders: int
- total_spent: bigint
- avg_order_frequency: decimal
- features: jsonb             -- Additional risk factors
- calculated_at: timestamptz
```

**Function: `calculate_churn_risk()`**
Calculates churn risk for all users based on behavioral patterns.

**Risk Calculation Logic:**
- **Critical (80+)**: No orders in 60+ days OR 3x longer than usual
- **High (60-79)**: No orders in 30-60 days OR 2x longer than usual
- **Medium (40-59)**: No orders in 15-30 days
- **Low (0-39)**: Active users, recent orders

Adjustments:
- Loyal customers (10+ orders): -5 to -10 points
- New customers (≤2 orders): +15 points
- High value (avg > 500₽): -5 points

**Function: `refresh_churn_risk()`**
Updates the user_churn_risk table with fresh calculations.

### 4. Customer Lifetime Value (LTV)

**Function: `calculate_customer_ltv(months_back)`**
Calculates predicted lifetime value for customers.

Returns:
- First and last order dates
- Total orders and revenue
- Average order value and frequency
- Predicted annual LTV
- Customer segment (vip, high_value, medium_value, frequent, regular, new)

### 5. RFM Segmentation

**Function: `calculate_rfm_segments()`**
Segments customers by Recency, Frequency, and Monetary value.

**RFM Scores (1-5 scale):**
- **Recency**: Days since last order (lower is better)
  - Score 5: ≤7 days
  - Score 4: 8-14 days
  - Score 3: 15-30 days
  - Score 2: 31-60 days
  - Score 1: >60 days

- **Frequency**: Number of orders
  - Score 5: ≥20 orders
  - Score 4: 10-19 orders
  - Score 3: 5-9 orders
  - Score 2: 2-4 orders
  - Score 1: 1 order

- **Monetary**: Total spent
  - Score 5: ≥10,000₽
  - Score 4: 5,000-9,999₽
  - Score 3: 2,000-4,999₽
  - Score 2: 1,000-1,999₽
  - Score 1: <1,000₽

**Customer Segments:**
- **Champions** (R≥4, F≥4, M≥4): Best customers, buy often and recently
- **Loyal Customers** (R≥3, F≥4, M≥4): Regular buyers
- **Big Spenders** (R≥4, F≤2, M≥4): High value, infrequent
- **Promising** (R≥4, F≥3): Recently active, frequent buyers
- **Potential Loyalists** (R≥3, F≥3): Could become regular
- **New Customers** (R≥4, F≤2, M≤2): Just made first purchase
- **At Risk** (R≤2, F≥4, M≥4): Valuable customers who stopped
- **Need Attention** (R≤2, F≥2, M≥2): Need re-engagement
- **Lost** (R≤2, F≤2): Haven't bought in a long time

### 6. Revenue Analytics

**Function: `get_revenue_breakdown(cafe_id, from_date, to_date)`**
Comprehensive revenue analysis with breakdowns by:
- Cafe overview (gross, net, bonus usage)
- Category performance
- Hourly patterns

### 7. Analytics Dashboard

**Function: `get_analytics_dashboard(cafe_id)`**
Single function that returns all key metrics:
- Churn risk distribution
- RFM segment counts
- LTV summary
- Recent cohort retention

## ETL Scripts

### Directory Structure

```
analytics/
├── README.md                 # ETL documentation
├── requirements.txt          # Python dependencies
├── config.py                # Configuration management
├── db_utils.py              # Database utilities
├── etl_cohort.py            # Cohort analysis ETL
├── etl_churn.py             # Churn prediction ETL
├── etl_aggregate.py         # Main aggregation script
├── export_data.py           # Data export to CSV/JSON/Parquet
├── logs/                    # ETL execution logs
└── exports/                 # Exported data files
```

### Setup

1. **Install dependencies:**
```bash
cd analytics
pip install -r requirements.txt
```

2. **Configure environment:**
Create `.env` file:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your_service_role_key
DATABASE_URL=postgresql://postgres:password@host:5432/postgres
```

3. **Run ETL processes:**
```bash
# Run all analytics
python etl_aggregate.py --all

# Run specific processes
python etl_cohort.py
python etl_churn.py

# Export data
python export_data.py --format csv --all
```

### Scheduling

**Option 1: Cron Jobs (Recommended for production)**
```cron
# Daily at 2 AM
0 2 * * * cd /path/to/analytics && python etl_cohort.py >> logs/cohort.log 2>&1

# Daily at 3 AM
0 3 * * * cd /path/to/analytics && python etl_churn.py >> logs/churn.log 2>&1

# Weekly exports on Monday at 4 AM
0 4 * * 1 cd /path/to/analytics && python export_data.py --all >> logs/export.log 2>&1
```

**Option 2: Supabase pg_cron**
Enable pg_cron in Supabase Dashboard, then:
```sql
-- Schedule cohort analysis
SELECT cron.schedule('refresh-cohort-analytics', '0 2 * * *', 'SELECT refresh_cohort_analytics()');

-- Schedule churn prediction
SELECT cron.schedule('refresh-churn-risk', '0 3 * * *', 'SELECT refresh_churn_risk()');
```

## API Usage

All analytics functions can be called via Supabase RPC:

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Get analytics dashboard
const { data: dashboard } = await supabase.rpc('get_analytics_dashboard', {
  cafe_id_param: cafeId // optional
});

// Get cohort retention
const { data: cohorts } = await supabase.rpc('calculate_cohort_retention', {
  months_back: 12
});

// Get churn risk users
const { data: churnUsers } = await supabase.rpc('calculate_churn_risk');

// Get RFM segments
const { data: segments } = await supabase.rpc('calculate_rfm_segments');

// Get LTV analysis
const { data: ltv } = await supabase.rpc('calculate_customer_ltv', {
  months_back: 12
});

// Get revenue breakdown
const { data: revenue } = await supabase.rpc('get_revenue_breakdown', {
  cafe_id_param: cafeId,
  from_date: '2024-01-01',
  to_date: '2024-12-31'
});

// Get conversion funnel
const { data: funnel } = await supabase.rpc('calculate_conversion_funnel', {
  cafe_id_param: cafeId,
  from_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
  to_date: new Date().toISOString()
});
```

## Admin Panel Integration

### Pages to Create

**`/admin/analytics`** - Main analytics dashboard
- Overview metrics
- Quick stats (churn, retention, LTV)
- Links to detailed reports

**`/admin/analytics/cohorts`** - Cohort retention heatmap
- Interactive cohort table
- Retention curves
- Cohort comparison

**`/admin/analytics/churn`** - Churn risk management
- High-risk user list
- Risk distribution chart
- Trend analysis
- Export high-risk users for campaigns

**`/admin/analytics/ltv`** - Customer value analysis
- LTV distribution
- Customer segments
- Top customers by value

**`/admin/analytics/rfm`** - RFM segmentation
- Segment breakdown
- Customer lists per segment
- Marketing recommendations

**`/admin/analytics/funnel`** - Conversion funnel
- Step-by-step conversion rates
- Drop-off analysis
- Time-to-convert metrics

**`/admin/analytics/revenue`** - Revenue deep dive
- Revenue trends
- Category performance
- Hourly patterns
- Cafe comparison

## BI Tools Integration

### Metabase

1. **Install Metabase:**
```bash
docker run -d -p 3000:3000 --name metabase metabase/metabase
```

2. **Connect to Supabase:**
   - Database Type: PostgreSQL
   - Host: db.your-project.supabase.co
   - Port: 5432
   - Database: postgres
   - Username: postgres
   - Password: [your password]

3. **Create Dashboards:**
   - Cohort Retention Heatmap
   - Churn Risk Distribution
   - RFM Segment Analysis
   - Revenue Trends

### Apache Superset

1. **Install:**
```bash
pip install apache-superset
superset db upgrade
superset fab create-admin
superset init
superset run -p 8088
```

2. **Connect Database:**
   - SQLAlchemy URI: `postgresql://postgres:password@host:5432/postgres`

3. **Use SQL Lab** to query analytics functions directly

## Performance Optimization

### Indexes

The migration includes essential indexes:
```sql
CREATE INDEX idx_funnel_events_customer ON funnel_events(customer_phone);
CREATE INDEX idx_funnel_events_session ON funnel_events(session_id);
CREATE INDEX idx_funnel_events_created ON funnel_events(created_at);
CREATE INDEX idx_churn_risk_phone ON user_churn_risk(customer_phone);
CREATE INDEX idx_churn_risk_level ON user_churn_risk(risk_level);
```

Add more as needed:
```sql
CREATE INDEX idx_orders_customer_created ON orders(customer_phone, created_at);
CREATE INDEX idx_orders_cafe_status_created ON orders(cafe_id, status, created_at);
```

### Query Optimization

- Use pre-aggregated tables (`cohort_analytics`, `user_churn_risk`) for dashboards
- Run heavy calculations during off-peak hours
- Use `EXPLAIN ANALYZE` to identify slow queries
- Run `VACUUM ANALYZE` regularly (included in ETL scripts)

### Caching

For admin panel:
```typescript
// Cache expensive queries for 5 minutes
const cachedData = await redis.get('analytics:dashboard');
if (cachedData) return JSON.parse(cachedData);

const data = await supabase.rpc('get_analytics_dashboard');
await redis.setex('analytics:dashboard', 300, JSON.stringify(data));
```

## Monitoring and Alerts

### Log Monitoring

Monitor ETL logs:
```bash
tail -f analytics/logs/etl.log
tail -f analytics/logs/cohort.log
tail -f analytics/logs/churn.log
```

### Alerting

Set up alerts for:
- ETL job failures
- Sudden spike in churn risk
- Significant drop in retention rates
- Database query performance degradation

Example using Slack webhook:
```python
import requests

def send_alert(message):
    webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    requests.post(webhook_url, json={"text": message})

# In ETL script
if critical_churn_count > threshold:
    send_alert(f"⚠️ Alert: {critical_churn_count} users at critical churn risk!")
```

## Business Use Cases

### 1. Retention Campaigns

Target users at risk of churning:
```sql
SELECT customer_phone, days_since_last_order, total_orders
FROM user_churn_risk
WHERE risk_level IN ('high', 'critical')
  AND total_orders >= 5  -- Focus on previously active users
ORDER BY risk_score DESC
LIMIT 100;
```

### 2. VIP Program

Identify high-value customers:
```sql
SELECT customer_phone, predicted_ltv, total_orders
FROM calculate_customer_ltv(12)
WHERE customer_segment IN ('vip', 'high_value')
ORDER BY predicted_ltv DESC;
```

### 3. Targeted Marketing

Use RFM segments for campaigns:
```sql
-- At-risk valuable customers
SELECT * FROM calculate_rfm_segments()
WHERE rfm_segment = 'at_risk';

-- New customers to nurture
SELECT * FROM calculate_rfm_segments()
WHERE rfm_segment = 'new_customers';
```

### 4. Menu Optimization

Analyze category performance:
```typescript
const { data } = await supabase.rpc('get_revenue_breakdown', {
  cafe_id_param: cafeId,
  from_date: '2024-01-01',
  to_date: '2024-12-31'
});

// data.by_category shows which categories drive revenue
```

### 5. Operational Planning

Identify peak hours:
```typescript
const { data } = await supabase.rpc('get_revenue_breakdown', {
  cafe_id_param: cafeId
});

// data.by_hour shows busiest times for staffing decisions
```

## Testing

Run the migration:
```bash
cd supabase
supabase db reset  # Reset and apply all migrations
```

Test functions:
```sql
-- Test cohort calculation
SELECT * FROM calculate_cohort_retention(12) LIMIT 10;

-- Test churn prediction
SELECT * FROM calculate_churn_risk() LIMIT 10;

-- Test RFM segmentation
SELECT rfm_segment, COUNT(*) FROM calculate_rfm_segments() GROUP BY rfm_segment;

-- Test analytics dashboard
SELECT get_analytics_dashboard();
```

## Troubleshooting

### Slow Queries

```sql
-- Check query execution time
EXPLAIN ANALYZE SELECT * FROM calculate_cohort_retention(12);

-- Check table sizes
SELECT 
  schemaname, tablename, 
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Missing Permissions

```sql
-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_cohort_retention TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_churn_risk TO authenticated;
GRANT SELECT ON cohort_analytics TO authenticated;
GRANT SELECT ON user_churn_risk TO authenticated;
```

### Stale Data

Manually refresh:
```sql
SELECT refresh_cohort_analytics();
SELECT refresh_churn_risk();
```

## Future Enhancements

1. **Machine Learning Models**
   - Train ML model for better churn prediction
   - Use Python scikit-learn or TensorFlow
   - Deploy as Supabase Edge Function

2. **Predictive Analytics**
   - Forecast future revenue
   - Predict customer lifetime value more accurately
   - Anomaly detection for unusual patterns

3. **Real-time Analytics**
   - Stream processing with Apache Kafka
   - Real-time dashboards with WebSockets
   - Live funnel tracking

4. **Advanced Segmentation**
   - Behavioral segmentation
   - Product affinity analysis
   - Customer journey mapping

## Conclusion

This advanced analytics infrastructure provides comprehensive insights into user behavior, business performance, and growth opportunities. The combination of SQL-based analytics with Python ETL scripts creates a flexible, scalable system that can grow with the business.

For questions or issues, refer to:
- ETL logs in `analytics/logs/`
- Database query plans with `EXPLAIN ANALYZE`
- Supabase Dashboard for database metrics
