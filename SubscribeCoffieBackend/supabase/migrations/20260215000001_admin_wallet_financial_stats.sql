-- ============================================================================
-- Admin Wallet Financial Stats (List + Overview)
-- Date: 2026-02-15
-- Purpose:
--   1) Extend admin_get_wallets with per-wallet financial aggregates for list view
--   2) Extend admin_get_wallet_overview with financial totals for detailed analytics
--
-- Backward compatibility:
--   - Existing columns are preserved in the same order
--   - New fields are appended at the end of result sets
-- ============================================================================

-- ============================================================================
-- 1) admin_get_wallets (extended contract)
-- ============================================================================

DROP FUNCTION IF EXISTS admin_get_wallets(int, int, text);

CREATE OR REPLACE FUNCTION admin_get_wallets(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL
)
RETURNS TABLE (
  wallet_id uuid,
  user_id uuid,
  wallet_type wallet_type,
  balance_credits int,
  lifetime_top_up_credits int,
  created_at timestamptz,
  user_email text,
  user_phone text,
  user_full_name text,
  cafe_id uuid,
  cafe_name text,
  network_id uuid,
  network_name text,
  last_transaction_at timestamptz,
  last_payment_at timestamptz,
  last_order_at timestamptz,
  total_transactions int,
  total_payments int,
  total_orders int,
  total_topups int,
  total_refunds int,
  total_topup_credits int,
  total_spent_credits int,
  total_refund_credits int,
  net_wallet_change_credits int,
  total_orders_paid_credits int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int;
  v_offset int;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT validated_limit, validated_offset
  INTO v_limit, v_offset
  FROM validate_pagination(p_limit, p_offset, 200);

  p_search := NULLIF(TRIM(p_search), '');

  RETURN QUERY
  SELECT
    w.id AS wallet_id,
    w.user_id,
    w.wallet_type,
    w.balance_credits,
    w.lifetime_top_up_credits,
    w.created_at,
    p.email AS user_email,
    p.phone AS user_phone,
    p.full_name AS user_full_name,
    w.cafe_id,
    c.name AS cafe_name,
    w.network_id,
    wn.name AS network_name,
    tx.last_transaction_at,
    pay.last_payment_at,
    ord.last_order_at,
    tx.total_transactions,
    pay.total_payments,
    ord.total_orders,
    tx.total_topups,
    tx.total_refunds,
    COALESCE(tx.total_topup_credits, w.lifetime_top_up_credits, 0) AS total_topup_credits,
    COALESCE(tx.total_payment_credits, ord.total_orders_paid_credits, 0) AS total_spent_credits,
    tx.total_refund_credits,
    tx.net_wallet_change_credits,
    ord.total_orders_paid_credits
  FROM wallets w
  LEFT JOIN profiles p ON w.user_id = p.id
  LEFT JOIN cafes c ON w.cafe_id = c.id
  LEFT JOIN wallet_networks wn ON w.network_id = wn.id
  LEFT JOIN LATERAL (
    SELECT
      MAX(wt.created_at) AS last_transaction_at,
      COUNT(*)::int AS total_transactions,
      COUNT(*) FILTER (WHERE wt.type = 'topup')::int AS total_topups,
      COUNT(*) FILTER (WHERE wt.type = 'refund')::int AS total_refunds,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type = 'topup'), 0)::int AS total_topup_credits,
      COALESCE(SUM(ABS(wt.amount)) FILTER (WHERE wt.type = 'payment'), 0)::int AS total_payment_credits,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type = 'refund'), 0)::int AS total_refund_credits,
      COALESCE(SUM(wt.amount), 0)::int AS net_wallet_change_credits
    FROM wallet_transactions wt
    WHERE wt.wallet_id = w.id
  ) tx ON TRUE
  LEFT JOIN LATERAL (
    SELECT
      MAX(pt.completed_at) FILTER (WHERE pt.status = 'completed') AS last_payment_at,
      COUNT(*)::int AS total_payments
    FROM payment_transactions pt
    WHERE pt.wallet_id = w.id
  ) pay ON TRUE
  LEFT JOIN LATERAL (
    SELECT
      MAX(o.created_at) AS last_order_at,
      COUNT(*)::int AS total_orders,
      COALESCE(SUM(o.paid_credits), 0)::int AS total_orders_paid_credits
    FROM orders_core o
    WHERE o.wallet_id = w.id
  ) ord ON TRUE
  WHERE
    (
      p_search IS NULL OR
      p.email ILIKE '%' || p_search || '%' OR
      p.phone ILIKE '%' || p_search || '%' OR
      p.full_name ILIKE '%' || p_search || '%' OR
      c.name ILIKE '%' || p_search || '%'
    )
  ORDER BY w.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION admin_get_wallets IS
  'Admin: Get wallets with activity + financial stats (topups/payments/refunds/orders)';

-- ============================================================================
-- 2) admin_get_wallet_overview (extended contract)
-- ============================================================================

DROP FUNCTION IF EXISTS admin_get_wallet_overview(uuid);

CREATE OR REPLACE FUNCTION admin_get_wallet_overview(p_wallet_id uuid)
RETURNS TABLE (
  wallet_id uuid,
  user_id uuid,
  wallet_type wallet_type,
  balance_credits int,
  lifetime_top_up_credits int,
  created_at timestamptz,
  updated_at timestamptz,
  user_email text,
  user_phone text,
  user_full_name text,
  user_avatar_url text,
  user_registered_at timestamptz,
  cafe_id uuid,
  cafe_name text,
  cafe_address text,
  network_id uuid,
  network_name text,
  total_transactions int,
  total_topups int,
  total_payments int,
  total_refunds int,
  total_orders int,
  completed_orders int,
  last_transaction_at timestamptz,
  last_payment_at timestamptz,
  last_order_at timestamptz,
  total_topup_credits int,
  total_payment_credits int,
  total_refund_credits int,
  total_adjustment_credits int,
  net_wallet_change_credits int,
  total_orders_paid_credits int,
  avg_order_paid_credits int,
  last_topup_at timestamptz,
  last_refund_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Invalid wallet_id: NULL';
  END IF;

  RETURN QUERY
  SELECT
    w.id AS wallet_id,
    w.user_id,
    w.wallet_type,
    w.balance_credits,
    w.lifetime_top_up_credits,
    w.created_at,
    w.updated_at,
    p.email AS user_email,
    p.phone AS user_phone,
    p.full_name AS user_full_name,
    p.avatar_url AS user_avatar_url,
    p.created_at AS user_registered_at,
    w.cafe_id,
    c.name AS cafe_name,
    c.address AS cafe_address,
    w.network_id,
    wn.name AS network_name,
    tx.total_transactions,
    tx.total_topups,
    tx.total_payments,
    tx.total_refunds,
    ord.total_orders,
    ord.completed_orders,
    tx.last_transaction_at,
    pay.last_payment_at,
    ord.last_order_at,
    COALESCE(tx.total_topup_credits, w.lifetime_top_up_credits, 0) AS total_topup_credits,
    COALESCE(tx.total_payment_credits, ord.total_orders_paid_credits, 0) AS total_payment_credits,
    tx.total_refund_credits,
    tx.total_adjustment_credits,
    tx.net_wallet_change_credits,
    ord.total_orders_paid_credits,
    ord.avg_order_paid_credits,
    tx.last_topup_at,
    tx.last_refund_at
  FROM wallets w
  LEFT JOIN profiles p ON w.user_id = p.id
  LEFT JOIN cafes c ON w.cafe_id = c.id
  LEFT JOIN wallet_networks wn ON w.network_id = wn.id
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::int AS total_transactions,
      COUNT(*) FILTER (WHERE wt.type = 'topup')::int AS total_topups,
      COUNT(*) FILTER (WHERE wt.type = 'payment')::int AS total_payments,
      COUNT(*) FILTER (WHERE wt.type = 'refund')::int AS total_refunds,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type = 'topup'), 0)::int AS total_topup_credits,
      COALESCE(SUM(ABS(wt.amount)) FILTER (WHERE wt.type = 'payment'), 0)::int AS total_payment_credits,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type = 'refund'), 0)::int AS total_refund_credits,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type IN ('admin_credit', 'admin_debit')), 0)::int AS total_adjustment_credits,
      COALESCE(SUM(wt.amount), 0)::int AS net_wallet_change_credits,
      MAX(wt.created_at) AS last_transaction_at,
      MAX(wt.created_at) FILTER (WHERE wt.type = 'topup') AS last_topup_at,
      MAX(wt.created_at) FILTER (WHERE wt.type = 'refund') AS last_refund_at
    FROM wallet_transactions wt
    WHERE wt.wallet_id = w.id
  ) tx ON TRUE
  LEFT JOIN LATERAL (
    SELECT
      MAX(pt.completed_at) FILTER (WHERE pt.status = 'completed') AS last_payment_at
    FROM payment_transactions pt
    WHERE pt.wallet_id = w.id
  ) pay ON TRUE
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::int AS total_orders,
      COUNT(*) FILTER (WHERE o.status IN ('issued', 'picked_up'))::int AS completed_orders,
      COALESCE(SUM(o.paid_credits), 0)::int AS total_orders_paid_credits,
      COALESCE(ROUND(AVG(o.paid_credits)), 0)::int AS avg_order_paid_credits,
      MAX(o.created_at) AS last_order_at
    FROM orders_core o
    WHERE o.wallet_id = w.id
  ) ord ON TRUE
  WHERE w.id = p_wallet_id;
END;
$$;

COMMENT ON FUNCTION admin_get_wallet_overview IS
  'Admin: Detailed wallet overview with financial aggregates and timestamps';

GRANT EXECUTE ON FUNCTION admin_get_wallets(int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_wallet_overview(uuid) TO authenticated;

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Admin wallet financial stats extended';
  RAISE NOTICE '   - admin_get_wallets: added topups/refunds/credits aggregates';
  RAISE NOTICE '   - admin_get_wallet_overview: added financial totals and last topup/refund timestamps';
  RAISE NOTICE '';
END $$;
