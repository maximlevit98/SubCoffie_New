# Wallet Creation Idempotency

**Date**: 2026-02-05  
**Status**: ✅ Implemented

## Overview

Functions `create_citypass_wallet` and `create_cafe_wallet` are now **idempotent** - they return existing wallet ID instead of throwing an error if wallet already exists.

## Changes

### 1. `create_citypass_wallet` - Idempotent

**Before:**
- If CityPass wallet exists → ❌ `raise exception 'User already has a CityPass wallet'`

**After:**
- If CityPass wallet exists → ✅ Return existing wallet ID
- If no wallet → Create new and return ID

**Security:**
- Uses `auth.uid()` from JWT token (ignores `p_user_id` parameter)
- Validates user exists in `auth.users`
- Raises "Not authenticated" if JWT missing
- Raises "User not found" if user not in database

### 2. `create_cafe_wallet` - Idempotent

**Before:**
- If Cafe Wallet exists for cafe/network → ❌ `raise exception 'User already has a Cafe Wallet'`

**After:**
- If Cafe Wallet exists for cafe/network → ✅ Return existing wallet ID
- If no wallet → Create new and return ID

**Security:**
- Uses `auth.uid()` from JWT token (ignores `p_user_id` parameter)
- Validates user exists in `auth.users`
- Validates `cafe_id` OR `network_id` provided (not both)

## Implementation

**File:** `supabase/migrations/20260201000002_wallet_types_mock_payments.sql`

**Key Changes:**
1. Replaced `raise exception` with `return v_wallet_id` when wallet exists
2. Added `🔄 IDEMPOTENT` markers in comments
3. Updated function comments to indicate idempotent behavior

## Benefits

### For iOS App
- ✅ No need to handle "already exists" errors
- ✅ Simplified wallet selection flow
- ✅ Can call `create_*_wallet` multiple times safely
- ✅ No race conditions if multiple requests happen

### For Backend
- ✅ Cleaner API semantics (create-or-get pattern)
- ✅ Aligns with REST idempotency principles
- ✅ Safer for retry logic and network issues

## Usage Example

**iOS Code (before):**
```swift
do {
    let walletId = try await walletService.createCityPassWallet(userId: userId)
} catch {
    if error.localizedDescription.contains("already has") {
        // Load existing wallet
        await realWalletStore.refreshWallets()
        if let existing = realWalletStore.cityPassWallet {
            return existing.id
        }
    }
}
```

**iOS Code (after):**
```swift
// Just call create - it returns existing or new wallet ID
let walletId = try await walletService.createCityPassWallet(userId: userId)
// Done! ✅
```

## Testing

### Manual Test
1. Login to iOS app
2. Click "Пополнить CityPass" → Creates wallet (first time)
3. Click "Пополнить CityPass" again → Returns same wallet (idempotent)
4. Check logs: should see same `wallet_id` both times

### Database Test
```sql
-- Call once
select create_citypass_wallet('00000000-0000-0000-0000-000000000000');
-- Returns: abc123...

-- Call again
select create_citypass_wallet('00000000-0000-0000-0000-000000000000');
-- Returns: abc123... (same ID, no error)
```

## Migration Status

✅ Applied in: `20260201000002_wallet_types_mock_payments.sql`  
✅ Database reset: Successful  
✅ iOS build: Successful

## Related Files

- **Migration**: `supabase/migrations/20260201000002_wallet_types_mock_payments.sql`
- **iOS Service**: `SubscribeCoffieClean/Helpers/WalletService.swift`
- **iOS Store**: `SubscribeCoffieClean/Stores/RealWalletStore.swift`
- **iOS View**: `SubscribeCoffieClean/ContentView.swift`

## Notes

- Functions remain `SECURITY DEFINER` for security
- `p_user_id` parameter kept for API compatibility but ignored
- JWT `auth.uid()` is the only source of truth for user identity
- Both functions perform same security checks before create/return
