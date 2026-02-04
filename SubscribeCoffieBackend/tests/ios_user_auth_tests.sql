-- ============================================================================
-- iOS User Authentication Migration Tests
-- ============================================================================
-- This test file validates the 20260204000001_ios_user_auth.sql migration
-- Run these tests after applying the migration to verify functionality
--
-- PREREQUISITES:
-- 1. Migration 20260204000001_ios_user_auth.sql must be applied
-- 2. A test user must be authenticated (use Supabase Dashboard or API)
--
-- RUN WITH:
-- psql -U postgres -d postgres -f tests/ios_user_auth_tests.sql

\echo '============================================================================'
\echo 'iOS User Authentication Migration Tests'
\echo '============================================================================'
\echo ''

-- Start transaction for clean rollback
begin;

\echo 'TEST 1: Verify profiles table has new columns'
\echo '----------------------------------------------'
select 
  exists(
    select 1 from information_schema.columns 
    where table_name = 'profiles' 
    and column_name = 'avatar_url'
  ) as has_avatar_url,
  exists(
    select 1 from information_schema.columns 
    where table_name = 'profiles' 
    and column_name = 'auth_provider'
  ) as has_auth_provider,
  exists(
    select 1 from information_schema.columns 
    where table_name = 'profiles' 
    and column_name = 'updated_at'
  ) as has_updated_at;

\echo ''
\echo 'TEST 2: Verify auth_provider constraint exists'
\echo '-----------------------------------------------'
select 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
from pg_constraint
where conname = 'profiles_auth_provider_check'
and conrelid = 'public.profiles'::regclass;

\echo ''
\echo 'TEST 3: Verify indexes were created'
\echo '------------------------------------'
select 
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public' 
and tablename = 'profiles'
and indexname in (
  'profiles_phone_idx',
  'profiles_auth_provider_idx', 
  'profiles_avatar_url_idx'
)
order by indexname;

\echo ''
\echo 'TEST 4: Verify RPC functions exist'
\echo '-----------------------------------'
select 
  routine_name,
  routine_type
from information_schema.routines
where routine_schema = 'public'
and routine_name in (
  'init_user_profile',
  'get_my_profile',
  'update_my_profile',
  'get_user_profile',
  'search_users'
)
order by routine_name;

\echo ''
\echo 'TEST 5: Verify orders_with_profiles view exists'
\echo '------------------------------------------------'
select 
  table_name,
  table_type
from information_schema.tables
where table_schema = 'public'
and table_name = 'orders_with_profiles';

\echo ''
\echo 'TEST 6: Verify trigger was updated'
\echo '-----------------------------------'
select 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
from information_schema.triggers
where trigger_schema = 'public'
and trigger_name = 'on_auth_user_created';

\echo ''
\echo '============================================================================'
\echo 'FUNCTIONAL TESTS (require authenticated user)'
\echo '============================================================================'
\echo ''

\echo 'TEST 7: Create test user and verify profile creation'
\echo '-----------------------------------------------------'
-- Note: This would normally be done via Supabase Auth API
-- Here we simulate by directly inserting into auth.users (for testing only)

-- Create a test auth user
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  instance_id,
  aud,
  role
)
values (
  gen_random_uuid(),
  'test_ios_user@example.com',
  crypt('testpassword123', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"full_name": "Test iOS User"}'::jsonb,
  now(),
  now(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated'
)
returning id as test_user_id
\gset

\echo 'Created test user with ID:' :test_user_id
\echo ''

\echo 'TEST 8: Verify profile was auto-created by trigger'
\echo '---------------------------------------------------'
select 
  id,
  email,
  full_name,
  auth_provider,
  role,
  created_at
from public.profiles
where id = :'test_user_id';

\echo ''
\echo 'TEST 9: Test init_user_profile RPC'
\echo '-----------------------------------'
-- Set the auth context to simulate authenticated user
set local "request.jwt.claims" = json_build_object(
  'sub', :'test_user_id',
  'role', 'authenticated'
)::text;

select public.init_user_profile(
  p_full_name := 'Test User Full Name',
  p_birth_date := '1990-01-15',
  p_city := 'Москва',
  p_phone := '+79991234567'
) as init_result;

\echo ''
\echo 'TEST 10: Verify profile was updated'
\echo '------------------------------------'
select 
  id,
  email,
  full_name,
  birth_date,
  city,
  phone,
  auth_provider,
  avatar_url,
  updated_at > created_at as was_updated
from public.profiles
where id = :'test_user_id';

\echo ''
\echo 'TEST 11: Test get_my_profile RPC'
\echo '---------------------------------'
select public.get_my_profile() as my_profile;

\echo ''
\echo 'TEST 12: Test update_my_profile RPC'
\echo '------------------------------------'
select public.update_my_profile(
  p_city := 'Санкт-Петербург',
  p_avatar_url := 'https://example.com/avatar.jpg'
) as update_result;

\echo ''
\echo 'TEST 13: Verify updates were applied'
\echo '-------------------------------------'
select 
  id,
  city,
  avatar_url,
  updated_at
from public.profiles
where id = :'test_user_id';

\echo ''
\echo 'TEST 14: Test OAuth user creation (simulate Apple Sign In)'
\echo '-----------------------------------------------------------'
-- Simulate Apple OAuth user
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  instance_id,
  aud,
  role
)
values (
  gen_random_uuid(),
  'apple_user@example.com',
  crypt('', gen_salt('bf')),
  now(),
  '{"provider": "apple", "providers": ["apple"]}'::jsonb,
  '{
    "provider": "apple",
    "full_name": "Apple User",
    "avatar_url": "https://example.com/apple_avatar.jpg"
  }'::jsonb,
  now(),
  now(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated'
)
returning id as apple_user_id
\gset

\echo 'Created Apple OAuth user with ID:' :apple_user_id
\echo ''

\echo 'TEST 15: Verify Apple OAuth profile creation'
\echo '---------------------------------------------'
select 
  id,
  email,
  full_name,
  auth_provider,
  avatar_url,
  role
from public.profiles
where id = :'apple_user_id';

\echo ''
\echo 'TEST 16: Test Google OAuth user creation'
\echo '-----------------------------------------'
-- Simulate Google OAuth user
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  instance_id,
  aud,
  role
)
values (
  gen_random_uuid(),
  'google_user@example.com',
  crypt('', gen_salt('bf')),
  now(),
  '{"provider": "google", "providers": ["google"]}'::jsonb,
  '{
    "provider": "google",
    "name": "Google User",
    "picture": "https://lh3.googleusercontent.com/avatar.jpg"
  }'::jsonb,
  now(),
  now(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated'
)
returning id as google_user_id
\gset

\echo 'Created Google OAuth user with ID:' :google_user_id
\echo ''

\echo 'TEST 17: Verify Google OAuth profile creation'
\echo '----------------------------------------------'
select 
  id,
  email,
  full_name,
  auth_provider,
  avatar_url,
  role
from public.profiles
where id = :'google_user_id';

\echo ''
\echo 'TEST 18: Test orders_with_profiles view'
\echo '----------------------------------------'
-- Create a test order for our test user
insert into public.orders_core (
  cafe_id,
  user_id,
  customer_phone,
  status,
  subtotal_credits,
  paid_credits
)
select
  (select id from public.cafes limit 1),
  :'test_user_id'::uuid,
  '+79991234567',
  'created',
  100,
  100
where exists (select 1 from public.cafes limit 1)
returning id as test_order_id
\gset

\echo 'Created test order with ID:' :test_order_id
\echo ''

-- Query the view to see joined data
select 
  id as order_id,
  customer_phone,
  status,
  user_full_name,
  user_email,
  user_phone,
  user_auth_provider,
  user_registered_at
from public.orders_with_profiles
where id = :'test_order_id';

\echo ''
\echo 'TEST 19: Test profile updated_at trigger'
\echo '-----------------------------------------'
-- Get current updated_at
select updated_at as old_updated_at
from public.profiles
where id = :'test_user_id'
\gset

-- Wait a moment
select pg_sleep(0.1);

-- Update profile
update public.profiles
set city = 'Казань'
where id = :'test_user_id';

-- Check if updated_at changed
select 
  id,
  city,
  updated_at as new_updated_at,
  updated_at > :'old_updated_at'::timestamptz as updated_at_changed
from public.profiles
where id = :'test_user_id';

\echo ''
\echo 'TEST 20: Test phone index performance'
\echo '--------------------------------------'
explain (costs off)
select * from public.profiles
where phone = '+79991234567';

\echo ''
\echo '============================================================================'
\echo 'ADMIN FUNCTION TESTS'
\echo '============================================================================'
\echo ''

\echo 'TEST 21: Create admin user for testing'
\echo '---------------------------------------'
-- Create admin user
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  instance_id,
  aud,
  role
)
values (
  gen_random_uuid(),
  'admin_test@example.com',
  crypt('adminpass123', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated'
)
returning id as admin_user_id
\gset

-- Set admin role
update public.profiles
set role = 'admin'
where id = :'admin_user_id';

\echo 'Created admin user with ID:' :admin_user_id
\echo ''

\echo 'TEST 22: Test get_user_profile as admin'
\echo '----------------------------------------'
-- Set auth context as admin
set local "request.jwt.claims" = json_build_object(
  'sub', :'admin_user_id',
  'role', 'authenticated'
)::text;

select public.get_user_profile(:'test_user_id'::uuid) as user_profile;

\echo ''
\echo 'TEST 23: Test search_users as admin'
\echo '------------------------------------'
select public.search_users('test', 10, 0) as search_results;

\echo ''
\echo '============================================================================'
\echo 'ALL TESTS COMPLETED'
\echo '============================================================================'
\echo ''
\echo 'Rolling back transaction to clean up test data...'

-- Rollback to clean up
rollback;

\echo 'Test data cleaned up. Migration validation complete!'
\echo ''
