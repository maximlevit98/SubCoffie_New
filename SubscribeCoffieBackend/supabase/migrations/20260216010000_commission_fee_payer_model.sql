-- ============================================================================
-- Commission & Bonus Policy Foundation (Fee payer = cafe where applicable)
-- Date: 2026-02-16
-- Purpose:
--   1) Move cafe_wallet top-up fee burden from customer to cafe
--   2) Charge CityPass commission per order transaction (paid by cafe)
--   3) Expose payer metadata in payment_transactions for accounting
-- ============================================================================

-- ============================================================================
-- 1) Extend commission operation types + defaults
-- ============================================================================

ALTER TABLE public.commission_config
  DROP CONSTRAINT IF EXISTS commission_config_operation_type_check;

ALTER TABLE public.commission_config
  ADD CONSTRAINT commission_config_operation_type_check
  CHECK (
    operation_type IN (
      'citypass_topup',
      'cafe_wallet_topup',
      'direct_order',
      'citypass_order_payment'
    )
  );

-- CityPass top-up should no longer reduce customer credited amount.
UPDATE public.commission_config
SET
  commission_percent = 0,
  updated_at = now()
WHERE operation_type = 'citypass_topup';

INSERT INTO public.commission_config (operation_type, commission_percent, active)
VALUES ('citypass_order_payment', 7.00, true)
ON CONFLICT (operation_type) DO NOTHING;

-- ============================================================================
-- 2) Add fee payer metadata to payment transactions
-- ============================================================================

ALTER TABLE public.payment_transactions
  ADD COLUMN IF NOT EXISTS fee_payer text;

UPDATE public.payment_transactions
SET fee_payer = 'customer'
WHERE fee_payer IS NULL;

ALTER TABLE public.payment_transactions
  ALTER COLUMN fee_payer SET DEFAULT 'customer';

ALTER TABLE public.payment_transactions
  ALTER COLUMN fee_payer SET NOT NULL;

ALTER TABLE public.payment_transactions
  DROP CONSTRAINT IF EXISTS payment_transactions_fee_payer_check;

ALTER TABLE public.payment_transactions
  ADD CONSTRAINT payment_transactions_fee_payer_check
  CHECK (fee_payer IN ('customer', 'cafe', 'platform'));

ALTER TABLE public.payment_transactions
  ADD COLUMN IF NOT EXISTS fee_cafe_id uuid REFERENCES public.cafes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS payment_transactions_fee_cafe_id_idx
  ON public.payment_transactions (fee_cafe_id, created_at DESC);

-- Backfill obvious historical fee owner for cafe wallet top-ups
UPDATE public.payment_transactions pt
SET
  fee_payer = 'cafe',
  fee_cafe_id = w.cafe_id
FROM public.wallets w
WHERE pt.wallet_id = w.id
  AND pt.transaction_type = 'topup'
  AND w.wallet_type = 'cafe_wallet'
  AND COALESCE(pt.commission_credits, 0) > 0;

-- ============================================================================
-- 3) Update commission calculation mapping
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_commission(
  p_amount int,
  p_operation_type text,
  p_wallet_type wallet_type DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_commission_percent decimal(5,2);
  v_commission_amount int;
  v_actual_operation_type text;
BEGIN
  IF p_amount IS NULL OR p_amount < 0 THEN
    RAISE EXCEPTION 'Invalid amount: %', p_amount;
  END IF;

  -- Top-up mappings
  IF p_operation_type = 'topup' AND p_wallet_type IS NOT NULL THEN
    IF p_wallet_type = 'citypass' THEN
      v_actual_operation_type := 'citypass_topup';
    ELSIF p_wallet_type = 'cafe_wallet' THEN
      v_actual_operation_type := 'cafe_wallet_topup';
    ELSE
      v_actual_operation_type := p_operation_type;
    END IF;

  -- Order payment mappings
  ELSIF p_operation_type IN ('order_payment', 'wallet_order_payment') AND p_wallet_type IS NOT NULL THEN
    IF p_wallet_type = 'citypass' THEN
      v_actual_operation_type := 'citypass_order_payment';
    ELSE
      v_actual_operation_type := p_operation_type;
    END IF;
  ELSE
    v_actual_operation_type := p_operation_type;
  END IF;

  SELECT commission_percent
  INTO v_commission_percent
  FROM public.commission_config
  WHERE operation_type = v_actual_operation_type
    AND active = true;

  IF v_commission_percent IS NULL THEN
    RAISE EXCEPTION 'Commission rate not found for operation type: %', v_actual_operation_type;
  END IF;

  v_commission_amount := FLOOR(p_amount * v_commission_percent / 100.0);

  RETURN v_commission_amount;
END;
$$;

COMMENT ON FUNCTION public.calculate_commission IS
  'Calculates commission by operation type. CityPass order commission is charged per order transaction.';

-- ============================================================================
-- 4) Commission preview for top-up screens
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_commission_for_wallet(
  p_wallet_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_type wallet_type;
  v_operation_type text;
  v_commission_percent decimal(5,2);
BEGIN
  SELECT wallet_type
  INTO v_wallet_type
  FROM public.wallets
  WHERE id = p_wallet_id;

  IF v_wallet_type IS NULL THEN
    RAISE EXCEPTION 'Wallet not found: %', p_wallet_id;
  END IF;

  IF v_wallet_type = 'citypass' THEN
    -- CityPass top-up itself does not deduct user amount.
    v_operation_type := 'citypass_topup';
  ELSIF v_wallet_type = 'cafe_wallet' THEN
    v_operation_type := 'cafe_wallet_topup';
  ELSE
    RAISE EXCEPTION 'Unknown wallet type: %', v_wallet_type;
  END IF;

  SELECT commission_percent
  INTO v_commission_percent
  FROM public.commission_config
  WHERE operation_type = v_operation_type
    AND active = true;

  IF v_commission_percent IS NULL THEN
    RAISE EXCEPTION 'Commission rate not found for: %', v_operation_type;
  END IF;

  RETURN jsonb_build_object(
    'wallet_id', p_wallet_id,
    'wallet_type', v_wallet_type,
    'operation_type', v_operation_type,
    'commission_percent', v_commission_percent
  );
END;
$$;

COMMENT ON FUNCTION public.get_commission_for_wallet IS
  'Returns commission rate for top-up preview. CityPass top-up rate is expected to be 0 (fee charged later on order transaction).';

-- ============================================================================
-- 5) Update mock_wallet_topup to credit full amount to user wallet
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
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  SELECT user_id, wallet_type, balance_credits, cafe_id
  INTO v_user_id, v_wallet_type, v_balance_before, v_wallet_cafe_id
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
  'Mock wallet top-up credits full amount to user wallet. Cafe wallet top-up commission is charged to cafe, not customer.';

-- ============================================================================
-- 6) Trigger: Apply CityPass order commission when order_payment is linked
-- ============================================================================

CREATE OR REPLACE FUNCTION public.apply_citypass_order_payment_commission()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_type wallet_type;
  v_order_cafe_id uuid;
  v_commission int;
BEGIN
  IF NEW.transaction_type <> 'order_payment' THEN
    RETURN NEW;
  END IF;

  IF NEW.status <> 'completed' THEN
    RETURN NEW;
  END IF;

  IF NEW.wallet_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT wallet_type INTO v_wallet_type
  FROM public.wallets
  WHERE id = NEW.wallet_id;

  IF v_wallet_type IS NULL OR v_wallet_type <> 'citypass' THEN
    RETURN NEW;
  END IF;

  -- We can only attribute commission to specific cafe when order_id is linked.
  IF NEW.order_id IS NULL THEN
    NEW.fee_payer := 'cafe';
    RETURN NEW;
  END IF;

  SELECT cafe_id INTO v_order_cafe_id
  FROM public.orders_core
  WHERE id = NEW.order_id;

  IF v_order_cafe_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.commission_credits, 0) = 0 THEN
    v_commission := public.calculate_commission(
      NEW.amount_credits,
      'order_payment',
      'citypass'::wallet_type
    );
    NEW.commission_credits := v_commission;
  END IF;

  IF COALESCE(NEW.commission_credits, 0) > 0 THEN
    NEW.fee_payer := 'cafe';
    NEW.fee_cafe_id := v_order_cafe_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_citypass_order_payment_commission ON public.payment_transactions;

CREATE TRIGGER trg_apply_citypass_order_payment_commission
BEFORE INSERT OR UPDATE OF order_id, wallet_id, amount_credits, transaction_type, status
ON public.payment_transactions
FOR EACH ROW
EXECUTE FUNCTION public.apply_citypass_order_payment_commission();

COMMENT ON FUNCTION public.apply_citypass_order_payment_commission IS
  'Trigger that assigns CityPass order-payment commission to cafe when order is linked.';

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Commission fee-payer model applied';
  RAISE NOTICE '   - cafe_wallet top-up credits full amount to customer';
  RAISE NOTICE '   - citypass order payment commission is charged to cafe';
  RAISE NOTICE '   - payment_transactions now stores fee_payer and fee_cafe_id';
  RAISE NOTICE '';
END $$;
