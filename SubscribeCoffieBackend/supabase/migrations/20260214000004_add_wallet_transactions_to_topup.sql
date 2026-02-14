-- Migration: Add wallet_transactions audit trail to mock_wallet_topup
-- Date: 2026-02-14
-- Purpose: Ensure mock_wallet_topup creates audit record in wallet_transactions for transaction history

-- ============================================================================
-- Update mock_wallet_topup to create wallet_transactions record
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
BEGIN
  -- ✅ Check idempotency first
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status, amount_credits, commission_credits, provider_transaction_id
    INTO v_existing_transaction
    FROM public.payment_transactions
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;
    
    IF v_existing_transaction.id IS NOT NULL THEN
      -- Transaction already exists with this idempotency key
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

  -- Get wallet info and current balance
  SELECT user_id, wallet_type, balance_credits 
  INTO v_user_id, v_wallet_type, v_balance_before
  FROM public.wallets
  WHERE id = p_wallet_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;

  -- Calculate commission
  v_commission := public.calculate_commission(p_amount, 'topup', v_wallet_type);
  v_amount_credited := p_amount - v_commission;
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  -- Insert payment transaction
  INSERT INTO public.payment_transactions (
    user_id, wallet_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, 
    provider_transaction_id, completed_at,
    idempotency_key
  )
  VALUES (
    v_user_id, p_wallet_id, p_amount, v_commission,
    'topup', p_payment_method_id, 'completed', 
    v_mock_provider_id, now(),
    p_idempotency_key
  )
  RETURNING id INTO v_transaction_id;

  -- Update wallet balance
  UPDATE public.wallets
  SET
    balance_credits = balance_credits + v_amount_credited,
    lifetime_top_up_credits = lifetime_top_up_credits + v_amount_credited,
    updated_at = now()
  WHERE id = p_wallet_id
  RETURNING balance_credits INTO v_balance_after;

  -- ✅ NEW: Create wallet_transactions audit record
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
    v_amount_credited,  -- Amount actually credited (after commission)
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
  'Mock wallet top-up with idempotency support and wallet_transactions audit trail';

-- ============================================================================
-- Complete
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ mock_wallet_topup updated with wallet_transactions audit trail';
  RAISE NOTICE '   - Creates record in wallet_transactions for transaction history';
  RAISE NOTICE '   - Includes balance_before and balance_after';
  RAISE NOTICE '';
END $$;
