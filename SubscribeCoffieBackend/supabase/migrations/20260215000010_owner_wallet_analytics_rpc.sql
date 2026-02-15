-- Migration: Owner Wallet Analytics RPC
-- Date: 2026-02-15
-- Purpose: Owner-scoped wallet analytics (strict access control to own cafes only)

-- ============================================================================
-- Helper: Check if user is owner or admin
-- ============================================================================

CREATE OR REPLACE FUNCTION is_owner_or_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_role text;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;
  
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;
  
  -- Admin or owner can access
  RETURN (v_role IN ('admin', 'owner'));
END;
$$;

COMMENT ON FUNCTION is_owner_or_admin IS 'Check if current user is owner or admin';

-- ============================================================================
-- Helper: Verify cafe ownership for owner
-- ============================================================================

CREATE OR REPLACE FUNCTION verify_cafe_ownership(p_cafe_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_role text;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;
  
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;
  
  -- Admin can access all
  IF v_role = 'admin' THEN
    RETURN true;
  END IF;
  
  -- Owner can only access their own cafes
  IF v_role = 'owner' THEN
    RETURN EXISTS (
      SELECT 1 
      FROM cafes c
      JOIN accounts a ON c.account_id = a.id
      WHERE c.id = p_cafe_id 
        AND a.owner_user_id = v_user_id
    );
  END IF;
  
  RETURN false;
END;
$$;

COMMENT ON FUNCTION verify_cafe_ownership IS 'Verify that owner has access to cafe (admin bypasses check)';

-- ============================================================================
-- Helper: Verify wallet ownership for owner
-- ============================================================================

CREATE OR REPLACE FUNCTION verify_wallet_ownership(p_wallet_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_role text;
  v_wallet_cafe_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;
  
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;
  
  -- Admin can access all
  IF v_role = 'admin' THEN
    RETURN true;
  END IF;
  
  -- Owner can only access wallets for their cafes
  IF v_role = 'owner' THEN
    -- Get wallet's cafe_id (for cafe_wallet type)
    SELECT cafe_id INTO v_wallet_cafe_id
    FROM wallets
    WHERE id = p_wallet_id;
    
    -- CityPass wallets (cafe_id = NULL) are not owner-scoped
    IF v_wallet_cafe_id IS NULL THEN
      RETURN false;
    END IF;
    
    -- Check if owner owns this cafe
    RETURN EXISTS (
      SELECT 1
      FROM cafes c
      JOIN accounts a ON c.account_id = a.id
      WHERE c.id = v_wallet_cafe_id
        AND a.owner_user_id = v_user_id
    );
  END IF;
  
  RETURN false;
END;
$$;

COMMENT ON FUNCTION verify_wallet_ownership IS 'Verify that owner has access to wallet (only cafe wallets for owned cafes)';

-- ============================================================================
-- 1. owner_get_wallets - List wallets for owner's cafes
-- ============================================================================

CREATE OR REPLACE FUNCTION owner_get_wallets(
  p_cafe_id uuid DEFAULT NULL,
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
  v_user_id uuid;
  v_role text;
BEGIN
  -- 🛡️ SECURITY: Check owner/admin permission
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;
  
  v_user_id := auth.uid();
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;
  
  -- 🛡️ SECURITY: Validate pagination
  SELECT validated_limit, validated_offset 
  INTO v_limit, v_offset
  FROM validate_pagination(p_limit, p_offset, 200);
  
  -- 🛡️ SECURITY: Sanitize search input
  p_search := NULLIF(TRIM(p_search), '');
  
  -- 🛡️ SECURITY: If cafe_id provided, verify ownership
  IF p_cafe_id IS NOT NULL AND v_role = 'owner' THEN
    IF NOT verify_cafe_ownership(p_cafe_id) THEN
      RAISE EXCEPTION 'Unauthorized: cafe not owned by you';
    END IF;
  END IF;

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
    -- 🛡️ SECURITY: Owner can only see wallets for their cafes
    (v_role = 'admin' OR (
      v_role = 'owner' AND
      w.wallet_type = 'cafe_wallet' AND
      w.cafe_id IN (
        SELECT ca.id 
        FROM cafes ca
        JOIN accounts acc ON ca.account_id = acc.id
        WHERE acc.owner_user_id = v_user_id
      )
    ))
    -- Filter by specific cafe if provided
    AND (p_cafe_id IS NULL OR w.cafe_id = p_cafe_id)
    -- Search filter
    AND (p_search IS NULL OR
         p.email ILIKE '%' || p_search || '%' OR
         p.phone ILIKE '%' || p_search || '%' OR
         p.full_name ILIKE '%' || p_search || '%' OR
         c.name ILIKE '%' || p_search || '%')
  ORDER BY w.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION owner_get_wallets IS 'Owner: Get wallets for owned cafes (cafe_wallet only, strict ownership check)';

-- ============================================================================
-- 2. owner_get_wallet_overview - Detailed wallet info
-- ============================================================================

CREATE OR REPLACE FUNCTION owner_get_wallet_overview(p_wallet_id uuid)
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
  -- 🛡️ SECURITY: Check owner/admin permission
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;
  
  -- 🛡️ SECURITY: Validate wallet_id
  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Invalid wallet_id: NULL';
  END IF;
  
  -- 🛡️ SECURITY: Verify wallet ownership
  IF NOT verify_wallet_ownership(p_wallet_id) THEN
    RAISE EXCEPTION 'Unauthorized: wallet not accessible';
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

COMMENT ON FUNCTION owner_get_wallet_overview IS 'Owner: Get detailed wallet overview (ownership verified)';

-- ============================================================================
-- 3. owner_get_wallet_transactions - Transaction history
-- ============================================================================

CREATE OR REPLACE FUNCTION owner_get_wallet_transactions(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  transaction_id uuid,
  wallet_id uuid,
  amount int,
  type text,
  description text,
  order_id uuid,
  order_number text,
  actor_user_id uuid,
  actor_email text,
  actor_full_name text,
  balance_before int,
  balance_after int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int;
  v_offset int;
BEGIN
  -- 🛡️ SECURITY: Check owner/admin permission
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;
  
  -- 🛡️ SECURITY: Validate wallet_id
  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Invalid wallet_id: NULL';
  END IF;
  
  -- 🛡️ SECURITY: Verify wallet ownership
  IF NOT verify_wallet_ownership(p_wallet_id) THEN
    RAISE EXCEPTION 'Unauthorized: wallet not accessible';
  END IF;
  
  -- 🛡️ SECURITY: Validate pagination
  SELECT validated_limit, validated_offset 
  INTO v_limit, v_offset
  FROM validate_pagination(p_limit, p_offset, 200);

  RETURN QUERY
  SELECT
    wt.id AS transaction_id,
    wt.wallet_id,
    wt.amount,
    wt.type,
    wt.description,
    wt.order_id,
    o.order_number,
    wt.actor_user_id,
    ap.email AS actor_email,
    ap.full_name AS actor_full_name,
    wt.balance_before,
    wt.balance_after,
    wt.created_at
  FROM wallet_transactions wt
  LEFT JOIN orders_core o ON wt.order_id = o.id
  LEFT JOIN profiles ap ON wt.actor_user_id = ap.id
  WHERE wt.wallet_id = p_wallet_id
  ORDER BY wt.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION owner_get_wallet_transactions IS 'Owner: Get wallet transaction history (ownership verified)';

-- ============================================================================
-- 4. owner_get_wallet_payments - Payment transactions
-- ============================================================================

CREATE OR REPLACE FUNCTION owner_get_wallet_payments(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  payment_id uuid,
  wallet_id uuid,
  order_id uuid,
  order_number text,
  amount_credits int,
  commission_credits int,
  net_amount int,
  transaction_type text,
  payment_method_id uuid,
  status text,
  provider_transaction_id text,
  idempotency_key text,
  created_at timestamptz,
  completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int;
  v_offset int;
BEGIN
  -- 🛡️ SECURITY: Check owner/admin permission
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;
  
  -- 🛡️ SECURITY: Validate wallet_id
  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Invalid wallet_id: NULL';
  END IF;
  
  -- 🛡️ SECURITY: Verify wallet ownership
  IF NOT verify_wallet_ownership(p_wallet_id) THEN
    RAISE EXCEPTION 'Unauthorized: wallet not accessible';
  END IF;
  
  -- 🛡️ SECURITY: Validate pagination
  SELECT validated_limit, validated_offset 
  INTO v_limit, v_offset
  FROM validate_pagination(p_limit, p_offset, 200);

  RETURN QUERY
  SELECT
    pt.id AS payment_id,
    pt.wallet_id,
    pt.order_id,
    o.order_number,
    pt.amount_credits,
    pt.commission_credits,
    (pt.amount_credits - pt.commission_credits) AS net_amount,
    pt.transaction_type,
    pt.payment_method_id,
    pt.status,
    pt.provider_transaction_id,
    pt.idempotency_key,
    pt.created_at,
    pt.completed_at
  FROM payment_transactions pt
  LEFT JOIN orders_core o ON pt.order_id = o.id
  WHERE pt.wallet_id = p_wallet_id
  ORDER BY pt.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION owner_get_wallet_payments IS 'Owner: Get wallet payment transactions (ownership verified)';

-- ============================================================================
-- 5. owner_get_wallet_orders - Orders with itemized breakdown
-- ============================================================================

CREATE OR REPLACE FUNCTION owner_get_wallet_orders(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  order_id uuid,
  order_number text,
  created_at timestamptz,
  status text,
  cafe_id uuid,
  cafe_name text,
  subtotal_credits int,
  paid_credits int,
  bonus_used int,
  payment_method text,
  payment_status text,
  customer_name text,
  customer_phone text,
  items jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int;
  v_offset int;
BEGIN
  -- 🛡️ SECURITY: Check owner/admin permission
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;
  
  -- 🛡️ SECURITY: Validate wallet_id
  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Invalid wallet_id: NULL';
  END IF;
  
  -- 🛡️ SECURITY: Verify wallet ownership
  IF NOT verify_wallet_ownership(p_wallet_id) THEN
    RAISE EXCEPTION 'Unauthorized: wallet not accessible';
  END IF;
  
  -- 🛡️ SECURITY: Validate pagination
  SELECT validated_limit, validated_offset 
  INTO v_limit, v_offset
  FROM validate_pagination(p_limit, p_offset, 200);

  RETURN QUERY
  SELECT
    o.id AS order_id,
    o.order_number,
    o.created_at,
    o.status,
    o.cafe_id,
    c.name AS cafe_name,
    o.subtotal_credits,
    o.paid_credits,
    COALESCE(o.bonus_used, 0) AS bonus_used,
    o.payment_method,
    o.payment_status,
    o.customer_name,
    o.customer_phone,
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'item_id', oi.id,
            'item_name', oi.item_name,
            'qty', oi.quantity,
            'unit_price_credits', oi.unit_credits,
            'line_total_credits', oi.total_price_credits,
            'modifiers', oi.modifiers
          )
          ORDER BY oi.created_at
        )
        FROM order_items oi
        WHERE oi.order_id = o.id
      ),
      '[]'::jsonb
    ) AS items
  FROM orders_core o
  LEFT JOIN cafes c ON o.cafe_id = c.id
  WHERE o.wallet_id = p_wallet_id
  ORDER BY o.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION owner_get_wallet_orders IS 'Owner: Get wallet orders with itemized breakdown (ownership verified)';

-- ============================================================================
-- 6. owner_get_wallets_stats - Aggregated stats for owner's wallets
-- ============================================================================

CREATE OR REPLACE FUNCTION owner_get_wallets_stats(p_cafe_id uuid DEFAULT NULL)
RETURNS TABLE (
  total_wallets int,
  total_balance_credits bigint,
  total_lifetime_topup_credits bigint,
  total_transactions int,
  total_orders int,
  total_revenue_credits bigint,
  avg_wallet_balance numeric,
  active_wallets_30d int,
  total_topup_credits bigint,
  total_spent_credits bigint,
  total_refund_credits bigint,
  net_wallet_change_credits bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_role text;
BEGIN
  -- 🛡️ SECURITY: Check owner/admin permission
  IF NOT is_owner_or_admin() THEN
    RAISE EXCEPTION 'Owner or admin access required';
  END IF;
  
  v_user_id := auth.uid();
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;
  
  -- 🛡️ SECURITY: If cafe_id provided, verify ownership
  IF p_cafe_id IS NOT NULL AND v_role = 'owner' THEN
    IF NOT verify_cafe_ownership(p_cafe_id) THEN
      RAISE EXCEPTION 'Unauthorized: cafe not owned by you';
    END IF;
  END IF;

  RETURN QUERY
  WITH selected_wallets AS (
    SELECT
      w.id,
      w.balance_credits,
      w.lifetime_top_up_credits
    FROM wallets w
    WHERE
      -- 🛡️ SECURITY: Owner can only see wallets for their cafes
      (v_role = 'admin' OR (
        v_role = 'owner' AND
        w.wallet_type = 'cafe_wallet' AND
        w.cafe_id IN (
          SELECT ca.id
          FROM cafes ca
          JOIN accounts acc ON ca.account_id = acc.id
          WHERE acc.owner_user_id = v_user_id
        )
      ))
      -- Filter by specific cafe if provided
      AND (p_cafe_id IS NULL OR w.cafe_id = p_cafe_id)
  ),
  tx_stats AS (
    SELECT
      COUNT(*)::int AS total_transactions,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type = 'topup'), 0)::bigint AS total_topup_credits,
      COALESCE(SUM(ABS(wt.amount)) FILTER (WHERE wt.type = 'payment'), 0)::bigint AS total_spent_credits,
      COALESCE(SUM(wt.amount) FILTER (WHERE wt.type = 'refund'), 0)::bigint AS total_refund_credits,
      COALESCE(SUM(wt.amount), 0)::bigint AS net_wallet_change_credits,
      COUNT(DISTINCT wt.wallet_id) FILTER (
        WHERE wt.created_at >= NOW() - INTERVAL '30 days'
      )::int AS active_wallets_30d
    FROM wallet_transactions wt
    JOIN selected_wallets sw ON sw.id = wt.wallet_id
  ),
  order_stats AS (
    SELECT
      COUNT(*)::int AS total_orders,
      COALESCE(SUM(COALESCE(o.paid_credits, 0) + COALESCE(o.bonus_used, 0)), 0)::bigint AS total_revenue_credits
    FROM orders_core o
    JOIN selected_wallets sw ON sw.id = o.wallet_id
  )
  SELECT
    COUNT(sw.id)::int AS total_wallets,
    COALESCE(SUM(sw.balance_credits), 0)::bigint AS total_balance_credits,
    COALESCE(SUM(sw.lifetime_top_up_credits), 0)::bigint AS total_lifetime_topup_credits,
    COALESCE((SELECT ts.total_transactions FROM tx_stats ts), 0)::int AS total_transactions,
    COALESCE((SELECT os.total_orders FROM order_stats os), 0)::int AS total_orders,
    COALESCE((SELECT os.total_revenue_credits FROM order_stats os), 0)::bigint AS total_revenue_credits,
    COALESCE(AVG(sw.balance_credits), 0)::numeric AS avg_wallet_balance,
    COALESCE((SELECT ts.active_wallets_30d FROM tx_stats ts), 0)::int AS active_wallets_30d,
    COALESCE((SELECT ts.total_topup_credits FROM tx_stats ts), 0)::bigint AS total_topup_credits,
    COALESCE((SELECT ts.total_spent_credits FROM tx_stats ts), 0)::bigint AS total_spent_credits,
    COALESCE((SELECT ts.total_refund_credits FROM tx_stats ts), 0)::bigint AS total_refund_credits,
    COALESCE((SELECT ts.net_wallet_change_credits FROM tx_stats ts), 0)::bigint AS net_wallet_change_credits
  FROM selected_wallets sw;
END;
$$;

COMMENT ON FUNCTION owner_get_wallets_stats IS 'Owner: Get aggregated wallet stats + financial flow for owned cafes';

-- ============================================================================
-- Performance Indexes for Owner Queries
-- ============================================================================

-- Index for owner wallet filtering (cafe_wallet + cafe_id)
CREATE INDEX IF NOT EXISTS idx_wallets_cafe_type_owner 
ON wallets(cafe_id, wallet_type) 
WHERE wallet_type = 'cafe_wallet';

-- Index for cafes by account (owner lookup)
CREATE INDEX IF NOT EXISTS idx_cafes_account_owner 
ON cafes(account_id) 
WHERE account_id IS NOT NULL;

-- ============================================================================
-- Grant Permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION is_owner_or_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION verify_cafe_ownership(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_wallet_ownership(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_wallets(uuid, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_wallet_overview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_wallet_transactions(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_wallet_payments(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_wallet_orders(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION owner_get_wallets_stats(uuid) TO authenticated;

-- ============================================================================
-- Complete
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Owner Wallet Analytics RPC created';
  RAISE NOTICE '';
  RAISE NOTICE 'Functions:';
  RAISE NOTICE '  - owner_get_wallets(cafe_id?, limit, offset, search)';
  RAISE NOTICE '  - owner_get_wallet_overview(wallet_id)';
  RAISE NOTICE '  - owner_get_wallet_transactions(wallet_id, limit, offset)';
  RAISE NOTICE '  - owner_get_wallet_payments(wallet_id, limit, offset)';
  RAISE NOTICE '  - owner_get_wallet_orders(wallet_id, limit, offset)';
  RAISE NOTICE '  - owner_get_wallets_stats(cafe_id?)';
  RAISE NOTICE '';
  RAISE NOTICE 'Security:';
  RAISE NOTICE '  - Owner can only access cafe_wallet for owned cafes';
  RAISE NOTICE '  - Strict ownership verification via accounts.owner_user_id';
  RAISE NOTICE '  - Admin can access all (bypass ownership check)';
  RAISE NOTICE '';
END $$;
