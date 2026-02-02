-- Test suite for cafe onboarding system
-- Run this after applying the migration 20260202000000_cafe_onboarding.sql

-- Setup test environment
begin;

-- Create test users
insert into auth.users (id, email)
values 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'test_applicant@example.com'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'test_admin@example.com')
on conflict (id) do nothing;

insert into public.profiles (id, email, role)
values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'test_applicant@example.com', 'user'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'test_admin@example.com', 'admin')
on conflict (id) do update set role = excluded.role;

-- Test 1: Submit cafe application
do $$
declare
  v_request_id uuid;
begin
  -- Set session to test user
  perform set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);
  
  -- Submit application
  select public.submit_cafe_application(
    p_cafe_name := 'Test Coffee Shop',
    p_cafe_address := '123 Test Street, Test City',
    p_cafe_phone := '+1234567890',
    p_cafe_email := 'test@coffeeshop.com',
    p_cafe_description := 'A cozy coffee shop with great atmosphere',
    p_business_type := 'independent',
    p_opening_hours := '8:00-20:00',
    p_estimated_daily_orders := 50
  ) into v_request_id;
  
  if v_request_id is null then
    raise exception 'Test 1 FAILED: submit_cafe_application returned null';
  end if;
  
  -- Verify the request was created
  if not exists (
    select 1 from public.cafe_onboarding_requests 
    where id = v_request_id 
      and cafe_name = 'Test Coffee Shop'
      and status = 'pending'
  ) then
    raise exception 'Test 1 FAILED: Request not found or incorrect data';
  end if;
  
  raise notice 'Test 1 PASSED: submit_cafe_application created request %', v_request_id;
end$$;

-- Test 2: Get my onboarding requests
do $$
declare
  v_count int;
begin
  -- Set session to test user
  perform set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);
  
  -- Get requests
  select count(*) into v_count
  from public.get_my_onboarding_requests();
  
  if v_count = 0 then
    raise exception 'Test 2 FAILED: get_my_onboarding_requests returned no results';
  end if;
  
  raise notice 'Test 2 PASSED: get_my_onboarding_requests returned % requests', v_count;
end$$;

-- Test 3: Approve cafe application (as admin)
do $$
declare
  v_request_id uuid;
  v_cafe_id uuid;
  v_user_role text;
begin
  -- Get the pending request
  select id into v_request_id
  from public.cafe_onboarding_requests
  where applicant_user_id = '11111111-1111-1111-1111-111111111111'::uuid
    and status = 'pending'
  limit 1;
  
  if v_request_id is null then
    raise exception 'Test 3 FAILED: No pending request found';
  end if;
  
  -- Set session to admin
  perform set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text, true);
  
  -- Approve the cafe
  select public.approve_cafe(
    p_request_id := v_request_id,
    p_review_comment := 'Looks good! Welcome to the platform.'
  ) into v_cafe_id;
  
  if v_cafe_id is null then
    raise exception 'Test 3 FAILED: approve_cafe returned null cafe_id';
  end if;
  
  -- Verify cafe was created
  if not exists (select 1 from public.cafes where id = v_cafe_id) then
    raise exception 'Test 3 FAILED: Cafe was not created';
  end if;
  
  -- Verify request status was updated
  if not exists (
    select 1 from public.cafe_onboarding_requests
    where id = v_request_id
      and status = 'approved'
      and created_cafe_id = v_cafe_id
  ) then
    raise exception 'Test 3 FAILED: Request status not updated correctly';
  end if;
  
  -- Verify applicant role was updated to owner
  select role into v_user_role
  from public.profiles
  where id = '11111111-1111-1111-1111-111111111111'::uuid;
  
  if v_user_role != 'owner' then
    raise exception 'Test 3 FAILED: User role not updated to owner (got: %)', v_user_role;
  end if;
  
  raise notice 'Test 3 PASSED: approve_cafe created cafe % and updated user role', v_cafe_id;
end$$;

-- Test 4: Reject cafe application
do $$
declare
  v_request_id uuid;
begin
  -- Set session to test user
  perform set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);
  
  -- Submit another application
  select public.submit_cafe_application(
    p_cafe_name := 'Another Coffee Shop',
    p_cafe_address := '456 Another Street',
    p_cafe_phone := '+9876543210',
    p_cafe_email := 'another@coffeeshop.com'
  ) into v_request_id;
  
  -- Set session to admin
  perform set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text, true);
  
  -- Reject the cafe
  perform public.reject_cafe(
    p_request_id := v_request_id,
    p_rejection_reason := 'Incomplete information provided'
  );
  
  -- Verify request was rejected
  if not exists (
    select 1 from public.cafe_onboarding_requests
    where id = v_request_id
      and status = 'rejected'
      and rejection_reason is not null
  ) then
    raise exception 'Test 4 FAILED: Request was not rejected correctly';
  end if;
  
  raise notice 'Test 4 PASSED: reject_cafe updated request status';
end$$;

-- Test 5: Cancel own request
do $$
declare
  v_request_id uuid;
begin
  -- Set session to test user
  perform set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);
  
  -- Submit another application
  select public.submit_cafe_application(
    p_cafe_name := 'Third Coffee Shop',
    p_cafe_address := '789 Third Street',
    p_cafe_phone := '+1122334455',
    p_cafe_email := 'third@coffeeshop.com'
  ) into v_request_id;
  
  -- Cancel it
  perform public.cancel_onboarding_request(p_request_id := v_request_id);
  
  -- Verify request was cancelled
  if not exists (
    select 1 from public.cafe_onboarding_requests
    where id = v_request_id
      and status = 'cancelled'
  ) then
    raise exception 'Test 5 FAILED: Request was not cancelled';
  end if;
  
  raise notice 'Test 5 PASSED: cancel_onboarding_request updated status';
end$$;

-- Test 6: Get all onboarding requests (admin only)
do $$
declare
  v_count int;
begin
  -- Set session to admin
  perform set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text, true);
  
  -- Get all requests
  select count(*) into v_count
  from public.get_onboarding_requests();
  
  if v_count = 0 then
    raise exception 'Test 6 FAILED: get_onboarding_requests returned no results';
  end if;
  
  raise notice 'Test 6 PASSED: get_onboarding_requests returned % requests', v_count;
end$$;

-- Test 7: Validate required fields
do $$
declare
  v_request_id uuid;
  v_error_raised boolean := false;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111')::text, true);
  
  -- Try to submit with missing required field (should fail)
  begin
    select public.submit_cafe_application(
      p_cafe_name := '',  -- Empty name should fail
      p_cafe_address := '123 Test',
      p_cafe_phone := '+123',
      p_cafe_email := 'test@test.com'
    ) into v_request_id;
  exception
    when others then
      v_error_raised := true;
  end;
  
  if not v_error_raised then
    raise exception 'Test 7 FAILED: Validation did not catch empty cafe_name';
  end if;
  
  raise notice 'Test 7 PASSED: Required field validation working';
end$$;

-- Test 8: RLS - User cannot see other user's requests
do $$
declare
  v_count int;
begin
  -- Create another test user
  insert into auth.users (id, email)
  values ('33333333-3333-3333-3333-333333333333'::uuid, 'another_user@example.com')
  on conflict (id) do nothing;
  
  insert into public.profiles (id, email, role)
  values ('33333333-3333-3333-3333-333333333333'::uuid, 'another_user@example.com', 'user')
  on conflict (id) do nothing;
  
  -- Set session to another user
  perform set_config('request.jwt.claims', json_build_object('sub', '33333333-3333-3333-3333-333333333333')::text, true);
  
  -- Try to get requests (should only see own, which is 0)
  select count(*) into v_count
  from public.get_my_onboarding_requests();
  
  if v_count > 0 then
    raise exception 'Test 8 FAILED: User can see other users requests';
  end if;
  
  raise notice 'Test 8 PASSED: RLS working correctly';
end$$;

-- Cleanup
rollback;

-- Summary
raise notice '========================================';
raise notice 'All tests completed successfully!';
raise notice '========================================';
