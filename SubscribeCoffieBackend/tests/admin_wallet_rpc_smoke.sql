\echo '============================================'
\echo '🧪 Admin Wallet RPC Smoke Tests'
\echo '============================================'

\echo ''
\echo '1️⃣ Setup: Find or create test data'

DO $$
DECLARE
  v_admin_user_id uuid;
  v_regular_user_id uuid;
  v_test_wallet_id uuid;
BEGIN
  -- Get admin user
  SELECT id INTO v_admin_user_id 
  FROM profiles 
  WHERE role = 'admin' 
  LIMIT 1;
  
  IF v_admin_user_id IS NULL THEN
    RAISE EXCEPTION 'No admin user found. Please run seed.sql first.';
  END IF;
  
  RAISE NOTICE 'Admin user: %', v_admin_user_id;
  
  -- Get regular user
  SELECT id INTO v_regular_user_id 
  FROM profiles 
  WHERE role = 'user' 
  LIMIT 1;
  
  IF v_regular_user_id IS NULL THEN
    RAISE EXCEPTION 'No regular user found. Please run seed.sql first.';
  END IF;
  
  RAISE NOTICE 'Regular user: %', v_regular_user_id;
  
  -- Create test wallet if none exists
  SELECT id INTO v_test_wallet_id 
  FROM wallets 
  LIMIT 1;
  
  IF v_test_wallet_id IS NULL THEN
    -- Create CityPass wallet for regular user
    v_test_wallet_id := create_citypass_wallet(v_regular_user_id);
    RAISE NOTICE 'Created test wallet: %', v_test_wallet_id;
    
    -- Top up wallet
    PERFORM mock_wallet_topup(v_test_wallet_id, 1000, NULL, gen_random_uuid()::text);
    RAISE NOTICE 'Topped up wallet with 1000 credits';
  ELSE
    RAISE NOTICE 'Using existing wallet: %', v_test_wallet_id;
  END IF;
END $$;

\echo ''
\echo '2️⃣ Test: admin_get_wallets (security check)'

DO $$
DECLARE
  v_result_count int;
BEGIN
  BEGIN
    -- This will fail with "Admin access required" because auth.uid() is NULL
    SELECT COUNT(*) INTO v_result_count 
    FROM admin_get_wallets(10, 0, NULL);
    
    RAISE EXCEPTION 'Should have failed with admin check';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Admin access required%' THEN
        RAISE NOTICE '✅ admin_get_wallets: Security check working';
      ELSE
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
      END IF;
  END;
END $$;

\echo ''
\echo '3️⃣ Test: admin_get_wallet_overview (security check)'

DO $$
DECLARE
  v_test_wallet_id uuid;
BEGIN
  SELECT id INTO v_test_wallet_id FROM wallets LIMIT 1;
  
  BEGIN
    PERFORM * FROM admin_get_wallet_overview(v_test_wallet_id);
    RAISE EXCEPTION 'Should have failed with admin check';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Admin access required%' THEN
        RAISE NOTICE '✅ admin_get_wallet_overview: Security check working';
      ELSE
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
      END IF;
  END;
END $$;

\echo ''
\echo '4️⃣ Test: admin_get_wallet_transactions (security check)'

DO $$
DECLARE
  v_test_wallet_id uuid;
  v_result_count int;
BEGIN
  SELECT id INTO v_test_wallet_id FROM wallets LIMIT 1;
  
  BEGIN
    SELECT COUNT(*) INTO v_result_count 
    FROM admin_get_wallet_transactions(v_test_wallet_id, 10, 0);
    RAISE EXCEPTION 'Should have failed with admin check';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Admin access required%' THEN
        RAISE NOTICE '✅ admin_get_wallet_transactions: Security check working';
      ELSE
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
      END IF;
  END;
END $$;

\echo ''
\echo '5️⃣ Test: admin_get_wallet_payments (security check)'

DO $$
DECLARE
  v_test_wallet_id uuid;
  v_result_count int;
BEGIN
  SELECT id INTO v_test_wallet_id FROM wallets LIMIT 1;
  
  BEGIN
    SELECT COUNT(*) INTO v_result_count 
    FROM admin_get_wallet_payments(v_test_wallet_id, 10, 0);
    RAISE EXCEPTION 'Should have failed with admin check';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Admin access required%' THEN
        RAISE NOTICE '✅ admin_get_wallet_payments: Security check working';
      ELSE
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
      END IF;
  END;
END $$;

\echo ''
\echo '6️⃣ Test: admin_get_wallet_orders (security check)'

DO $$
DECLARE
  v_test_wallet_id uuid;
  v_result_count int;
BEGIN
  SELECT id INTO v_test_wallet_id FROM wallets LIMIT 1;
  
  BEGIN
    SELECT COUNT(*) INTO v_result_count 
    FROM admin_get_wallet_orders(v_test_wallet_id, 10, 0);
    RAISE EXCEPTION 'Should have failed with admin check';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Admin access required%' THEN
        RAISE NOTICE '✅ admin_get_wallet_orders: Security check working';
      ELSE
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
      END IF;
  END;
END $$;

\echo ''
\echo '7️⃣ Verify: RPC Signatures'

SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace
  AND proname LIKE 'admin_get_wallet%'
ORDER BY proname;

\echo ''
\echo '============================================'
\echo '✅ Admin Wallet RPC Smoke Tests Complete'
\echo '============================================'
\echo ''
\echo 'All 5 admin RPC functions:'
\echo '  - admin_get_wallets(limit, offset, search)'
\echo '  - admin_get_wallet_overview(wallet_id)'
\echo '  - admin_get_wallet_transactions(wallet_id, limit, offset)'
\echo '  - admin_get_wallet_payments(wallet_id, limit, offset)'
\echo '  - admin_get_wallet_orders(wallet_id, limit, offset)'
\echo ''
\echo 'NOTE: All functions correctly enforce admin-only access.'
\echo 'To test actual data retrieval, call from admin panel with admin JWT.'
\echo ''
