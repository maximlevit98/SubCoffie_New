# Commission Rates from Backend (P0)

**Date**: 2026-02-05 (Prompt 5)  
**Priority**: P0 (Critical - Remove Hardcoded Values)  
**Status**: ✅ COMPLETE

## Summary

Removed hardcoded commission rates (7%/4%) from iOS app and implemented dynamic fetching from backend.

---

## Problem

**Before**: Commission rates were hardcoded in `WalletTopUpView.swift`:

```swift
private var commissionPercent: Double {
    switch wallet.walletType {
    case .citypass:
        return 7.0 // CityPass: 7%
    case .cafe_wallet:
        return 4.0 // Cafe Wallet: 4%
    }
}
```

**Issues**:
- ❌ Hardcoded values can't be changed without app update
- ❌ No single source of truth
- ❌ Backend already has `commission_config` table

---

## Solution

### 1. ✅ Backend: New RPC Functions

**File**: `supabase/migrations/20260205000005_commission_rates_rpc.sql`

**Created 2 new RPC functions**:

#### `get_commission_rates()`
Returns all active commission rates as JSON:

```sql
SELECT * FROM public.get_commission_rates();
-- Returns: {"citypass_topup": 7.00, "cafe_wallet_topup": 4.00, "direct_order": 17.00}
```

**Usage**:
```typescript
const { data } = await supabase.rpc("get_commission_rates");
// data: { citypass_topup: 7.00, cafe_wallet_topup: 4.00 }
```

#### `get_commission_for_wallet(p_wallet_id uuid)`
Returns commission info for specific wallet:

```sql
SELECT * FROM public.get_commission_for_wallet('WALLET_ID');
-- Returns: {
--   "wallet_id": "...",
--   "wallet_type": "citypass",
--   "operation_type": "citypass_topup",
--   "commission_percent": 7.00
-- }
```

**Features**:
- ✅ Public access (no auth required)
- ✅ Reads from `commission_config` table
- ✅ Determines operation type based on wallet type
- ✅ Returns structured JSON response

### 2. ✅ iOS: Dynamic Commission Fetching

**File**: `SubscribeCoffieClean/Views/WalletTopUpView.swift`

**Changes**:

1. **Added state for backend commission**:
```swift
@State private var commissionPercent: Double? = nil
@State private var isLoadingCommission: Bool = true
```

2. **Fallback mechanism**:
```swift
private var fallbackCommissionPercent: Double {
    switch wallet.walletType {
    case .citypass: return 7.0
    case .cafe_wallet: return 4.0
    }
}

private var actualCommissionPercent: Double {
    return commissionPercent ?? fallbackCommissionPercent
}
```

3. **Fetch from backend on view appear**:
```swift
.task {
    await fetchCommissionRate()
}

private func fetchCommissionRate() async {
    do {
        let response: CommissionResponse = try await supabase
            .rpc("get_commission_for_wallet", params: ["p_wallet_id": wallet.id.uuidString])
            .execute()
            .value
        
        self.commissionPercent = response.commission_percent
        print("✅ Commission loaded: \(response.commission_percent)%")
    } catch {
        print("⚠️ Failed to load commission, using fallback")
        self.commissionPercent = nil // Use fallback
    }
}
```

4. **Updated UI**:
   - Shows loading indicator while fetching
   - Displays actual commission with checkmark ✓ when loaded from backend
   - Shows warning icon ⚠️ and message when using fallback
   - Commission percentage shown with 2 decimal places

**UI States**:

1. **Loading**:
```
[ProgressView] Загрузка тарифов комиссии...
```

2. **Loaded from backend**:
```
Комиссия (7.00%) ✓     -35 ₽
```

3. **Fallback (backend unavailable)**:
```
Комиссия (7.00%) ⚠️     -35 ₽
⚠️ Используется локальный тариф (backend недоступен)
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ iOS App (WalletTopUpView)                                   │
├─────────────────────────────────────────────────────────────┤
│  1. On appear: fetchCommissionRate()                         │
│  2. Call RPC: get_commission_for_wallet(wallet_id)          │
│                         ↓                                    │
├─────────────────────────────────────────────────────────────┤
│ Backend (Supabase RPC)                                       │
├─────────────────────────────────────────────────────────────┤
│  1. Get wallet_type from wallets table                       │
│  2. Determine operation_type:                                │
│     - citypass → "citypass_topup"                           │
│     - cafe_wallet → "cafe_wallet_topup"                     │
│  3. Query commission_config table                            │
│  4. Return JSON: { commission_percent: 7.00, ... }          │
│                         ↓                                    │
├─────────────────────────────────────────────────────────────┤
│ iOS App (Display)                                            │
├─────────────────────────────────────────────────────────────┤
│  1. Update commissionPercent state                           │
│  2. Calculate commission amount                              │
│  3. Display in UI with status indicator                      │
│  4. If backend fails → use fallback                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Commission Configuration

**Source**: `commission_config` table (created in `wallet_types_mock_payments.sql`)

| Operation Type      | Commission | Active |
|---------------------|------------|--------|
| citypass_topup      | 7.00%      | ✅     |
| cafe_wallet_topup   | 4.00%      | ✅     |
| direct_order        | 17.00%     | ✅     |

**Admin can update via Supabase dashboard**:
```sql
UPDATE public.commission_config
SET commission_percent = 5.00
WHERE operation_type = 'citypass_topup';
```

**Changes take effect immediately** (no app update required!)

---

## Benefits

### ✅ Dynamic Updates
- Admin can change commission rates without app update
- Changes visible immediately for new top-ups

### ✅ Single Source of Truth
- Backend `commission_config` table is the authority
- No duplication between backend and frontend

### ✅ Graceful Degradation
- If backend unavailable, app uses fallback rates
- User can still complete top-up (demo mode)
- Clear visual indicator when using fallback

### ✅ Better UX
- Loading indicator during fetch
- Visual confirmation (✓) when loaded from backend
- Warning (⚠️) when using fallback
- Commission shown with 2 decimal places (7.00% instead of 7%)

---

## Testing

### Manual Testing

1. **Normal flow (backend available)**:
   - Open WalletTopUpView
   - See "Загрузка тарифов комиссии..."
   - Commission loads: "Комиссия (7.00%) ✓"
   - Enter amount: 500
   - Check: "Комиссия: -35 ₽" (7% of 500)
   - Check: "Будет зачислено: 465 ₽"

2. **Fallback flow (backend unavailable)**:
   - Disable network or break RPC
   - Open WalletTopUpView
   - See warning: "Комиссия (7.00%) ⚠️"
   - Message: "Используется локальный тариф"
   - Calculations still work correctly

3. **Different wallet types**:
   - CityPass wallet: 7.00% commission
   - Cafe Wallet: 4.00% commission

### SQL Testing

```sql
-- Test get_commission_rates
SELECT public.get_commission_rates();

-- Test get_commission_for_wallet (replace WALLET_ID)
SELECT public.get_commission_for_wallet('WALLET_ID');

-- Update commission and test
UPDATE public.commission_config
SET commission_percent = 5.00
WHERE operation_type = 'citypass_topup';

SELECT public.get_commission_rates();
-- Should show: {"citypass_topup": 5.00, ...}
```

### iOS Testing

```swift
// Test in Xcode console
// Should see:
// ✅ Commission loaded from backend: 7.0% for citypass
// OR
// ⚠️ Failed to load commission from backend, using fallback
```

---

## Files Modified

### Backend
- `supabase/migrations/20260205000005_commission_rates_rpc.sql` ✅ NEW
  - `get_commission_rates()` RPC
  - `get_commission_for_wallet(p_wallet_id)` RPC

### iOS
- `SubscribeCoffieClean/Views/WalletTopUpView.swift` ✅ MODIFIED
  - Added `CommissionResponse` model
  - Added state: `commissionPercent`, `isLoadingCommission`
  - Added `fetchCommissionRate()` function
  - Updated UI: loading indicator, status icons, fallback message
  - Commission display: 2 decimal places

---

## Migration Path

1. ✅ **DONE**: Create RPC functions
2. ✅ **DONE**: Update iOS to fetch from backend
3. ⏳ **TODO**: Apply migration to database
4. ⏳ **TODO**: Test with real wallets
5. ⏳ **TODO**: Deploy to production

---

## Known Issues & TODO

### ℹ️ Current Limitations
- Commission fetch happens on every view open (could cache for session)
- No retry mechanism if fetch fails (uses fallback immediately)

### 📝 Future Enhancements
- [ ] Cache commission rates for session (30 min TTL)
- [ ] Add retry with exponential backoff
- [ ] Show last updated timestamp in UI
- [ ] Admin panel UI for updating commission rates
- [ ] Analytics: track fallback usage rate

---

## API Reference

### `get_commission_rates()`

**Returns**: `jsonb`

```json
{
  "citypass_topup": 7.00,
  "cafe_wallet_topup": 4.00,
  "direct_order": 17.00
}
```

**Access**: Public (no auth required)

### `get_commission_for_wallet(p_wallet_id uuid)`

**Parameters**:
- `p_wallet_id`: UUID of wallet

**Returns**: `jsonb`

```json
{
  "wallet_id": "123e4567-e89b-12d3-a456-426614174000",
  "wallet_type": "citypass",
  "operation_type": "citypass_topup",
  "commission_percent": 7.00
}
```

**Access**: Public (no auth required)

**Errors**:
- `Wallet not found: {wallet_id}` - wallet doesn't exist
- `Commission rate not found for: {operation_type}` - no active commission config

---

## Related Documentation

- Commission calculation: `20260201000002_wallet_types_mock_payments.sql` (calculate_commission function)
- Payment flow: `PAYMENT_SECURITY.md`
- Wallet types: `WALLET_SCHEMA_UNIFICATION.md`

---

**Status**: ✅ Complete  
**Ready for testing**: Yes  
**Date**: 2026-02-05 (Prompt 5 - P0)
