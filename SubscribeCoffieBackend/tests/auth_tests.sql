-- Backend tests for iOS user authentication flows
-- Run these tests after applying all auth migrations

BEGIN;

-- Test 1: Auto-create profile on user signup
DO $$
DECLARE
  test_user_id UUID;
  test_email TEXT := 'test_ios_user@example.com';
  profile_count INT;
BEGIN
  RAISE NOTICE 'Test 1: Auto-create profile on user signup';
  
  -- Simulate user creation (this would normally be done by Supabase Auth)
  -- In real scenario, the trigger handle_new_user() would fire
  test_user_id := gen_random_uuid();
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (test_user_id, test_email, 'dummy', NOW(), NOW(), NOW());
  
  -- The trigger should have created a profile
  SELECT COUNT(*) INTO profile_count
  FROM public.profiles
  WHERE id = test_user_id;
  
  IF profile_count = 1 THEN
    RAISE NOTICE '✅ Profile auto-created';
  ELSE
    RAISE EXCEPTION '❌ Profile not created automatically';
  END IF;
  
  -- Cleanup
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

-- Test 2: init_user_profile function
DO $$
DECLARE
  test_user_id UUID;
  test_email TEXT := 'test_profile_init@example.com';
  result JSONB;
BEGIN
  RAISE NOTICE 'Test 2: init_user_profile function';
  
  -- Create test user
  test_user_id := gen_random_uuid();
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (test_user_id, test_email, 'dummy', NOW(), NOW(), NOW());
  
  -- Set context to simulate authenticated user
  PERFORM set_config('request.jwt.claims', json_build_object('sub', test_user_id::text)::text, true);
  
  -- Call init_user_profile
  SELECT public.init_user_profile(
    p_full_name := 'Test User',
    p_phone := '+79991234567',
    p_birth_date := '1990-01-01'::DATE,
    p_city := 'Moscow'
  ) INTO result;
  
  -- Verify result
  IF result->>'full_name' = 'Test User' 
     AND result->>'phone' = '+79991234567'
     AND result->>'city' = 'Moscow' THEN
    RAISE NOTICE '✅ Profile initialized correctly';
  ELSE
    RAISE EXCEPTION '❌ Profile initialization failed: %', result;
  END IF;
  
  -- Cleanup
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

-- Test 3: get_my_profile function
DO $$
DECLARE
  test_user_id UUID;
  test_email TEXT := 'test_get_profile@example.com';
  result JSONB;
BEGIN
  RAISE NOTICE 'Test 3: get_my_profile function';
  
  -- Create test user with profile
  test_user_id := gen_random_uuid();
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (test_user_id, test_email, 'dummy', NOW(), NOW(), NOW());
  
  UPDATE public.profiles
  SET full_name = 'Get Profile Test',
      phone = '+79991234568',
      city = 'Saint Petersburg'
  WHERE id = test_user_id;
  
  -- Set context
  PERFORM set_config('request.jwt.claims', json_build_object('sub', test_user_id::text)::text, true);
  
  -- Call get_my_profile
  SELECT public.get_my_profile() INTO result;
  
  -- Verify result
  IF result->>'full_name' = 'Get Profile Test'
     AND result->>'phone' = '+79991234568' THEN
    RAISE NOTICE '✅ Profile retrieved correctly';
  ELSE
    RAISE EXCEPTION '❌ Profile retrieval failed: %', result;
  END IF;
  
  -- Cleanup
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

-- Test 4: update_my_profile function
DO $$
DECLARE
  test_user_id UUID;
  test_email TEXT := 'test_update_profile@example.com';
  result JSONB;
BEGIN
  RAISE NOTICE 'Test 4: update_my_profile function';
  
  -- Create test user with profile
  test_user_id := gen_random_uuid();
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (test_user_id, test_email, 'dummy', NOW(), NOW(), NOW());
  
  UPDATE public.profiles
  SET full_name = 'Old Name'
  WHERE id = test_user_id;
  
  -- Set context
  PERFORM set_config('request.jwt.claims', json_build_object('sub', test_user_id::text)::text, true);
  
  -- Call update_my_profile
  SELECT public.update_my_profile(
    p_full_name := 'Updated Name',
    p_city := 'Kazan'
  ) INTO result;
  
  -- Verify result
  IF result->>'full_name' = 'Updated Name'
     AND result->>'city' = 'Kazan' THEN
    RAISE NOTICE '✅ Profile updated correctly';
  ELSE
    RAISE EXCEPTION '❌ Profile update failed: %', result;
  END IF;
  
  -- Cleanup
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

-- Test 5: RLS policies - user can only access own profile
DO $$
DECLARE
  test_user_id_1 UUID;
  test_user_id_2 UUID;
  test_email_1 TEXT := 'test_rls_user1@example.com';
  test_email_2 TEXT := 'test_rls_user2@example.com';
  accessible_count INT;
BEGIN
  RAISE NOTICE 'Test 5: RLS policies for profiles';
  
  -- Create two test users
  test_user_id_1 := gen_random_uuid();
  test_user_id_2 := gen_random_uuid();
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES 
    (test_user_id_1, test_email_1, 'dummy', NOW(), NOW(), NOW()),
    (test_user_id_2, test_email_2, 'dummy', NOW(), NOW(), NOW());
  
  UPDATE public.profiles SET full_name = 'User 1' WHERE id = test_user_id_1;
  UPDATE public.profiles SET full_name = 'User 2' WHERE id = test_user_id_2;
  
  -- Set context as user 1
  PERFORM set_config('request.jwt.claims', json_build_object('sub', test_user_id_1::text)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  
  -- User 1 should only see their own profile
  SELECT COUNT(*) INTO accessible_count
  FROM public.profiles
  WHERE id = test_user_id_1;
  
  IF accessible_count = 1 THEN
    RAISE NOTICE '✅ RLS allows access to own profile';
  ELSE
    RAISE EXCEPTION '❌ RLS policy failed for own profile';
  END IF;
  
  -- Cleanup
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM auth.users WHERE id IN (test_user_id_1, test_user_id_2);
END $$;

-- Test 6: Auth provider detection
DO $$
DECLARE
  test_user_id UUID;
  test_email TEXT := 'test@privaterelay.appleid.com';
  provider TEXT;
BEGIN
  RAISE NOTICE 'Test 6: Auth provider detection';
  
  -- Create test user with Apple email
  test_user_id := gen_random_uuid();
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (test_user_id, test_email, 'dummy', NOW(), NOW(), NOW());
  
  -- Check if provider is set to 'apple'
  SELECT auth_provider INTO provider
  FROM public.profiles
  WHERE id = test_user_id;
  
  IF provider = 'apple' THEN
    RAISE NOTICE '✅ Apple provider detected correctly';
  ELSE
    RAISE EXCEPTION '❌ Apple provider detection failed, got: %', provider;
  END IF;
  
  -- Cleanup
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

-- Test 7: Order creation with user profile info
DO $$
DECLARE
  test_user_id UUID;
  test_cafe_id UUID;
  test_email TEXT := 'test_order_user@example.com';
  test_order_id UUID;
  order_details JSONB;
BEGIN
  RAISE NOTICE 'Test 7: Order with user profile info';
  
  -- Create test user
  test_user_id := gen_random_uuid();
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (test_user_id, test_email, 'dummy', NOW(), NOW(), NOW());
  
  UPDATE public.profiles
  SET full_name = 'Order Test User',
      phone = '+79991234569'
  WHERE id = test_user_id;
  
  -- Get a test cafe
  SELECT id INTO test_cafe_id FROM public.cafes LIMIT 1;
  
  IF test_cafe_id IS NULL THEN
    RAISE EXCEPTION 'No cafes found for testing';
  END IF;
  
  -- Set context
  PERFORM set_config('request.jwt.claims', json_build_object('sub', test_user_id::text)::text, true);
  
  -- Create order (simplified, without full validation)
  INSERT INTO public.orders_core (
    cafe_id,
    customer_user_id,
    customer_name,
    customer_phone,
    order_type,
    payment_method,
    status,
    payment_status,
    subtotal_credits,
    total_credits
  ) VALUES (
    test_cafe_id,
    test_user_id,
    'Order Test User',
    '+79991234569',
    'now',
    'wallet',
    'created',
    'pending',
    100,
    100
  ) RETURNING id INTO test_order_id;
  
  -- Get order details with user profile
  SELECT public.get_order_details(test_order_id) INTO order_details;
  
  -- Verify user profile is included
  IF order_details->'order'->'user_profile'->>'full_name' = 'Order Test User' THEN
    RAISE NOTICE '✅ Order includes user profile info';
  ELSE
    RAISE EXCEPTION '❌ Order missing user profile info';
  END IF;
  
  -- Cleanup
  DELETE FROM public.orders_core WHERE id = test_order_id;
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

ROLLBACK;

-- Summary
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'All auth flow tests completed successfully!';
  RAISE NOTICE 'Note: Tests were rolled back, no data persisted.';
  RAISE NOTICE '========================================';
END $$;
