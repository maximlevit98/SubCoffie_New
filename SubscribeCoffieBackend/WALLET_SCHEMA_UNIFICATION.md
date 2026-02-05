# Wallet Schema Unification (P0)

**Date**: 2026-02-05  
**Priority**: P0 (Critical)  
**Status**: ✅ COMPLETE

## Problem Statement

The wallets table had **inconsistent schema** across different migrations:

### Old Schema Issues

1. **MVP Migration** (`20260120120000_mvp_coffee.sql`):
   - Used `type` (text) instead of `wallet_type` (enum)
   - Used `credits_balance` instead of `balance_credits`
   - No `lifetime_top_up_credits` field

2. **Wallet Sync Functions** (`20260131010000_wallet_sync_functions.sql`):
   - Used `balance` instead of `balance_credits`
   - Used `bonus_balance` (separate column)
   - Used `lifetime_topup` instead of `lifetime_top_up_credits`

3. **Payment Integration** (`20260201000002_wallet_types_mock_payments.sql`):
   - Introduced **canonical schema** with:
     - `wallet_type` (enum: 'citypass' | 'cafe_wallet')
     - `balance_credits` (int, NOT NULL)
     - `lifetime_top_up_credits` (int, NOT NULL, default 0)

## Canonical Schema (Final)

```sql
create table public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  
  -- CANONICAL FIELDS (2026-02-05)
  wallet_type wallet_type not null default 'citypass',
  balance_credits int not null default 0,
  lifetime_top_up_credits int not null default 0,
  
  -- Optional: For cafe_wallet type
  cafe_id uuid references public.cafes(id) on delete set null,
  network_id uuid references public.wallet_networks(id) on delete set null,
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Key Points

- **`wallet_type`**: Enum ('citypass' | 'cafe_wallet')
- **`balance_credits`**: Current balance (includes all funds - regular + bonus merged)
- **`lifetime_top_up_credits`**: Total amount topped up over lifetime (for loyalty/analytics)
- **No separate bonus_balance**: Bonuses are merged into `balance_credits`

## Migration Path

### 1. Schema Migration

**File**: `supabase/migrations/20260205000003_unify_wallets_schema.sql`

**Actions**:
- Add canonical columns (`wallet_type`, `balance_credits`, `lifetime_top_up_credits`)
- Migrate data from old columns:
  - `type` → `wallet_type`
  - `balance` / `credits_balance` → `balance_credits`
  - `bonus_balance` → merged into `balance_credits`
  - `lifetime_topup` → `lifetime_top_up_credits`
- Drop old columns
- Update constraints and indexes

### 2. Deprecate Old RPC Functions

**File**: `supabase/migrations/20260205000004_deprecate_wallet_sync_functions.sql`

**Deprecated RPCs**:
- ❌ `get_user_wallet()` → Use `get_user_wallets()` (returns array)
- ❌ `add_wallet_transaction()` → Use direct insertion + new RPC
- ❌ `sync_wallet_balance()` → Not needed (balance_credits is source of truth)
- ❌ `get_wallet_transactions()` → Use direct query
- ❌ `get_wallets_stats()` → Use direct aggregation

**New RPCs** (from `wallet_types_mock_payments.sql`):
- ✅ `create_citypass_wallet(p_user_id)`
- ✅ `create_cafe_wallet(p_user_id, p_cafe_id, p_network_id)`
- ✅ `get_user_wallets(p_user_id)` - Returns all wallets with canonical schema
- ✅ `validate_wallet_for_order(p_wallet_id, p_cafe_id)`
- ✅ `calculate_commission(p_amount, p_operation_type, p_wallet_type)`

## Updated Components

### ✅ iOS App (SubscribeCoffieClean)

**Status**: Already using canonical schema

**Files**:
- `Models/WalletModels.swift` - Uses `balance_credits`, `lifetime_top_up_credits`
- `Helpers/WalletService.swift` - Calls `get_user_wallets()` RPC
- All views correctly display canonical fields

**DTO Example**:
```swift
struct SupabaseWalletDTO: Codable {
    let id: UUID?
    let wallet_type: String?
    let balance_credits: Int?
    let lifetime_top_up_credits: Int?
    let cafe_id: UUID?
    let network_id: UUID?
}
```

### ✅ Admin Panel (subscribecoffie-admin)

**Status**: Updated to canonical schema

**Files Updated**:
1. `lib/supabase/queries/wallets.ts`:
   - Updated `Wallet` type to canonical schema
   - `listWallets()` - Queries canonical fields + joins cafe/network names
   - `getWalletByUserId()` - Uses `get_user_wallets()` RPC
   - `getWalletTransactions()` - Direct query (RPC deprecated)
   - `getWalletsStats()` - Direct aggregation (RPC deprecated)

2. `app/admin/wallets/page.tsx`:
   - Displays `wallet_type` badge (CityPass | Cafe)
   - Shows `balance_credits` and `lifetime_top_up_credits`
   - Stats include wallet type breakdown

3. `app/admin/wallets/[userId]/page.tsx`:
   - Displays canonical fields
   - Shows cafe/network name for cafe_wallet type

4. `app/admin/wallets/actions.ts`:
   - ⚠️ `addManualTransaction()` - DEPRECATED (RPC not available)
   - ⚠️ `syncWalletBalance()` - DEPRECATED (not needed)
   - ✅ `getUserWallet()` - Updated to use `get_user_wallets()`
   - ✅ `getUserTransactions()` - Direct query

**TODO for Admin Panel**:
- [ ] Implement new `addManualTransaction()` with direct wallet update
- [ ] Update UI to handle multiple wallets per user (CityPass + Cafe Wallets)
- [ ] Add wallet type filter/selector

## Breaking Changes

### Removed Columns
- ❌ `type` (text) → `wallet_type` (enum)
- ❌ `balance` (int) → `balance_credits` (int)
- ❌ `credits_balance` (int) → `balance_credits` (int)
- ❌ `bonus_balance` (int) → merged into `balance_credits`
- ❌ `lifetime_topup` (int) → `lifetime_top_up_credits` (int)

### Removed RPCs
- ❌ `get_user_wallet(user_id_param)` → Use `get_user_wallets(p_user_id)`
- ❌ `add_wallet_transaction(...)` → Direct insert or new RPC
- ❌ `sync_wallet_balance(wallet_id_param)` → Not needed
- ❌ `get_wallet_transactions(user_id_param, ...)` → Direct query
- ❌ `get_wallets_stats()` → Direct aggregation

## Migration Checklist

- [x] Create schema unification migration (`20260205000003_unify_wallets_schema.sql`)
- [x] Create RPC deprecation migration (`20260205000004_deprecate_wallet_sync_functions.sql`)
- [x] Update admin queries to canonical schema
- [x] Update admin pages to canonical schema
- [x] Verify iOS uses canonical schema (already compliant)
- [x] Document migration process
- [ ] Apply migrations to development database
- [ ] Apply migrations to staging database
- [ ] Test admin wallet management
- [ ] Test iOS wallet display and top-up
- [ ] Apply migrations to production database

## Testing

### Database

```sql
-- Check current schema
\d public.wallets

-- Verify data migration
SELECT 
  wallet_type,
  COUNT(*) as count,
  SUM(balance_credits) as total_balance,
  SUM(lifetime_top_up_credits) as total_lifetime
FROM public.wallets
GROUP BY wallet_type;

-- Check for negative balances (should be 0)
SELECT COUNT(*) FROM public.wallets WHERE balance_credits < 0;
```

### Admin Panel

1. Navigate to `/admin/wallets`
2. Verify stats show wallet type breakdown
3. Check table displays canonical fields
4. Open wallet detail page
5. Verify fields display correctly

### iOS App

1. Open Profile screen
2. Check wallet balance displays
3. Test wallet top-up flow
4. Verify transactions history

## Rollback Plan

If migration fails:

```sql
-- Rollback: Re-add old columns (data will be lost)
ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS type text,
  ADD COLUMN IF NOT EXISTS balance int,
  ADD COLUMN IF NOT EXISTS bonus_balance int,
  ADD COLUMN IF NOT EXISTS lifetime_topup int;

-- Copy back from canonical
UPDATE public.wallets
SET 
  type = wallet_type::text,
  balance = balance_credits,
  lifetime_topup = lifetime_top_up_credits;
```

**Note**: This rollback will lose bonus_balance data (merged into balance_credits).

## Next Steps

1. **Apply migrations** to development environment
2. **Test thoroughly** with admin panel and iOS app
3. **Create new RPC** for admin manual transactions if needed:
   ```sql
   create or replace function public.admin_adjust_wallet_balance(
     p_user_id uuid,
     p_wallet_type wallet_type,
     p_amount int,
     p_type text, -- 'admin_credit' | 'admin_debit'
     p_description text,
     p_actor_user_id uuid
   )
   ```
4. **Update admin UI** to support multiple wallets per user
5. **Apply to production** after full testing

## References

- Migration: `20260205000003_unify_wallets_schema.sql`
- Deprecation: `20260205000004_deprecate_wallet_sync_functions.sql`
- Canonical schema: `20260201000002_wallet_types_mock_payments.sql`
- iOS models: `SubscribeCoffieClean/Models/WalletModels.swift`
- Admin queries: `subscribecoffie-admin/lib/supabase/queries/wallets.ts`
