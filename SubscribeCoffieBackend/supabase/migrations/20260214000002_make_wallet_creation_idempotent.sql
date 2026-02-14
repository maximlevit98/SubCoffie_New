-- Migration: Make create_citypass_wallet and create_cafe_wallet idempotent
-- Date: 2026-02-14
-- Purpose: Return existing wallet ID instead of throwing error

-- ============================================================================
-- Fix create_citypass_wallet to be idempotent
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_citypass_wallet(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id uuid;
BEGIN
  -- Check if user already has a CityPass wallet
  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE user_id = p_user_id AND wallet_type = 'citypass';

  -- ✅ IDEMPOTENT: Return existing wallet if found
  IF v_wallet_id IS NOT NULL THEN
    RETURN v_wallet_id;
  END IF;

  -- Create CityPass wallet
  INSERT INTO public.wallets (user_id, wallet_type, balance_credits, lifetime_top_up_credits)
  VALUES (p_user_id, 'citypass', 0, 0)
  RETURNING id INTO v_wallet_id;

  RETURN v_wallet_id;
END;
$$;

COMMENT ON FUNCTION public.create_citypass_wallet IS 'Creates or returns existing CityPass wallet (idempotent)';

-- ============================================================================
-- Fix create_cafe_wallet to be idempotent
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_cafe_wallet(
  p_user_id uuid,
  p_cafe_id uuid DEFAULT NULL,
  p_network_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id uuid;
BEGIN
  -- Validate: must provide either cafe_id or network_id
  IF p_cafe_id IS NULL AND p_network_id IS NULL THEN
    RAISE EXCEPTION 'Must provide either cafe_id or network_id';
  END IF;

  IF p_cafe_id IS NOT NULL AND p_network_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot provide both cafe_id and network_id';
  END IF;

  -- Check if user already has a wallet for this cafe/network
  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE user_id = p_user_id
    AND wallet_type = 'cafe_wallet'
    AND (
      (p_cafe_id IS NOT NULL AND cafe_id = p_cafe_id) OR
      (p_network_id IS NOT NULL AND network_id = p_network_id)
    );

  -- ✅ IDEMPOTENT: Return existing wallet if found
  IF v_wallet_id IS NOT NULL THEN
    RETURN v_wallet_id;
  END IF;

  -- Create Cafe Wallet
  INSERT INTO public.wallets (user_id, wallet_type, cafe_id, network_id, balance_credits, lifetime_top_up_credits)
  VALUES (p_user_id, 'cafe_wallet', p_cafe_id, p_network_id, 0, 0)
  RETURNING id INTO v_wallet_id;

  RETURN v_wallet_id;
END;
$$;

COMMENT ON FUNCTION public.create_cafe_wallet IS 'Creates or returns existing Cafe Wallet (idempotent)';

-- ============================================================================
-- Complete
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Wallet creation functions now idempotent';
  RAISE NOTICE '   - create_citypass_wallet: returns existing wallet ID if found';
  RAISE NOTICE '   - create_cafe_wallet: returns existing wallet ID if found';
  RAISE NOTICE '';
END $$;
