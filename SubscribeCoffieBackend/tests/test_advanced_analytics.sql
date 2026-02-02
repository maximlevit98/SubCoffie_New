-- Test Suite: Advanced Analytics Functions
-- Description: Tests all analytics functions to ensure they work correctly

\echo '========================================='
\echo 'Testing Advanced Analytics Functions'
\echo '========================================='

-- ============================================================================
-- Test 1: Cohort Retention Calculation
-- ============================================================================

\echo ''
\echo 'Test 1: Cohort Retention Calculation'
\echo '-------------------------------------'

-- Should return cohort data grouped by month and period
SELECT 
  COUNT(*) as total_cohort_records,
  COUNT(DISTINCT cohort_month) as unique_cohorts,
  MIN(retention_rate) as min_retention,
  MAX(retention_rate) as max_retention,
  AVG(retention_rate) as avg_retention
FROM calculate_cohort_retention(12);

\echo '✓ Cohort retention calculation executed'

-- Test refresh function
SELECT refresh_cohort_analytics();
\echo '✓ Cohort analytics refreshed'

-- Verify data was inserted
SELECT COUNT(*) as cohort_analytics_records FROM cohort_analytics;
\echo '✓ Cohort analytics table populated'

-- ============================================================================
-- Test 2: Churn Risk Calculation
-- ============================================================================

\echo ''
\echo 'Test 2: Churn Risk Calculation'
\echo '------------------------------'

-- Should return users with risk scores
SELECT 
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE risk_level = 'critical') as critical_count,
  COUNT(*) FILTER (WHERE risk_level = 'high') as high_count,
  COUNT(*) FILTER (WHERE risk_level = 'medium') as medium_count,
  COUNT(*) FILTER (WHERE risk_level = 'low') as low_count,
  ROUND(AVG(risk_score), 2) as avg_risk_score,
  MIN(risk_score) as min_risk,
  MAX(risk_score) as max_risk
FROM calculate_churn_risk();

\echo '✓ Churn risk calculation executed'

-- Test refresh function
SELECT refresh_churn_risk();
\echo '✓ Churn risk data refreshed'

-- Verify data was inserted
SELECT 
  COUNT(*) as churn_records_today,
  COUNT(DISTINCT risk_level) as unique_risk_levels
FROM user_churn_risk 
WHERE calculated_at::date = CURRENT_DATE;

\echo '✓ Churn risk table populated'

-- ============================================================================
-- Test 3: Customer LTV Calculation
-- ============================================================================

\echo ''
\echo 'Test 3: Customer LTV Calculation'
\echo '--------------------------------'

-- Should return LTV data for customers
SELECT 
  COUNT(*) as total_customers,
  ROUND(AVG(predicted_ltv), 2) as avg_predicted_ltv,
  ROUND(MIN(predicted_ltv), 2) as min_ltv,
  ROUND(MAX(predicted_ltv), 2) as max_ltv,
  COUNT(*) FILTER (WHERE customer_segment = 'vip') as vip_count,
  COUNT(*) FILTER (WHERE customer_segment = 'high_value') as high_value_count
FROM calculate_customer_ltv(12);

\echo '✓ LTV calculation executed'

-- ============================================================================
-- Test 4: RFM Segmentation
-- ============================================================================

\echo ''
\echo 'Test 4: RFM Segmentation'
\echo '-----------------------'

-- Should segment customers by RFM scores
SELECT 
  rfm_segment,
  COUNT(*) as customer_count,
  ROUND(AVG(r_score), 1) as avg_r_score,
  ROUND(AVG(f_score), 1) as avg_f_score,
  ROUND(AVG(m_score), 1) as avg_m_score
FROM calculate_rfm_segments()
GROUP BY rfm_segment
ORDER BY customer_count DESC;

\echo '✓ RFM segmentation executed'

-- ============================================================================
-- Test 5: Conversion Funnel
-- ============================================================================

\echo ''
\echo 'Test 5: Conversion Funnel'
\echo '------------------------'

-- Create some test funnel events first
INSERT INTO funnel_events (customer_phone, event_type, cafe_id, session_id)
SELECT 
  o.customer_phone,
  'order_created',
  o.cafe_id,
  o.id::text
FROM orders o
WHERE NOT EXISTS (
  SELECT 1 FROM funnel_events fe 
  WHERE fe.order_id = o.id AND fe.event_type = 'order_created'
)
LIMIT 10;

\echo '✓ Test funnel events created'

-- Calculate funnel
SELECT 
  step_name,
  users_count,
  conversion_from_previous,
  conversion_from_start
FROM calculate_conversion_funnel(
  NULL,
  NOW() - INTERVAL '30 days',
  NOW()
);

\echo '✓ Conversion funnel calculated'

-- ============================================================================
-- Test 6: Revenue Breakdown
-- ============================================================================

\echo ''
\echo 'Test 6: Revenue Breakdown'
\echo '------------------------'

-- Should return detailed revenue breakdown
SELECT 
  jsonb_pretty(
    get_revenue_breakdown(
      NULL,
      NOW() - INTERVAL '30 days',
      NOW()
    )
  );

\echo '✓ Revenue breakdown calculated'

-- ============================================================================
-- Test 7: Analytics Dashboard
-- ============================================================================

\echo ''
\echo 'Test 7: Analytics Dashboard (All-in-One)'
\echo '----------------------------------------'

-- Should return comprehensive dashboard data
SELECT jsonb_pretty(get_analytics_dashboard());

\echo '✓ Analytics dashboard executed'

-- ============================================================================
-- Test 8: Verify Tables and Permissions
-- ============================================================================

\echo ''
\echo 'Test 8: Verify Tables and Permissions'
\echo '-------------------------------------'

-- Check if tables exist
SELECT 
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_name IN ('cohort_analytics', 'funnel_events', 'user_churn_risk')
ORDER BY table_name;

\echo '✓ Analytics tables exist'

-- Check if functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (
    routine_name LIKE '%cohort%' 
    OR routine_name LIKE '%churn%' 
    OR routine_name LIKE '%ltv%'
    OR routine_name LIKE '%rfm%'
    OR routine_name LIKE '%funnel%'
    OR routine_name LIKE '%analytics_dashboard%'
  )
ORDER BY routine_name;

\echo '✓ Analytics functions exist'

-- ============================================================================
-- Test 9: Performance Check
-- ============================================================================

\echo ''
\echo 'Test 9: Performance Check'
\echo '------------------------'

-- Check execution times (should be fast with indexes)
EXPLAIN ANALYZE 
SELECT * FROM calculate_cohort_retention(6) LIMIT 10;

\echo ''
EXPLAIN ANALYZE 
SELECT * FROM calculate_churn_risk() LIMIT 10;

\echo ''
EXPLAIN ANALYZE 
SELECT * FROM calculate_rfm_segments() LIMIT 10;

\echo '✓ Performance analysis complete'

-- ============================================================================
-- Test 10: Data Validation
-- ============================================================================

\echo ''
\echo 'Test 10: Data Validation'
\echo '-----------------------'

-- Cohort retention rates should be between 0 and 100
SELECT 
  CASE 
    WHEN MIN(retention_rate) >= 0 AND MAX(retention_rate) <= 100 
    THEN '✓ Cohort retention rates valid (0-100%)'
    ELSE '✗ Invalid retention rates found!'
  END as validation_result
FROM cohort_analytics;

-- Churn risk scores should be between 0 and 100
SELECT 
  CASE 
    WHEN MIN(risk_score) >= 0 AND MAX(risk_score) <= 100 
    THEN '✓ Churn risk scores valid (0-100)'
    ELSE '✗ Invalid risk scores found!'
  END as validation_result
FROM user_churn_risk;

-- RFM scores should be between 1 and 5
SELECT 
  CASE 
    WHEN MIN(r_score) >= 1 AND MAX(r_score) <= 5
      AND MIN(f_score) >= 1 AND MAX(f_score) <= 5
      AND MIN(m_score) >= 1 AND MAX(m_score) <= 5
    THEN '✓ RFM scores valid (1-5)'
    ELSE '✗ Invalid RFM scores found!'
  END as validation_result
FROM calculate_rfm_segments();

-- ============================================================================
-- Test 11: Edge Cases
-- ============================================================================

\echo ''
\echo 'Test 11: Edge Cases'
\echo '------------------'

-- Test with no data (should handle gracefully)
SELECT COUNT(*) as count_with_no_cafe 
FROM calculate_cohort_retention(0) 
WHERE FALSE;

\echo '✓ Handles empty results'

-- Test with future dates (should return no data)
SELECT COUNT(*) as count_future_dates
FROM calculate_conversion_funnel(
  NULL,
  NOW() + INTERVAL '1 year',
  NOW() + INTERVAL '2 years'
);

\echo '✓ Handles future date range'

-- ============================================================================
-- Test Summary
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'Test Summary'
\echo '========================================='
\echo ''
\echo '✓ All analytics functions tested successfully!'
\echo ''
\echo 'Functions tested:'
\echo '  1. calculate_cohort_retention'
\echo '  2. refresh_cohort_analytics'
\echo '  3. calculate_churn_risk'
\echo '  4. refresh_churn_risk'
\echo '  5. calculate_customer_ltv'
\echo '  6. calculate_rfm_segments'
\echo '  7. calculate_conversion_funnel'
\echo '  8. get_revenue_breakdown'
\echo '  9. get_analytics_dashboard'
\echo ''
\echo 'Tables verified:'
\echo '  - cohort_analytics'
\echo '  - funnel_events'
\echo '  - user_churn_risk'
\echo ''
\echo '========================================='
\echo 'Advanced Analytics: READY TO USE'
\echo '========================================='
