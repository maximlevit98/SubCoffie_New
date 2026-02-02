# Owner Admin Panel - Backend Quickstart Guide

## Overview

This guide will help you quickly set up and use the Owner Admin Panel backend. The backend provides a complete API for cafe owners to manage their locations, menus, and orders.

## Prerequisites

- Supabase project set up (local or cloud)
- Supabase CLI installed
- PostgreSQL client (optional, for testing)

## Installation

### 1. Apply Migrations

Apply the migrations in order:

```bash
cd SubscribeCoffieBackend

# Apply all migrations
supabase db reset

# Or apply specific migrations
supabase migration up --version 20260201120000
supabase migration up --version 20260201130000
```

### 2. Verify Installation

Run the test suite to verify everything is working:

```bash
# Using psql
psql -h localhost -U postgres -d postgres -f tests/owner_admin_panel_tests.sql

# Or using Supabase SQL editor
# Copy and paste contents of tests/owner_admin_panel_tests.sql
```

If all tests pass, you're ready to go! ✅

## Quick Start - API Usage

### Step 1: Create Owner Account

When a new owner signs up, create their account:

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// After user signs up
const { data: { user } } = await supabase.auth.signUp({
  email: 'owner@example.com',
  password: 'secure_password'
});

// Set user role to 'owner'
await supabase
  .from('profiles')
  .update({ role: 'owner' })
  .eq('id', user.id);

// Create owner account
const { data: account } = await supabase.rpc('get_or_create_owner_account', {
  p_user_id: user.id,
  p_company_name: 'My Coffee Business'
});

console.log('Account created:', account);
```

### Step 2: Create First Cafe

Create a cafe in draft status:

```typescript
const { data: cafe, error } = await supabase
  .from('cafes')
  .insert({
    account_id: account.id,
    name: 'Downtown Coffee',
    address: '123 Main Street',
    phone: '+1234567890',
    email: 'downtown@coffee.com',
    description: 'Best coffee in town',
    mode: 'closed', // Start closed
    status: 'draft', // Start as draft
    latitude: 40.7128,
    longitude: -74.0060,
    opening_time: '08:00',
    closing_time: '20:00'
  })
  .select()
  .single();

console.log('Cafe created:', cafe);
```

### Step 3: Add Menu Categories

```typescript
const categories = [
  { name: 'Coffee', sort_order: 0 },
  { name: 'Tea', sort_order: 1 },
  { name: 'Food', sort_order: 2 }
];

const { data } = await supabase
  .from('menu_categories')
  .insert(
    categories.map(cat => ({
      cafe_id: cafe.id,
      ...cat,
      is_visible: true
    }))
  )
  .select();

console.log('Categories created:', data);
```

### Step 4: Add Menu Items

```typescript
const { data: coffeeCategory } = await supabase
  .from('menu_categories')
  .select('id')
  .eq('cafe_id', cafe.id)
  .eq('name', 'Coffee')
  .single();

const menuItems = [
  {
    cafe_id: cafe.id,
    category_id: coffeeCategory.id,
    category: 'drinks',
    name: 'Cappuccino',
    description: 'Classic cappuccino with foam art',
    price_credits: 250,
    prep_time_sec: 180,
    is_active: true
  },
  {
    cafe_id: cafe.id,
    category_id: coffeeCategory.id,
    category: 'drinks',
    name: 'Espresso',
    description: 'Strong espresso shot',
    price_credits: 150,
    prep_time_sec: 60,
    is_active: true
  },
  {
    cafe_id: cafe.id,
    category_id: coffeeCategory.id,
    category: 'drinks',
    name: 'Latte',
    description: 'Smooth latte with steamed milk',
    price_credits: 280,
    prep_time_sec: 200,
    is_active: true
  }
];

const { data } = await supabase
  .from('menu_items')
  .insert(menuItems)
  .select();

console.log('Menu items created:', data);
```

### Step 5: Add Modifiers (Optional)

```typescript
const { data: cappuccino } = await supabase
  .from('menu_items')
  .select('id')
  .eq('name', 'Cappuccino')
  .single();

const modifiers = [
  // Volume group
  {
    menu_item_id: cappuccino.id,
    group_name: 'Volume',
    modifier_name: 'Small',
    price_change: 0,
    is_required: true,
    allow_multiple: false,
    sort_order: 0
  },
  {
    menu_item_id: cappuccino.id,
    group_name: 'Volume',
    modifier_name: 'Large',
    price_change: 50,
    is_required: true,
    allow_multiple: false,
    sort_order: 1
  },
  // Milk type group
  {
    menu_item_id: cappuccino.id,
    group_name: 'Milk Type',
    modifier_name: 'Regular',
    price_change: 0,
    is_required: false,
    allow_multiple: false,
    sort_order: 0
  },
  {
    menu_item_id: cappuccino.id,
    group_name: 'Milk Type',
    modifier_name: 'Oat',
    price_change: 40,
    is_required: false,
    allow_multiple: false,
    sort_order: 1
  }
];

await supabase
  .from('menu_modifiers')
  .insert(modifiers);
```

### Step 6: Check Publication Readiness

```typescript
const { data: checklist } = await supabase.rpc('get_cafe_publication_checklist', {
  p_cafe_id: cafe.id
});

console.log('Publication checklist:', checklist);
// {
//   basic_info: true,
//   working_hours: true,
//   storefront: false, // Need logo and cover
//   menu: true,
//   legal_data: false, // Need INN in account
//   coordinates: true
// }

// Calculate percentage
const items = Object.values(checklist);
const completed = items.filter(Boolean).length;
const percentage = (completed / items.length) * 100;
console.log(`Ready: ${percentage}%`);
```

### Step 7: Submit for Moderation

Once the checklist is 100% complete:

```typescript
try {
  const { data: updatedCafe } = await supabase.rpc('submit_cafe_for_moderation', {
    p_cafe_id: cafe.id
  });
  
  console.log('Submitted for moderation:', updatedCafe);
  // Status will change from 'draft' to 'moderation'
} catch (error) {
  console.error('Not ready:', error.message);
}
```

## Managing Orders

### Get Orders for Cafe

```typescript
// Get all orders
const { data: orders } = await supabase.rpc('get_cafe_orders', {
  p_cafe_id: cafe.id,
  p_limit: 50
});

// Get orders by status
const { data: newOrders } = await supabase.rpc('get_cafe_orders', {
  p_cafe_id: cafe.id,
  p_status_filter: 'Created'
});

// Get orders for Kanban board
const { data: ordersByStatus } = await supabase.rpc('get_cafe_orders_by_status', {
  p_cafe_id: cafe.id
});

console.log('New:', ordersByStatus.Created);
console.log('Accepted:', ordersByStatus.Accepted);
console.log('Ready:', ordersByStatus.Ready);
```

### Update Order Status

```typescript
// Accept order
const { data } = await supabase.rpc('owner_update_order_status', {
  p_order_id: order.id,
  p_new_status: 'Accepted'
});

// Mark as preparing
await supabase.rpc('owner_update_order_status', {
  p_order_id: order.id,
  p_new_status: 'In progress'
});

// Mark as ready
await supabase.rpc('owner_update_order_status', {
  p_order_id: order.id,
  p_new_status: 'Ready'
});

// Mark as picked up
await supabase.rpc('owner_update_order_status', {
  p_order_id: order.id,
  p_new_status: 'Picked up'
});
```

### Cancel Order

```typescript
const { data } = await supabase.rpc('owner_cancel_order', {
  p_order_id: order.id,
  p_reason: 'Out of stock'
});

console.log('Order canceled:', data);
// Automatic refund will be processed
```

## Real-time Order Notifications

Subscribe to new orders:

```typescript
const channel = supabase
  .channel('cafe-orders')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'orders',
      filter: `cafe_id=eq.${cafe.id}`
    },
    (payload) => {
      console.log('New order received!', payload.new);
      
      // Play sound
      playNotificationSound();
      
      // Show notification
      showToast(`New order #${payload.new.id.slice(0, 8)}`);
      
      // Update UI
      refreshOrders();
    }
  )
  .subscribe();

// Clean up when component unmounts
return () => {
  channel.unsubscribe();
};
```

## Dashboard Statistics

### Cafe Dashboard

```typescript
const { data: stats } = await supabase.rpc('get_cafe_dashboard_stats', {
  p_cafe_id: cafe.id,
  p_date_from: new Date().toISOString(), // Today
  p_date_to: new Date().toISOString()
});

console.log('Today:', {
  orders: stats.total_orders,
  revenue: stats.total_revenue,
  average: stats.avg_order_value,
  active: stats.active_orders
});
```

### Account Dashboard (All Cafes)

```typescript
const { data: stats } = await supabase.rpc('get_account_dashboard_stats', {
  p_user_id: user.id
});

console.log('Account overview:', {
  totalCafes: stats.total_cafes,
  published: stats.published_cafes,
  orders: stats.total_orders,
  revenue: stats.total_revenue
});
```

## Common Operations

### Duplicate a Cafe

```typescript
const { data: newCafe } = await supabase.rpc('duplicate_cafe', {
  p_cafe_id: cafe.id,
  p_new_name: 'Downtown Coffee - Branch 2'
});

console.log('Cafe duplicated:', newCafe);
// All menu items, categories, and modifiers are copied
```

### Toggle Stop-List

```typescript
// Add item to stop-list
await supabase.rpc('toggle_menu_item_stop_list', {
  p_item_id: menuItem.id,
  p_is_available: false
});

// Remove from stop-list
await supabase.rpc('toggle_menu_item_stop_list', {
  p_item_id: menuItem.id,
  p_is_available: true
});
```

### Update Cafe Details

```typescript
const { data } = await supabase
  .from('cafes')
  .update({
    description: 'Updated description',
    logo_url: 'https://storage.url/logo.png',
    cover_url: 'https://storage.url/cover.jpg',
    working_hours: {
      mon: { open: '08:00', close: '20:00' },
      tue: { open: '08:00', close: '20:00' },
      wed: { open: '08:00', close: '20:00' },
      thu: { open: '08:00', close: '20:00' },
      fri: { open: '08:00', close: '20:00' },
      sat: { open: '09:00', close: '18:00' },
      sun: { closed: true }
    }
  })
  .eq('id', cafe.id)
  .select()
  .single();
```

## Security Notes

### Row Level Security (RLS)

All tables have RLS enabled. Users can only access their own data:

- ✅ Owners see only their cafes and orders
- ✅ Customers see only their own orders
- ✅ Public sees only published cafes
- ✅ Admins see everything

### Permissions

The backend enforces strict permissions:

- Owners **cannot** see other owners' data
- Owners **cannot** see customer payment details (only payment status)
- Owners **cannot** modify system settings
- Owners **can** manage their cafes, menus, and orders

## Troubleshooting

### "Unauthorized" Error

Make sure:
1. User is authenticated
2. User has `role = 'owner'` in profiles table
3. Cafe belongs to user's account

### "Cafe not ready for publication"

Check the publication checklist:
```typescript
const checklist = await supabase.rpc('get_cafe_publication_checklist', {
  p_cafe_id: cafe.id
});
```

All items must be `true` before submitting for moderation.

### Real-time Not Working

Ensure:
1. Real-time is enabled in Supabase dashboard
2. Channel is subscribed before receiving events
3. RLS policies allow viewing the table

## Next Steps

1. **Frontend Implementation**: Build UI components using this API
2. **Testing**: Run test suite regularly during development
3. **Documentation**: See `OWNER_API_CONTRACT.md` for complete API reference
4. **TypeScript**: Import types from `types/owner-admin-panel.ts`

## Resources

- [Full API Contract](./OWNER_API_CONTRACT.md)
- [TypeScript Types](./types/owner-admin-panel.ts)
- [Test Suite](./tests/owner_admin_panel_tests.sql)
- [Migration Files](./supabase/migrations/)
- [Implementation Roadmap](../.cursor/plans/owner_admin_panel_roadmap.plan.md)

## Support

For issues or questions:
1. Check the API contract documentation
2. Run the test suite to verify setup
3. Review RLS policies in migration files
4. Check Supabase logs for detailed error messages
