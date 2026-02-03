-- ⚠️ ⚠️ ⚠️ DEV-ONLY: MOCK PAYMENT FUNCTIONS ⚠️ ⚠️ ⚠️
--
-- This file contains MOCK payment functions for development/testing ONLY
-- DO NOT run in production environment
--
-- These functions simulate instant payment processing without real money
-- Required for: local development, demos, testing
-- 
-- Deployment: Applied automatically by supabase/seed.sql in local/dev
-- Production: MUST BE EXCLUDED from production migrations
--
-- ⚠️ ⚠️ ⚠️ END WARNING ⚠️ ⚠️ ⚠️

-- ============================================================================
-- Mock Payment Functions (DEV/TEST ONLY)
-- ============================================================================

-- Function: mock_wallet_topup (simulates payment)
-- Used in: Development, demos, testing
-- Production alternative: create_payment_intent() in real_payment_integration.sql
CREATE OR REPLACE FUNCTION public.mock_wallet_topup(
  p_wallet_id uuid,
  p_amount int,
  p_payment_method_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_wallet_type wallet_type;
  v_commission int;
  v_amount_credited int;
  v_transaction_id uuid;
  v_mock_provider_id text;
BEGIN
  -- Get wallet info
  SELECT user_id, wallet_type INTO v_user_id, v_wallet_type
  FROM public.wallets
  WHERE id = p_wallet_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;

  -- Calculate commission
  v_commission := public.calculate_commission(p_amount, 'topup', v_wallet_type);
  v_amount_credited := p_amount - v_commission;

  -- Generate mock provider transaction ID
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  -- Create transaction record
  INSERT INTO public.payment_transactions (
    user_id, wallet_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, provider_transaction_id, completed_at
  )
  VALUES (
    v_user_id, p_wallet_id, p_amount, v_commission,
    'topup', p_payment_method_id, 'completed', v_mock_provider_id, NOW()
  )
  RETURNING id INTO v_transaction_id;

  -- Update wallet balance
  UPDATE public.wallets
  SET
    balance_credits = balance_credits + v_amount_credited,
    lifetime_top_up_credits = lifetime_top_up_credits + v_amount_credited,
    updated_at = NOW()
  WHERE id = p_wallet_id;

  -- Return result
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'commission', v_commission,
    'amount_credited', v_amount_credited,
    'provider_transaction_id', v_mock_provider_id,
    'provider', 'mock',
    'mock_mode', true
  );
END;
$$;

COMMENT ON FUNCTION public.mock_wallet_topup IS '🚨 DEV-ONLY: Mock simulation of wallet top-up payment (instant, no real money)';

-- Function: mock_direct_order_payment (simulates direct payment without wallet)
-- Used in: Development, demos, testing
-- Production alternative: Use real payment provider integration
CREATE OR REPLACE FUNCTION public.mock_direct_order_payment(
  p_order_id uuid,
  p_amount int,
  p_payment_method_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_commission int;
  v_transaction_id uuid;
  v_mock_provider_id text;
BEGIN
  -- Get order user_id
  SELECT user_id INTO v_user_id
  FROM public.orders_core
  WHERE id = p_order_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Calculate commission for direct order
  v_commission := public.calculate_commission(p_amount, 'direct_order');

  -- Generate mock provider transaction ID
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  -- Create transaction record
  INSERT INTO public.payment_transactions (
    user_id, order_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, provider_transaction_id, completed_at
  )
  VALUES (
    v_user_id, p_order_id, p_amount, v_commission,
    'order_payment', p_payment_method_id, 'completed', v_mock_provider_id, NOW()
  )
  RETURNING id INTO v_transaction_id;

  -- Update order status to paid
  UPDATE public.orders_core
  SET payment_status = 'paid', updated_at = NOW()
  WHERE id = p_order_id;

  -- Return result
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'commission', v_commission,
    'provider_transaction_id', v_mock_provider_id,
    'provider', 'mock',
    'mock_mode', true
  );
END;
$$;

COMMENT ON FUNCTION public.mock_direct_order_payment IS '🚨 DEV-ONLY: Mock simulation of direct order payment without wallet (instant, no real money)';

-- Function: create_mock_payment_method (creates mock card for testing)
-- Used in: Development, demos, testing
CREATE OR REPLACE FUNCTION public.create_mock_payment_method(
  p_user_id uuid,
  p_card_last4 text DEFAULT '4242',
  p_card_brand text DEFAULT 'visa'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment_method_id uuid;
BEGIN
  -- Validate card_last4
  IF LENGTH(p_card_last4) != 4 THEN
    RAISE EXCEPTION 'card_last4 must be exactly 4 characters';
  END IF;

  -- Create mock payment method
  -- Note: In production migration, payment_provider check constraint doesn't allow 'mock'
  -- So we insert with a valid provider but mark it as test
  INSERT INTO public.payment_methods (
    user_id,
    card_last4,
    card_brand,
    is_default,
    payment_provider,
    provider_token,
    provider_payment_method_id
  )
  VALUES (
    p_user_id,
    p_card_last4,
    p_card_brand,
    false,
    'stripe', -- Use valid provider
    'mock_token_' || gen_random_uuid()::text, -- Mock token
    'pm_mock_' || gen_random_uuid()::text -- Mock payment method ID
  )
  RETURNING id INTO v_payment_method_id;

  RETURN v_payment_method_id;
END;
$$;

COMMENT ON FUNCTION public.create_mock_payment_method IS '🚨 DEV-ONLY: Creates a mock payment method for testing';

-- ============================================================================
-- Grant permissions (DEV ONLY)
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.mock_wallet_topup(uuid, int, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.mock_direct_order_payment(uuid, int, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.create_mock_payment_method(uuid, text, text) TO authenticated, anon;

-- ============================================================================
-- Audit log
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '🚨 DEV-ONLY: Mock payment functions created';
  RAISE NOTICE '⚠️  These functions provide instant credits WITHOUT real money';
  RAISE NOTICE '⚠️  DO NOT use in production environment';
  RAISE NOTICE '✅ Safe for: local development, demos, testing';
END $$;
