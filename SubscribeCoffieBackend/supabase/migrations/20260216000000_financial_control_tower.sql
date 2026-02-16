-- ============================================================================
-- Financial Control Tower RPCs (Admin + Owner scopes)
-- Date: 2026-02-16
-- Purpose:
--   1) Centralize financial control metrics for wallets/orders/payments
--   2) Provide anomaly feed for reconciliation and accounting monitoring
--   3) Keep owner scope restricted to owned cafes only
-- ============================================================================

-- Performance indexes for financial dashboards
CREATE INDEX IF NOT EXISTS payment_transactions_type_status_created_at_idx
  ON public.payment_transactions (transaction_type, status, created_at DESC);

CREATE INDEX IF NOT EXISTS payment_transactions_order_id_status_idx
  ON public.payment_transactions (order_id, status);

CREATE INDEX IF NOT EXISTS orders_core_created_at_cafe_id_idx
  ON public.orders_core (created_at DESC, cafe_id);

CREATE INDEX IF NOT EXISTS wallet_transactions_wallet_id_type_created_at_idx
  ON public.wallet_transactions (wallet_id, type, created_at DESC);

-- ============================================================================
-- Admin metrics: financial control tower
-- ============================================================================

DROP FUNCTION IF EXISTS admin_get_financial_control_tower(timestamptz, timestamptz, uuid);

CREATE OR REPLACE FUNCTION admin_get_financial_control_tower(
  p_from timestamptz DEFAULT now() - INTERVAL '30 days',
  p_to timestamptz DEFAULT now(),
  p_cafe_id uuid DEFAULT NULL
)
RETURNS TABLE (
  scope text,
  date_from timestamptz,
  date_to timestamptz,
  selected_cafe_id uuid,
  topup_completed_count int,
  topup_completed_credits int,
  order_payment_completed_count int,
  order_payment_completed_credits int,
  refund_completed_count int,
  refund_completed_credits int,
  platform_commission_credits int,
  pending_credits int,
  failed_credits int,
  wallet_balance_snapshot_credits int,
  orders_count int,
  completed_orders_count int,
  orders_paid_credits int,
  wallet_ledger_delta_credits int,
  expected_wallet_delta_credits int,
  discrepancy_credits int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from timestamptz;
  v_to timestamptz;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  v_from := COALESCE(p_from, now() - INTERVAL '30 days');
  v_to := COALESCE(p_to, now());

  IF v_from > v_to THEN
    RAISE EXCEPTION 'Invalid date range: p_from (%) is after p_to (%)', v_from, v_to;
  END IF;

  RETURN QUERY
  WITH scoped_wallets AS (
    SELECT w.id, w.cafe_id
    FROM wallets w
    WHERE p_cafe_id IS NULL OR w.cafe_id = p_cafe_id
  ),
  scoped_orders AS (
    SELECT o.*
    FROM orders_core o
    WHERE o.created_at >= v_from
      AND o.created_at <= v_to
      AND (p_cafe_id IS NULL OR o.cafe_id = p_cafe_id)
  ),
  scoped_payments AS (
    SELECT pt.*
    FROM payment_transactions pt
    LEFT JOIN scoped_wallets sw ON sw.id = pt.wallet_id
    LEFT JOIN orders_core o ON o.id = pt.order_id
    WHERE pt.created_at >= v_from
      AND pt.created_at <= v_to
      AND (
        p_cafe_id IS NULL
        OR sw.cafe_id = p_cafe_id
        OR o.cafe_id = p_cafe_id
      )
  ),
  scoped_wallet_tx AS (
    SELECT wt.*
    FROM wallet_transactions wt
    JOIN scoped_wallets sw ON sw.id = wt.wallet_id
    WHERE wt.created_at >= v_from
      AND wt.created_at <= v_to
  ),
  payments_agg AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'completed' AND transaction_type = 'topup')::int AS topup_completed_count,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'completed' AND transaction_type = 'topup'), 0)::int AS topup_completed_credits,
      COUNT(*) FILTER (WHERE status = 'completed' AND transaction_type = 'order_payment')::int AS order_payment_completed_count,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'completed' AND transaction_type = 'order_payment'), 0)::int AS order_payment_completed_credits,
      COUNT(*) FILTER (WHERE status = 'completed' AND transaction_type = 'refund')::int AS refund_completed_count,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'completed' AND transaction_type = 'refund'), 0)::int AS refund_completed_credits,
      COALESCE(SUM(commission_credits) FILTER (WHERE status = 'completed'), 0)::int AS platform_commission_credits,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'pending'), 0)::int AS pending_credits,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'failed'), 0)::int AS failed_credits
    FROM scoped_payments
  ),
  orders_agg AS (
    SELECT
      COUNT(*)::int AS orders_count,
      COUNT(*) FILTER (WHERE status IN ('issued', 'picked_up'))::int AS completed_orders_count,
      COALESCE(SUM(paid_credits), 0)::int AS orders_paid_credits
    FROM scoped_orders
  ),
  wallets_agg AS (
    SELECT COALESCE(SUM(balance_credits), 0)::int AS wallet_balance_snapshot_credits
    FROM scoped_wallets sw
    JOIN wallets w ON w.id = sw.id
  ),
  wallet_tx_agg AS (
    SELECT COALESCE(SUM(amount), 0)::int AS wallet_ledger_delta_credits
    FROM scoped_wallet_tx
  ),
  merged AS (
    SELECT
      pa.topup_completed_count,
      pa.topup_completed_credits,
      pa.order_payment_completed_count,
      pa.order_payment_completed_credits,
      pa.refund_completed_count,
      pa.refund_completed_credits,
      pa.platform_commission_credits,
      pa.pending_credits,
      pa.failed_credits,
      wa.wallet_balance_snapshot_credits,
      oa.orders_count,
      oa.completed_orders_count,
      oa.orders_paid_credits,
      wta.wallet_ledger_delta_credits,
      (
        COALESCE(pa.topup_completed_credits, 0)
        + COALESCE(pa.refund_completed_credits, 0)
        - COALESCE(pa.order_payment_completed_credits, 0)
      )::int AS expected_wallet_delta_credits
    FROM payments_agg pa
    CROSS JOIN orders_agg oa
    CROSS JOIN wallets_agg wa
    CROSS JOIN wallet_tx_agg wta
  )
  SELECT
    'admin'::text,
    v_from,
    v_to,
    p_cafe_id,
    m.topup_completed_count,
    m.topup_completed_credits,
    m.order_payment_completed_count,
    m.order_payment_completed_credits,
    m.refund_completed_count,
    m.refund_completed_credits,
    m.platform_commission_credits,
    m.pending_credits,
    m.failed_credits,
    m.wallet_balance_snapshot_credits,
    m.orders_count,
    m.completed_orders_count,
    m.orders_paid_credits,
    m.wallet_ledger_delta_credits,
    m.expected_wallet_delta_credits,
    (m.wallet_ledger_delta_credits - m.expected_wallet_delta_credits)::int AS discrepancy_credits
  FROM merged m;
END;
$$;

COMMENT ON FUNCTION admin_get_financial_control_tower(timestamptz, timestamptz, uuid)
  IS 'Admin: Financial Control Tower metrics for wallets/orders/payments with reconciliation delta';

-- ============================================================================
-- Admin anomalies: financial control tower
-- ============================================================================

DROP FUNCTION IF EXISTS admin_get_financial_anomalies(timestamptz, timestamptz, uuid, int);

CREATE OR REPLACE FUNCTION admin_get_financial_anomalies(
  p_from timestamptz DEFAULT now() - INTERVAL '30 days',
  p_to timestamptz DEFAULT now(),
  p_cafe_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  anomaly_key text,
  severity text,
  anomaly_type text,
  wallet_id uuid,
  order_id uuid,
  cafe_id uuid,
  amount_credits int,
  detected_at timestamptz,
  message text,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from timestamptz;
  v_to timestamptz;
  v_limit int;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  v_from := COALESCE(p_from, now() - INTERVAL '30 days');
  v_to := COALESCE(p_to, now());

  IF v_from > v_to THEN
    RAISE EXCEPTION 'Invalid date range: p_from (%) is after p_to (%)', v_from, v_to;
  END IF;

  SELECT validated_limit
  INTO v_limit
  FROM validate_pagination(p_limit, 0, 200);

  RETURN QUERY
  WITH anomalies AS (
    -- 1) Wallet with negative balance
    SELECT
      ('negative_balance:' || w.id)::text AS anomaly_key,
      'critical'::text AS severity,
      'negative_wallet_balance'::text AS anomaly_type,
      w.id AS wallet_id,
      NULL::uuid AS order_id,
      w.cafe_id,
      w.balance_credits::int AS amount_credits,
      now() AS detected_at,
      'Wallet has negative balance'::text AS message,
      jsonb_build_object(
        'wallet_type', w.wallet_type,
        'balance_credits', w.balance_credits
      ) AS details
    FROM wallets w
    WHERE w.balance_credits < 0
      AND (p_cafe_id IS NULL OR w.cafe_id = p_cafe_id)

    UNION ALL

    -- 2) Wallet order without completed payment transaction
    SELECT
      ('order_without_payment:' || o.id)::text,
      'high'::text,
      'wallet_order_without_payment_tx'::text,
      o.wallet_id,
      o.id,
      o.cafe_id,
      COALESCE(o.paid_credits, 0)::int,
      o.created_at,
      'Wallet-paid order has no completed order_payment transaction'::text,
      jsonb_build_object(
        'order_number', o.order_number,
        'payment_status', o.payment_status,
        'status', o.status
      )
    FROM orders_core o
    WHERE o.created_at >= v_from
      AND o.created_at <= v_to
      AND (p_cafe_id IS NULL OR o.cafe_id = p_cafe_id)
      AND o.wallet_id IS NOT NULL
      AND o.payment_method = 'wallet'
      AND COALESCE(o.paid_credits, 0) > 0
      AND NOT EXISTS (
        SELECT 1
        FROM payment_transactions pt
        WHERE pt.order_id = o.id
          AND pt.transaction_type = 'order_payment'
          AND pt.status = 'completed'
      )

    UNION ALL

    -- 3) Completed payment transaction without matching wallet ledger row
    SELECT
      ('payment_without_ledger:' || pt.id)::text,
      'high'::text,
      'completed_payment_without_wallet_ledger'::text,
      pt.wallet_id,
      pt.order_id,
      o.cafe_id,
      pt.amount_credits::int,
      pt.created_at,
      'Completed payment transaction has no matching wallet ledger entry'::text,
      jsonb_build_object(
        'transaction_type', pt.transaction_type,
        'status', pt.status,
        'idempotency_key', pt.idempotency_key
      )
    FROM payment_transactions pt
    LEFT JOIN orders_core o ON o.id = pt.order_id
    WHERE pt.created_at >= v_from
      AND pt.created_at <= v_to
      AND pt.status = 'completed'
      AND pt.wallet_id IS NOT NULL
      AND (
        p_cafe_id IS NULL
        OR o.cafe_id = p_cafe_id
        OR EXISTS (
          SELECT 1
          FROM wallets w2
          WHERE w2.id = pt.wallet_id
            AND w2.cafe_id = p_cafe_id
        )
      )
      AND NOT EXISTS (
        SELECT 1
        FROM wallet_transactions wt
        WHERE wt.wallet_id = pt.wallet_id
          AND (
            (pt.transaction_type = 'topup' AND wt.type = 'topup')
            OR (pt.transaction_type = 'refund' AND wt.type = 'refund')
            OR (pt.transaction_type = 'order_payment' AND wt.type = 'payment')
          )
          AND (
            (pt.order_id IS NOT NULL AND wt.order_id = pt.order_id)
            OR (
              pt.order_id IS NULL
              AND wt.amount = CASE
                WHEN pt.transaction_type = 'order_payment' THEN -pt.amount_credits
                ELSE pt.amount_credits
              END
              AND wt.created_at BETWEEN pt.created_at - INTERVAL '15 minutes' AND pt.created_at + INTERVAL '15 minutes'
            )
          )
      )

    UNION ALL

    -- 4) Reconciliation delta anomaly (single aggregate signal)
    SELECT
      'reconciliation_delta'::text,
      CASE
        WHEN ABS(fc.discrepancy_credits) >= 100 THEN 'critical'
        WHEN ABS(fc.discrepancy_credits) >= 20 THEN 'high'
        ELSE 'medium'
      END::text,
      'reconciliation_delta'::text,
      NULL::uuid,
      NULL::uuid,
      p_cafe_id,
      fc.discrepancy_credits::int,
      now(),
      'Wallet ledger delta does not match expected payment delta'::text,
      jsonb_build_object(
        'wallet_ledger_delta_credits', fc.wallet_ledger_delta_credits,
        'expected_wallet_delta_credits', fc.expected_wallet_delta_credits
      )
    FROM admin_get_financial_control_tower(v_from, v_to, p_cafe_id) fc
    WHERE fc.discrepancy_credits <> 0
  )
  SELECT
    a.anomaly_key,
    a.severity,
    a.anomaly_type,
    a.wallet_id,
    a.order_id,
    a.cafe_id,
    a.amount_credits,
    a.detected_at,
    a.message,
    a.details
  FROM anomalies a
  ORDER BY
    CASE a.severity
      WHEN 'critical' THEN 4
      WHEN 'high' THEN 3
      WHEN 'medium' THEN 2
      ELSE 1
    END DESC,
    a.detected_at DESC
  LIMIT v_limit;
END;
$$;

COMMENT ON FUNCTION admin_get_financial_anomalies(timestamptz, timestamptz, uuid, int)
  IS 'Admin: Financial anomaly feed (negative balances, missing links, reconciliation delta)';

-- ============================================================================
-- Owner metrics: financial control tower (owner-scoped)
-- ============================================================================

DROP FUNCTION IF EXISTS owner_get_financial_control_tower(timestamptz, timestamptz, uuid);

CREATE OR REPLACE FUNCTION owner_get_financial_control_tower(
  p_from timestamptz DEFAULT now() - INTERVAL '30 days',
  p_to timestamptz DEFAULT now(),
  p_cafe_id uuid DEFAULT NULL
)
RETURNS TABLE (
  scope text,
  date_from timestamptz,
  date_to timestamptz,
  selected_cafe_id uuid,
  topup_completed_count int,
  topup_completed_credits int,
  order_payment_completed_count int,
  order_payment_completed_credits int,
  refund_completed_count int,
  refund_completed_credits int,
  platform_commission_credits int,
  pending_credits int,
  failed_credits int,
  wallet_balance_snapshot_credits int,
  orders_count int,
  completed_orders_count int,
  orders_paid_credits int,
  wallet_ledger_delta_credits int,
  expected_wallet_delta_credits int,
  discrepancy_credits int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from timestamptz;
  v_to timestamptz;
  v_user_id uuid;
  v_role text;
BEGIN
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;

  v_user_id := auth.uid();
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;

  IF p_cafe_id IS NOT NULL AND v_role = 'owner' AND NOT verify_cafe_ownership(p_cafe_id) THEN
    RAISE EXCEPTION 'Unauthorized: cafe not owned by you';
  END IF;

  v_from := COALESCE(p_from, now() - INTERVAL '30 days');
  v_to := COALESCE(p_to, now());

  IF v_from > v_to THEN
    RAISE EXCEPTION 'Invalid date range: p_from (%) is after p_to (%)', v_from, v_to;
  END IF;

  RETURN QUERY
  WITH owner_cafes AS (
    SELECT c.id
    FROM cafes c
    JOIN accounts a ON a.id = c.account_id
    WHERE a.owner_user_id = v_user_id
  ),
  scoped_wallets AS (
    SELECT w.id, w.cafe_id
    FROM wallets w
    WHERE w.wallet_type = 'cafe_wallet'
      AND (
        v_role = 'admin'
        OR w.cafe_id IN (SELECT id FROM owner_cafes)
      )
      AND (p_cafe_id IS NULL OR w.cafe_id = p_cafe_id)
  ),
  scoped_orders AS (
    SELECT o.*
    FROM orders_core o
    WHERE o.created_at >= v_from
      AND o.created_at <= v_to
      AND (
        v_role = 'admin'
        OR o.cafe_id IN (SELECT id FROM owner_cafes)
      )
      AND (p_cafe_id IS NULL OR o.cafe_id = p_cafe_id)
  ),
  scoped_payments AS (
    SELECT pt.*
    FROM payment_transactions pt
    LEFT JOIN scoped_wallets sw ON sw.id = pt.wallet_id
    LEFT JOIN orders_core o ON o.id = pt.order_id
    WHERE pt.created_at >= v_from
      AND pt.created_at <= v_to
      AND (
        v_role = 'admin'
        OR sw.cafe_id IN (SELECT id FROM owner_cafes)
        OR o.cafe_id IN (SELECT id FROM owner_cafes)
      )
      AND (
        p_cafe_id IS NULL
        OR sw.cafe_id = p_cafe_id
        OR o.cafe_id = p_cafe_id
      )
  ),
  scoped_wallet_tx AS (
    SELECT wt.*
    FROM wallet_transactions wt
    JOIN scoped_wallets sw ON sw.id = wt.wallet_id
    WHERE wt.created_at >= v_from
      AND wt.created_at <= v_to
  ),
  payments_agg AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'completed' AND transaction_type = 'topup')::int AS topup_completed_count,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'completed' AND transaction_type = 'topup'), 0)::int AS topup_completed_credits,
      COUNT(*) FILTER (WHERE status = 'completed' AND transaction_type = 'order_payment')::int AS order_payment_completed_count,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'completed' AND transaction_type = 'order_payment'), 0)::int AS order_payment_completed_credits,
      COUNT(*) FILTER (WHERE status = 'completed' AND transaction_type = 'refund')::int AS refund_completed_count,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'completed' AND transaction_type = 'refund'), 0)::int AS refund_completed_credits,
      COALESCE(SUM(commission_credits) FILTER (WHERE status = 'completed'), 0)::int AS platform_commission_credits,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'pending'), 0)::int AS pending_credits,
      COALESCE(SUM(amount_credits) FILTER (WHERE status = 'failed'), 0)::int AS failed_credits
    FROM scoped_payments
  ),
  orders_agg AS (
    SELECT
      COUNT(*)::int AS orders_count,
      COUNT(*) FILTER (WHERE status IN ('issued', 'picked_up'))::int AS completed_orders_count,
      COALESCE(SUM(paid_credits), 0)::int AS orders_paid_credits
    FROM scoped_orders
  ),
  wallets_agg AS (
    SELECT COALESCE(SUM(balance_credits), 0)::int AS wallet_balance_snapshot_credits
    FROM scoped_wallets sw
    JOIN wallets w ON w.id = sw.id
  ),
  wallet_tx_agg AS (
    SELECT COALESCE(SUM(amount), 0)::int AS wallet_ledger_delta_credits
    FROM scoped_wallet_tx
  ),
  merged AS (
    SELECT
      pa.topup_completed_count,
      pa.topup_completed_credits,
      pa.order_payment_completed_count,
      pa.order_payment_completed_credits,
      pa.refund_completed_count,
      pa.refund_completed_credits,
      pa.platform_commission_credits,
      pa.pending_credits,
      pa.failed_credits,
      wa.wallet_balance_snapshot_credits,
      oa.orders_count,
      oa.completed_orders_count,
      oa.orders_paid_credits,
      wta.wallet_ledger_delta_credits,
      (
        COALESCE(pa.topup_completed_credits, 0)
        + COALESCE(pa.refund_completed_credits, 0)
        - COALESCE(pa.order_payment_completed_credits, 0)
      )::int AS expected_wallet_delta_credits
    FROM payments_agg pa
    CROSS JOIN orders_agg oa
    CROSS JOIN wallets_agg wa
    CROSS JOIN wallet_tx_agg wta
  )
  SELECT
    'owner'::text,
    v_from,
    v_to,
    p_cafe_id,
    m.topup_completed_count,
    m.topup_completed_credits,
    m.order_payment_completed_count,
    m.order_payment_completed_credits,
    m.refund_completed_count,
    m.refund_completed_credits,
    m.platform_commission_credits,
    m.pending_credits,
    m.failed_credits,
    m.wallet_balance_snapshot_credits,
    m.orders_count,
    m.completed_orders_count,
    m.orders_paid_credits,
    m.wallet_ledger_delta_credits,
    m.expected_wallet_delta_credits,
    (m.wallet_ledger_delta_credits - m.expected_wallet_delta_credits)::int AS discrepancy_credits
  FROM merged m;
END;
$$;

COMMENT ON FUNCTION owner_get_financial_control_tower(timestamptz, timestamptz, uuid)
  IS 'Owner/Admin: Financial Control Tower metrics for owner-scoped cafes (reconciliation-ready)';

-- ============================================================================
-- Owner anomalies: financial control tower (owner-scoped)
-- ============================================================================

DROP FUNCTION IF EXISTS owner_get_financial_anomalies(timestamptz, timestamptz, uuid, int);

CREATE OR REPLACE FUNCTION owner_get_financial_anomalies(
  p_from timestamptz DEFAULT now() - INTERVAL '30 days',
  p_to timestamptz DEFAULT now(),
  p_cafe_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  anomaly_key text,
  severity text,
  anomaly_type text,
  wallet_id uuid,
  order_id uuid,
  cafe_id uuid,
  amount_credits int,
  detected_at timestamptz,
  message text,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from timestamptz;
  v_to timestamptz;
  v_limit int;
  v_user_id uuid;
  v_role text;
BEGIN
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;

  v_user_id := auth.uid();
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;

  IF p_cafe_id IS NOT NULL AND v_role = 'owner' AND NOT verify_cafe_ownership(p_cafe_id) THEN
    RAISE EXCEPTION 'Unauthorized: cafe not owned by you';
  END IF;

  v_from := COALESCE(p_from, now() - INTERVAL '30 days');
  v_to := COALESCE(p_to, now());

  IF v_from > v_to THEN
    RAISE EXCEPTION 'Invalid date range: p_from (%) is after p_to (%)', v_from, v_to;
  END IF;

  SELECT validated_limit
  INTO v_limit
  FROM validate_pagination(p_limit, 0, 200);

  RETURN QUERY
  WITH owner_cafes AS (
    SELECT c.id
    FROM cafes c
    JOIN accounts a ON a.id = c.account_id
    WHERE a.owner_user_id = v_user_id
  ),
  scoped_wallets AS (
    SELECT w.id, w.cafe_id
    FROM wallets w
    WHERE w.wallet_type = 'cafe_wallet'
      AND (
        v_role = 'admin'
        OR w.cafe_id IN (SELECT id FROM owner_cafes)
      )
      AND (p_cafe_id IS NULL OR w.cafe_id = p_cafe_id)
  ),
  anomalies AS (
    -- 1) Wallet with negative balance
    SELECT
      ('negative_balance:' || w.id)::text AS anomaly_key,
      'critical'::text AS severity,
      'negative_wallet_balance'::text AS anomaly_type,
      w.id AS wallet_id,
      NULL::uuid AS order_id,
      w.cafe_id,
      w.balance_credits::int AS amount_credits,
      now() AS detected_at,
      'Wallet has negative balance'::text AS message,
      jsonb_build_object(
        'wallet_type', w.wallet_type,
        'balance_credits', w.balance_credits
      ) AS details
    FROM wallets w
    JOIN scoped_wallets sw ON sw.id = w.id
    WHERE w.balance_credits < 0

    UNION ALL

    -- 2) Wallet order without completed payment transaction
    SELECT
      ('order_without_payment:' || o.id)::text,
      'high'::text,
      'wallet_order_without_payment_tx'::text,
      o.wallet_id,
      o.id,
      o.cafe_id,
      COALESCE(o.paid_credits, 0)::int,
      o.created_at,
      'Wallet-paid order has no completed order_payment transaction'::text,
      jsonb_build_object(
        'order_number', o.order_number,
        'payment_status', o.payment_status,
        'status', o.status
      )
    FROM orders_core o
    WHERE o.created_at >= v_from
      AND o.created_at <= v_to
      AND (
        v_role = 'admin'
        OR o.cafe_id IN (SELECT id FROM owner_cafes)
      )
      AND (p_cafe_id IS NULL OR o.cafe_id = p_cafe_id)
      AND o.wallet_id IN (SELECT id FROM scoped_wallets)
      AND o.payment_method = 'wallet'
      AND COALESCE(o.paid_credits, 0) > 0
      AND NOT EXISTS (
        SELECT 1
        FROM payment_transactions pt
        WHERE pt.order_id = o.id
          AND pt.transaction_type = 'order_payment'
          AND pt.status = 'completed'
      )

    UNION ALL

    -- 3) Completed payment transaction without matching wallet ledger row
    SELECT
      ('payment_without_ledger:' || pt.id)::text,
      'high'::text,
      'completed_payment_without_wallet_ledger'::text,
      pt.wallet_id,
      pt.order_id,
      o.cafe_id,
      pt.amount_credits::int,
      pt.created_at,
      'Completed payment transaction has no matching wallet ledger entry'::text,
      jsonb_build_object(
        'transaction_type', pt.transaction_type,
        'status', pt.status,
        'idempotency_key', pt.idempotency_key
      )
    FROM payment_transactions pt
    LEFT JOIN orders_core o ON o.id = pt.order_id
    WHERE pt.created_at >= v_from
      AND pt.created_at <= v_to
      AND pt.status = 'completed'
      AND pt.wallet_id IN (SELECT id FROM scoped_wallets)
      AND (
        p_cafe_id IS NULL
        OR o.cafe_id = p_cafe_id
        OR EXISTS (
          SELECT 1
          FROM wallets w2
          WHERE w2.id = pt.wallet_id
            AND w2.cafe_id = p_cafe_id
        )
      )
      AND NOT EXISTS (
        SELECT 1
        FROM wallet_transactions wt
        WHERE wt.wallet_id = pt.wallet_id
          AND (
            (pt.transaction_type = 'topup' AND wt.type = 'topup')
            OR (pt.transaction_type = 'refund' AND wt.type = 'refund')
            OR (pt.transaction_type = 'order_payment' AND wt.type = 'payment')
          )
          AND (
            (pt.order_id IS NOT NULL AND wt.order_id = pt.order_id)
            OR (
              pt.order_id IS NULL
              AND wt.amount = CASE
                WHEN pt.transaction_type = 'order_payment' THEN -pt.amount_credits
                ELSE pt.amount_credits
              END
              AND wt.created_at BETWEEN pt.created_at - INTERVAL '15 minutes' AND pt.created_at + INTERVAL '15 minutes'
            )
          )
      )

    UNION ALL

    -- 4) Reconciliation delta anomaly (single aggregate signal)
    SELECT
      'reconciliation_delta'::text,
      CASE
        WHEN ABS(fc.discrepancy_credits) >= 100 THEN 'critical'
        WHEN ABS(fc.discrepancy_credits) >= 20 THEN 'high'
        ELSE 'medium'
      END::text,
      'reconciliation_delta'::text,
      NULL::uuid,
      NULL::uuid,
      p_cafe_id,
      fc.discrepancy_credits::int,
      now(),
      'Wallet ledger delta does not match expected payment delta'::text,
      jsonb_build_object(
        'wallet_ledger_delta_credits', fc.wallet_ledger_delta_credits,
        'expected_wallet_delta_credits', fc.expected_wallet_delta_credits
      )
    FROM owner_get_financial_control_tower(v_from, v_to, p_cafe_id) fc
    WHERE fc.discrepancy_credits <> 0
  )
  SELECT
    a.anomaly_key,
    a.severity,
    a.anomaly_type,
    a.wallet_id,
    a.order_id,
    a.cafe_id,
    a.amount_credits,
    a.detected_at,
    a.message,
    a.details
  FROM anomalies a
  ORDER BY
    CASE a.severity
      WHEN 'critical' THEN 4
      WHEN 'high' THEN 3
      WHEN 'medium' THEN 2
      ELSE 1
    END DESC,
    a.detected_at DESC
  LIMIT v_limit;
END;
$$;

COMMENT ON FUNCTION owner_get_financial_anomalies(timestamptz, timestamptz, uuid, int)
  IS 'Owner/Admin: owner-scoped anomaly feed for reconciliation and accounting control';

-- Grants
GRANT EXECUTE ON FUNCTION admin_get_financial_control_tower(timestamptz, timestamptz, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_financial_anomalies(timestamptz, timestamptz, uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_financial_control_tower(timestamptz, timestamptz, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_financial_anomalies(timestamptz, timestamptz, uuid, int) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Financial Control Tower RPCs created';
  RAISE NOTICE '   - admin_get_financial_control_tower';
  RAISE NOTICE '   - admin_get_financial_anomalies';
  RAISE NOTICE '   - owner_get_financial_control_tower';
  RAISE NOTICE '   - owner_get_financial_anomalies';
  RAISE NOTICE '';
END $$;
