# Owner Admin Panel Backend - Installation Verification Checklist

Use this checklist to verify that the Owner Admin Panel backend has been correctly installed and is ready to use.

## ✅ Pre-Installation Checklist

- [ ] Supabase project created (local or cloud)
- [ ] Supabase CLI installed (`supabase --version`)
- [ ] PostgreSQL client available (optional, for manual testing)
- [ ] Git repository contains all migration files

## ✅ Migration Files Checklist

Verify these files exist in `supabase/migrations/`:

- [ ] `20260201120000_owner_admin_panel_foundation.sql` (~800 lines)
- [ ] `20260201130000_owner_order_management.sql` (~700 lines)

## ✅ Installation Steps

### Step 1: Apply Migrations

```bash
cd SubscribeCoffieBackend
supabase db reset
```

**Expected output:**
- ✅ No errors
- ✅ "Finished supabase db reset"
- ✅ All migrations applied successfully

**Verification:**
```bash
supabase migration list
```
- [ ] Both migrations shown as applied
- [ ] No "pending" migrations

### Step 2: Run Test Suite

```bash
psql -h localhost -U postgres -d postgres -f tests/owner_admin_panel_tests.sql
```

**Expected output:**
```
=== Test 1: Account Creation ===
NOTICE:  Test 1 PASSED: Account created with ID...

=== Test 2: Cafe Creation ===
NOTICE:  Test 2 PASSED: Cafe created with ID...

...

=== ALL TESTS PASSED ===
ROLLBACK
```

**Verification:**
- [ ] All 10 tests report "PASSED"
- [ ] No errors or failures
- [ ] Final "ROLLBACK" confirms transaction safety

## ✅ Database Schema Verification

### Check Tables Exist

Run in Supabase SQL Editor or psql:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'accounts', 
    'cafes', 
    'menu_categories', 
    'menu_items', 
    'menu_modifiers',
    'cafe_publication_history'
  )
ORDER BY table_name;
```

**Expected result: 6 rows**
- [ ] accounts
- [ ] cafe_publication_history
- [ ] cafes
- [ ] menu_categories
- [ ] menu_items
- [ ] menu_modifiers

### Check RLS is Enabled

```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN (
    'accounts', 
    'cafes', 
    'menu_categories', 
    'menu_items', 
    'menu_modifiers',
    'orders',
    'cafe_publication_history'
  )
ORDER BY tablename;
```

**Expected result:**
- [ ] All tables show `rowsecurity = true`
- [ ] 7 tables with RLS enabled

### Check Functions Exist

```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%owner%' 
  OR routine_name LIKE '%cafe%'
ORDER BY routine_name;
```

**Expected result: At least 16 functions**
- [ ] approve_cafe
- [ ] duplicate_cafe
- [ ] get_account_dashboard_stats
- [ ] get_cafe_dashboard_stats
- [ ] get_cafe_orders
- [ ] get_cafe_orders_by_status
- [ ] get_cafe_publication_checklist
- [ ] get_or_create_owner_account
- [ ] get_order_details
- [ ] get_owner_cafes
- [ ] owner_cancel_order
- [ ] owner_update_order_status
- [ ] reject_cafe
- [ ] submit_cafe_application
- [ ] submit_cafe_for_moderation
- [ ] toggle_menu_item_stop_list

## ✅ RLS Policy Verification

### Check Policy Count

```sql
SELECT schemaname, tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'accounts',
    'cafes',
    'menu_categories',
    'menu_items',
    'menu_modifiers',
    'orders',
    'cafe_publication_history'
  )
GROUP BY schemaname, tablename
ORDER BY tablename;
```

**Expected result:**
- [ ] accounts: ~4 policies
- [ ] cafe_publication_history: ~3 policies
- [ ] cafes: ~5 policies
- [ ] menu_categories: ~2 policies
- [ ] menu_items: ~2 policies
- [ ] menu_modifiers: ~2 policies
- [ ] orders: ~5 policies

### Test RLS (as authenticated user)

```sql
-- Set test context
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "00000000-0000-0000-0000-000000000001"}'::text;

-- Try to select from accounts (should work for own account)
SELECT COUNT(*) FROM public.accounts 
WHERE owner_user_id = '00000000-0000-0000-0000-000000000001';

-- Try to select from another user's account (should return 0)
SELECT COUNT(*) FROM public.accounts 
WHERE owner_user_id = '00000000-0000-0000-0000-000000000099';

RESET role;
```

**Expected result:**
- [ ] First query returns count >= 0 (own account)
- [ ] Second query returns 0 (no access to other accounts)

## ✅ API Function Testing

### Test Account Creation

```sql
SELECT public.get_or_create_owner_account(
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Test Company'
);
```

**Expected result:**
- [ ] Returns account object
- [ ] No errors

### Test Cafe Operations

```sql
-- Get cafes (will be empty initially)
SELECT * FROM public.get_owner_cafes(
  '00000000-0000-0000-0000-000000000001'::uuid
);
```

**Expected result:**
- [ ] Query executes successfully
- [ ] Returns empty array or existing cafes

### Test Publication Checklist

```sql
-- Create a test cafe first
INSERT INTO public.cafes (
  account_id, 
  name, 
  address, 
  status
)
SELECT 
  id, 
  'Test Cafe', 
  '123 Test St', 
  'draft'
FROM public.accounts 
WHERE owner_user_id = '00000000-0000-0000-0000-000000000001'
LIMIT 1
RETURNING id;

-- Then check its publication readiness
SELECT public.get_cafe_publication_checklist(
  'YOUR_CAFE_ID_HERE'::uuid
);
```

**Expected result:**
- [ ] Returns JSON object with checklist items
- [ ] Shows true/false for each requirement

## ✅ Real-time Configuration

### Check Real-time is Enabled

In Supabase Dashboard:
- [ ] Go to Database → Replication
- [ ] Verify `orders` table is enabled for real-time
- [ ] Verify publication includes INSERT, UPDATE, DELETE

Or via SQL:

```sql
SELECT * FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';
```

**Expected result:**
- [ ] `orders` table is in the list

## ✅ TypeScript Types Verification

### Check Types File Exists

- [ ] File exists: `types/owner-admin-panel.ts`
- [ ] File size: ~450 lines
- [ ] Contains at least 30 interfaces

### Verify Types Compile

```bash
# If you have TypeScript installed
cd SubscribeCoffieBackend
npx tsc --noEmit types/owner-admin-panel.ts
```

**Expected result:**
- [ ] No compilation errors

## ✅ Documentation Verification

### Check All Documentation Files Exist

- [ ] `OWNER_API_CONTRACT.md` (~650 lines)
- [ ] `OWNER_BACKEND_QUICKSTART.md` (~500 lines)
- [ ] `OWNER_BACKEND_IMPLEMENTATION_SUMMARY.md` (~400 lines)
- [ ] `OWNER_BACKEND_README.md` (~350 lines)
- [ ] `BACKEND_FOUNDATION_COMPLETE.md` (~450 lines)
- [ ] `ARCHITECTURE_DIAGRAMS.md` (~500 lines)

### Quick Documentation Test

- [ ] Can open each file without errors
- [ ] Markdown renders correctly
- [ ] Code examples are properly formatted
- [ ] Links between documents work

## ✅ Integration Readiness

### Frontend Integration Checklist

- [ ] TypeScript types are available
- [ ] API contract is documented
- [ ] Quick start examples are clear
- [ ] Real-time subscription examples provided

### Supabase Client Setup

```typescript
// Verify this code would work:
import { createClient } from '@supabase/supabase-js';
import type { Cafe } from './types/owner-admin-panel';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// This should be type-safe
const { data: cafes } = await supabase
  .rpc('get_owner_cafes', {
    p_user_id: 'user-id'
  });
```

- [ ] Types import correctly
- [ ] Supabase client initialization works
- [ ] RPC call types are correct

## ✅ Performance Verification

### Check Indexes

```sql
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'accounts',
    'cafes',
    'menu_categories',
    'menu_items',
    'menu_modifiers',
    'orders'
  )
ORDER BY tablename, indexname;
```

**Expected result:**
- [ ] At least 15+ indexes created
- [ ] Primary keys and foreign keys indexed
- [ ] Common query patterns covered

### Test Query Performance

```sql
EXPLAIN ANALYZE
SELECT * FROM public.get_owner_cafes(
  '00000000-0000-0000-0000-000000000001'::uuid
);
```

**Expected result:**
- [ ] Query plan shows index usage
- [ ] Execution time < 50ms (on local)

## ✅ Security Verification

### Test Unauthorized Access

```sql
-- Try to access another user's account (should fail)
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "00000000-0000-0000-0000-000000000099"}'::text;

SELECT * FROM public.accounts 
WHERE owner_user_id = '00000000-0000-0000-0000-000000000001';

RESET role;
```

**Expected result:**
- [ ] Query returns 0 rows (RLS blocks access)

### Test Function Authorization

```sql
-- Try to update someone else's order (should fail)
SELECT public.owner_update_order_status(
  'some-order-id'::uuid,
  'Accepted',
  'wrong-user-id'::uuid
);
```

**Expected result:**
- [ ] Function throws "Unauthorized" exception

## ✅ Final Checklist

Before considering installation complete:

- [ ] All migrations applied successfully
- [ ] All 10 tests pass
- [ ] All tables exist with RLS enabled
- [ ] All 16+ functions exist
- [ ] RLS policies protect data correctly
- [ ] Real-time is configured
- [ ] TypeScript types are available
- [ ] Documentation is complete and readable
- [ ] No linting errors in SQL files
- [ ] Test suite runs without errors

## 🎉 Installation Complete!

If all items above are checked, your Owner Admin Panel backend is:

✅ **Installed**  
✅ **Tested**  
✅ **Secured**  
✅ **Documented**  
✅ **Ready for frontend integration**

## 🚀 Next Steps

1. **Read the Quickstart**: [OWNER_BACKEND_QUICKSTART.md](./OWNER_BACKEND_QUICKSTART.md)
2. **Review API Contract**: [OWNER_API_CONTRACT.md](./OWNER_API_CONTRACT.md)
3. **Import TypeScript Types**: `types/owner-admin-panel.ts`
4. **Start Building Frontend**: Phase 2 of the roadmap

## 🐛 Troubleshooting

If any checks failed:

1. **Migrations not applied**: Run `supabase db reset`
2. **Tests failing**: Check error messages, verify data setup
3. **RLS issues**: Ensure user roles are set correctly
4. **Functions missing**: Re-apply migrations
5. **Types errors**: Check TypeScript version compatibility

## 📞 Support Resources

- **Quickstart Guide**: Step-by-step API usage
- **API Contract**: Complete API reference
- **Architecture Diagrams**: Visual system overview
- **Test Suite**: `tests/owner_admin_panel_tests.sql`
- **Implementation Summary**: Complete feature list

---

**Verification Date:** _____________  
**Verified By:** _____________  
**Status:** ⬜ Pending / ✅ Complete / ❌ Failed

---

**All checks passing? Congratulations! 🎉**  
**The Owner Admin Panel backend is production-ready!**
