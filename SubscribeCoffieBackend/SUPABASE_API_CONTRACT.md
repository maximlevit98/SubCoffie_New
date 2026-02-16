# Supabase API Contract (Backend)

This document defines the stable REST contract for the iOS client. All identifiers
are in `snake_case`. Status values are in `lower_snake` at the storage level, while
legacy REST views may return Title Case to keep existing clients working.

## Tables (REST resources)

### `cafes`
Fields:
- `id` (uuid, pk)
- `name` (text, not null)
- `address` (text, not null)
- `mode` (text, not null) — enum
- `eta_minutes` (int, nullable)
- `active_orders` (int, not null, default 0)
- `max_active_orders` (int, nullable)
- `distance_km` (numeric, nullable)
- `supports_citypass` (boolean, not null, default true)
- `brand_id` (uuid, nullable)
- `created_at` (timestamptz, not null)
- `updated_at` (timestamptz, not null)

Enums:
- `mode`: `open`, `busy`, `paused`, `closed`

### `profiles`
Fields:
- `id` (uuid, pk)
- `email` (text, nullable)
- `role` (text, not null, default `user`) — enum
- `created_at` (timestamptz, not null)
- `updated_at` (timestamptz, not null)

Enums:
- `role`: `user`, `admin`

### `menu_items`
Fields:
- `id` (uuid, pk)
- `cafe_id` (uuid, fk → cafes.id)
- `category` (text, not null) — enum
- `title` (text, not null)
- `name` (text, not null) — alias of `title` for legacy clients
- `description` (text, nullable)
- `price_credits` (int, not null)
- `sort_order` (int, not null, default 0)
- `is_available` (boolean, not null, default true)
- `created_at` (timestamptz, not null)
- `updated_at` (timestamptz, not null)

Enums:
- `category`: `drinks`, `food`, `syrups`, `merch`

### `orders` (REST view, legacy-compatible)
Fields:
- `id` (uuid, pk)
- `cafe_id` (uuid, fk → cafes.id)
- `customer_phone` (text, not null)
- `status` (text, not null) — enum (legacy Title Case via view)
- `eta_minutes` (int, not null, default 0)
- `subtotal_credits` (int, not null, default 0)
- `bonus_used` (int, not null, default 0)
- `paid_credits` (int, not null, default 0)
- `pickup_deadline` (timestamptz, nullable)
- `no_show_at` (timestamptz, nullable)
- `created_at` (timestamptz, not null)
- `updated_at` (timestamptz, not null)

Enums (legacy REST, Title Case):
- `status`: `Created`, `Accepted`, `Rejected`, `In progress`, `Ready`,
  `Picked up`, `Canceled`, `Refunded`, `No-show`, `Issued`

Storage enum (`orders_core.status`):
- `created`, `accepted`, `rejected`, `in_progress`, `ready`,
  `picked_up`, `canceled`, `refunded`, `no_show`, `issued`

### `order_items`
Fields:
- `id` (uuid, pk)
- `order_id` (uuid, fk → orders_core.id)
- `menu_item_id` (uuid, fk → menu_items.id, nullable)
- `title` (text, not null)
- `unit_credits` (int, not null)
- `quantity` (int, not null)
- `line_total` (int, generated: unit_credits * quantity)
- `category` (text, not null) — enum
- `created_at` (timestamptz, not null)
- `updated_at` (timestamptz, not null)

Enums:
- `category`: `drinks`, `food`, `syrups`, `merch`

### `order_events` (REST view, legacy-compatible)
Fields:
- `id` (uuid, pk)
- `order_id` (uuid, fk → orders_core.id)
- `status` (text, not null) — enum (legacy Title Case via view)
- `created_at` (timestamptz, not null)
- `updated_at` (timestamptz, not null)

Enums (legacy REST, Title Case):
- `status`: `Created`, `Accepted`, `Rejected`, `In progress`, `Ready`,
  `Picked up`, `Canceled`, `Refunded`, `No-show`, `Issued`

Storage enum (`order_events_core.status`):
- `created`, `accepted`, `rejected`, `in_progress`, `ready`,
  `picked_up`, `canceled`, `refunded`, `no_show`, `issued`

### `order_qr_tokens`
Fields:
- `id` (uuid, pk)
- `order_id` (uuid, fk → orders_core.id)
- `token_hash` (text, not null)
- `expires_at` (timestamptz, not null)
- `used_at` (timestamptz, nullable)
- `created_at` (timestamptz, not null)

## RPC

### `create_order_qr_token(p_order_id, p_expires_sec)`
Returns plain token (string). Stores SHA-256 hash in `order_qr_tokens`.

### `redeem_order_qr(p_token, p_actor_user_id)`
Validates token, checks status `ready`, then:
- updates `orders_core.status` → `issued`
- sets `issued_at`
- inserts `order_events_core(status='issued')`

---

## Owner Wallet Analytics RPC

**Access**: Owner/Admin only. Owner can only access `cafe_wallet` wallets for cafes they own (via `accounts.owner_user_id`). Admin can access all.

**Security Model**:
- Owner: Strict ownership check via `cafes.account_id → accounts.owner_user_id = auth.uid()`
- Admin: Bypass ownership check (can access all wallets)
- CityPass wallets: Excluded from owner scope (not cafe-specific)

### `owner_get_wallets(p_cafe_id?, p_limit?, p_offset?, p_search?)`

**Parameters**:
- `p_cafe_id` (uuid, optional): Filter by specific cafe
- `p_limit` (int, default 50): Max results (clamped 1-200)
- `p_offset` (int, default 0): Pagination offset
- `p_search` (text, optional): Search by user email/phone/name or cafe name

**Returns** (TABLE):
```typescript
{
  wallet_id: uuid,
  user_id: uuid,
  wallet_type: 'cafe_wallet',
  balance_credits: number,
  lifetime_top_up_credits: number,
  created_at: timestamp,
  user_email: string,
  user_phone: string,
  user_full_name: string,
  cafe_id: uuid,
  cafe_name: string,
  last_transaction_at: timestamp | null,
  last_payment_at: timestamp | null,
  last_order_at: timestamp | null,
  total_transactions: number,
  total_payments: number,
  total_orders: number,
  total_topups: number,
  total_refunds: number,
  total_topup_credits: number,
  total_spent_credits: number,
  total_refund_credits: number,
  net_wallet_change_credits: number,
  total_orders_paid_credits: number
}[]
```

**Errors**:
- `Owner or admin access required`: User is not owner/admin
- `Unauthorized: cafe not owned by you`: Owner trying to access unowned cafe

### `owner_get_wallet_overview(p_wallet_id)`

**Parameters**:
- `p_wallet_id` (uuid, required): Wallet ID

**Returns** (TABLE, single row):
```typescript
{
  wallet_id: uuid,
  user_id: uuid,
  wallet_type: 'cafe_wallet',
  balance_credits: number,
  lifetime_top_up_credits: number,
  created_at: timestamp,
  updated_at: timestamp,
  user_email: string,
  user_phone: string,
  user_full_name: string,
  user_avatar_url: string | null,
  user_registered_at: timestamp,
  cafe_id: uuid,
  cafe_name: string,
  cafe_address: string,
  total_transactions: number,
  total_topups: number,
  total_payments: number,
  total_refunds: number,
  total_orders: number,
  completed_orders: number,
  last_transaction_at: timestamp | null,
  last_payment_at: timestamp | null,
  last_order_at: timestamp | null,
  total_topup_credits: number,
  total_payment_credits: number,
  total_refund_credits: number,
  total_adjustment_credits: number,
  net_wallet_change_credits: number,
  total_orders_paid_credits: number,
  avg_order_paid_credits: number,
  last_topup_at: timestamp | null,
  last_refund_at: timestamp | null
}
```

**Errors**:
- `Owner or admin access required`: User is not owner/admin
- `Invalid wallet_id: NULL`: Wallet ID is NULL
- `Unauthorized: wallet not accessible`: Owner doesn't own the wallet's cafe

### `owner_get_wallet_transactions(p_wallet_id, p_limit?, p_offset?)`

**Parameters**:
- `p_wallet_id` (uuid, required): Wallet ID
- `p_limit` (int, default 50): Max results (clamped 1-200)
- `p_offset` (int, default 0): Pagination offset

**Returns** (TABLE):
```typescript
{
  transaction_id: uuid,
  wallet_id: uuid,
  amount: number,  // Positive = topup/refund, negative = payment
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

**Errors**: Same as `owner_get_wallet_overview`

### `owner_get_wallet_payments(p_wallet_id, p_limit?, p_offset?)`

**Parameters**:
- `p_wallet_id` (uuid, required): Wallet ID
- `p_limit` (int, default 50): Max results (clamped 1-200)
- `p_offset` (int, default 0): Pagination offset

**Returns** (TABLE):
```typescript
{
  payment_id: uuid,
  wallet_id: uuid,
  order_id: uuid | null,
  order_number: string | null,
  amount_credits: number,  // Gross amount
  commission_credits: number,
  net_amount: number,  // amount - commission
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

**Errors**: Same as `owner_get_wallet_overview`

### `owner_get_wallet_orders(p_wallet_id, p_limit?, p_offset?)`

**Parameters**:
- `p_wallet_id` (uuid, required): Wallet ID
- `p_limit` (int, default 50): Max results (clamped 1-200)
- `p_offset` (int, default 0): Pagination offset

**Returns** (TABLE):
```typescript
{
  order_id: uuid,
  order_number: string,
  created_at: timestamp,
  status: string,
  cafe_id: uuid,
  cafe_name: string,
  subtotal_credits: number,
  paid_credits: number,
  bonus_used: number,
  payment_method: string,
  payment_status: string,
  customer_name: string,
  customer_phone: string,
  items: [  // Always array, never null
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

**Errors**: Same as `owner_get_wallet_overview`

### `owner_get_wallets_stats(p_cafe_id?)`

**Parameters**:
- `p_cafe_id` (uuid, optional): Filter by specific cafe

**Returns** (TABLE, single row):
```typescript
{
  total_wallets: number,
  total_balance_credits: number,
  total_lifetime_topup_credits: number,
  total_transactions: number,
  total_orders: number,
  total_revenue_credits: number,  // Sum of paid_credits + bonus_used
  avg_wallet_balance: number,
  active_wallets_30d: number,  // Wallets with transactions in last 30 days
  total_topup_credits: number,
  total_spent_credits: number,
  total_refund_credits: number,
  net_wallet_change_credits: number
}
```

**Errors**: Same as `owner_get_wallets`

---

## Financial Control Tower RPC

### `admin_get_financial_control_tower(p_from?, p_to?, p_cafe_id?)`

**Access**: Admin only

**Returns** (single row):
```typescript
{
  scope: "admin",
  date_from: timestamp,
  date_to: timestamp,
  selected_cafe_id: uuid | null,
  topup_completed_count: number,
  topup_completed_credits: number,
  order_payment_completed_count: number,
  order_payment_completed_credits: number,
  refund_completed_count: number,
  refund_completed_credits: number,
  platform_commission_credits: number,
  pending_credits: number,
  failed_credits: number,
  wallet_balance_snapshot_credits: number,
  orders_count: number,
  completed_orders_count: number,
  orders_paid_credits: number,
  wallet_ledger_delta_credits: number,
  expected_wallet_delta_credits: number,
  discrepancy_credits: number
}
```

**Notes**:
- `discrepancy_credits = wallet_ledger_delta_credits - expected_wallet_delta_credits`
- `expected_wallet_delta_credits = topups + refunds - order_payments`

### `admin_get_financial_anomalies(p_from?, p_to?, p_cafe_id?, p_limit?)`

**Access**: Admin only

**Returns**:
```typescript
{
  anomaly_key: string,
  severity: "critical" | "high" | "medium" | "low",
  anomaly_type: string,
  wallet_id: uuid | null,
  order_id: uuid | null,
  cafe_id: uuid | null,
  amount_credits: number,
  detected_at: timestamp,
  message: string,
  details: jsonb | null
}[]
```

**Anomaly types**:
- `negative_wallet_balance`
- `wallet_order_without_payment_tx`
- `completed_payment_without_wallet_ledger`
- `reconciliation_delta`

### `owner_get_financial_control_tower(p_from?, p_to?, p_cafe_id?)`

**Access**: Owner/Admin. Owner scope is restricted to owned cafes only.

**Returns**: Same contract as `admin_get_financial_control_tower`, with `scope = "owner"`.

### `owner_get_financial_anomalies(p_from?, p_to?, p_cafe_id?, p_limit?)`

**Access**: Owner/Admin. Owner receives only anomalies for owned cafes.

**Returns**: Same contract as `admin_get_financial_anomalies`.

---

## Commission & Bonus Model (2026-02-16)

### Policy Summary
- `cafe_wallet_topup`: customer wallet is credited with full top-up amount, commission is paid by cafe.
- `citypass_order_payment`: commission is applied per order transaction and paid by cafe.
- `citypass_topup`: expected to be `0%` for top-up preview (fee does not reduce customer credit).

### `payment_transactions` (extended fields)
```typescript
{
  fee_payer: "customer" | "cafe" | "platform",
  fee_cafe_id: uuid | null
}
```

### `get_commission_for_wallet(p_wallet_id)`
- Returns top-up preview rate for wallet.
- For `citypass` wallets, expected rate is `0` (commission handled at order payment stage).

### `mock_wallet_topup(p_wallet_id, p_amount, p_payment_method_id?, p_idempotency_key?)`
- Credits full top-up amount to wallet balance.
- For `cafe_wallet`, fee metadata is stored in `payment_transactions` with:
  - `fee_payer = "cafe"`
  - `fee_cafe_id = wallet.cafe_id`

### Runtime hook: CityPass order commission
- Trigger `apply_citypass_order_payment_commission` enriches `payment_transactions` when `order_payment` is linked to an order:
  - computes `commission_credits` by policy
  - sets `fee_payer = "cafe"`
  - sets `fee_cafe_id = orders_core.cafe_id`

---

## REST examples

### GET /rest/v1/cafes?select=id,name&limit=1
```json
[
  {
    "id": "11111111-1111-1111-1111-111111111111",
    "name": "Downtown Roasters"
  }
]
```

### GET /rest/v1/menu_items?select=id,cafe_id,category,name,price_credits&limit=1
```json
[
  {
    "id": "9bfe5c67-72a0-4a5e-8bcb-f2a7f1a8c2a1",
    "cafe_id": "11111111-1111-1111-1111-111111111111",
    "category": "drinks",
    "name": "Drink #1",
    "price_credits": 145
  }
]
```

### GET /rest/v1/orders?select=id,status&limit=1
```json
[
  {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "status": "Created"
  }
]
```
