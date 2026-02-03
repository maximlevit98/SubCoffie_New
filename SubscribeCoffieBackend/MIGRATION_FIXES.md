# Migration Conflict Resolution: Orders & Order_Items

## Problem: Multiple Duplicate Migrations
During project evolution, multiple duplicate migrations were created for orders and order_items tables, causing:
- Confusion about which migration is authoritative
- Risk of different schemas in different environments
- Maintenance overhead

### Duplicates Found:

**order_items enhancements (3 duplicates):**
- `20260201000002_create_order_items_table.sql` ❌
- `20260201000003_create_order_items_table.sql` ❌
- `20260202120002_create_order_items_table.sql` ✅ **KEPT**
- `20260202140002_create_order_items_table.sql` ❌

**orders enhancements (2 duplicates):**
- `20260202120001_create_orders_table.sql` ✅ **KEPT**
- `20260202140001_create_orders_table.sql` ❌

**RLS policies (2 duplicates):**
- `20260202120004_add_orders_rls.sql` ✅ **KEPT**
- `20260202140004_add_orders_rls.sql` ❌

## Resolution
**Disabled (renamed to `.disabled`):**
- `20260201000002_create_order_items_table.sql`
- `20260201000003_create_order_items_table.sql`
- `20260202140001_create_orders_table.sql`
- `20260202140002_create_order_items_table.sql`
- `20260202140004_add_orders_rls.sql`

**Active Migration Path:**
1. `20260121000000_orders_mvp.sql` - Creates base tables
2. `20260123133000_orders_preorder_fields.sql` - Adds preorder support
3. `20260202120001_create_orders_table.sql` - Enhances orders_core
4. `20260202120002_create_order_items_table.sql` - Adds modifiers support
5. `20260202120004_add_orders_rls.sql` - Adds RLS policies

## Rationale
Kept `202601202120xxx` series because:
1. ✅ Earlier timestamp (first in sequence)
2. ✅ Better data migration logic with `COALESCE` for safety
3. ✅ Properly updates existing rows before setting NOT NULL constraints
4. ✅ More comprehensive error handling
5. ✅ Aligns with `create_order_rpc` expectations

## Verification Results ✅

```bash
# Clean database test
cd SubscribeCoffieBackend
supabase db reset  # SUCCESS - no errors
```

### Final order_items Structure:
```
✅ id, order_id, menu_item_id, product_id (keys)
✅ title, unit_credits, quantity, line_total, category (MVP legacy)
✅ modifiers, item_name, base_price_credits, total_price_credits (enhanced)
✅ created_at, updated_at (timestamps)
```

### Indexes (5 total):
- ✅ order_items_pkey (PRIMARY KEY)
- ✅ idx_order_items_order_id (FK optimization)
- ✅ idx_order_items_menu_item (FK optimization)
- ✅ order_items_order_idx (legacy, kept for compatibility)
- ✅ order_items_order_id_idx (legacy, kept for compatibility)

### RLS Policies:
- ✅ Order items insert own order
- ✅ Order items select own
- ✅ anon_create_order_items (for MVP/local)

## Impact
- ✅ Linear migration path (5 migrations instead of 10)
- ✅ No conflicts on fresh deploys
- ✅ Idempotent (safe to re-run)
- ✅ Compatible with iOS checkout flow
- ✅ Compatible with `create_order_rpc` (validated)
- ✅ Seed data works correctly

## Date: 2026-02-03
## Status: ✅ RESOLVED
