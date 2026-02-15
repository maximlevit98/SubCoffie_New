-- Migration: Admin Wallet RPC Contracts
-- Date: 2026-02-14
-- Purpose: RPC functions for admin panel to manage and view wallet information

-- ============================================================================
-- Helper function: Check if user is admin
-- ============================================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- ============================================================================
-- 1. admin_get_wallets - List all wallets with user info and activity
-- ============================================================================

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
  total_orders int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check admin permission
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
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
    w.network_id,
    wn.name AS network_name,
    (SELECT MAX(created_at) FROM wallet_transactions WHERE wallet_id = w.id) AS last_transaction_at,
    (SELECT MAX(completed_at) FROM payment_transactions WHERE wallet_id = w.id AND status = 'completed') AS last_payment_at,
    (SELECT MAX(created_at) FROM orders_core WHERE wallet_id = w.id) AS last_order_at,
    (SELECT COUNT(*)::int FROM wallet_transactions WHERE wallet_id = w.id) AS total_transactions,
    (SELECT COUNT(*)::int FROM payment_transactions WHERE wallet_id = w.id) AS total_payments,
    (SELECT COUNT(*)::int FROM orders_core WHERE wallet_id = w.id) AS total_orders
  FROM wallets w
  LEFT JOIN profiles p ON w.user_id = p.id
  LEFT JOIN cafes c ON w.cafe_id = c.id
  LEFT JOIN wallet_networks wn ON w.network_id = wn.id
  WHERE
    (p_search IS NULL OR
     p.email ILIKE '%' || p_search || '%' OR
     p.phone ILIKE '%' || p_search || '%' OR
     p.full_name ILIKE '%' || p_search || '%' OR
     c.name ILIKE '%' || p_search || '%')
  ORDER BY w.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION admin_get_wallets IS 'Admin: Get list of all wallets with user info and activity stats';

-- ============================================================================
-- 2. admin_get_wallet_overview - Detailed wallet information
-- ============================================================================

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
  last_order_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check admin permission
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
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
    (SELECT COUNT(*)::int FROM wallet_transactions WHERE wallet_id = w.id) AS total_transactions,
    (SELECT COUNT(*)::int FROM wallet_transactions WHERE wallet_id = w.id AND type = 'topup') AS total_topups,
    (SELECT COUNT(*)::int FROM wallet_transactions WHERE wallet_id = w.id AND type = 'payment') AS total_payments,
    (SELECT COUNT(*)::int FROM wallet_transactions WHERE wallet_id = w.id AND type = 'refund') AS total_refunds,
    (SELECT COUNT(*)::int FROM orders_core WHERE wallet_id = w.id) AS total_orders,
    (SELECT COUNT(*)::int FROM orders_core WHERE wallet_id = w.id AND status IN ('issued', 'picked_up')) AS completed_orders,
    (SELECT MAX(created_at) FROM wallet_transactions WHERE wallet_id = w.id) AS last_transaction_at,
    (SELECT MAX(completed_at) FROM payment_transactions WHERE wallet_id = w.id AND status = 'completed') AS last_payment_at,
    (SELECT MAX(created_at) FROM orders_core WHERE wallet_id = w.id) AS last_order_at
  FROM wallets w
  LEFT JOIN profiles p ON w.user_id = p.id
  LEFT JOIN cafes c ON w.cafe_id = c.id
  LEFT JOIN wallet_networks wn ON w.network_id = wn.id
  WHERE w.id = p_wallet_id;
END;
$$;

COMMENT ON FUNCTION admin_get_wallet_overview IS 'Admin: Get detailed overview of a specific wallet';

-- ============================================================================
-- 3. admin_get_wallet_transactions - Wallet transaction history
-- ============================================================================

CREATE OR REPLACE FUNCTION admin_get_wallet_transactions(
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
BEGIN
  -- Check admin permission
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

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
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION admin_get_wallet_transactions IS 'Admin: Get transaction history for a wallet';

-- ============================================================================
-- 4. admin_get_wallet_payments - Payment transactions for wallet
-- ============================================================================

CREATE OR REPLACE FUNCTION admin_get_wallet_payments(
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
BEGIN
  -- Check admin permission
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

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
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION admin_get_wallet_payments IS 'Admin: Get payment transactions for a wallet';

-- ============================================================================
-- 5. admin_get_wallet_orders - Orders with itemized breakdown
-- ============================================================================

CREATE OR REPLACE FUNCTION admin_get_wallet_orders(
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
BEGIN
  -- Check admin permission
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

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
    COALESCE(o.bonus_used_credits, 0) AS bonus_used,
    o.payment_method,
    o.payment_status,
    o.customer_name,
    o.customer_phone,
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
    ) AS items
  FROM orders_core o
  LEFT JOIN cafes c ON o.cafe_id = c.id
  WHERE o.wallet_id = p_wallet_id
  ORDER BY o.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION admin_get_wallet_orders IS 'Admin: Get orders with itemized breakdown for a wallet';

-- ============================================================================
-- Grant permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_wallets(int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_wallet_overview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_wallet_transactions(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_wallet_payments(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_wallet_orders(uuid, int, int) TO authenticated;

-- ============================================================================
-- Complete
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Admin Wallet RPC Contracts created';
  RAISE NOTICE '';
  RAISE NOTICE 'Functions:';
  RAISE NOTICE '  - admin_get_wallets(limit, offset, search)';
  RAISE NOTICE '  - admin_get_wallet_overview(wallet_id)';
  RAISE NOTICE '  - admin_get_wallet_transactions(wallet_id, limit, offset)';
  RAISE NOTICE '  - admin_get_wallet_payments(wallet_id, limit, offset)';
  RAISE NOTICE '  - admin_get_wallet_orders(wallet_id, limit, offset)';
  RAISE NOTICE '';
  RAISE NOTICE 'All functions require admin role';
  RAISE NOTICE '';
END $$;
