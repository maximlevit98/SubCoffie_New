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
