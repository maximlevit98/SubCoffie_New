# Contract Checklist (Backend + iOS)

Audit date: 2026-01-23

## Backend schema (Supabase migrations)

### Tables
- `cafes`
  - `id`, `name`, `address`, `mode`, `eta_minutes`, `active_orders`, `max_active_orders`,
    `distance_km`, `supports_citypass`, `brand_id`, `created_at`, `updated_at`
  - Enum: `mode` = `open|busy|paused|closed`
- `menu_items`
  - `id`, `cafe_id`, `category`, `title`, `name` (alias, synced), `description`,
    `price_credits`, `sort_order`, `is_available`, `created_at`, `updated_at`
  - Enum: `category` = `drinks|food|syrups|merch`
- `orders_core`
  - `id`, `created_at`, `updated_at`, `cafe_id`, `customer_phone`, `status`,
    `eta_minutes`, `subtotal_credits`, `bonus_used`, `paid_credits`,
    `pickup_deadline`, `no_show_at`, `user_id`, `wallet_id`
  - Enum storage: `status` = `created|accepted|rejected|in_progress|ready|picked_up|canceled|refunded|no_show`
- `order_items`
  - `id`, `order_id`, `menu_item_id`, `title`, `unit_credits`, `quantity`,
    `line_total` (generated), `category`, `created_at`, `updated_at`
  - Enum: `category` = `drinks|food|syrups|merch`
- `order_events_core`
  - `id`, `order_id`, `status`, `created_at`, `updated_at`
  - Enum storage: `status` = `created|accepted|rejected|in_progress|ready|picked_up|canceled|refunded|no_show`

### Legacy REST views (for `/rest/v1`)
- `orders` (view on `orders_core`) with Title Case `status`
- `order_events` (view on `order_events_core`) with Title Case `status`

### Note on sync helpers
- `menu_items` has trigger to keep `name` and `title` in sync.
- `orders` / `order_events` have triggers to map legacy ↔ storage status.

## Frontend expectations (iOS SwiftUI)

### Models + CodingKeys
- `SupabaseCafeDTO` (`Models/SupabaseModels.swift`)
  - Expects: `eta_minutes`, `active_orders`, `max_active_orders`,
    `distance_minutes`, `supports_citypass`
- `SupabaseMenuItemDTO` (`Models/SupabaseModels.swift`)
  - Expects: `cafe_id`, `category`, `name` or `title`, `description`,
    `price_credits`, `sort_order`, `is_available` (fallback: `is_active`)
- `SupabaseOrderDTO` (`Models/SupabaseOrderModels.swift`)
  - Expects: `cafe_id`, `customer_phone`, `status` (Title Case or snake),
    `eta_minutes`, `subtotal_credits`, `bonus_used`, `paid_credits`,
    `pickup_deadline`, `created_at`
- `SupabaseOrderEventDTO` (`Models/SupabaseOrderModels.swift`)
  - Expects: `order_id`, `status`, `created_at`

### REST endpoints used (via `SupabaseAPIClient`)
- GET `cafes?select=*&order=distance_minutes.asc`
- GET `menu_items?select=*&cafe_id=eq.<uuid>&order=category.asc,sort_order.asc`
- POST `orders` (insert)
- POST `order_items` (insert)
- POST `order_events` (insert)
- GET `orders?select=*&id=eq.<uuid>&limit=1`
- GET `order_events?select=*&order_id=eq.<uuid>&order=created_at.asc`
- PATCH `orders?id=eq.<uuid>` (update status)

## Top 5 risks
1. **Distance field mismatch**: backend has `distance_km`, frontend orders by `distance_minutes`. This can break `GET /cafes` with a 400 and sort mismatch.
2. **Status casing drift**: frontend sends Title Case (`Created`, `In progress`), backend storage is `lower_snake`. Views map both ways, but direct reads on core tables or status typos will break decoding.
3. **Menu schema cache 404**: app already detects missing `menu_items`. If migrations are not applied, menu fetch returns 404 and UI falls back to mocks.
4. **Menu name/title sync**: backend expects both `name` and `title`. If trigger is missing, legacy clients can receive null `name`.
5. **Order_items FK**: `order_items.order_id` must reference `orders_core`. If FK or view triggers are missing, inserts can fail on order creation flow.
