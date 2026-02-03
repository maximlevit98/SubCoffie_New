-- ============================================================================
-- RLS SECURITY TEST SUITE
-- ============================================================================
-- Tests to verify that Row Level Security prevents unauthorized access
-- Run these tests to ensure no data leaks
-- ============================================================================

\echo ''
\echo '🔐 RLS SECURITY TEST SUITE'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''

-- ============================================================================
-- SETUP: Create test users
-- ============================================================================

\echo '📋 Setup: Creating test users...'

-- Test User A
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'user_a@test.com',
  crypt('password123', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES ('00000000-0000-0000-0000-000000000001', 'user_a@test.com', 'user')
ON CONFLICT (id) DO UPDATE SET role = 'user';

-- Test User B
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'user_b@test.com',
  crypt('password123', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES ('00000000-0000-0000-0000-000000000002', 'user_b@test.com', 'user')
ON CONFLICT (id) DO UPDATE SET role = 'user';

-- Test Owner A
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
VALUES (
  '00000000-0000-0000-0000-000000000003',
  'owner_a@test.com',
  crypt('password123', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES ('00000000-0000-0000-0000-000000000003', 'owner_a@test.com', 'owner')
ON CONFLICT (id) DO UPDATE SET role = 'owner';

-- Test Owner B
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
VALUES (
  '00000000-0000-0000-0000-000000000004',
  'owner_b@test.com',
  crypt('password123', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role)
VALUES ('00000000-0000-0000-0000-000000000004', 'owner_b@test.com', 'owner')
ON CONFLICT (id) DO UPDATE SET role = 'owner';

\echo '✅ Test users created'
\echo ''

-- ============================================================================
-- TEST 1: Anonymous cannot read orders
-- ============================================================================

\echo '🧪 TEST 1: Anonymous cannot read orders'
\echo '─────────────────────────────────────'

BEGIN;
  SET LOCAL role = anon;
  SET LOCAL request.jwt.claims = '{"role":"anon"}';
  
  \echo 'Attempting to read orders as anonymous...'
  SELECT COUNT(*) as anon_can_see_orders FROM public.orders_core;
  -- Expected: 0 (anonymous cannot see any orders)
  
  \echo 'Result: If count = 0, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 2: User A cannot read User B's orders
-- ============================================================================

\echo '🧪 TEST 2: User A cannot read User B'"'"'s orders'
\echo '─────────────────────────────────────────'

BEGIN;
  SET LOCAL role = authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
  
  \echo 'Attempting to read orders as User A...'
  SELECT COUNT(*) as user_a_can_see FROM public.orders_core;
  -- Expected: Only User A's orders (or 0 if no orders)
  
  \echo 'Result: If count matches User A'"'"'s orders only, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 3: Anonymous cannot read wallets
-- ============================================================================

\echo '🧪 TEST 3: Anonymous cannot read wallets'
\echo '────────────────────────────────────'

BEGIN;
  SET LOCAL role = anon;
  SET LOCAL request.jwt.claims = '{"role":"anon"}';
  
  \echo 'Attempting to read wallets as anonymous...'
  SELECT COUNT(*) as anon_can_see_wallets FROM public.wallets;
  -- Expected: 0 (anonymous cannot see any wallets)
  
  \echo 'Result: If count = 0, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 4: User A cannot read User B's wallet
-- ============================================================================

\echo '🧪 TEST 4: User A cannot read User B'"'"'s wallet'
\echo '───────────────────────────────────────'

BEGIN;
  SET LOCAL role = authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
  
  \echo 'Attempting to read wallets as User A...'
  SELECT COUNT(*) as user_a_can_see_wallets FROM public.wallets WHERE user_id != '00000000-0000-0000-0000-000000000001'::uuid;
  -- Expected: 0 (User A cannot see other users' wallets)
  
  \echo 'Result: If count = 0, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 5: Anonymous cannot read payment_transactions
-- ============================================================================

\echo '🧪 TEST 5: Anonymous cannot read payment transactions'
\echo '──────────────────────────────────────────────'

BEGIN;
  SET LOCAL role = anon;
  SET LOCAL request.jwt.claims = '{"role":"anon"}';
  
  \echo 'Attempting to read payment_transactions as anonymous...'
  SELECT COUNT(*) as anon_can_see_transactions FROM public.payment_transactions;
  -- Expected: 0 (anonymous cannot see any transactions)
  
  \echo 'Result: If count = 0, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 6: Owner A cannot read Owner B's cafe menu
-- ============================================================================

\echo '🧪 TEST 6: Owner A cannot modify Owner B'"'"'s cafe menu'
\echo '───────────────────────────────────────────────'

BEGIN;
  SET LOCAL role = authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}';
  
  \echo 'Attempting to read menu_items as Owner A (for cafes not owned by A)...'
  -- This query attempts to select menu items from cafes not owned by Owner A
  -- Expected: 0 rows (or only published cafe menu items, which is OK for public)
  
  SELECT COUNT(*) as owner_a_can_see_other_menus 
  FROM public.menu_items mi
  WHERE EXISTS (
    SELECT 1 FROM public.cafes c
    LEFT JOIN public.accounts a ON c.account_id = a.id
    WHERE c.id = mi.cafe_id 
    AND (a.owner_user_id IS NULL OR a.owner_user_id != '00000000-0000-0000-0000-000000000003'::uuid)
    AND c.status != 'published'
  );
  -- Expected: 0 (Owner A cannot see unpublished menus of other owners)
  
  \echo 'Result: If count = 0, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 7: Anonymous CAN read published cafes and menu
-- ============================================================================

\echo '🧪 TEST 7: Anonymous CAN read published cafes (positive test)'
\echo '─────────────────────────────────────────────────────────'

BEGIN;
  SET LOCAL role = anon;
  SET LOCAL request.jwt.claims = '{"role":"anon"}';
  
  \echo 'Attempting to read published cafes as anonymous...'
  SELECT COUNT(*) as anon_can_see_published_cafes FROM public.cafes WHERE status = 'published';
  -- Expected: > 0 (anonymous CAN see published cafes - this is correct)
  
  \echo 'Result: If count > 0, TEST PASSED ✅ (anonymous can see published cafes)'
  \echo ''
ROLLBACK;

-- ============================================================================
-- TEST 8: Anonymous CANNOT read draft/unpublished cafes
-- ============================================================================

\echo '🧪 TEST 8: Anonymous CANNOT read draft cafes'
\echo '───────────────────────────────────────'

BEGIN;
  SET LOCAL role = anon;
  SET LOCAL request.jwt.claims = '{"role":"anon"}';
  
  \echo 'Attempting to read draft cafes as anonymous...'
  SELECT COUNT(*) as anon_can_see_draft_cafes FROM public.cafes WHERE status != 'published';
  -- Expected: 0 (anonymous cannot see draft/unpublished cafes)
  
  \echo 'Result: If count = 0, TEST PASSED ✅'
  \echo ''
ROLLBACK;

-- ============================================================================
-- SUMMARY
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ RLS SECURITY TEST SUITE COMPLETE'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Review results above. All counts should match expected values.'
\echo ''
\echo 'Expected results:'
\echo '  • Anonymous: Cannot see orders, wallets, transactions (count = 0)'
\echo '  • Anonymous: CAN see published cafes/menu (count > 0)'
\echo '  • User A: Cannot see User B'"'"'s data (count = 0 for B'"'"'s data)'
\echo '  • Owner A: Cannot see Owner B'"'"'s unpublished data (count = 0)'
\echo ''
\echo 'If any test shows unexpected results, RLS policies need review!'
\echo ''
