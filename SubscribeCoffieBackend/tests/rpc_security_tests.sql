-- ============================================================================
-- RPC SECURITY TESTS
-- Test hardened RPC functions for orders and wallets
-- Run: psql [connection_string] -f tests/rpc_security_tests.sql
-- ============================================================================

\set ECHO all
\set ON_ERROR_STOP on

BEGIN;

-- Setup: Create test users with different roles
DO $$
DECLARE
  v_admin_id uuid;
  v_owner1_id uuid;
  v_owner2_id uuid;
  v_user1_id uuid;
  v_user2_id uuid;
  v_account1_id uuid;
  v_account2_id uuid;
  v_cafe1_id uuid;
  v_cafe2_id uuid;
  v_order1_id uuid;
  v_order2_id uuid;
  v_wallet1_id uuid;
  v_wallet2_id uuid;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 RPC SECURITY TESTS';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
  
  -- Clean up previous test data
  DELETE FROM public.order_items WHERE order_id IN (
    SELECT id FROM public.orders_core WHERE customer_phone LIKE '+7900%'
  );
  DELETE FROM public.orders_core WHERE customer_phone LIKE '+7900%';
  DELETE FROM public.wallet_transactions WHERE wallet_id IN (
    SELECT id FROM public.wallets WHERE user_id IN (
      SELECT id FROM auth.users WHERE email LIKE '%rpc_test%'
    )
  );
  DELETE FROM public.wallets WHERE user_id IN (
    SELECT id FROM auth.users WHERE email LIKE '%rpc_test%'
  );
  DELETE FROM public.cafes WHERE name LIKE '%RPC Test%';
  DELETE FROM public.accounts WHERE owner_user_id IN (
    SELECT id FROM auth.users WHERE email LIKE '%rpc_test%'
  );
  DELETE FROM public.profiles WHERE id IN (
    SELECT id FROM auth.users WHERE email LIKE '%rpc_test%'
  );
  DELETE FROM auth.users WHERE email LIKE '%rpc_test%';
  
  RAISE NOTICE '📋 Setting up test data...';
  RAISE NOTICE '';
  
  -- Create test users (one at a time to capture IDs)
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role)
  VALUES (gen_random_uuid(), 'admin_rpc_test@test.com', crypt('test123', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated')
  RETURNING id INTO v_admin_id;
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role)
  VALUES (gen_random_uuid(), 'owner1_rpc_test@test.com', crypt('test123', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated')
  RETURNING id INTO v_owner1_id;
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role)
  VALUES (gen_random_uuid(), 'owner2_rpc_test@test.com', crypt('test123', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated')
  RETURNING id INTO v_owner2_id;
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role)
  VALUES (gen_random_uuid(), 'user1_rpc_test@test.com', crypt('test123', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated')
  RETURNING id INTO v_user1_id;
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, aud, role)
  VALUES (gen_random_uuid(), 'user2_rpc_test@test.com', crypt('test123', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated')
  RETURNING id INTO v_user2_id;
  
  -- Update profiles with roles (profiles auto-created by trigger on auth.users insert)
  UPDATE public.profiles SET role = 'admin', full_name = 'Test Admin' WHERE id = v_admin_id;
  UPDATE public.profiles SET role = 'owner', full_name = 'Test Owner 1' WHERE id = v_owner1_id;
  UPDATE public.profiles SET role = 'owner', full_name = 'Test Owner 2' WHERE id = v_owner2_id;
  UPDATE public.profiles SET role = 'user', full_name = 'Test User 1' WHERE id = v_user1_id;
  UPDATE public.profiles SET role = 'user', full_name = 'Test User 2' WHERE id = v_user2_id;
  
  -- Create accounts for owners
  INSERT INTO public.accounts (id, owner_user_id, company_name) VALUES
    (gen_random_uuid(), v_owner1_id, 'Owner 1 Company')
  RETURNING id INTO v_account1_id;
  
  INSERT INTO public.accounts (id, owner_user_id, company_name) VALUES
    (gen_random_uuid(), v_owner2_id, 'Owner 2 Company')
  RETURNING id INTO v_account2_id;
  
  -- Create cafes
  INSERT INTO public.cafes (id, account_id, name, address, mode, status) VALUES
    (gen_random_uuid(), v_account1_id, 'RPC Test Cafe 1', 'Address 1', 'open', 'published')
  RETURNING id INTO v_cafe1_id;
  
  INSERT INTO public.cafes (id, account_id, name, address, mode, status) VALUES
    (gen_random_uuid(), v_account2_id, 'RPC Test Cafe 2', 'Address 2', 'open', 'published')
  RETURNING id INTO v_cafe2_id;
  
  -- Create test orders
  INSERT INTO public.orders_core (id, cafe_id, user_id, customer_phone, status, subtotal_credits, total_credits) VALUES
    (gen_random_uuid(), v_cafe1_id, v_user1_id, '+79001111111', 'created', 500, 500)
  RETURNING id INTO v_order1_id;
  
  INSERT INTO public.orders_core (id, cafe_id, user_id, customer_phone, status, subtotal_credits, total_credits) VALUES
    (gen_random_uuid(), v_cafe2_id, v_user2_id, '+79002222222', 'created', 600, 600)
  RETURNING id INTO v_order2_id;
  
  -- Create wallets
  INSERT INTO public.wallets (id, user_id, type, wallet_type, credits_balance, bonus_balance) VALUES
    (gen_random_uuid(), v_user1_id, 'citypass', 'citypass', 1000, 100)
  RETURNING id INTO v_wallet1_id;
  
  INSERT INTO public.wallets (id, user_id, type, wallet_type, credits_balance, bonus_balance) VALUES
    (gen_random_uuid(), v_user2_id, 'citypass', 'citypass', 2000, 200)
  RETURNING id INTO v_wallet2_id;
  
  RAISE NOTICE '✅ Test data created';
  RAISE NOTICE '   Admin: %', v_admin_id;
  RAISE NOTICE '   Owner1: % (Cafe: %)', v_owner1_id, v_cafe1_id;
  RAISE NOTICE '   Owner2: % (Cafe: %)', v_owner2_id, v_cafe2_id;
  RAISE NOTICE '   User1: % (Order: %, Wallet: %)', v_user1_id, v_order1_id, v_wallet1_id;
  RAISE NOTICE '   User2: % (Order: %, Wallet: %)', v_user2_id, v_order2_id, v_wallet2_id;
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 1: Order Status Update - Unauthorized User (SHOULD FAIL)
-- ============================================================================
DO $$
DECLARE
  v_user1_id uuid;
  v_order1_id uuid;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 1: Order Status Update - Unauthorized User';
  
  SELECT id INTO v_user1_id FROM auth.users WHERE email = 'user1_rpc_test@test.com';
  SELECT id INTO v_order1_id FROM public.orders_core WHERE customer_phone = '+79001111111';
  
  -- Set session to user1 (not admin/owner)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);
  
  BEGIN
    v_result := update_order_status(v_order1_id, 'ready', v_user1_id);
    RAISE EXCEPTION '❌ TEST FAILED: User was able to update order status (should be denied)';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Admin or Owner role required%' THEN
        RAISE NOTICE '   ✅ PASS: User correctly denied (%)' , SQLERRM;
      ELSE
        RAISE EXCEPTION '❌ TEST FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 2: Order Status Update - Owner of Different Cafe (SHOULD FAIL)
-- ============================================================================
DO $$
DECLARE
  v_owner2_id uuid;
  v_order1_id uuid;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 2: Order Status Update - Owner of Different Cafe';
  
  SELECT id INTO v_owner2_id FROM auth.users WHERE email = 'owner2_rpc_test@test.com';
  SELECT id INTO v_order1_id FROM public.orders_core WHERE customer_phone = '+79001111111';
  
  -- Set session to owner2 (owns cafe2, but order is from cafe1)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner2_id)::text, true);
  
  BEGIN
    v_result := update_order_status(v_order1_id, 'ready', v_owner2_id);
    RAISE EXCEPTION '❌ TEST FAILED: Owner was able to update order from different cafe';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%You do not own this cafe%' THEN
        RAISE NOTICE '   ✅ PASS: Owner correctly denied (%)' , SQLERRM;
      ELSE
        RAISE EXCEPTION '❌ TEST FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 3: Order Status Update - Correct Owner (SHOULD SUCCEED)
-- ============================================================================
DO $$
DECLARE
  v_owner1_id uuid;
  v_order1_id uuid;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 3: Order Status Update - Correct Owner';
  
  SELECT id INTO v_owner1_id FROM auth.users WHERE email = 'owner1_rpc_test@test.com';
  SELECT id INTO v_order1_id FROM public.orders_core WHERE customer_phone = '+79001111111';
  
  -- Set session to owner1 (owns cafe1)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner1_id)::text, true);
  
  v_result := update_order_status(v_order1_id, 'ready', v_owner1_id);
  
  IF v_result->>'status' = 'ready' THEN
    RAISE NOTICE '   ✅ PASS: Owner successfully updated order status';
  ELSE
    RAISE EXCEPTION '❌ TEST FAILED: Status not updated correctly';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 4: Get Orders by Cafe - Owner Can Only See Own Cafe (SHOULD SUCCEED)
-- ============================================================================
DO $$
DECLARE
  v_owner1_id uuid;
  v_cafe2_id uuid;
  v_count int;
BEGIN
  RAISE NOTICE '🧪 TEST 4: Get Orders by Cafe - Owner Isolation';
  
  SELECT id INTO v_owner1_id FROM auth.users WHERE email = 'owner1_rpc_test@test.com';
  SELECT id INTO v_cafe2_id FROM public.cafes WHERE name = 'RPC Test Cafe 2';
  
  -- Set session to owner1
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner1_id)::text, true);
  
  BEGIN
    SELECT COUNT(o.id) INTO v_count FROM get_orders_by_cafe(v_cafe2_id) o;
    RAISE EXCEPTION '❌ TEST FAILED: Owner was able to view orders from different cafe';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%You do not own this cafe%' THEN
        RAISE NOTICE '   ✅ PASS: Owner correctly denied access to other cafe';
      ELSE
        RAISE EXCEPTION '❌ TEST FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 5: Get Wallet - User Cannot Access Other User's Wallet (SHOULD FAIL)
-- ============================================================================
DO $$
DECLARE
  v_user1_id uuid;
  v_user2_id uuid;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 5: Get Wallet - User Isolation';
  
  SELECT id INTO v_user1_id FROM auth.users WHERE email = 'user1_rpc_test@test.com';
  SELECT id INTO v_user2_id FROM auth.users WHERE email = 'user2_rpc_test@test.com';
  
  -- Set session to user1
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);
  
  BEGIN
    v_result := get_user_wallet(v_user2_id);
    RAISE EXCEPTION '❌ TEST FAILED: User was able to access other user wallet';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Cannot access other users wallets%' THEN
        RAISE NOTICE '   ✅ PASS: User correctly denied access to other wallet';
      ELSE
        RAISE EXCEPTION '❌ TEST FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 6: Add Wallet Transaction - User Cannot Modify Other User's Wallet (SHOULD FAIL)
-- ============================================================================
DO $$
DECLARE
  v_user1_id uuid;
  v_user2_id uuid;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 6: Add Wallet Transaction - User Isolation';
  
  SELECT id INTO v_user1_id FROM auth.users WHERE email = 'user1_rpc_test@test.com';
  SELECT id INTO v_user2_id FROM auth.users WHERE email = 'user2_rpc_test@test.com';
  
  -- Set session to user1
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);
  
  BEGIN
    v_result := add_wallet_transaction(v_user2_id, 1000, 'topup', 'Unauthorized topup', null, v_user1_id);
    RAISE EXCEPTION '❌ TEST FAILED: User was able to modify other user wallet';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Cannot modify other users wallets%' THEN
        RAISE NOTICE '   ✅ PASS: User correctly denied wallet modification';
      ELSE
        RAISE EXCEPTION '❌ TEST FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 7: Admin Can Access All Resources (SHOULD SUCCEED)
-- ============================================================================
DO $$
DECLARE
  v_admin_id uuid;
  v_order1_id uuid;
  v_user2_id uuid;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 7: Admin Full Access';
  
  SELECT id INTO v_admin_id FROM auth.users WHERE email = 'admin_rpc_test@test.com';
  SELECT id INTO v_order1_id FROM public.orders_core WHERE customer_phone = '+79001111111';
  SELECT id INTO v_user2_id FROM auth.users WHERE email = 'user2_rpc_test@test.com';
  
  -- Set session to admin
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin_id)::text, true);
  
  -- Admin can update any order
  v_result := update_order_status(v_order1_id, 'ready', v_admin_id);
  IF v_result->>'status' = 'ready' THEN
    RAISE NOTICE '   ✅ PASS: Admin can update orders';
  ELSE
    RAISE EXCEPTION '❌ TEST FAILED: Admin cannot update orders';
  END IF;
  
  -- Admin can access any wallet
  v_result := get_user_wallet(v_user2_id);
  IF v_result->>'user_id' = v_user2_id::text THEN
    RAISE NOTICE '   ✅ PASS: Admin can access wallets';
  ELSE
    RAISE EXCEPTION '❌ TEST FAILED: Admin cannot access wallets';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST 8: Wallet Balance Validation (SHOULD FAIL for insufficient balance)
-- ============================================================================
DO $$
DECLARE
  v_user1_id uuid;
  v_wallet1_balance int;
  v_result jsonb;
BEGIN
  RAISE NOTICE '🧪 TEST 8: Wallet Balance Validation';
  
  SELECT id INTO v_user1_id FROM auth.users WHERE email = 'user1_rpc_test@test.com';
  SELECT credits_balance INTO v_wallet1_balance FROM public.wallets WHERE user_id = v_user1_id;
  
  -- Set session to user1
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);
  
  BEGIN
    -- Try to pay more than balance
    v_result := add_wallet_transaction(v_user1_id, v_wallet1_balance + 1000, 'payment', 'Overpayment', null, v_user1_id);
    RAISE EXCEPTION '❌ TEST FAILED: Payment allowed despite insufficient balance';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Insufficient balance%' THEN
        RAISE NOTICE '   ✅ PASS: Insufficient balance correctly detected';
      ELSE
        RAISE EXCEPTION '❌ TEST FAILED: Wrong error: %', SQLERRM;
      END IF;
  END;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '✅ ALL RPC SECURITY TESTS PASSED';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
  RAISE NOTICE 'Summary:';
  RAISE NOTICE '  ✅ Order status updates: Role-based access enforced';
  RAISE NOTICE '  ✅ Order viewing: Owner isolation enforced';
  RAISE NOTICE '  ✅ Wallet access: User isolation enforced';
  RAISE NOTICE '  ✅ Wallet transactions: User isolation enforced';
  RAISE NOTICE '  ✅ Admin access: Full access confirmed';
  RAISE NOTICE '  ✅ Balance validation: Overdraft prevented';
  RAISE NOTICE '';
END $$;

ROLLBACK;
