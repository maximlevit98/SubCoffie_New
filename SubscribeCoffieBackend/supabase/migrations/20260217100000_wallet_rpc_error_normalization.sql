-- ============================================================================
-- Wallet RPC Error Normalization + TRK-01 hardening
-- Date: 2026-02-17
-- Purpose:
--   1) Keep wallet RPC behavior idempotent and auth-bound
--   2) Normalize common error messages for iOS parsing
--      - wallet_auth_required
--      - wallet_access_denied
--      - wallet_user_not_found
--      - wallet_not_found
--      - wallet_amount_invalid
-- ============================================================================

-- ---------------------------------------------------------------------------
-- create_citypass_wallet
-- ---------------------------------------------------------------------------

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
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'wallet_access_denied',
        DETAIL = 'p_user_id must match authenticated user';
    END IF;
    v_effective_user_id := v_authenticated_user_id;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    IF p_user_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'wallet_user_id_required',
        DETAIL = 'p_user_id is required in service context';
    END IF;
    v_effective_user_id := p_user_id;
  ELSE
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_auth_required',
      DETAIL = 'Not authenticated. Please sign in.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_effective_user_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_user_not_found',
      DETAIL = 'User not found in auth.users. Please re-authenticate.';
  END IF;

  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE user_id = v_effective_user_id
    AND wallet_type = 'citypass'
  LIMIT 1;

  IF v_wallet_id IS NOT NULL THEN
    RETURN v_wallet_id;
  END IF;

  BEGIN
    INSERT INTO public.wallets (user_id, wallet_type, balance_credits, lifetime_top_up_credits)
    VALUES (v_effective_user_id, 'citypass', 0, 0)
    RETURNING id INTO v_wallet_id;
  EXCEPTION
    WHEN unique_violation THEN
      SELECT id INTO v_wallet_id
      FROM public.wallets
      WHERE user_id = v_effective_user_id
        AND wallet_type = 'citypass'
      LIMIT 1;
  END;

  RETURN v_wallet_id;
END;
$$;

COMMENT ON FUNCTION public.create_citypass_wallet IS
  'Creates or returns existing CityPass wallet (idempotent + auth-bound, normalized errors).';

-- ---------------------------------------------------------------------------
-- create_cafe_wallet
-- ---------------------------------------------------------------------------

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
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'wallet_access_denied',
        DETAIL = 'p_user_id must match authenticated user';
    END IF;
    v_effective_user_id := v_authenticated_user_id;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    IF p_user_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'wallet_user_id_required',
        DETAIL = 'p_user_id is required in service context';
    END IF;
    v_effective_user_id := p_user_id;
  ELSE
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_auth_required',
      DETAIL = 'Not authenticated. Please sign in.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_effective_user_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_user_not_found',
      DETAIL = 'User not found in auth.users. Please re-authenticate.';
  END IF;

  IF p_cafe_id IS NULL AND p_network_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_scope_required',
      DETAIL = 'Must provide either cafe_id or network_id';
  END IF;

  IF p_cafe_id IS NOT NULL AND p_network_id IS NOT NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_scope_conflict',
      DETAIL = 'Cannot provide both cafe_id and network_id';
  END IF;

  IF p_cafe_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.cafes WHERE id = p_cafe_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_cafe_not_found',
      DETAIL = format('Cafe not found: %s', p_cafe_id::text);
  END IF;

  IF p_network_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.wallet_networks WHERE id = p_network_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_network_not_found',
      DETAIL = format('Network not found: %s', p_network_id::text);
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

  BEGIN
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
  EXCEPTION
    WHEN unique_violation THEN
      SELECT id INTO v_wallet_id
      FROM public.wallets
      WHERE user_id = v_effective_user_id
        AND wallet_type = 'cafe_wallet'
        AND (
          (p_cafe_id IS NOT NULL AND cafe_id = p_cafe_id) OR
          (p_network_id IS NOT NULL AND network_id = p_network_id)
        )
      LIMIT 1;
  END;

  RETURN v_wallet_id;
END;
$$;

COMMENT ON FUNCTION public.create_cafe_wallet IS
  'Creates or returns existing Cafe Wallet (idempotent + auth-bound, normalized errors).';

-- ---------------------------------------------------------------------------
-- get_user_wallets
-- ---------------------------------------------------------------------------

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
  created_at timestamptz
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
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_user_id_required',
      DETAIL = 'p_user_id is required';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF v_authenticated_user_id <> p_user_id THEN
      SELECT pr.role INTO v_actor_role
      FROM public.profiles pr
      WHERE pr.id = v_authenticated_user_id;

      IF COALESCE(v_actor_role, '') <> 'admin' THEN
        RAISE EXCEPTION USING
          ERRCODE = 'P0001',
          MESSAGE = 'wallet_access_denied',
          DETAIL = 'Cannot view other users wallets';
      END IF;
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_auth_required',
      DETAIL = 'Not authenticated. Please sign in.';
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
  'Returns wallets for user (own wallets/admin/service only, normalized errors).';

-- ---------------------------------------------------------------------------
-- mock_wallet_topup
-- ---------------------------------------------------------------------------

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
  v_wallet_cafe_id uuid;
  v_commission int;
  v_amount_credited int;
  v_transaction_id uuid;
  v_mock_provider_id text;
  v_existing_transaction record;
  v_balance_before int;
  v_balance_after int;
  v_authenticated_user_id uuid;
  v_jwt_role text;
  v_existing_amount_credited int;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_amount_invalid',
      DETAIL = 'Amount must be greater than 0';
  END IF;

  SELECT user_id, wallet_type, balance_credits, cafe_id
  INTO v_user_id, v_wallet_type, v_balance_before, v_wallet_cafe_id
  FROM public.wallets
  WHERE id = p_wallet_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_not_found',
      DETAIL = 'Wallet not found';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF v_authenticated_user_id <> v_user_id THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'wallet_access_denied',
        DETAIL = 'Cannot top up another user wallet';
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'wallet_auth_required',
      DETAIL = 'Not authenticated. Please sign in.';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT
      id,
      status,
      amount_credits,
      commission_credits,
      provider_transaction_id,
      fee_payer,
      fee_cafe_id
    INTO v_existing_transaction
    FROM public.payment_transactions
    WHERE idempotency_key = p_idempotency_key
      AND wallet_id = p_wallet_id
    LIMIT 1;

    IF v_existing_transaction.id IS NOT NULL THEN
      v_existing_amount_credited := CASE
        WHEN COALESCE(v_existing_transaction.fee_payer, 'customer') = 'customer'
          THEN v_existing_transaction.amount_credits - v_existing_transaction.commission_credits
        ELSE
          v_existing_transaction.amount_credits
      END;

      RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_existing_transaction.id,
        'amount', v_existing_transaction.amount_credits,
        'commission', v_existing_transaction.commission_credits,
        'amount_credited', v_existing_amount_credited,
        'status', v_existing_transaction.status,
        'fee_payer', v_existing_transaction.fee_payer,
        'fee_cafe_id', v_existing_transaction.fee_cafe_id,
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

  -- Business rule:
  -- - CityPass top-up: user receives full amount (commission at order transaction level)
  -- - Cafe wallet top-up: user receives full amount, fee is charged to cafe
  IF v_wallet_type = 'citypass' THEN
    v_commission := 0;
  ELSE
    v_commission := public.calculate_commission(p_amount, 'topup', v_wallet_type);
  END IF;

  v_amount_credited := p_amount;
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
    idempotency_key,
    fee_payer,
    fee_cafe_id
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
    p_idempotency_key,
    CASE
      WHEN v_wallet_type = 'cafe_wallet' AND v_commission > 0 THEN 'cafe'
      ELSE 'customer'
    END,
    CASE
      WHEN v_wallet_type = 'cafe_wallet' AND v_commission > 0 THEN v_wallet_cafe_id
      ELSE NULL
    END
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
    'provider', 'mock',
    'fee_payer', CASE
      WHEN v_wallet_type = 'cafe_wallet' AND v_commission > 0 THEN 'cafe'
      ELSE 'customer'
    END,
    'fee_cafe_id', CASE
      WHEN v_wallet_type = 'cafe_wallet' AND v_commission > 0 THEN v_wallet_cafe_id
      ELSE NULL
    END
  );
END;
$$;

COMMENT ON FUNCTION public.mock_wallet_topup IS
  'Mock wallet top-up with ownership checks, idempotency and normalized errors.';

DO $$
BEGIN
  RAISE NOTICE '✅ wallet RPC error normalization applied';
END $$;
