# Advanced Analytics - Quick Start Guide

This guide will get you up and running with the advanced analytics system in 10 minutes.

## Step 1: Apply Database Migration (2 minutes)

```bash
cd SubscribeCoffieBackend

# If using local Supabase
supabase db reset

# Or apply just the analytics migration
supabase migration up 20260225000000_advanced_analytics
```

**What this does:**
- Creates analytics tables: `cohort_analytics`, `funnel_events`, `user_churn_risk`
- Creates analytics functions: cohort, churn, LTV, RFM, revenue breakdown
- Sets up automatic funnel tracking trigger
- Grants necessary permissions

## Step 2: Verify Installation (1 minute)

Test the analytics functions:

```sql
-- Check if functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%cohort%' OR routine_name LIKE '%churn%';

-- Quick test: Calculate churn risk
SELECT COUNT(*), risk_level 
FROM calculate_churn_risk() 
GROUP BY risk_level;

-- Quick test: Get RFM segments
SELECT rfm_segment, COUNT(*) 
FROM calculate_rfm_segments() 
GROUP BY rfm_segment;
```

Expected output: Functions should exist and return data (if you have orders in the system).

## Step 3: Setup ETL Scripts (3 minutes)

```bash
cd analytics

# Install Python dependencies
pip install -r requirements.txt

# Create environment file
cat > .env << EOF
SUPABASE_URL=http://localhost:54321
SUPABASE_SERVICE_KEY=your_service_role_key
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres
EOF

# Test ETL scripts
python etl_cohort.py
python etl_churn.py
```

**What this does:**
- Installs Python packages for ETL
- Configures database connection
- Runs initial analytics calculation

## Step 4: View Analytics (2 minutes)

### Option A: SQL Query

```sql
-- Get full analytics dashboard
SELECT get_analytics_dashboard();

-- Get cohort retention
SELECT * FROM calculate_cohort_retention(6) 
ORDER BY cohort_month DESC, period_number;

-- Get high-risk churn users
SELECT customer_phone, risk_score, risk_level, days_since_last_order
FROM calculate_churn_risk()
WHERE risk_level IN ('high', 'critical')
ORDER BY risk_score DESC
LIMIT 20;

-- Get RFM segments
SELECT rfm_segment, segment_description, COUNT(*) as count
FROM calculate_rfm_segments()
GROUP BY rfm_segment, segment_description
ORDER BY count DESC;
```

### Option B: Via Supabase Client

```typescript
// In your admin panel or app
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Get dashboard summary
const { data, error } = await supabase.rpc('get_analytics_dashboard');

console.log('Churn Risk:', data.churn_risk);
console.log('RFM Segments:', data.rfm_segments);
console.log('LTV Summary:', data.ltv_summary);
```

### Option C: Export to CSV

```bash
cd analytics

# Export all analytics to CSV
python export_data.py --format csv --all

# Check exports
ls -lh exports/
```

## Step 5: Schedule Automated Updates (2 minutes)

### Option A: Cron (Linux/Mac)

```bash
# Edit crontab
crontab -e

# Add these lines (adjust paths):
0 2 * * * cd /path/to/analytics && python etl_cohort.py >> logs/cohort.log 2>&1
0 3 * * * cd /path/to/analytics && python etl_churn.py >> logs/churn.log 2>&1
```

### Option B: Supabase pg_cron

```sql
-- Enable pg_cron in Supabase Dashboard first
-- Then schedule jobs:

SELECT cron.schedule(
  'refresh-cohort-analytics',
  '0 2 * * *',
  'SELECT refresh_cohort_analytics()'
);

SELECT cron.schedule(
  'refresh-churn-risk',
  '0 3 * * *',
  'SELECT refresh_churn_risk()'
);

-- Verify scheduled jobs
SELECT * FROM cron.job;
```

## Quick Reference: Key Functions

### 1. Analytics Dashboard (Everything in one call)
```sql
SELECT get_analytics_dashboard(cafe_id_param := NULL);
```
Returns: Churn risk, RFM segments, LTV summary, recent cohort

### 2. Cohort Retention
```sql
SELECT * FROM calculate_cohort_retention(months_back := 12);
```
Returns: Cohort month, size, retention rates by period

### 3. Churn Risk
```sql
SELECT * FROM calculate_churn_risk();
```
Returns: Users with risk scores (0-100) and risk levels

### 4. Customer LTV
```sql
SELECT * FROM calculate_customer_ltv(months_back := 12);
```
Returns: Predicted lifetime value per customer

### 5. RFM Segmentation
```sql
SELECT * FROM calculate_rfm_segments();
```
Returns: Customers segmented by Recency, Frequency, Monetary

### 6. Conversion Funnel
```sql
SELECT * FROM calculate_conversion_funnel(
  cafe_id_param := NULL,
  from_date := NOW() - INTERVAL '30 days',
  to_date := NOW()
);
```
Returns: Conversion rates at each funnel step

### 7. Revenue Breakdown
```sql
SELECT get_revenue_breakdown(
  cafe_id_param := NULL,
  from_date := NOW() - INTERVAL '30 days',
  to_date := NOW()
);
```
Returns: Revenue by cafe, category, hour

## Common Use Cases

### Use Case 1: Identify At-Risk Customers

**Goal:** Find valuable customers who haven't ordered recently

```sql
SELECT 
  customer_phone,
  risk_score,
  days_since_last_order,
  total_orders,
  total_spent
FROM calculate_churn_risk()
WHERE risk_level IN ('high', 'critical')
  AND total_orders >= 5
  AND total_spent >= 2000
ORDER BY risk_score DESC
LIMIT 50;
```

**Action:** Export to CSV and import to email marketing tool

```bash
python export_data.py --churn --format csv
```

### Use Case 2: Measure Retention

**Goal:** See how well we're retaining customers month-over-month

```sql
SELECT 
  cohort_month,
  cohort_size,
  retention_rate,
  period_number as months_since_first_order
FROM calculate_cohort_retention(12)
WHERE period_number IN (0, 1, 3, 6)
ORDER BY cohort_month DESC;
```

**Interpretation:**
- Period 0: 100% (first month)
- Period 1: Month 1 retention
- Period 3: Month 3 retention
- Period 6: Month 6 retention

### Use Case 3: Segment for Marketing

**Goal:** Send targeted campaigns to different customer segments

```sql
-- Champions: Give VIP perks
SELECT customer_phone FROM calculate_rfm_segments()
WHERE rfm_segment = 'champions';

-- At Risk: Win-back campaign
SELECT customer_phone FROM calculate_rfm_segments()
WHERE rfm_segment = 'at_risk';

-- New Customers: Onboarding campaign
SELECT customer_phone FROM calculate_rfm_segments()
WHERE rfm_segment = 'new_customers';
```

### Use Case 4: Optimize Menu

**Goal:** Identify best and worst performing categories

```sql
WITH revenue AS (
  SELECT get_revenue_breakdown(
    cafe_id_param := 'YOUR-CAFE-ID',
    from_date := NOW() - INTERVAL '30 days',
    to_date := NOW()
  ) as data
)
SELECT 
  cat->>'category' as category,
  (cat->>'revenue')::int as revenue,
  (cat->>'items_sold')::int as items_sold,
  (cat->>'avg_item_price')::decimal as avg_price
FROM revenue, jsonb_array_elements(data->'by_category') cat
ORDER BY (cat->>'revenue')::int DESC;
```

### Use Case 5: Track Conversion

**Goal:** See where customers drop off in the order process

```sql
SELECT 
  step_name,
  users_count,
  conversion_from_previous as "% from previous step",
  conversion_from_start as "% from start"
FROM calculate_conversion_funnel(
  cafe_id_param := NULL,
  from_date := NOW() - INTERVAL '30 days',
  to_date := NOW()
)
ORDER BY step_order;
```

**Interpretation:**
- Low conversion from `view_cafe` → `add_to_cart`: Menu or pricing issue?
- Low conversion from `add_to_cart` → `checkout`: Cart abandonment?
- Low conversion from `checkout` → `payment`: Payment friction?

## Monitoring

### Check ETL Logs

```bash
# Recent cohort ETL runs
tail -50 analytics/logs/cohort.log

# Recent churn ETL runs
tail -50 analytics/logs/churn.log

# All ETL activity
tail -50 analytics/logs/etl.log
```

### Check Data Freshness

```sql
-- When was cohort data last updated?
SELECT MAX(updated_at) FROM cohort_analytics;

-- When was churn data last calculated?
SELECT MAX(calculated_at) FROM user_churn_risk;

-- How many users analyzed today?
SELECT COUNT(*) FROM user_churn_risk 
WHERE calculated_at::date = CURRENT_DATE;
```

## Troubleshooting

### "Function does not exist"

**Problem:** Analytics functions not found

**Solution:**
```bash
# Reapply migration
supabase migration up 20260225000000_advanced_analytics

# Or reset database
supabase db reset
```

### "No data returned"

**Problem:** Functions return empty results

**Solution:** You need order data first. Functions calculate analytics based on existing orders.

```sql
-- Check if you have orders
SELECT COUNT(*) FROM orders;

-- If no orders, you won't see analytics yet
```

### "Permission denied"

**Problem:** User can't execute functions

**Solution:**
```sql
-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_cohort_retention TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_churn_risk TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_customer_ltv TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_rfm_segments TO authenticated;
GRANT EXECUTE ON FUNCTION get_analytics_dashboard TO authenticated;
```

### "ETL script fails"

**Problem:** Python script errors

**Solution:**
```bash
# Check Python version (need 3.9+)
python3 --version

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall

# Check database connection
echo "SELECT 1;" | psql $DATABASE_URL

# Check .env file exists and has correct values
cat analytics/.env
```

### "Slow queries"

**Problem:** Analytics queries take too long

**Solution:**
```sql
-- Use pre-aggregated tables for dashboards
SELECT * FROM cohort_analytics;  -- Fast
SELECT * FROM user_churn_risk WHERE calculated_at::date = CURRENT_DATE;  -- Fast

-- Instead of calculating live
SELECT * FROM calculate_cohort_retention(12);  -- Slower

-- Add indexes if needed
CREATE INDEX idx_orders_customer_created ON orders(customer_phone, created_at);
CREATE INDEX idx_orders_cafe_status ON orders(cafe_id, status);

-- Run VACUUM ANALYZE
VACUUM ANALYZE;
```

## Next Steps

1. **Integrate into Admin Panel**
   - Create dashboard pages at `/admin/analytics`
   - Display charts using Chart.js or Recharts
   - Add export buttons

2. **Set Up BI Tool**
   - Install Metabase or Superset
   - Connect to Supabase database
   - Create interactive dashboards

3. **Create Alerts**
   - Alert when churn risk spikes
   - Alert when retention drops below threshold
   - Alert on ETL job failures

4. **Add More Tracking**
   - Track funnel events in your app:
   ```typescript
   await supabase.from('funnel_events').insert({
     customer_phone: user.phone,
     event_type: 'view_cafe',
     cafe_id: cafeId,
     session_id: sessionId
   });
   ```

5. **Experiment with ML**
   - Export data for ML training
   - Build better churn prediction models
   - Forecast revenue with time series

## Resources

- **Full Documentation:** `ADVANCED_ANALYTICS_IMPLEMENTATION.md`
- **ETL Scripts:** `analytics/` directory
- **Migration File:** `supabase/migrations/20260225000000_advanced_analytics.sql`
- **API Contract:** `SUPABASE_API_CONTRACT.md`

## Support

If you encounter issues:

1. Check logs: `analytics/logs/`
2. Read full docs: `ADVANCED_ANALYTICS_IMPLEMENTATION.md`
3. Test SQL directly in Supabase Dashboard
4. Verify migration applied: `SELECT * FROM supabase_migrations.schema_migrations;`

---

**You're ready to go! Start by running the dashboard query:**

```sql
SELECT get_analytics_dashboard();
```

This will give you an instant overview of your business analytics.
