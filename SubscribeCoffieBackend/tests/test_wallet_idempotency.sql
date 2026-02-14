-- Test idempotency of mock_wallet_topup
DO $$
DECLARE
  v_user_id uuid;
  v_wallet_id uuid;
  v_result1 jsonb;
  v_result2 jsonb;
  v_idempotency_key text;
  v_balance_before int;
  v_balance_after int;
BEGIN
  -- Get first available user
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found in database';
  END IF;
  
  v_idempotency_key := 'test_' || gen_random_uuid()::text;
  
  SELECT id, balance_credits INTO v_wallet_id, v_balance_before 
  FROM public.wallets 
  WHERE user_id = v_user_id AND wallet_type = 'citypass' LIMIT 1;
  
  IF v_wallet_id IS NULL THEN
    INSERT INTO public.wallets (user_id, wallet_type, balance_credits, lifetime_top_up_credits)
    VALUES (v_user_id, 'citypass', 0, 0)
    RETURNING id, balance_credits INTO v_wallet_id, v_balance_before;
  END IF;
  
  RAISE NOTICE '🔑 Idempotency key: %', v_idempotency_key;
  RAISE NOTICE '💰 Initial balance: %', v_balance_before;
  
  -- First call
  v_result1 := public.mock_wallet_topup(v_wallet_id, 500, null, v_idempotency_key);
  RAISE NOTICE '✅ Call 1: TX %', v_result1->>'transaction_id';
  RAISE NOTICE '   Amount credited: %', v_result1->>'amount_credited';
  
  -- Second call with same key
  v_result2 := public.mock_wallet_topup(v_wallet_id, 500, null, v_idempotency_key);
  RAISE NOTICE '✅ Call 2: TX %', v_result2->>'transaction_id';
  RAISE NOTICE '   Message: %', v_result2->>'message';
  
  -- Verify same transaction ID
  IF (v_result1->>'transaction_id') = (v_result2->>'transaction_id') THEN
    RAISE NOTICE '✅✅ IDEMPOTENCY PASSED: Same TX ID';
  ELSE
    RAISE EXCEPTION '❌ Different TXs: % vs %', 
      v_result1->>'transaction_id', v_result2->>'transaction_id';
  END IF;
  
  -- Check balance credited only once
  SELECT balance_credits INTO v_balance_after FROM public.wallets WHERE id = v_wallet_id;
  RAISE NOTICE '💰 Final balance: %', v_balance_after;
  RAISE NOTICE '   Expected: %', v_balance_before + (v_result1->>'amount_credited')::int;
  
  IF v_balance_after = v_balance_before + (v_result1->>'amount_credited')::int THEN
    RAISE NOTICE '✅✅ BALANCE CHECK PASSED: Credited only once';
  ELSE
    RAISE EXCEPTION '❌ BALANCE MISMATCH: Expected %, Got %', 
      v_balance_before + (v_result1->>'amount_credited')::int,
      v_balance_after;
  END IF;
END $$;
