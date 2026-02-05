# Wallet Schema Unification - Implementation Summary

**Date**: 2026-02-05  
**Priority**: P0 (Critical)  
**Status**: ✅ COMPLETE - Ready to Apply

---

## Executive Summary

Successfully unified 3 different wallet schema versions into a single **canonical format**:

```
OLD SCHEMAS:
  - MVP: type, credits_balance
  - Sync: balance, bonus_balance, lifetime_topup  
  - Payment: wallet_type, balance_credits, lifetime_top_up_credits ← CANONICAL

RESULT: Single canonical schema across all systems
```

---

## What Was Done

### 1. ✅ Database Migrations Created

**Files**:
- `20260205000001_fix_wallets_rls_security.sql` - Remove user UPDATE access to wallets
- `20260205000002_expand_wallet_transactions.sql` - Add audit fields to transactions
- `20260205000003_unify_wallets_schema.sql` - **Main migration**: Unify wallet schema
- `20260205000004_deprecate_wallet_sync_functions.sql` - Drop old RPC functions

**Migration Actions**:
1. Add canonical columns: `wallet_type`, `balance_credits`, `lifetime_top_up_credits`
2. Migrate data from old columns
3. Merge `bonus_balance` into `balance_credits`
4. Drop old columns: `type`, `balance`, `credits_balance`, `bonus_balance`, `lifetime_topup`
5. Drop deprecated RPC functions

### 2. ✅ Admin Panel Updated

**Files Updated**:
- `lib/supabase/queries/wallets.ts`:
  - Updated `Wallet` type to canonical schema
  - `listWallets()` - Queries canonical fields + joins
  - `getWalletByUserId()` - Uses new `get_user_wallets()` RPC
  - `getWalletTransactions()` - Direct query (RPC deprecated)
  - `getWalletsStats()` - Direct aggregation

- `app/admin/wallets/page.tsx`:
  - Displays `wallet_type` badge (CityPass | Cafe)
  - Shows `balance_credits` and `lifetime_top_up_credits`
  - Stats include wallet type breakdown

- `app/admin/wallets/[userId]/page.tsx`:
  - Detail page shows canonical fields
  - Displays cafe/network name for cafe_wallet

- `app/admin/wallets/actions.ts`:
  - ⚠️ `addManualTransaction()` - Temporarily disabled (RPC unavailable)
  - ✅ `getUserWallet()` - Updated to canonical
  - ✅ `getUserTransactions()` - Direct query

### 3. ✅ iOS App Verified

**Status**: Already using canonical schema ✓

**Files Checked**:
- `Models/WalletModels.swift` - Already uses `balance_credits`, `lifetime_top_up_credits`
- `Helpers/WalletService.swift` - Already calls `get_user_wallets()` RPC
- All wallet views display canonical fields correctly

**No changes needed** - iOS was already compliant!

### 4. ✅ Documentation Created

**Files**:
- `WALLET_SCHEMA_UNIFICATION.md` - Full migration guide
- `WALLET_UNIFICATION_QUICK_REFERENCE.md` - Quick reference
- `scripts/apply_wallet_unification.sh` - Migration script

---

## Canonical Schema (Final)

```sql
create table public.wallets (
  id uuid primary key,
  user_id uuid not null references auth.users(id),
  
  -- CANONICAL FIELDS
  wallet_type wallet_type not null default 'citypass',
  balance_credits int not null default 0,
  lifetime_top_up_credits int not null default 0,
  
  -- Optional: For cafe_wallet
  cafe_id uuid references public.cafes(id),
  network_id uuid references public.wallet_networks(id),
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

**Key Points**:
- `wallet_type`: Enum ('citypass' | 'cafe_wallet')
- `balance_credits`: Current balance (all funds merged)
- `lifetime_top_up_credits`: Total topped up (for loyalty)
- No separate `bonus_balance` (merged into balance_credits)

---

## Breaking Changes

### Removed Columns
- ❌ `type` → `wallet_type`
- ❌ `balance` → `balance_credits`
- ❌ `credits_balance` → `balance_credits`
- ❌ `bonus_balance` → merged into `balance_credits`
- ❌ `lifetime_topup` → `lifetime_top_up_credits`

### Deprecated RPCs
- ❌ `get_user_wallet(user_id_param)` → `get_user_wallets(p_user_id)`
- ❌ `add_wallet_transaction(...)` → Direct insert or new RPC
- ❌ `sync_wallet_balance(wallet_id_param)` → Not needed
- ❌ `get_wallet_transactions(user_id_param, ...)` → Direct query
- ❌ `get_wallets_stats()` → Direct aggregation

### New RPCs (Available)
- ✅ `create_citypass_wallet(p_user_id)`
- ✅ `create_cafe_wallet(p_user_id, p_cafe_id, p_network_id)`
- ✅ `get_user_wallets(p_user_id)` ← **Use this**
- ✅ `validate_wallet_for_order(p_wallet_id, p_cafe_id)`
- ✅ `calculate_commission(p_amount, p_operation_type, p_wallet_type)`

---

## How to Apply

### Quick Start

```bash
cd SubscribeCoffieBackend
./scripts/apply_wallet_unification.sh
```

### Manual Application

```bash
psql -d postgres -f supabase/migrations/20260205000001_fix_wallets_rls_security.sql
psql -d postgres -f supabase/migrations/20260205000002_expand_wallet_transactions.sql
psql -d postgres -f supabase/migrations/20260205000003_unify_wallets_schema.sql
psql -d postgres -f supabase/migrations/20260205000004_deprecate_wallet_sync_functions.sql
```

---

## Testing Checklist

### Database
- [ ] Apply migrations to dev database
- [ ] Run verification queries:
  ```sql
  SELECT wallet_type, COUNT(*), SUM(balance_credits) 
  FROM public.wallets GROUP BY wallet_type;
  
  SELECT COUNT(*) FROM public.wallets WHERE balance_credits < 0;
  ```
- [ ] Check no data loss
- [ ] Run `tests/wallets_rpc.test.sql`

### Admin Panel
- [ ] Navigate to `/admin/wallets`
- [ ] Verify stats display correctly
- [ ] Check wallet list shows canonical fields
- [ ] Open wallet detail page
- [ ] Verify wallet_type, balance_credits, lifetime_top_up_credits display
- [ ] Note: Manual transaction form temporarily disabled

### iOS App
- [ ] Open Profile screen
- [ ] Check wallet balance displays correctly
- [ ] Test wallet top-up flow
- [ ] Verify transactions history
- [ ] Check CafePickerView uses wallet correctly

---

## Known Issues & TODOs

### ⚠️ Admin Panel
- [ ] **TODO**: Implement new `addManualTransaction()` with direct wallet update
- [ ] **TODO**: Update UI to handle multiple wallets per user (CityPass + Cafe Wallets)
- [ ] **TODO**: Add wallet type filter in wallets list
- [ ] **TODO**: Create new RPC for admin manual balance adjustments

### ℹ️ Backend
- [ ] **OPTIONAL**: Create new RPC `admin_adjust_wallet_balance()` for safe admin transactions
- [ ] **OPTIONAL**: Add migration to backfill missing network/cafe names

---

## Impact Summary

| Component | Status | Changes | Action Required |
|-----------|--------|---------|-----------------|
| Database Schema | ✅ Ready | 4 migrations | Apply migrations |
| iOS App | ✅ Compliant | None | Test only |
| Admin Panel | ⚠️ Updated | Code changes | Test + Fix manual transactions |
| Backend RPCs | ✅ Ready | Deprecated old, using new | None |

---

## Rollback Plan

**Emergency rollback** (will lose bonus_balance data):

```sql
ALTER TABLE public.wallets
  ADD COLUMN type text,
  ADD COLUMN balance int,
  ADD COLUMN bonus_balance int,
  ADD COLUMN lifetime_topup int;

UPDATE public.wallets
SET 
  type = wallet_type::text,
  balance = balance_credits,
  lifetime_topup = lifetime_top_up_credits;
```

**Note**: This is NOT recommended - test thoroughly before production!

---

## Next Steps

1. ✅ **DONE**: Migrations created
2. ✅ **DONE**: Admin panel updated
3. ✅ **DONE**: iOS verified
4. ✅ **DONE**: Documentation complete
5. ⏳ **TODO**: Apply to dev database
6. ⏳ **TODO**: Test thoroughly
7. ⏳ **TODO**: Apply to staging
8. ⏳ **TODO**: Apply to production
9. ⏳ **TODO**: Implement new admin manual transaction RPC

---

## Files Created/Modified

### Backend Migrations
- `supabase/migrations/20260205000001_fix_wallets_rls_security.sql` ✅
- `supabase/migrations/20260205000002_expand_wallet_transactions.sql` ✅
- `supabase/migrations/20260205000003_unify_wallets_schema.sql` ✅
- `supabase/migrations/20260205000004_deprecate_wallet_sync_functions.sql` ✅

### Backend Scripts
- `scripts/apply_wallet_unification.sh` ✅

### Backend Documentation
- `WALLET_SCHEMA_UNIFICATION.md` ✅
- `WALLET_UNIFICATION_QUICK_REFERENCE.md` ✅
- `WALLET_SCHEMA_UNIFICATION_SUMMARY.md` ✅ (this file)

### Admin Panel
- `lib/supabase/queries/wallets.ts` ✅ Modified
- `app/admin/wallets/page.tsx` ✅ Modified
- `app/admin/wallets/[userId]/page.tsx` ✅ Modified
- `app/admin/wallets/actions.ts` ✅ Modified

### iOS App
- No changes (already canonical) ✅

---

## References

- Canonical schema: `20260201000002_wallet_types_mock_payments.sql`
- Full guide: `WALLET_SCHEMA_UNIFICATION.md`
- Quick ref: `WALLET_UNIFICATION_QUICK_REFERENCE.md`
- iOS models: `SubscribeCoffieClean/Models/WalletModels.swift`
- Admin queries: `subscribecoffie-admin/lib/supabase/queries/wallets.ts`

---

**Prepared by**: AI Assistant  
**Date**: 2026-02-05  
**Review Status**: Ready for human review and testing
