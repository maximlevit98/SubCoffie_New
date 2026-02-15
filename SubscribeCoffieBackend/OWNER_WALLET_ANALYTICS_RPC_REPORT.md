# ✅ OWNER WALLET ANALYTICS RPC - FINAL REPORT

**Date**: 2026-02-15  
**Agent**: Backend Agent  
**Status**: ✅ **ALL TASKS COMPLETE**

---

## 📊 Executive Summary

**Migration**: `20260215000010_owner_wallet_analytics_rpc.sql`  
**Test File**: `tests/owner_wallet_analytics_security.sql`  
**API Contract**: `SUPABASE_API_CONTRACT.md` (updated)  
**Status**: ✅ Production Ready

Создано **6 owner-scoped RPC функций** для аналитики кошельков с строгим контролем доступа: owner видит только кошельки для своих кофеен.

---

## 🔒 Security Model

### Owner Access Control

**Правило**: Owner может видеть **только** `cafe_wallet` для кофеен, которыми он владеет.

**Проверка владения**:
```sql
-- Owner owns cafe if:
SELECT 1 
FROM cafes c
JOIN accounts a ON c.account_id = a.id
WHERE c.id = p_cafe_id 
  AND a.owner_user_id = auth.uid()
```

### Access Matrix

| Role | CityPass Wallets | Cafe Wallets (Own) | Cafe Wallets (Other) |
|------|------------------|-------------------|----------------------|
| **Owner** | ❌ No access | ✅ Full access | ❌ No access |
| **Admin** | ✅ Full access | ✅ Full access | ✅ Full access |
| **User** | ❌ No access | ❌ No access | ❌ No access |

### Why Owner Can't See CityPass Wallets

CityPass wallets are **not cafe-specific** (`cafe_id = NULL`). They can be used across all cafes, so they don't belong to any single owner's scope.

**Example**:
- User has CityPass wallet with 1000 credits
- User visits Owner A's cafe → spends 100 credits
- User visits Owner B's cafe → spends 50 credits
- **Neither Owner A nor B can see the CityPass wallet** (not their property)
- Both owners can see the **orders** from this wallet in their cafe order history

---

## 📋 RPC Functions (6/6)

### 1. ✅ `owner_get_wallets`

**Purpose**: List wallets for owner's cafes with pagination and search.

**Signature**:
```sql
owner_get_wallets(
  p_cafe_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL
)
```

**Security**:
- ✅ Owner/admin role check
- ✅ Cafe ownership verification (if `p_cafe_id` provided)
- ✅ Filters to only `cafe_wallet` for owned cafes
- ✅ Search sanitization
- ✅ Pagination validation (1-200)

**Returns**: List of wallets with user info, cafe info, activity stats

---

### 2. ✅ `owner_get_wallet_overview`

**Purpose**: Detailed wallet information.

**Signature**:
```sql
owner_get_wallet_overview(p_wallet_id uuid)
```

**Security**:
- ✅ Owner/admin role check
- ✅ NULL wallet_id validation
- ✅ Wallet ownership verification (checks if wallet's cafe is owned)

**Returns**: Full wallet details + user info + aggregated stats

---

### 3. ✅ `owner_get_wallet_transactions`

**Purpose**: Transaction history for wallet.

**Signature**:
```sql
owner_get_wallet_transactions(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
```

**Security**: Same as `owner_get_wallet_overview` + pagination validation

**Returns**: Transaction history with balance snapshots, actor info

---

### 4. ✅ `owner_get_wallet_payments`

**Purpose**: Payment transactions (topups) for wallet.

**Signature**:
```sql
owner_get_wallet_payments(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
```

**Security**: Same as `owner_get_wallet_overview` + pagination validation

**Returns**: Payment history with gross/net amounts, commission, idempotency keys

---

### 5. ✅ `owner_get_wallet_orders`

**Purpose**: Orders with itemized breakdown.

**Signature**:
```sql
owner_get_wallet_orders(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
```

**Security**: Same as `owner_get_wallet_overview` + pagination validation

**Returns**: Order history with **itemized breakdown** (items as jsonb array)

**Note**: Uses canonical `bonus_used` field (not `bonus_used_credits`)

---

### 6. ✅ `owner_get_wallets_stats`

**Purpose**: Aggregated stats for owner's wallets.

**Signature**:
```sql
owner_get_wallets_stats(p_cafe_id uuid DEFAULT NULL)
```

**Security**:
- ✅ Owner/admin role check
- ✅ Cafe ownership verification (if `p_cafe_id` provided)
- ✅ Aggregates only wallets for owned cafes

**Returns**:
- `total_wallets`: Count of wallets
- `total_balance_credits`: Sum of all balances
- `total_lifetime_topup_credits`: Sum of lifetime topups
- `total_transactions`: Total transaction count
- `total_orders`: Total order count
- `total_revenue_credits`: Sum of `paid_credits + bonus_used`
- `avg_wallet_balance`: Average balance across wallets
- `active_wallets_30d`: Wallets with transactions in last 30 days

---

## 🛡️ Helper Functions (3)

### 1. `is_owner_or_admin()`
Returns `true` if current user has role `owner` or `admin`.

### 2. `verify_cafe_ownership(p_cafe_id)`
Returns `true` if:
- User is admin (bypass check), OR
- User is owner AND owns the cafe via `accounts.owner_user_id`

### 3. `verify_wallet_ownership(p_wallet_id)`
Returns `true` if:
- User is admin (bypass check), OR
- User is owner AND wallet is `cafe_wallet` for owned cafe

**CityPass wallets** (`cafe_id = NULL`) always return `false` for owners.

---

## ⚡ Performance Indexes (2)

### 1. `idx_wallets_cafe_type_owner`
```sql
CREATE INDEX idx_wallets_cafe_type_owner 
ON wallets(cafe_id, wallet_type) 
WHERE wallet_type = 'cafe_wallet';
```

**Purpose**: Fast filtering of cafe wallets by cafe_id

### 2. `idx_cafes_account_owner`
```sql
CREATE INDEX idx_cafes_account_owner 
ON cafes(account_id) 
WHERE account_id IS NOT NULL;
```

**Purpose**: Fast owner lookup via `accounts.owner_user_id`

---

## 🧪 Test Results

### 1. Database Reset ✅
```bash
supabase db reset
✅ Migration 20260215000010_owner_wallet_analytics_rpc.sql applied
```

### 2. Security Tests ✅
```bash
psql -f tests/owner_wallet_analytics_security.sql

✅ owner_get_wallets: Security check passed
✅ owner_get_wallet_overview: Security check passed
✅ owner_get_wallet_transactions: Security check passed
✅ owner_get_wallet_payments: Security check passed
✅ owner_get_wallet_orders: Security check passed
✅ owner_get_wallets_stats: Security check passed
✅ is_owner_or_admin: Returns false for unauthenticated
✅ verify_cafe_ownership: Returns false for unauthenticated
✅ verify_wallet_ownership: Returns false for unauthenticated
✅ Owner performance indexes: 2 of 2 created
```

---

## 📊 Response Contract Compatibility

**100% compatible with admin RPC response structure**.

Frontend components can be reused:

```typescript
// Same interface works for both admin and owner
interface WalletListItem {
  wallet_id: string;
  user_email: string;
  balance_credits: number;
  cafe_name: string;
  // ... same fields
}

// Call as admin
const adminWallets = await supabase.rpc('admin_get_wallets', { ... });

// Call as owner (same response structure)
const ownerWallets = await supabase.rpc('owner_get_wallets', { ... });

// ✅ Both return same TypeScript interface
```

**Only difference**: Owner RPC automatically filters to owned cafes.

---

## 🔐 Security Guarantees

### ✅ No Data Leakage

**Scenario**: Owner A tries to access Owner B's wallet

```typescript
// Owner A's cafe: cafe_123
// Owner B's cafe: cafe_456
// Wallet belongs to cafe_456

const result = await supabase.rpc('owner_get_wallet_overview', {
  p_wallet_id: 'wallet_for_cafe_456'
});

// ❌ ERROR: Unauthorized: wallet not accessible
```

### ✅ CityPass Exclusion

**Scenario**: Owner tries to access CityPass wallet

```typescript
// CityPass wallet: cafe_id = NULL

const result = await supabase.rpc('owner_get_wallet_overview', {
  p_wallet_id: 'citypass_wallet_id'
});

// ❌ ERROR: Unauthorized: wallet not accessible
// (CityPass wallets excluded from owner scope)
```

### ✅ Admin Bypass

**Scenario**: Admin can access all wallets

```typescript
// Admin user

const result = await supabase.rpc('owner_get_wallet_overview', {
  p_wallet_id: 'any_wallet_id'
});

// ✅ SUCCESS: Admin bypasses ownership check
```

---

## 📁 Created Files

### 1. Migration (NEW)
```
supabase/migrations/20260215000010_owner_wallet_analytics_rpc.sql (30 KB)
```
- 3 helper functions
- 6 owner RPC functions
- 2 performance indexes
- Full security checks

### 2. Test File (NEW)
```
tests/owner_wallet_analytics_security.sql (9 KB)
```
- 9 security tests
- Ownership verification
- Index verification

### 3. API Contract (UPDATED)
```
SUPABASE_API_CONTRACT.md
```
- Added "Owner Wallet Analytics RPC" section
- Full API documentation
- TypeScript interfaces
- Error cases

---

## 🚀 Integration Example

### Owner Panel (Next.js)

```typescript
// lib/supabase/queries/ownerWalletQueries.ts
import { createClient } from '@/lib/supabase/server';

export async function getOwnerWallets(cafeId?: string, search?: string) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('owner_get_wallets', {
    p_cafe_id: cafeId || null,
    p_limit: 50,
    p_offset: 0,
    p_search: search || null
  });
  
  if (error) throw error;
  return data;
}

export async function getOwnerWalletStats(cafeId?: string) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('owner_get_wallets_stats', {
    p_cafe_id: cafeId || null
  });
  
  if (error) throw error;
  return data[0]; // Single row
}
```

### Owner Dashboard

```typescript
// app/cafe-owner/wallets/page.tsx
import { getOwnerWallets, getOwnerWalletStats } from '@/lib/supabase/queries/ownerWalletQueries';

export default async function OwnerWalletsPage() {
  const wallets = await getOwnerWallets();
  const stats = await getOwnerWalletStats();
  
  return (
    <div>
      <h1>Кошельки моих кофеен</h1>
      
      <div>
        <p>Всего кошельков: {stats.total_wallets}</p>
        <p>Общий баланс: {stats.total_balance_credits} кредитов</p>
        <p>Активных за 30 дней: {stats.active_wallets_30d}</p>
      </div>
      
      <ul>
        {wallets.map(w => (
          <li key={w.wallet_id}>
            {w.user_full_name} ({w.user_email}) - 
            {w.cafe_name} - 
            {w.balance_credits} кредитов
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

## 📝 Canonical Schema Fields

✅ Uses canonical field names:
- `bonus_used` (not `bonus_used_credits`)
- `balance_credits` (not `credits_balance`)
- `wallet_type` enum: `'citypass'` | `'cafe_wallet'`

---

## 🎯 Итог

✅ **6 owner RPC functions** created  
✅ **Strict ownership verification** (via `accounts.owner_user_id`)  
✅ **CityPass exclusion** (not owner-scoped)  
✅ **100% compatible** with admin RPC response structure  
✅ **2 performance indexes** for fast owner queries  
✅ **9 security tests** passed  
✅ **API contract** updated  

**Owner wallet analytics ready for production with enterprise-grade security.**

---

## 📚 Git Info

**Changed/Created Files**:
1. `supabase/migrations/20260215000010_owner_wallet_analytics_rpc.sql` (NEW)
2. `tests/owner_wallet_analytics_security.sql` (NEW)
3. `SUPABASE_API_CONTRACT.md` (UPDATED)

**Next Step**: Integration with Owner Admin Panel (Frontend-Agent)

---

**Full Report**: `OWNER_WALLET_ANALYTICS_RPC_REPORT.md`
