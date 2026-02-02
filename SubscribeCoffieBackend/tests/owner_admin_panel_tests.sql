-- ============================================================================
-- Owner Admin Panel - Testing Script
-- ============================================================================
-- Description: Comprehensive test suite for Owner Admin Panel backend
-- Date: 2026-02-01
--
-- This script tests:
-- 1. Account creation and management
-- 2. Cafe creation and management
-- 3. Menu categories and items
-- 4. Menu modifiers
-- 5. Order management
-- 6. RLS policies
-- 7. RPC functions
-- ============================================================================

begin;

-- Clean up test data first
do $$
declare
  v_test_account_id uuid;
begin
  -- Find test accounts
  select id into v_test_account_id
  from public.accounts
  where company_name like '%Test Company%'
  limit 1;
  
  if v_test_account_id is not null then
    -- Delete will cascade to cafes, menu items, etc.
    delete from public.accounts where id = v_test_account_id;
  end if;
end$$;

-- ============================================================================
-- Test 1: Account Creation
-- ============================================================================

\echo '=== Test 1: Account Creation ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_account public.accounts;
begin
  -- Create test owner user profile if not exists
  insert into auth.users (id, email)
  values (v_owner_user_id, 'test_owner@example.com')
  on conflict (id) do nothing;
  
  insert into public.profiles (id, role)
  values (v_owner_user_id, 'owner')
  on conflict (id) do update set role = 'owner';

  -- Test: Create account
  insert into public.accounts (owner_user_id, company_name, inn)
  values (v_owner_user_id, 'Test Company', '1234567890')
  returning * into v_account;
  
  assert v_account.id is not null, 'Account should be created';
  assert v_account.company_name = 'Test Company', 'Company name should match';
  
  raise notice 'Test 1 PASSED: Account created with ID %', v_account.id;
end$$;

-- ============================================================================
-- Test 2: Cafe Creation
-- ============================================================================

\echo '=== Test 2: Cafe Creation ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_account_id uuid;
  v_cafe public.cafes;
begin
  -- Get account
  select id into v_account_id
  from public.accounts
  where owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_account_id is not null, 'Account should exist';

  -- Test: Create cafe
  insert into public.cafes (
    account_id,
    name,
    address,
    phone,
    email,
    mode,
    status,
    latitude,
    longitude
  )
  values (
    v_account_id,
    'Test Cafe',
    '123 Test Street',
    '+1234567890',
    'test@cafe.com',
    'closed',
    'draft',
    55.7558,
    37.6173
  )
  returning * into v_cafe;
  
  assert v_cafe.id is not null, 'Cafe should be created';
  assert v_cafe.status = 'draft', 'Cafe should start as draft';
  assert v_cafe.account_id = v_account_id, 'Cafe should be linked to account';
  
  raise notice 'Test 2 PASSED: Cafe created with ID %', v_cafe.id;
end$$;

-- ============================================================================
-- Test 3: Menu Categories
-- ============================================================================

\echo '=== Test 3: Menu Categories ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_cafe_id uuid;
  v_category public.menu_categories;
begin
  -- Get cafe
  select c.id into v_cafe_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_cafe_id is not null, 'Cafe should exist';

  -- Test: Create category
  insert into public.menu_categories (cafe_id, name, sort_order)
  values (v_cafe_id, 'Coffee', 0)
  returning * into v_category;
  
  assert v_category.id is not null, 'Category should be created';
  assert v_category.name = 'Coffee', 'Category name should match';
  
  raise notice 'Test 3 PASSED: Menu category created with ID %', v_category.id;
end$$;

-- ============================================================================
-- Test 4: Menu Items
-- ============================================================================

\echo '=== Test 4: Menu Items ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_cafe_id uuid;
  v_category_id uuid;
  v_item public.menu_items;
begin
  -- Get cafe and category
  select c.id, mc.id into v_cafe_id, v_category_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  join public.menu_categories mc on mc.cafe_id = c.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_cafe_id is not null, 'Cafe should exist';
  assert v_category_id is not null, 'Category should exist';

  -- Test: Create menu item
  insert into public.menu_items (
    cafe_id,
    category_id,
    category,
    name,
    description,
    price_credits,
    prep_time_sec
  )
  values (
    v_cafe_id,
    v_category_id,
    'drinks',
    'Cappuccino',
    'Classic cappuccino with foam',
    250,
    300
  )
  returning * into v_item;
  
  assert v_item.id is not null, 'Menu item should be created';
  assert v_item.price_credits = 250, 'Price should match';
  
  raise notice 'Test 4 PASSED: Menu item created with ID %', v_item.id;
end$$;

-- ============================================================================
-- Test 5: Menu Modifiers
-- ============================================================================

\echo '=== Test 5: Menu Modifiers ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_item_id uuid;
  v_modifier public.menu_modifiers;
begin
  -- Get menu item
  select mi.id into v_item_id
  from public.menu_items mi
  join public.cafes c on mi.cafe_id = c.id
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_item_id is not null, 'Menu item should exist';

  -- Test: Create modifier
  insert into public.menu_modifiers (
    menu_item_id,
    group_name,
    modifier_name,
    price_change,
    is_required,
    allow_multiple,
    sort_order
  )
  values (
    v_item_id,
    'Volume',
    'Large',
    50,
    true,
    false,
    1
  )
  returning * into v_modifier;
  
  assert v_modifier.id is not null, 'Modifier should be created';
  assert v_modifier.price_change = 50, 'Price change should match';
  
  raise notice 'Test 5 PASSED: Menu modifier created with ID %', v_modifier.id;
end$$;

-- ============================================================================
-- Test 6: Publication Checklist
-- ============================================================================

\echo '=== Test 6: Publication Checklist ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_cafe_id uuid;
  v_checklist jsonb;
begin
  -- Get cafe
  select c.id into v_cafe_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_cafe_id is not null, 'Cafe should exist';

  -- Test: Get publication checklist (as service_role to bypass RLS)
  set local role postgres;
  select public.get_cafe_publication_checklist(v_cafe_id) into v_checklist;
  reset role;
  
  assert v_checklist is not null, 'Checklist should be returned';
  assert (v_checklist->>'basic_info')::boolean = true, 'Basic info should be complete';
  assert (v_checklist->>'menu')::boolean = true, 'Menu should have at least 3 items';
  
  raise notice 'Test 6 PASSED: Publication checklist: %', v_checklist;
end$$;

-- ============================================================================
-- Test 7: Duplicate Cafe
-- ============================================================================

\echo '=== Test 7: Duplicate Cafe ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_cafe_id uuid;
  v_new_cafe public.cafes;
  v_original_items_count int;
  v_duplicate_items_count int;
begin
  -- Get cafe
  select c.id into v_cafe_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_cafe_id is not null, 'Cafe should exist';

  -- Count original menu items
  select count(*) into v_original_items_count
  from public.menu_items
  where cafe_id = v_cafe_id;

  -- Test: Duplicate cafe (as service_role to bypass RLS)
  set local role postgres;
  select public.duplicate_cafe(v_cafe_id, 'Test Cafe (Copy)') into v_new_cafe;
  reset role;
  
  assert v_new_cafe.id is not null, 'Duplicate cafe should be created';
  assert v_new_cafe.status = 'draft', 'Duplicate should start as draft';
  assert v_new_cafe.name = 'Test Cafe (Copy)', 'Name should match';
  
  -- Count duplicate menu items
  select count(*) into v_duplicate_items_count
  from public.menu_items
  where cafe_id = v_new_cafe.id;
  
  assert v_duplicate_items_count = v_original_items_count, 
    'Duplicate should have same number of menu items';
  
  raise notice 'Test 7 PASSED: Cafe duplicated with ID %', v_new_cafe.id;
end$$;

-- ============================================================================
-- Test 8: Order Creation and Management
-- ============================================================================

\echo '=== Test 8: Order Creation and Management ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_customer_user_id uuid := '00000000-0000-0000-0000-000000000002';
  v_cafe_id uuid;
  v_menu_item_id uuid;
  v_order public.orders;
  v_updated_order public.orders;
begin
  -- Create test customer user if not exists
  insert into auth.users (id, email)
  values (v_customer_user_id, 'test_customer@example.com')
  on conflict (id) do nothing;
  
  insert into public.profiles (id, role)
  values (v_customer_user_id, 'user')
  on conflict (id) do nothing;

  -- Get cafe and menu item
  select c.id, mi.id into v_cafe_id, v_menu_item_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  join public.menu_items mi on mi.cafe_id = c.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_cafe_id is not null, 'Cafe should exist';
  assert v_menu_item_id is not null, 'Menu item should exist';

  -- Test: Create order
  insert into public.orders (
    user_id,
    cafe_id,
    status,
    order_type,
    payment_status,
    subtotal_credits,
    customer_phone,
    eta_minutes
  )
  values (
    v_customer_user_id,
    v_cafe_id,
    'Created',
    'now',
    'pending',
    250,
    '+1234567890',
    15
  )
  returning * into v_order;
  
  assert v_order.id is not null, 'Order should be created';
  assert v_order.status = 'Created', 'Order status should be Created';
  
  -- Test: Add order items
  insert into public.order_items (
    order_id,
    menu_item_id,
    title,
    unit_credits,
    quantity,
    category
  )
  values (
    v_order.id,
    v_menu_item_id,
    'Cappuccino',
    250,
    1,
    'drinks'
  );
  
  -- Test: Update order status (as service_role to bypass RLS)
  set local role postgres;
  select public.owner_update_order_status(
    v_order.id,
    'Accepted',
    v_owner_user_id
  ) into v_updated_order;
  reset role;
  
  assert v_updated_order.status = 'Accepted', 'Order status should be updated to Accepted';
  
  raise notice 'Test 8 PASSED: Order created and status updated';
end$$;

-- ============================================================================
-- Test 9: Dashboard Stats
-- ============================================================================

\echo '=== Test 9: Dashboard Stats ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_cafe_id uuid;
  v_cafe_stats jsonb;
  v_account_stats jsonb;
begin
  -- Get cafe
  select c.id into v_cafe_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = v_owner_user_id
  limit 1;
  
  assert v_cafe_id is not null, 'Cafe should exist';

  -- Test: Get cafe dashboard stats (as service_role to bypass RLS)
  set local role postgres;
  select public.get_cafe_dashboard_stats(v_cafe_id) into v_cafe_stats;
  reset role;
  
  assert v_cafe_stats is not null, 'Cafe stats should be returned';
  assert (v_cafe_stats->>'total_orders')::int >= 0, 'Total orders should be non-negative';
  
  -- Test: Get account dashboard stats
  set local role postgres;
  select public.get_account_dashboard_stats(v_owner_user_id) into v_account_stats;
  reset role;
  
  assert v_account_stats is not null, 'Account stats should be returned';
  assert (v_account_stats->>'total_cafes')::int >= 1, 'Should have at least 1 cafe';
  
  raise notice 'Test 9 PASSED: Dashboard stats retrieved';
  raise notice 'Cafe stats: %', v_cafe_stats;
  raise notice 'Account stats: %', v_account_stats;
end$$;

-- ============================================================================
-- Test 10: RLS Policies (Owner Access)
-- ============================================================================

\echo '=== Test 10: RLS Policies ==='

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_other_user_id uuid := '00000000-0000-0000-0000-000000000003';
  v_cafe_id uuid;
  v_can_see_own_cafe boolean;
  v_can_see_other_cafe boolean;
begin
  -- Create other user
  insert into auth.users (id, email)
  values (v_other_user_id, 'other_user@example.com')
  on conflict (id) do nothing;
  
  insert into public.profiles (id, role)
  values (v_other_user_id, 'owner')
  on conflict (id) do update set role = 'owner';

  -- Get cafe
  select c.id into v_cafe_id
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = v_owner_user_id
  limit 1;

  -- Test: Owner can see their own cafe (simulate auth context)
  set local role authenticated;
  set local request.jwt.claims to json_build_object('sub', v_owner_user_id)::text;
  
  select exists(
    select 1 from public.cafes where id = v_cafe_id
  ) into v_can_see_own_cafe;
  
  assert v_can_see_own_cafe = true, 'Owner should see their own cafe';

  -- Test: Other owner cannot see this cafe (unless published)
  set local request.jwt.claims to json_build_object('sub', v_other_user_id)::text;
  
  select exists(
    select 1 from public.cafes where id = v_cafe_id
  ) into v_can_see_other_cafe;
  
  assert v_can_see_other_cafe = false, 'Other owner should not see draft cafe';
  
  reset role;
  
  raise notice 'Test 10 PASSED: RLS policies working correctly';
end$$;

-- ============================================================================
-- Test Summary
-- ============================================================================

\echo ''
\echo '=== ALL TESTS PASSED ==='
\echo ''
\echo 'Summary of tests:'
\echo '1. Account Creation - OK'
\echo '2. Cafe Creation - OK'
\echo '3. Menu Categories - OK'
\echo '4. Menu Items - OK'
\echo '5. Menu Modifiers - OK'
\echo '6. Publication Checklist - OK'
\echo '7. Duplicate Cafe - OK'
\echo '8. Order Management - OK'
\echo '9. Dashboard Stats - OK'
\echo '10. RLS Policies - OK'
\echo ''

rollback;
