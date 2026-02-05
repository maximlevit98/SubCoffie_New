# Wallet Schema Unification - Quick Reference

**Date**: 2026-02-05 | **Priority**: P0 | **Status**: ✅ Ready to Apply

## TL;DR

Унифицированы 3 разные схемы кошельков в одну **каноническую**:

```
OLD: type, balance, credits_balance, bonus_balance, lifetime_topup
NEW: wallet_type, balance_credits, lifetime_top_up_credits
```

## Canonical Schema

```typescript
type Wallet = {
  id: uuid;
  user_id: uuid;
  wallet_type: "citypass" | "cafe_wallet";  // ✅ NEW
  balance_credits: number;                   // ✅ NEW (merged balance + bonus)
  lifetime_top_up_credits: number;           // ✅ NEW
  cafe_id?: uuid;                            // For cafe_wallet
  network_id?: uuid;                         // For cafe_wallet
  created_at: timestamp;
  updated_at: timestamp;
};
```

## What Changed

### ✅ Added
- `wallet_type` enum ('citypass' | 'cafe_wallet')
- `balance_credits` (replaces balance/credits_balance)
- `lifetime_top_up_credits` (replaces lifetime_topup)

### ❌ Removed
- `type` (text)
- `balance` (int)
- `credits_balance` (int)
- `bonus_balance` (int) - merged into balance_credits
- `lifetime_topup` (int)

### ❌ Deprecated RPCs
- `get_user_wallet()` → Use `get_user_wallets(p_user_id)`
- `add_wallet_transaction()` → TODO: new canonical RPC
- `sync_wallet_balance()` → Not needed
- `get_wallet_transactions()` → Direct query
- `get_wallets_stats()` → Direct query

### ✅ New RPCs (from wallet_types_mock_payments.sql)
- `create_citypass_wallet(p_user_id)`
- `create_cafe_wallet(p_user_id, p_cafe_id, p_network_id)`
- `get_user_wallets(p_user_id)` ← Use this
- `validate_wallet_for_order(p_wallet_id, p_cafe_id)`
- `calculate_commission(p_amount, p_operation_type, p_wallet_type)`

## Quick Apply (Dev Environment)

```bash
cd SubscribeCoffieBackend
./scripts/apply_wallet_unification.sh
```

Or manually:

```bash
psql -d postgres -f supabase/migrations/20260205000001_fix_wallets_rls_security.sql
psql -d postgres -f supabase/migrations/20260205000002_expand_wallet_transactions.sql
psql -d postgres -f supabase/migrations/20260205000003_unify_wallets_schema.sql
psql -d postgres -f supabase/migrations/20260205000004_deprecate_wallet_sync_functions.sql
```

## Impact

### ✅ iOS (SubscribeCoffieClean)
**Status**: Already canonical ✓  
**Action**: None needed - already uses `balance_credits`, `lifetime_top_up_credits`

### ⚠️ Admin Panel (subscribecoffie-admin)
**Status**: Updated to canonical ✓  
**Action**: Code updated, test after migration
**Known issues**:
- `addManualTransaction()` - Temporarily disabled (RPC deprecated)
- Need to implement direct wallet update or new RPC

### ✅ Backend (SubscribeCoffieBackend)
**Status**: Migrations ready ✓  
**Action**: Apply migrations, test thoroughly

## Verification Queries

```sql
-- Check schema
\d public.wallets

-- Wallet counts by type
SELECT wallet_type, COUNT(*) 
FROM public.wallets 
GROUP BY wallet_type;

-- Check for data issues
SELECT COUNT(*) as negative_balance 
FROM public.wallets 
WHERE balance_credits < 0;

-- Total balance
SELECT SUM(balance_credits) as total_balance 
FROM public.wallets;
```

## Testing Checklist

- [ ] Apply migrations to dev database
- [ ] Admin: View wallets list (`/admin/wallets`)
- [ ] Admin: View wallet detail (`/admin/wallets/[userId]`)
- [ ] iOS: Check Profile wallet display
- [ ] iOS: Test wallet top-up flow
- [ ] iOS: Check transactions history
- [ ] Backend: Run `tests/wallets_rpc.test.sql`

## Rollback (Emergency)

```sql
-- WARNING: Will lose bonus_balance data
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

## Files Changed

### Migrations
- `supabase/migrations/20260205000001_fix_wallets_rls_security.sql`
- `supabase/migrations/20260205000002_expand_wallet_transactions.sql`
- `supabase/migrations/20260205000003_unify_wallets_schema.sql`
- `supabase/migrations/20260205000004_deprecate_wallet_sync_functions.sql`

### Admin Panel
- `lib/supabase/queries/wallets.ts` - Updated types & queries
- `app/admin/wallets/page.tsx` - Display canonical fields
- `app/admin/wallets/[userId]/page.tsx` - Detail page
- `app/admin/wallets/actions.ts` - Deprecated old actions

### iOS App
- No changes needed (already canonical)

## Documentation

Full details: [WALLET_SCHEMA_UNIFICATION.md](./WALLET_SCHEMA_UNIFICATION.md)
