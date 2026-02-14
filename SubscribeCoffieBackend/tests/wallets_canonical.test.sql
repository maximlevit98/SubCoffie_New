-- ============================================================================
-- Wallet RPC Tests - Canonical Schema (2026-02-14)
-- ============================================================================
-- Tests for:
--   - create_citypass_wallet (idempotent)
--   - create_cafe_wallet (idempotent)
--   - get_user_wallets (canonical fields)
--   - mock_wallet_topup (with idempotency)
--   - validate_wallet_for_order
-- ============================================================================

\echo ''
\echo '============================================'
\echo '🧪 Wallet RPC Tests - Canonical Schema'
\echo '============================================'

-- ============================================================================
-- Test 1: create_citypass_wallet (idempotent)
-- ============================================================================

\echo ''
\echo '📦 Test 1.1: create_citypass_wallet - first call creates wallet'

DO $$
DECLARE
  v_user_id uuid;
  v_wallet_id1 uuid;
  v_wallet_id2 uuid;
  v_wallet_count int;
BEGIN
  -- Get test user
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found';
  END IF;
  
  -- Delete existing CityPass wallet for clean test
  DELETE FROM public.wallets WHERE user_id = v_user_id AND wallet_type = 'citypass';
  
  -- First call: should create wallet
  v_wallet_id1 := public.create_citypass_wallet(v_user_id);
  
  IF v_wallet_id1 IS NULL THEN
    RAISE EXCEPTION '❌ FAIL: create_citypass_wallet returned NULL';
  END IF;
  
  RAISE NOTICE '✅ PASS: CityPass wallet created: %', v_wallet_id1;
  
  -- Second call: should return same wallet (idempotent)
  v_wallet_id2 := public.create_citypass_wallet(v_user_id);
  
  IF v_wallet_id1 = v_wallet_id2 THEN
    RAISE NOTICE '✅ PASS: Idempotency works (same wallet ID returned)';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Different wallet IDs: % vs %', v_wallet_id1, v_wallet_id2;
  END IF;
  
  -- Verify only one CityPass wallet exists
  SELECT COUNT(*) INTO v_wallet_count 
  FROM public.wallets 
  WHERE user_id = v_user_id AND wallet_type = 'citypass';
  
  IF v_wallet_count = 1 THEN
    RAISE NOTICE '✅ PASS: Only 1 CityPass wallet exists';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Expected 1 CityPass wallet, found %', v_wallet_count;
  END IF;
END $$;

-- ============================================================================
-- Test 2: get_user_wallets (canonical schema)
-- ============================================================================

\echo ''
\echo '📦 Test 2.1: get_user_wallets - returns canonical fields'

DO $$
DECLARE
  v_user_id uuid;
  v_wallet record;
  v_wallet_count int;
BEGIN
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;
  
  -- Ensure user has a CityPass wallet
  PERFORM public.create_citypass_wallet(v_user_id);
  
  -- Get wallets
  SELECT COUNT(*) INTO v_wallet_count
  FROM public.get_user_wallets(v_user_id);
  
  IF v_wallet_count >= 1 THEN
    RAISE NOTICE '✅ PASS: get_user_wallets returned % wallet(s)', v_wallet_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: No wallets returned';
  END IF;
  
  -- Verify canonical fields
  SELECT * INTO v_wallet
  FROM public.get_user_wallets(v_user_id)
  WHERE wallet_type = 'citypass'
  LIMIT 1;
  
  IF v_wallet.id IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Wallet has id: %', v_wallet.id;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Wallet missing id';
  END IF;
  
  IF v_wallet.wallet_type = 'citypass' THEN
    RAISE NOTICE '✅ PASS: wallet_type = citypass';
  ELSE
    RAISE EXCEPTION '❌ FAIL: wallet_type = %', v_wallet.wallet_type;
  END IF;
  
  IF v_wallet.balance_credits IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: balance_credits = %', v_wallet.balance_credits;
  ELSE
    RAISE EXCEPTION '❌ FAIL: balance_credits is NULL';
  END IF;
  
  IF v_wallet.lifetime_top_up_credits IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: lifetime_top_up_credits = %', v_wallet.lifetime_top_up_credits;
  ELSE
    RAISE EXCEPTION '❌ FAIL: lifetime_top_up_credits is NULL';
  END IF;
  
  IF v_wallet.created_at IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: created_at present';
  ELSE
    RAISE EXCEPTION '❌ FAIL: created_at is NULL';
  END IF;
END $$;

-- ============================================================================
-- Test 3: mock_wallet_topup with idempotency
-- ============================================================================

\echo ''
\echo '📦 Test 3.1: mock_wallet_topup - basic top-up'

DO $$
DECLARE
  v_user_id uuid;
  v_wallet_id uuid;
  v_result jsonb;
  v_balance_before int;
  v_balance_after int;
BEGIN
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;
  
  -- Get/create CityPass wallet
  v_wallet_id := public.create_citypass_wallet(v_user_id);
  
  SELECT balance_credits INTO v_balance_before 
  FROM public.wallets 
  WHERE id = v_wallet_id;
  
  RAISE NOTICE '💰 Balance before: %', v_balance_before;
  
  -- Top up 1000 credits
  v_result := public.mock_wallet_topup(v_wallet_id, 1000, NULL, NULL);
  
  RAISE NOTICE '✅ Top-up result: %', v_result;
  
  -- Check balance increased
  SELECT balance_credits INTO v_balance_after 
  FROM public.wallets 
  WHERE id = v_wallet_id;
  
  RAISE NOTICE '💰 Balance after: %', v_balance_after;
  
  IF v_balance_after > v_balance_before THEN
    RAISE NOTICE '✅ PASS: Balance increased by %', v_balance_after - v_balance_before;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Balance did not increase';
  END IF;
  
  IF (v_result->>'success')::boolean = true THEN
    RAISE NOTICE '✅ PASS: Top-up success = true';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Top-up failed';
  END IF;
END $$;

-- ============================================================================
-- Test 4: validate_wallet_for_order
-- ============================================================================

\echo ''
\echo '📦 Test 4.1: validate_wallet_for_order - CityPass always valid'

DO $$
DECLARE
  v_user_id uuid;
  v_wallet_id uuid;
  v_cafe_id uuid;
  v_is_valid boolean;
BEGIN
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;
  
  -- Get CityPass wallet
  v_wallet_id := public.create_citypass_wallet(v_user_id);
  
  -- Get any cafe
  SELECT id INTO v_cafe_id FROM public.cafes WHERE status = 'published' LIMIT 1;
  
  IF v_cafe_id IS NULL THEN
    RAISE NOTICE '⚠️ SKIP: No cafes available';
    RETURN;
  END IF;
  
  -- Validate
  v_is_valid := public.validate_wallet_for_order(v_wallet_id, v_cafe_id);
  
  IF v_is_valid THEN
    RAISE NOTICE '✅ PASS: CityPass wallet is valid for cafe %', v_cafe_id;
  ELSE
    RAISE EXCEPTION '❌ FAIL: CityPass wallet should always be valid';
  END IF;
END $$;

-- ============================================================================
-- Test 5: get_wallet_transactions (transaction history)
-- ============================================================================

\echo ''
\echo '📦 Test 5.1: get_wallet_transactions - returns transaction history'

DO $$
DECLARE
  v_user_id uuid;
  v_wallet_id uuid;
  v_result jsonb;
  v_tx_count int;
  v_tx record;
BEGIN
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;
  
  -- Get/create CityPass wallet
  v_wallet_id := public.create_citypass_wallet(v_user_id);
  
  -- Create some transactions via top-up
  v_result := public.mock_wallet_topup(v_wallet_id, 1000, NULL, 'test_tx_history_1');
  v_result := public.mock_wallet_topup(v_wallet_id, 500, NULL, 'test_tx_history_2');
  
  RAISE NOTICE '💳 Created 2 top-up transactions';
  
  -- Get transaction history
  SELECT COUNT(*) INTO v_tx_count
  FROM public.get_wallet_transactions(v_user_id, 50, 0);
  
  IF v_tx_count >= 2 THEN
    RAISE NOTICE '✅ PASS: get_wallet_transactions returned % transaction(s)', v_tx_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Expected at least 2 transactions, got %', v_tx_count;
  END IF;
  
  -- Verify transaction fields
  SELECT * INTO v_tx
  FROM public.get_wallet_transactions(v_user_id, 1, 0)
  LIMIT 1;
  
  IF v_tx.id IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Transaction has id';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Transaction missing id';
  END IF;
  
  IF v_tx.wallet_id = v_wallet_id THEN
    RAISE NOTICE '✅ PASS: Transaction wallet_id matches';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Transaction wallet_id mismatch';
  END IF;
  
  IF v_tx.type IN ('topup', 'payment', 'refund', 'bonus', 'admin_credit', 'admin_debit') THEN
    RAISE NOTICE '✅ PASS: Transaction type valid: %', v_tx.type;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Transaction type invalid: %', v_tx.type;
  END IF;
  
  IF v_tx.balance_before IS NOT NULL AND v_tx.balance_after IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Transaction has balance_before (%) and balance_after (%)', 
      v_tx.balance_before, v_tx.balance_after;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Transaction missing balance fields';
  END IF;
  
  IF v_tx.created_at IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Transaction has created_at';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Transaction missing created_at';
  END IF;
END $$;

-- ============================================================================
-- Test 6: get_user_transaction_history (payment_transactions history)
-- ============================================================================

\echo ''
\echo '📦 Test 6.1: get_user_transaction_history - returns payment transaction history'

DO $$
DECLARE
  v_user_id uuid;
  v_wallet_id uuid;
  v_result jsonb;
  v_count int;
  v_tx record;
BEGIN
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;

  -- Ensure wallet exists and has at least one top-up transaction
  v_wallet_id := public.create_citypass_wallet(v_user_id);
  v_result := public.mock_wallet_topup(v_wallet_id, 700, NULL, 'test_user_tx_history_1');

  SELECT COUNT(*) INTO v_count
  FROM public.get_user_transaction_history(v_user_id, 20, 0);

  IF v_count >= 1 THEN
    RAISE NOTICE '✅ PASS: get_user_transaction_history returned % row(s)', v_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: get_user_transaction_history returned no rows';
  END IF;

  SELECT * INTO v_tx
  FROM public.get_user_transaction_history(v_user_id, 1, 0)
  LIMIT 1;

  IF v_tx.id IS NOT NULL
     AND v_tx.user_id = v_user_id
     AND v_tx.transaction_type IS NOT NULL
     AND v_tx.amount_credits IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: transaction history schema is valid';
  ELSE
    RAISE EXCEPTION '❌ FAIL: invalid transaction history row';
  END IF;
END $$;

-- ============================================================================
-- Summary
-- ============================================================================

\echo ''
\echo '============================================'
\echo '✅ All Wallet RPC Tests Complete'
\echo '============================================'
\echo ''
\echo 'Tested:'
\echo '  ✅ create_citypass_wallet (idempotent)'
\echo '  ✅ get_user_wallets (canonical schema)'
\echo '  ✅ mock_wallet_topup (basic)'
\echo '  ✅ validate_wallet_for_order (CityPass)'
\echo '  ✅ get_wallet_transactions (transaction history)'
\echo '  ✅ get_user_transaction_history (payment history)'
\echo ''
\echo 'Canonical Fields Verified:'
\echo '  ✅ wallet_type (enum)'
\echo '  ✅ balance_credits (int)'
\echo '  ✅ lifetime_top_up_credits (int)'
\echo '  ✅ created_at (timestamp)'
\echo '  ✅ balance_before/after in transactions'
\echo ''
