# Admin Panel Wallet Multi-Wallet Support

**Date**: 2026-02-05 (Prompt 4 - P0)  
**Status**: ✅ COMPLETE

## Summary

Updated admin panel to support **multiple wallets per user** (CityPass + Cafe Wallets) using canonical schema.

---

## What Changed

### 1. ✅ Updated Types (`lib/supabase/queries/wallets.ts`)

**Before**:
```typescript
type Wallet = {
  balance: number;
  bonus_balance: number;
  lifetime_topup: number;
}
```

**After**:
```typescript
type Wallet = {
  id: string;
  wallet_type: "citypass" | "cafe_wallet";
  balance_credits: number;
  lifetime_top_up_credits: number;
  cafe_id: string | null;
  cafe_name: string | null;
  network_id: string | null;
  network_name: string | null;
  created_at: string;
};

type WalletWithUser = Wallet & {
  user_id: string;
  profiles?: { ... };
};
```

### 2. ✅ Updated Queries

**`listWallets()`**:
- Returns `WalletWithUser[]`
- Transforms Supabase response to canonical format
- Joins `cafe_name` and `network_name`

**`getWalletsByUserId(userId)`**:
- **NEW**: Returns array of all user's wallets
- Uses `get_user_wallets(p_user_id)` RPC
- Replaces old `getWalletByUserId()` which returned single wallet

### 3. ✅ Updated Actions (`app/admin/wallets/actions.ts`)

**`getUserWallets(userId)`**:
- Returns `Wallet[]` (array)
- Uses `get_user_wallets(p_user_id)` RPC
- Replaced `getUserWallet()` which returned single wallet

**`getUserTransactions(walletId, limit, offset)`**:
- Now accepts `walletId` instead of `userId`
- Direct query to `wallet_transactions` table

### 4. ✅ Updated UI

#### Wallets List Page (`app/admin/wallets/page.tsx`)

**Before**: Table showing all wallets (one row per wallet)

**After**: 
- **Groups wallets by user** (one row per user)
- Shows wallet count per user
- Shows wallet type badges (CP for CityPass, Cafe for Cafe Wallet)
- Displays total balance across all user's wallets
- Displays total lifetime top-up across all user's wallets

**New columns**:
- "Кошельков" - wallet count
- "Типы" - visual badges for each wallet type
- "Общий баланс" - sum of all wallet balances
- "Всего пополнено" - sum of all lifetime top-ups

**Stats updated**:
- Added "Пользователей" stat
- Shows "Средн. X кош./польз." (average wallets per user)

#### Wallet Detail Page (`app/admin/wallets/[userId]/page.tsx`)

**Before**: Single wallet info + transactions

**After**:
- **Displays all user's wallets as cards** (grid layout)
- Each card shows:
  - Wallet type badge (CityPass / Cafe Wallet)
  - Cafe/Network name (for cafe wallets)
  - Balance
  - Lifetime top-up
  - Created date
  - Wallet ID (truncated)
- Color-coded cards:
  - CityPass: Blue border & background
  - Cafe Wallet: Green border & background
- **Transactions table**: Shows transactions from ALL wallets
  - Added "Кошелёк" column with wallet type badge
  - Sorted by date (newest first)

---

## UI Screenshots (Conceptual)

### Wallets List Page

```
┌─────────────────────────────────────────────────────────────────┐
│ Пользователь  │ Телефон │ Кош-в │ Типы      │ Баланс │ Пополн. │
├─────────────────────────────────────────────────────────────────┤
│ Иван Иванов  │ +7...   │   2   │ [CP][Cafe]│ 1500кр │ 5000кр  │
│ Мария Петрова│ +7...   │   1   │ [CP]      │  800кр │ 3000кр  │
│ ...          │         │       │           │        │         │
└─────────────────────────────────────────────────────────────────┘
```

### Wallet Detail Page

```
┌──────────────────────────────────────────────────────────────────┐
│ Кошельки пользователя | User ID: abc123... | Кошельков: 2        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │ 🔵 CityPass     │  │ 🟢 Cafe Wallet  │                       │
│  │                 │  │ Coffee Point    │                       │
│  │ Баланс:         │  │ Баланс:         │                       │
│  │ 1200 кр.        │  │ 300 кр.         │                       │
│  │                 │  │                 │                       │
│  │ Всего: 4000 кр. │  │ Всего: 1000 кр. │                       │
│  └─────────────────┘  └─────────────────┘                       │
│                                                                   │
│  История транзакций (все кошельки)                               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Дата │ Кошелёк │ Тип │ Описание │ До │ Сумма │ После │    │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │ ...  │  [CP]   │ Top │ ...      │... │  +500 │ ...   │    │ │
│  │ ...  │ [Cafe]  │ Pay │ ...      │... │  -100 │ ...   │    │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Breaking Changes

### API Changes

1. **`getWalletByUserId()` → `getWalletsByUserId()`**
   - Returns `Wallet[]` instead of `Wallet | null`
   - Always returns array (empty if no wallets)

2. **`getUserWallet()` → `getUserWallets()`**
   - Returns `Wallet[]` instead of `Wallet | null`
   - Server action name changed

3. **`getUserTransactions(userId, ...)` → `getUserTransactions(walletId, ...)`**
   - First parameter changed from `userId` to `walletId`
   - Direct query instead of RPC

### UI Changes

1. **Wallets list page**:
   - Now groups by user (fewer rows)
   - Shows aggregated stats per user
   - Multiple wallet type badges

2. **Wallet detail page**:
   - Shows multiple wallet cards
   - Transactions include wallet column
   - Manual transaction form temporarily disabled

---

## Testing

### Manual Testing Checklist

- [ ] Navigate to `/admin/wallets`
- [ ] Verify users are grouped (not individual wallets)
- [ ] Check wallet count per user
- [ ] Verify wallet type badges display correctly
- [ ] Check total balance calculation
- [ ] Click "Управление →" for a user with multiple wallets
- [ ] Verify multiple wallet cards display
- [ ] Check CityPass cards have blue styling
- [ ] Check Cafe Wallet cards have green styling
- [ ] Verify cafe/network names display for cafe wallets
- [ ] Check transactions table shows all wallets
- [ ] Verify wallet column in transactions table

### Database Testing

```sql
-- Get users with multiple wallets
SELECT user_id, COUNT(*) as wallet_count
FROM public.wallets
GROUP BY user_id
HAVING COUNT(*) > 1;

-- Get wallet type breakdown
SELECT 
  w.user_id,
  COUNT(CASE WHEN w.wallet_type = 'citypass' THEN 1 END) as citypass_count,
  COUNT(CASE WHEN w.wallet_type = 'cafe_wallet' THEN 1 END) as cafe_wallet_count,
  SUM(w.balance_credits) as total_balance
FROM public.wallets w
GROUP BY w.user_id;

-- Test get_user_wallets RPC
SELECT * FROM public.get_user_wallets('USER_ID_HERE');
```

---

## Known Issues & TODO

### ⚠️ Temporarily Disabled

- **Manual transaction form**: Disabled because `add_wallet_transaction` RPC deprecated
- Need to implement new RPC or direct wallet update logic

### 📝 Future Enhancements

- [ ] Add wallet selector in manual transaction form
- [ ] Filter wallets list by wallet type
- [ ] Search wallets by cafe/network name
- [ ] Add "Create Wallet" button for users
- [ ] Show wallet usage statistics (transaction count, last used)
- [ ] Add wallet type icons/emojis

---

## Files Modified

### Queries
- `lib/supabase/queries/wallets.ts`
  - Updated `Wallet` type
  - Added `WalletWithUser` type
  - `listWallets()` - returns grouped data
  - `getWalletsByUserId()` - new, returns array

### Actions
- `app/admin/wallets/actions.ts`
  - `getUserWallets()` - new name, returns array
  - `getUserTransactions()` - changed parameter

### UI
- `app/admin/wallets/page.tsx`
  - Groups wallets by user
  - Shows wallet type badges
  - Aggregates balance/lifetime

- `app/admin/wallets/[userId]/page.tsx`
  - Multiple wallet cards display
  - Color-coded by type
  - Transactions from all wallets
  - Added `WalletCard` component
  - Added `WalletTypeBadge` component

---

## Migration Path

1. ✅ **DONE**: Schema unified (Prompt 3)
2. ✅ **DONE**: Queries updated to canonical schema
3. ✅ **DONE**: UI updated to show multiple wallets
4. ⏳ **TODO**: Apply migrations to database
5. ⏳ **TODO**: Test admin panel thoroughly
6. ⏳ **TODO**: Implement new manual transaction logic

---

## RPC Reference

### `get_user_wallets(p_user_id uuid)`

**Returns**:
```sql
TABLE (
  id uuid,
  wallet_type wallet_type,
  balance_credits int,
  lifetime_top_up_credits int,
  cafe_id uuid,
  cafe_name text,
  network_id uuid,
  network_name text,
  created_at timestamptz
)
```

**Usage**:
```sql
SELECT * FROM public.get_user_wallets('USER_ID');
```

**JavaScript (Supabase)**:
```typescript
const { data, error } = await supabase.rpc("get_user_wallets", {
  p_user_id: userId,
});
```

---

## References

- Schema migration: `20260205000003_unify_wallets_schema.sql`
- RPC definition: `20260201000002_wallet_types_mock_payments.sql`
- Previous docs: `WALLET_SCHEMA_UNIFICATION.md`

---

**Status**: ✅ Complete  
**Ready for testing**: Yes  
**Date**: 2026-02-05 (Prompt 4)
