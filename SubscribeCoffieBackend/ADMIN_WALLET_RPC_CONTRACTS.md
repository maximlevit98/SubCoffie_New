# 📚 Admin Wallet RPC API Contracts

**Date**: 2026-02-14  
**Migration**: `20260214000008_admin_wallet_rpc_contracts.sql`  
**Status**: ✅ Production Ready

---

## 🔐 Authentication

**All admin wallet RPCs require admin role.**

- Functions check `auth.uid()` and verify `profiles.role = 'admin'`
- Returns error `Admin access required` if user is not admin
- Must be called with valid admin JWT token via `Authorization: Bearer <token>`

---

## 📋 RPC Functions

### 1. `admin_get_wallets` - List all wallets

**Purpose**: Get paginated list of all wallets with user info and activity stats.

**Signature**:
```sql
admin_get_wallets(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL
)
```

**Parameters**:
- `p_limit`: Max results (default 50)
- `p_offset`: Pagination offset (default 0)
- `p_search`: Optional search term (searches user email, phone, full_name, cafe name)

**Returns** (TABLE):
```typescript
{
  wallet_id: uuid,
  user_id: uuid,
  wallet_type: 'citypass' | 'cafe_wallet',
  balance_credits: number,
  lifetime_top_up_credits: number,
  created_at: timestamp,
  user_email: string,
  user_phone: string,
  user_full_name: string,
  cafe_id: uuid | null,
  cafe_name: string | null,
  network_id: uuid | null,
  network_name: string | null,
  last_transaction_at: timestamp | null,
  last_payment_at: timestamp | null,
  last_order_at: timestamp | null,
  total_transactions: number,
  total_payments: number,
  total_orders: number
}[]
```

**Example Usage** (from admin panel):
```typescript
const { data, error } = await supabase.rpc('admin_get_wallets', {
  p_limit: 20,
  p_offset: 0,
  p_search: 'john@example.com'
});
```

---

### 2. `admin_get_wallet_overview` - Detailed wallet info

**Purpose**: Get comprehensive overview of a specific wallet.

**Signature**:
```sql
admin_get_wallet_overview(p_wallet_id uuid)
```

**Parameters**:
- `p_wallet_id`: Wallet ID to retrieve

**Returns** (TABLE with single row):
```typescript
{
  wallet_id: uuid,
  user_id: uuid,
  wallet_type: 'citypass' | 'cafe_wallet',
  balance_credits: number,
  lifetime_top_up_credits: number,
  created_at: timestamp,
  updated_at: timestamp,
  user_email: string,
  user_phone: string,
  user_full_name: string,
  user_avatar_url: string | null,
  user_registered_at: timestamp,
  cafe_id: uuid | null,
  cafe_name: string | null,
  cafe_address: string | null,
  network_id: uuid | null,
  network_name: string | null,
  total_transactions: number,
  total_topups: number,
  total_payments: number,
  total_refunds: number,
  total_orders: number,
  completed_orders: number,
  last_transaction_at: timestamp | null,
  last_payment_at: timestamp | null,
  last_order_at: timestamp | null
}
```

**Example Usage**:
```typescript
const { data, error } = await supabase.rpc('admin_get_wallet_overview', {
  p_wallet_id: '8dd80de3-e1e1-492f-8a87-e8bd33b80985'
});

const walletInfo = data[0]; // Single row
```

---

### 3. `admin_get_wallet_transactions` - Transaction history

**Purpose**: Get wallet transaction audit trail.

**Signature**:
```sql
admin_get_wallet_transactions(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
```

**Parameters**:
- `p_wallet_id`: Wallet ID
- `p_limit`: Max results (default 50)
- `p_offset`: Pagination offset (default 0)

**Returns** (TABLE):
```typescript
{
  transaction_id: uuid,
  wallet_id: uuid,
  amount: number, // Positive for topup/refund, negative for payment
  type: 'topup' | 'payment' | 'refund' | 'adjustment',
  description: string,
  order_id: uuid | null,
  order_number: string | null,
  actor_user_id: uuid | null,
  actor_email: string | null,
  actor_full_name: string | null,
  balance_before: number,
  balance_after: number,
  created_at: timestamp
}[]
```

**Sorting**: DESC by `created_at` (newest first)

**Example Usage**:
```typescript
const { data, error } = await supabase.rpc('admin_get_wallet_transactions', {
  p_wallet_id: '8dd80de3-e1e1-492f-8a87-e8bd33b80985',
  p_limit: 10,
  p_offset: 0
});
```

---

### 4. `admin_get_wallet_payments` - Payment transactions

**Purpose**: Get payment transactions (topups, not wallet_transactions).

**Signature**:
```sql
admin_get_wallet_payments(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
```

**Parameters**:
- `p_wallet_id`: Wallet ID
- `p_limit`: Max results (default 50)
- `p_offset`: Pagination offset (default 0)

**Returns** (TABLE):
```typescript
{
  payment_id: uuid,
  wallet_id: uuid,
  order_id: uuid | null,
  order_number: string | null,
  amount_credits: number, // Gross amount
  commission_credits: number,
  net_amount: number, // amount - commission
  transaction_type: 'topup' | 'order',
  payment_method_id: uuid | null,
  status: 'pending' | 'completed' | 'failed' | 'refunded',
  provider_transaction_id: string | null,
  idempotency_key: string | null,
  created_at: timestamp,
  completed_at: timestamp | null
}[]
```

**Sorting**: DESC by `created_at` (newest first)

**Example Usage**:
```typescript
const { data, error } = await supabase.rpc('admin_get_wallet_payments', {
  p_wallet_id: '8dd80de3-e1e1-492f-8a87-e8bd33b80985',
  p_limit: 10,
  p_offset: 0
});
```

---

### 5. `admin_get_wallet_orders` - Orders with itemized breakdown

**Purpose**: Get orders paid with this wallet, including line items.

**Signature**:
```sql
admin_get_wallet_orders(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
```

**Parameters**:
- `p_wallet_id`: Wallet ID
- `p_limit`: Max results (default 50)
- `p_offset`: Pagination offset (default 0)

**Returns** (TABLE):
```typescript
{
  order_id: uuid,
  order_number: string,
  created_at: timestamp,
  status: 'pending' | 'cooking' | 'ready' | 'issued' | 'picked_up' | 'cancelled',
  cafe_id: uuid,
  cafe_name: string,
  subtotal_credits: number,
  paid_credits: number,
  bonus_used: number,
  payment_method: string,
  payment_status: string,
  customer_name: string,
  customer_phone: string,
  items: [
    {
      item_id: uuid,
      item_name: string,
      qty: number,
      unit_price_credits: number,
      line_total_credits: number,
      modifiers: jsonb | null
    }
  ]
}[]
```

**Sorting**: DESC by `created_at` (newest first)

**Example Usage**:
```typescript
const { data, error } = await supabase.rpc('admin_get_wallet_orders', {
  p_wallet_id: '8dd80de3-e1e1-492f-8a87-e8bd33b80985',
  p_limit: 10,
  p_offset: 0
});

// Access order items
data.forEach(order => {
  console.log(`Order ${order.order_number}:`);
  order.items.forEach(item => {
    console.log(`  - ${item.item_name} x${item.qty} = ${item.line_total_credits} credits`);
  });
});
```

---

## 🧪 Testing

**Smoke Test**: `tests/admin_wallet_rpc_smoke.sql`

Run:
```bash
cd SubscribeCoffieBackend
psql postgresql://postgres:postgres@localhost:54322/postgres -f tests/admin_wallet_rpc_smoke.sql
```

**Expected Output**: ✅ All 5 functions pass security checks

---

## 🚀 Integration with Admin Panel

### Setup Supabase Client (Next.js Admin Panel)

```typescript
// lib/supabase/queries/adminWalletQueries.ts
import { createClient } from '@/lib/supabase/server';

export async function getWallets(limit = 50, offset = 0, search?: string) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('admin_get_wallets', {
    p_limit: limit,
    p_offset: offset,
    p_search: search || null
  });
  
  if (error) throw error;
  return data;
}

export async function getWalletOverview(walletId: string) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('admin_get_wallet_overview', {
    p_wallet_id: walletId
  });
  
  if (error) throw error;
  return data[0]; // Single row
}

export async function getWalletTransactions(
  walletId: string, 
  limit = 50, 
  offset = 0
) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('admin_get_wallet_transactions', {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset
  });
  
  if (error) throw error;
  return data;
}

export async function getWalletPayments(
  walletId: string, 
  limit = 50, 
  offset = 0
) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('admin_get_wallet_payments', {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset
  });
  
  if (error) throw error;
  return data;
}

export async function getWalletOrders(
  walletId: string, 
  limit = 50, 
  offset = 0
) {
  const supabase = await createClient();
  
  const { data, error } = await supabase.rpc('admin_get_wallet_orders', {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset
  });
  
  if (error) throw error;
  return data;
}
```

### Example Admin Page

```typescript
// app/admin/wallets/[id]/page.tsx
import { getWalletOverview, getWalletTransactions, getWalletOrders } from '@/lib/supabase/queries/adminWalletQueries';

export default async function WalletDetailPage({ params }: { params: { id: string } }) {
  const overview = await getWalletOverview(params.id);
  const transactions = await getWalletTransactions(params.id, 20, 0);
  const orders = await getWalletOrders(params.id, 10, 0);
  
  return (
    <div>
      <h1>Wallet: {overview.wallet_id}</h1>
      <p>Balance: {overview.balance_credits} credits</p>
      <p>User: {overview.user_full_name} ({overview.user_email})</p>
      
      <h2>Recent Transactions</h2>
      <ul>
        {transactions.map(tx => (
          <li key={tx.transaction_id}>
            {tx.type}: {tx.amount} credits at {tx.created_at}
          </li>
        ))}
      </ul>
      
      <h2>Recent Orders</h2>
      <ul>
        {orders.map(order => (
          <li key={order.order_id}>
            {order.order_number} - {order.cafe_name} - {order.paid_credits} credits
            <ul>
              {order.items.map(item => (
                <li key={item.item_id}>
                  {item.item_name} x{item.qty} = {item.line_total_credits} credits
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

## 🔒 Security Notes

1. **Admin-only**: All functions enforce admin role via `is_admin()` helper
2. **No direct table access**: Uses `SECURITY DEFINER` with controlled queries
3. **Search sanitization**: Search uses `ILIKE` with parameter binding (SQL injection safe)
4. **Pagination**: All list functions support limit/offset
5. **Read-only**: No mutation functions (create/update/delete) in this migration

---

## 📊 Performance Considerations

- **Indexes**: Ensure indexes on `wallets.user_id`, `wallet_transactions.wallet_id`, `payment_transactions.wallet_id`, `orders_core.wallet_id`
- **Pagination**: Always use `limit` to avoid large result sets
- **Search**: `ILIKE` on large tables can be slow; consider adding trigram indexes if search is slow:

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX profiles_email_trgm_idx ON profiles USING gin (email gin_trgm_ops);
CREATE INDEX profiles_full_name_trgm_idx ON profiles USING gin (full_name gin_trgm_ops);
```

---

## 🐛 Troubleshooting

**Error: "Admin access required"**
- Ensure user is logged in as admin
- Check `profiles.role = 'admin'` for the current user
- Verify JWT token is valid and not expired

**Error: "column does not exist"**
- Run `supabase db reset` to ensure all migrations are applied
- Check migration `20260214000008_admin_wallet_rpc_contracts.sql` is applied

**Empty results**
- No wallets in database: Create test wallet via `create_citypass_wallet(user_id)`
- No transactions: Top up wallet via `mock_wallet_topup(wallet_id, amount, ...)`

---

**Status**: ✅ Ready for Admin Panel Integration
