-- Migration: Harden wallet RPC auth and restore get_user_transaction_history
-- Date: 2026-02-14
-- Purpose:
--   1) Keep wallet creation idempotent but enforce caller ownership
--   2) Harden wallet read/top-up RPCs against unauthenticated access
--   3) Restore get_user_transaction_history for iOS wallet history screens

-- ============================================================================
-- 1) create_citypass_wallet: idempotent + secure caller binding
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_citypass_wallet(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_wallet_id uuid;
  v_authenticated_user_id uuid;
  v_effective_user_id uuid;
  v_jwt_role text;
BEGIN
  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF p_user_id IS NOT NULL AND p_user_id <> v_authenticated_user_id THEN
      RAISE EXCEPTION 'Unauthorized: p_user_id must match authenticated user';
    END IF;
    v_effective_user_id := v_authenticated_user_id;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    IF p_user_id IS NULL THEN
      RAISE EXCEPTION 'p_user_id is required in service context';
    END IF;
    v_effective_user_id := p_user_id;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_effective_user_id) THEN
    RAISE EXCEPTION 'User not found in auth.users. Please re-authenticate.';
  END IF;

  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE user_id = v_effective_user_id
    AND wallet_type = 'citypass'
  LIMIT 1;

  IF v_wallet_id IS NOT NULL THEN
    RETURN v_wallet_id;
  END IF;

  INSERT INTO public.wallets (user_id, wallet_type, balance_credits, lifetime_top_up_credits)
  VALUES (v_effective_user_id, 'citypass', 0, 0)
  RETURNING id INTO v_wallet_id;

  RETURN v_wallet_id;
END;
$$;

COMMENT ON FUNCTION public.create_citypass_wallet IS
  'Creates or returns CityPass wallet (idempotent + auth-bound)';

-- ============================================================================
-- 2) create_cafe_wallet: idempotent + secure caller binding
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_cafe_wallet(
  p_user_id uuid,
  p_cafe_id uuid DEFAULT NULL,
  p_network_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_wallet_id uuid;
  v_authenticated_user_id uuid;
  v_effective_user_id uuid;
  v_jwt_role text;
BEGIN
  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF p_user_id IS NOT NULL AND p_user_id <> v_authenticated_user_id THEN
      RAISE EXCEPTION 'Unauthorized: p_user_id must match authenticated user';
    END IF;
    v_effective_user_id := v_authenticated_user_id;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    IF p_user_id IS NULL THEN
      RAISE EXCEPTION 'p_user_id is required in service context';
    END IF;
    v_effective_user_id := p_user_id;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_effective_user_id) THEN
    RAISE EXCEPTION 'User not found in auth.users. Please re-authenticate.';
  END IF;

  IF p_cafe_id IS NULL AND p_network_id IS NULL THEN
    RAISE EXCEPTION 'Must provide either cafe_id or network_id';
  END IF;

  IF p_cafe_id IS NOT NULL AND p_network_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot provide both cafe_id and network_id';
  END IF;

  IF p_cafe_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.cafes WHERE id = p_cafe_id) THEN
    RAISE EXCEPTION 'Cafe not found: %', p_cafe_id;
  END IF;

  IF p_network_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.wallet_networks WHERE id = p_network_id) THEN
    RAISE EXCEPTION 'Network not found: %', p_network_id;
  END IF;

  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE user_id = v_effective_user_id
    AND wallet_type = 'cafe_wallet'
    AND (
      (p_cafe_id IS NOT NULL AND cafe_id = p_cafe_id) OR
      (p_network_id IS NOT NULL AND network_id = p_network_id)
    )
  LIMIT 1;

  IF v_wallet_id IS NOT NULL THEN
    RETURN v_wallet_id;
  END IF;

  INSERT INTO public.wallets (
    user_id,
    wallet_type,
    cafe_id,
    network_id,
    balance_credits,
    lifetime_top_up_credits
  )
  VALUES (
    v_effective_user_id,
    'cafe_wallet',
    p_cafe_id,
    p_network_id,
    0,
    0
  )
  RETURNING id INTO v_wallet_id;

  RETURN v_wallet_id;
END;
$$;

COMMENT ON FUNCTION public.create_cafe_wallet IS
  'Creates or returns Cafe Wallet (idempotent + auth-bound)';

-- ============================================================================
-- 3) get_user_wallets: enforce ownership/admin/service access
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_wallets(p_user_id uuid)
RETURNS TABLE(
  id uuid,
  wallet_type wallet_type,
  balance_credits int,
  lifetime_top_up_credits int,
  cafe_id uuid,
  cafe_name text,
  network_id uuid,
  network_name text,
  created_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_authenticated_user_id uuid;
  v_actor_role text;
  v_jwt_role text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF v_authenticated_user_id <> p_user_id THEN
      SELECT role INTO v_actor_role
      FROM public.profiles
      WHERE id = v_authenticated_user_id;

      IF COALESCE(v_actor_role, '') <> 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Cannot view other users wallets';
      END IF;
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  RETURN QUERY
  SELECT
    w.id,
    w.wallet_type,
    w.balance_credits,
    w.lifetime_top_up_credits,
    w.cafe_id,
    c.name AS cafe_name,
    w.network_id,
    wn.name AS network_name,
    w.created_at
  FROM public.wallets w
  LEFT JOIN public.cafes c ON w.cafe_id = c.id
  LEFT JOIN public.wallet_networks wn ON w.network_id = wn.id
  WHERE w.user_id = p_user_id
  ORDER BY w.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_user_wallets IS
  'Returns wallets for user (own wallets/admin/service only)';

-- ============================================================================
-- 4) get_wallet_transactions: fix NULL auth bypass
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_wallet_transactions(
  user_id_param uuid,
  limit_param int DEFAULT 50,
  offset_param int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  wallet_id uuid,
  amount int,
  type text,
  description text,
  order_id uuid,
  actor_user_id uuid,
  balance_before int,
  balance_after int,
  created_at timestamptz
)
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql
AS $$
DECLARE
  v_authenticated_user_id uuid;
  v_caller_role text;
  v_jwt_role text;
BEGIN
  IF user_id_param IS NULL THEN
    RAISE EXCEPTION 'user_id_param is required';
  END IF;

  IF limit_param < 1 OR limit_param > 1000 THEN
    RAISE EXCEPTION 'limit_param must be between 1 and 1000';
  END IF;

  IF offset_param < 0 THEN
    RAISE EXCEPTION 'offset_param cannot be negative';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = v_authenticated_user_id;

    IF COALESCE(v_caller_role, '') <> 'admin' AND v_authenticated_user_id <> user_id_param THEN
      RAISE EXCEPTION 'Unauthorized: Cannot view other users transactions';
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  RETURN QUERY
  SELECT
    wt.id,
    wt.wallet_id,
    wt.amount,
    wt.type,
    wt.description,
    wt.order_id,
    wt.actor_user_id,
    wt.balance_before,
    wt.balance_after,
    wt.created_at
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  WHERE w.user_id = user_id_param
  ORDER BY wt.created_at DESC
  LIMIT limit_param
  OFFSET offset_param;
END;
$$;

COMMENT ON FUNCTION public.get_wallet_transactions IS
  'Returns wallet transactions (own/admin/service only, canonical schema)';

-- ============================================================================
-- 5) get_user_transaction_history: restore active RPC for iOS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_transaction_history(
  p_user_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  wallet_id uuid,
  order_id uuid,
  amount_credits int,
  commission_credits int,
  transaction_type text,
  status text,
  provider_transaction_id text,
  created_at timestamp with time zone,
  completed_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_authenticated_user_id uuid;
  v_actor_role text;
  v_jwt_role text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  IF p_limit < 1 OR p_limit > 200 THEN
    RAISE EXCEPTION 'p_limit must be between 1 and 200';
  END IF;

  IF p_offset < 0 THEN
    RAISE EXCEPTION 'p_offset cannot be negative';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF v_authenticated_user_id <> p_user_id THEN
      SELECT role INTO v_actor_role
      FROM public.profiles
      WHERE id = v_authenticated_user_id;

      IF COALESCE(v_actor_role, '') <> 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Cannot view other users transactions';
      END IF;
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.user_id,
    t.wallet_id,
    t.order_id,
    t.amount_credits,
    t.commission_credits,
    t.transaction_type,
    t.status,
    t.provider_transaction_id,
    t.created_at,
    t.completed_at
  FROM public.payment_transactions t
  WHERE t.user_id = p_user_id
  ORDER BY t.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION public.get_user_transaction_history IS
  'Returns payment transaction history for user (own/admin/service only)';

-- ============================================================================
-- 6) mock_wallet_topup: enforce wallet ownership for caller
-- ============================================================================

CREATE OR REPLACE FUNCTION public.mock_wallet_topup(
  p_wallet_id uuid,
  p_amount int,
  p_payment_method_id uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id uuid;
  v_wallet_type wallet_type;
  v_commission int;
  v_amount_credited int;
  v_transaction_id uuid;
  v_mock_provider_id text;
  v_existing_transaction record;
  v_balance_before int;
  v_balance_after int;
  v_authenticated_user_id uuid;
  v_jwt_role text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  SELECT user_id, wallet_type, balance_credits
  INTO v_user_id, v_wallet_type, v_balance_before
  FROM public.wallets
  WHERE id = p_wallet_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF v_authenticated_user_id <> v_user_id THEN
      RAISE EXCEPTION 'Unauthorized: Cannot top up another user wallet';
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  -- Check idempotency after ownership validation
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status, amount_credits, commission_credits, provider_transaction_id
    INTO v_existing_transaction
    FROM public.payment_transactions
    WHERE idempotency_key = p_idempotency_key
      AND wallet_id = p_wallet_id
    LIMIT 1;

    IF v_existing_transaction.id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_existing_transaction.id,
        'amount', v_existing_transaction.amount_credits,
        'commission', v_existing_transaction.commission_credits,
        'amount_credited', v_existing_transaction.amount_credits - v_existing_transaction.commission_credits,
        'status', v_existing_transaction.status,
        'message', 'Idempotent: Transaction already processed',
        'provider', coalesce(
          CASE
            WHEN v_existing_transaction.provider_transaction_id LIKE 'mock_%' THEN 'mock'
            ELSE 'real'
          END,
          'mock'
        )
      );
    END IF;
  END IF;

  v_commission := public.calculate_commission(p_amount, 'topup', v_wallet_type);
  v_amount_credited := p_amount - v_commission;
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  INSERT INTO public.payment_transactions (
    user_id,
    wallet_id,
    amount_credits,
    commission_credits,
    transaction_type,
    payment_method_id,
    status,
    provider_transaction_id,
    completed_at,
    idempotency_key
  )
  VALUES (
    v_user_id,
    p_wallet_id,
    p_amount,
    v_commission,
    'topup',
    p_payment_method_id,
    'completed',
    v_mock_provider_id,
    now(),
    p_idempotency_key
  )
  RETURNING id INTO v_transaction_id;

  UPDATE public.wallets
  SET
    balance_credits = balance_credits + v_amount_credited,
    lifetime_top_up_credits = lifetime_top_up_credits + v_amount_credited,
    updated_at = now()
  WHERE id = p_wallet_id
  RETURNING balance_credits INTO v_balance_after;

  INSERT INTO public.wallet_transactions (
    wallet_id,
    amount,
    type,
    description,
    actor_user_id,
    balance_before,
    balance_after,
    created_at
  )
  VALUES (
    p_wallet_id,
    v_amount_credited,
    'topup',
    'Mock wallet top-up (TX: ' || v_transaction_id::text || ')',
    v_user_id,
    v_balance_before,
    v_balance_after,
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'commission', v_commission,
    'amount_credited', v_amount_credited,
    'provider_transaction_id', v_mock_provider_id,
    'provider', 'mock'
  );
END;
$$;

COMMENT ON FUNCTION public.mock_wallet_topup IS
  'Mock wallet top-up with idempotency, ownership checks and wallet_transactions audit trail';

-- ============================================================================
-- 7) Grants
-- ============================================================================

REVOKE ALL ON FUNCTION public.create_citypass_wallet(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_cafe_wallet(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_user_wallets(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_wallet_transactions(uuid, int, int) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_user_transaction_history(uuid, int, int) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mock_wallet_topup(uuid, int, uuid, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.create_citypass_wallet(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_cafe_wallet(uuid, uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_wallets(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_wallet_transactions(uuid, int, int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_transaction_history(uuid, int, int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mock_wallet_topup(uuid, int, uuid, text) TO authenticated, service_role;

-- ============================================================================
-- Complete
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Wallet RPC hardening + transaction history restoration complete';
  RAISE NOTICE '   - create_citypass_wallet / create_cafe_wallet remain idempotent and auth-bound';
  RAISE NOTICE '   - get_user_wallets and get_wallet_transactions hardened';
  RAISE NOTICE '   - get_user_transaction_history restored for iOS';
  RAISE NOTICE '   - mock_wallet_topup ownership checks added';
  RAISE NOTICE '';
END $$;
