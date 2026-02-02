# Metabase Integration Guide

## Overview

This guide walks you through setting up Metabase as a Business Intelligence tool for SubscribeCoffie analytics.

Metabase provides:
- Interactive dashboards
- SQL query builder
- Automated reports
- User-friendly interface for non-technical users

## Prerequisites

- Docker installed (recommended) or Java 11+
- Supabase database connection details
- Admin access to create Metabase dashboards

## Installation Options

### Option 1: Docker (Recommended)

```bash
# Pull Metabase image
docker pull metabase/metabase:latest

# Run Metabase
docker run -d \
  -p 3000:3000 \
  --name metabase \
  -v ~/metabase-data:/metabase-data \
  -e MB_DB_FILE=/metabase-data/metabase.db \
  metabase/metabase
```

Access Metabase at: http://localhost:3000

### Option 2: Java JAR

```bash
# Download Metabase
wget https://downloads.metabase.com/latest/metabase.jar

# Run Metabase
java -jar metabase.jar
```

### Option 3: Cloud Hosted

Sign up for Metabase Cloud: https://www.metabase.com/cloud

## Initial Setup

### 1. Complete Onboarding

1. Navigate to http://localhost:3000
2. Create admin account
3. Select language and timezone

### 2. Connect to Supabase Database

1. Click "Add Database"
2. Select "PostgreSQL"
3. Enter connection details:

```
Database type: PostgreSQL
Name: SubscribeCoffie
Host: db.your-project.supabase.co
Port: 5432
Database name: postgres
Username: postgres
Password: your_database_password
```

4. Click "Save"
5. Wait for initial sync (may take a few minutes)

### 3. Verify Connection

1. Go to "Browse Data"
2. Select "SubscribeCoffie" database
3. Verify you can see tables:
   - `orders`
   - `cafes`
   - `users`
   - `cohort_analytics`
   - `user_churn_risk`
   - `funnel_events`

## Creating Dashboards

### Dashboard 1: Executive Overview

**Purpose:** High-level KPIs for leadership

**Metrics to include:**
1. Total Revenue (This Month)
2. Total Orders (This Month)
3. Active Cafes
4. Total Customers
5. Average Order Value
6. Month-over-Month Growth

**SQL Queries:**

```sql
-- Total Revenue This Month
SELECT 
  COALESCE(SUM(total_price_credits), 0) as total_revenue
FROM orders
WHERE created_at >= date_trunc('month', CURRENT_DATE)
  AND status = 'completed';

-- Total Orders This Month
SELECT COUNT(*) as order_count
FROM orders
WHERE created_at >= date_trunc('month', CURRENT_DATE)
  AND status = 'completed';

-- Active Cafes
SELECT COUNT(*) as active_cafes
FROM cafes
WHERE is_active = true;

-- Total Customers
SELECT COUNT(DISTINCT customer_phone) as total_customers
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '90 days';

-- Average Order Value
SELECT ROUND(AVG(total_price_credits), 2) as avg_order_value
FROM orders
WHERE status = 'completed'
  AND created_at >= CURRENT_DATE - INTERVAL '30 days';
```

### Dashboard 2: Cohort Retention Analysis

**Purpose:** Track customer retention by cohort

**Visualization:** Heatmap

**Query:**
```sql
SELECT 
  cohort_month,
  period_number,
  retention_rate,
  cohort_size,
  active_users
FROM cohort_analytics
WHERE cohort_month >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY cohort_month DESC, period_number ASC;
```

**Settings:**
- X-axis: period_number (Month 0, 1, 2, ...)
- Y-axis: cohort_month
- Color: retention_rate (gradient: red → yellow → green)

### Dashboard 3: Churn Risk Management

**Purpose:** Monitor and act on churn risk

**Metrics:**
1. Critical Risk Users
2. High Risk Users
3. Average Risk Score
4. Risk Distribution (Pie Chart)

**Queries:**

```sql
-- Risk Distribution
SELECT 
  risk_level,
  COUNT(*) as user_count,
  ROUND(AVG(risk_score), 1) as avg_score
FROM user_churn_risk
WHERE calculated_at::date = CURRENT_DATE
GROUP BY risk_level
ORDER BY 
  CASE risk_level
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
  END;

-- High-Risk User List
SELECT 
  customer_phone,
  risk_score,
  risk_level,
  days_since_last_order,
  total_orders,
  total_spent
FROM user_churn_risk
WHERE calculated_at::date = CURRENT_DATE
  AND risk_level IN ('critical', 'high')
ORDER BY risk_score DESC
LIMIT 50;
```

### Dashboard 4: RFM Segmentation

**Purpose:** Customer segmentation for targeted marketing

**Visualization:** Segment distribution + segment details table

**Query:**
```sql
WITH rfm_data AS (
  SELECT * FROM calculate_rfm_segments()
)
SELECT 
  rfm_segment,
  segment_description,
  COUNT(*) as customer_count,
  ROUND(AVG(recency_days), 0) as avg_recency,
  ROUND(AVG(frequency), 1) as avg_frequency,
  ROUND(AVG(monetary), 2) as avg_monetary,
  ROUND(SUM(monetary), 2) as total_revenue
FROM rfm_data
GROUP BY rfm_segment, segment_description
ORDER BY total_revenue DESC;
```

### Dashboard 5: Revenue Analytics

**Purpose:** Deep dive into revenue patterns

**Charts:**
1. Revenue by Day (Line chart)
2. Revenue by Cafe (Bar chart)
3. Revenue by Hour (Heatmap)
4. Top Products (Table)

**Queries:**

```sql
-- Revenue by Day (Last 30 days)
SELECT 
  DATE(created_at) as order_date,
  COUNT(*) as order_count,
  SUM(total_price_credits) as revenue
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
  AND status = 'completed'
GROUP BY DATE(created_at)
ORDER BY order_date;

-- Revenue by Cafe (This Month)
SELECT 
  c.name as cafe_name,
  COUNT(o.id) as order_count,
  SUM(o.total_price_credits) as revenue,
  ROUND(AVG(o.total_price_credits), 2) as avg_order_value
FROM orders o
JOIN cafes c ON o.cafe_id = c.id
WHERE o.created_at >= date_trunc('month', CURRENT_DATE)
  AND o.status = 'completed'
GROUP BY c.name
ORDER BY revenue DESC;

-- Revenue by Hour (Last 7 days)
SELECT 
  EXTRACT(HOUR FROM created_at) as hour,
  EXTRACT(DOW FROM created_at) as day_of_week,
  COUNT(*) as order_count,
  SUM(total_price_credits) as revenue
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
  AND status = 'completed'
GROUP BY EXTRACT(HOUR FROM created_at), EXTRACT(DOW FROM created_at)
ORDER BY day_of_week, hour;
```

### Dashboard 6: Conversion Funnel

**Purpose:** Identify drop-off points in user journey

**Query:**
```sql
SELECT * FROM calculate_conversion_funnel();
```

**Visualization:** Funnel chart or step bar chart
- Each step shows: step name, user count, conversion rate

### Dashboard 7: Customer Lifetime Value

**Purpose:** Understand customer value distribution

**Charts:**
1. LTV Distribution (Histogram)
2. Segment Comparison (Bar chart)
3. Top Customers (Table)

**Queries:**

```sql
-- LTV by Segment
WITH ltv_data AS (
  SELECT * FROM calculate_customer_ltv(12)
)
SELECT 
  customer_segment,
  COUNT(*) as customer_count,
  ROUND(AVG(total_spent), 2) as avg_ltv,
  ROUND(AVG(predicted_annual_revenue), 2) as predicted_annual,
  ROUND(SUM(total_spent), 2) as total_revenue
FROM ltv_data
GROUP BY customer_segment
ORDER BY avg_ltv DESC;

-- Top Customers by LTV
WITH ltv_data AS (
  SELECT * FROM calculate_customer_ltv(12)
)
SELECT 
  customer_phone,
  total_spent,
  total_orders,
  avg_order_value,
  predicted_annual_revenue,
  customer_segment
FROM ltv_data
WHERE customer_segment IN ('vip', 'high_value')
ORDER BY total_spent DESC
LIMIT 100;
```

## Best Practices

### 1. Dashboard Design

- **Keep it simple**: Max 6-8 metrics per dashboard
- **Use colors wisely**: Green = good, Red = bad, Yellow = warning
- **Add filters**: Date range, cafe, customer segment
- **Update frequency**: Most dashboards should refresh hourly

### 2. Performance Optimization

- **Use pre-aggregated tables**: Query `cohort_analytics` instead of calculating on-the-fly
- **Add database indexes**: Ensure key columns are indexed
- **Cache results**: Enable Metabase caching for slow queries
- **Schedule refreshes**: Run ETL before business hours

### 3. User Access Control

- **Admin**: Full access to all dashboards and data
- **Cafe Owners**: Limited to their cafe data only
- **Marketing**: Access to customer segmentation and churn data
- **Finance**: Access to revenue and LTV dashboards

### 4. Automated Reports

Set up email reports for key stakeholders:

1. Go to dashboard
2. Click "Share" → "Email it"
3. Set schedule (daily, weekly, monthly)
4. Add recipients
5. Customize message

**Recommended Reports:**
- **Daily**: Executive summary (sent at 8 AM)
- **Weekly**: Churn risk report (sent Monday morning)
- **Monthly**: Revenue analysis (sent 1st of month)

## Embedding Dashboards

### In Admin Panel (Next.js)

```typescript
// app/admin/analytics/embedded/page.tsx
export default function EmbeddedDashboard() {
  const METABASE_URL = process.env.METABASE_URL;
  const DASHBOARD_ID = process.env.METABASE_DASHBOARD_ID;
  const SECRET_KEY = process.env.METABASE_SECRET_KEY;
  
  // Generate signed URL (implement JWT signing)
  const iframeUrl = `${METABASE_URL}/embed/dashboard/${DASHBOARD_ID}`;
  
  return (
    <div className="h-screen">
      <iframe
        src={iframeUrl}
        frameBorder="0"
        width="100%"
        height="100%"
        allowTransparency
      />
    </div>
  );
}
```

### Public Embedding

1. In Metabase, go to dashboard
2. Click "Share" → "Embed"
3. Enable "Public link" or "Embed in your application"
4. Copy iframe code
5. Add to your admin panel

## Troubleshooting

### Connection Issues

**Problem:** Can't connect to Supabase database

**Solution:**
1. Check Supabase connection pooler settings
2. Verify IP whitelist (if using Supabase Cloud)
3. Use connection pooler port (6543) instead of direct (5432)
4. Connection string format:
   ```
   postgresql://postgres.your-ref:password@aws-0-region.pooler.supabase.com:6543/postgres
   ```

### Slow Queries

**Problem:** Dashboard takes too long to load

**Solution:**
1. Run ETL scripts to pre-aggregate data
2. Add database indexes:
   ```sql
   CREATE INDEX idx_orders_created_at ON orders(created_at);
   CREATE INDEX idx_orders_status ON orders(status);
   CREATE INDEX idx_orders_cafe_id ON orders(cafe_id);
   ```
3. Enable Metabase query caching
4. Use "Saved Questions" instead of raw SQL

### Missing Data

**Problem:** No data showing in analytics tables

**Solution:**
1. Verify ETL scripts have run:
   ```bash
   cd analytics
   python3 etl_aggregate.py --all
   ```
2. Check ETL logs:
   ```bash
   tail -f logs/etl.log
   ```
3. Manually refresh functions:
   ```sql
   SELECT refresh_cohort_analytics();
   SELECT refresh_churn_risk();
   ```

## Advanced Features

### Custom SQL Questions

Create reusable SQL queries:

1. Click "New" → "SQL query"
2. Write query
3. Save with descriptive name
4. Add to dashboard

### Alerts

Set up alerts for critical metrics:

1. Create metric question
2. Click "Set up an alert"
3. Define threshold (e.g., "Alert me if critical churn users > 50")
4. Choose notification method (email, Slack)

### API Access

Export data programmatically:

```bash
# Get dashboard data via API
curl -X GET \
  "http://localhost:3000/api/dashboard/1" \
  -H "X-Metabase-Session: YOUR_SESSION_TOKEN"
```

## Maintenance

### Regular Tasks

**Daily:**
- Verify ETL scripts ran successfully
- Check for slow queries

**Weekly:**
- Review dashboard usage
- Update queries if needed
- Clean up unused questions

**Monthly:**
- Update Metabase (Docker: `docker pull metabase/metabase:latest`)
- Review user access permissions
- Backup Metabase database

### Backup Metabase

```bash
# Backup Metabase data
docker exec metabase tar czf - /metabase-data > metabase-backup-$(date +%Y%m%d).tar.gz

# Restore from backup
docker exec -i metabase tar xzf - -C / < metabase-backup-20260130.tar.gz
```

## Resources

- [Metabase Documentation](https://www.metabase.com/docs/latest/)
- [SQL Query Reference](https://www.metabase.com/learn/sql-questions/)
- [Dashboard Best Practices](https://www.metabase.com/learn/dashboards/)
- [Embedding Guide](https://www.metabase.com/learn/embedding/)

## Support

For issues:
1. Check Metabase logs: `docker logs metabase`
2. Review analytics logs: `analytics/logs/`
3. Consult Metabase community: https://discourse.metabase.com/
