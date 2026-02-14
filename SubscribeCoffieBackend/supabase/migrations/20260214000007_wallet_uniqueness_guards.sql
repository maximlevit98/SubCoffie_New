-- Migration: Enforce wallet uniqueness per user/scope and harden create_* RPCs against races
-- Date: 2026-02-14
-- Purpose:
--   1) Prevent duplicate wallets per user (citypass) and per user+scope (cafe/network)
--   2) Keep create_citypass_wallet/create_cafe_wallet idempotent under concurrent calls

-- ============================================================================
-- 1) Deduplicate historical data (keep oldest wallet per uniqueness scope)
-- ============================================================================

WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at ASC, id ASC) AS rn
  FROM public.wallets
  WHERE wallet_type = 'citypass'
)
DELETE FROM public.wallets w
USING ranked r
WHERE w.id = r.id
  AND r.rn > 1;

WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY user_id, cafe_id ORDER BY created_at ASC, id ASC) AS rn
  FROM public.wallets
  WHERE wallet_type = 'cafe_wallet'
    AND cafe_id IS NOT NULL
)
DELETE FROM public.wallets w
USING ranked r
WHERE w.id = r.id
  AND r.rn > 1;

WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY user_id, network_id ORDER BY created_at ASC, id ASC) AS rn
  FROM public.wallets
  WHERE wallet_type = 'cafe_wallet'
    AND network_id IS NOT NULL
)
DELETE FROM public.wallets w
USING ranked r
WHERE w.id = r.id
  AND r.rn > 1;

-- ============================================================================
-- 2) Unique indexes to prevent future duplicates
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS wallets_one_citypass_per_user_uidx
  ON public.wallets (user_id)
  WHERE wallet_type = 'citypass';

CREATE UNIQUE INDEX IF NOT EXISTS wallets_one_cafe_wallet_per_user_cafe_uidx
  ON public.wallets (user_id, cafe_id)
  WHERE wallet_type = 'cafe_wallet'
    AND cafe_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS wallets_one_cafe_wallet_per_user_network_uidx
  ON public.wallets (user_id, network_id)
  WHERE wallet_type = 'cafe_wallet'
    AND network_id IS NOT NULL;

-- ============================================================================
-- 3) create_citypass_wallet: handle unique race and stay idempotent
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

-- ============================================================================
-- 4) create_cafe_wallet: handle unique race and stay idempotent
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

DO $$
BEGIN
  RAISE NOTICE '✅ Wallet uniqueness guards applied';
END $$;
