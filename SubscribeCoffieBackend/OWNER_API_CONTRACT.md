# Owner Admin Panel - Backend API Contract

## Overview

This document describes the backend API for the Owner Admin Panel. The API is built on Supabase and provides both REST endpoints (via Supabase Auto-generated REST API) and RPC functions for complex operations.

## Authentication

All owner endpoints require authentication. The user must:
1. Be authenticated via Supabase Auth (`auth.uid()`)
2. Have `role = 'owner'` in their `profiles` table
3. Have an associated `account` record

## Database Schema

### Core Tables

#### `accounts`
Organization/owner level. One account per owner, can manage multiple cafes.

```typescript
interface Account {
  id: string;
  owner_user_id: string;
  company_name: string;
  inn?: string;
  bank_details?: object;
  legal_address?: string;
  contact_phone?: string;
  contact_email?: string;
  created_at: string;
  updated_at: string;
}
```

#### `cafes`
Individual cafe locations.

```typescript
interface Cafe {
  id: string;
  account_id: string;
  name: string;
  address: string;
  phone?: string;
  email?: string;
  description?: string;
  mode: 'open' | 'busy' | 'paused' | 'closed';
  status: 'draft' | 'moderation' | 'published' | 'paused' | 'rejected';
  eta_minutes?: number;
  active_orders: number;
  max_active_orders?: number;
  supports_citypass: boolean;
  latitude?: number;
  longitude?: number;
  opening_time?: string;
  closing_time?: string;
  working_hours?: object;
  logo_url?: string;
  cover_url?: string;
  photo_urls?: string[];
  created_at: string;
  updated_at: string;
}
```

#### `menu_categories`
Menu categories for organizing items.

```typescript
interface MenuCategory {
  id: string;
  cafe_id: string;
  name: string;
  sort_order: number;
  is_visible: boolean;
  created_at: string;
  updated_at: string;
}
```

#### `menu_items`
Menu items/products.

```typescript
interface MenuItem {
  id: string;
  cafe_id: string;
  category_id?: string;
  category: 'drinks' | 'food' | 'syrups' | 'merch';
  name: string;
  description: string;
  price_credits: number;
  sort_order: number;
  is_active: boolean;
  photo_urls?: string[];
  prep_time_sec?: number;
  availability_schedule?: object;
  created_at: string;
  updated_at: string;
}
```

#### `menu_modifiers`
Modifiers for menu items (size, milk, add-ons).

```typescript
interface MenuModifier {
  id: string;
  menu_item_id: string;
  group_name: string;
  modifier_name: string;
  price_change: number;
  is_required: boolean;
  allow_multiple: boolean;
  sort_order: number;
  is_available: boolean;
  created_at: string;
  updated_at: string;
}
```

#### `orders`
Customer orders.

```typescript
interface Order {
  id: string;
  user_id?: string;
  cafe_id: string;
  status: 'Created' | 'Accepted' | 'Rejected' | 'In progress' | 'Ready' | 'Picked up' | 'Canceled' | 'Refunded' | 'No-show';
  order_type: 'now' | 'preorder' | 'subscription';
  payment_status: 'pending' | 'paid' | 'failed' | 'refunded';
  subtotal_credits: number;
  bonus_used: number;
  paid_credits: number;
  slot_time?: string;
  customer_phone: string;
  eta_minutes: number;
  pickup_deadline?: string;
  no_show_at?: string;
  created_at: string;
  updated_at: string;
}
```

#### `cafe_publication_history`
History of cafe publication status changes.

```typescript
interface CafePublicationHistory {
  id: string;
  cafe_id: string;
  status: string;
  moderator_comment?: string;
  moderator_user_id?: string;
  submitted_at?: string;
  reviewed_at?: string;
  created_at: string;
}
```

## RPC Functions

### Account Management

#### `get_or_create_owner_account`
Get or create owner account for current user.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_or_create_owner_account', {
  p_user_id: userId,
  p_company_name: 'My Company' // optional
});

// Returns: Account
```

#### `get_owner_cafes`
Get all cafes owned by user.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_owner_cafes', {
  p_user_id: userId
});

// Returns: Cafe[]
```

### Cafe Management

#### `duplicate_cafe`
Duplicate a cafe with all menu items and categories.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('duplicate_cafe', {
  p_cafe_id: cafeId,
  p_new_name: 'Cafe Name (Copy)' // optional
});

// Returns: Cafe
```

#### `get_cafe_publication_checklist`
Get publication readiness checklist for cafe.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_cafe_publication_checklist', {
  p_cafe_id: cafeId
});

// Returns: PublicationChecklist
interface PublicationChecklist {
  basic_info: boolean;
  working_hours: boolean;
  storefront: boolean;
  menu: boolean;
  legal_data: boolean;
  coordinates: boolean;
}
```

#### `submit_cafe_for_moderation`
Submit cafe for moderation review.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('submit_cafe_for_moderation', {
  p_cafe_id: cafeId
});

// Returns: Cafe
// Throws: Exception if cafe is not ready for publication
```

### Order Management

#### `owner_update_order_status`
Update order status with validation.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('owner_update_order_status', {
  p_order_id: orderId,
  p_new_status: 'Accepted', // or 'In progress', 'Ready', etc.
  p_owner_user_id: userId // optional, defaults to auth.uid()
});

// Returns: Order
```

#### `owner_cancel_order`
Cancel order with automatic refund.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('owner_cancel_order', {
  p_order_id: orderId,
  p_reason: 'Out of stock',
  p_owner_user_id: userId // optional
});

// Returns: Order
```

#### `get_cafe_orders`
Get orders for cafe with filters.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_cafe_orders', {
  p_cafe_id: cafeId,
  p_status_filter: 'Created', // optional
  p_date_from: '2026-02-01T00:00:00Z', // optional
  p_date_to: '2026-02-01T23:59:59Z', // optional
  p_limit: 100, // optional, default 100
  p_offset: 0 // optional, default 0
});

// Returns: OrderWithDetails[]
interface OrderWithDetails extends Order {
  items_count: number;
  customer_name?: string;
}
```

#### `get_order_details`
Get complete order details with items, customer, and cafe info.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_order_details', {
  p_order_id: orderId
});

// Returns: OrderDetails
interface OrderDetails {
  order: Order;
  items: OrderItem[];
  customer: {
    id: string;
    full_name?: string;
    phone?: string;
  };
  cafe: {
    id: string;
    name: string;
    address: string;
    phone?: string;
  };
}
```

#### `get_cafe_orders_by_status`
Get orders grouped by status for Kanban board.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_cafe_orders_by_status', {
  p_cafe_id: cafeId
});

// Returns: OrdersByStatus
interface OrdersByStatus {
  Created: Order[];
  Accepted: Order[];
  'In progress': Order[];
  Ready: Order[];
  'Picked up': Order[];
}
```

### Analytics & Dashboard

#### `get_cafe_dashboard_stats`
Get dashboard statistics for cafe.

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_cafe_dashboard_stats', {
  p_cafe_id: cafeId,
  p_date_from: '2026-02-01T00:00:00Z', // optional
  p_date_to: '2026-02-01T23:59:59Z' // optional
});

// Returns: CafeDashboardStats
interface CafeDashboardStats {
  total_orders: number;
  total_revenue: number;
  avg_order_value: number;
  active_orders: number;
  date_from: string;
  date_to: string;
}
```

#### `get_account_dashboard_stats`
Get dashboard statistics for owner account (all cafes).

```typescript
// RPC Call
const { data, error } = await supabase.rpc('get_account_dashboard_stats', {
  p_user_id: userId,
  p_date_from: '2026-02-01T00:00:00Z', // optional
  p_date_to: '2026-02-01T23:59:59Z' // optional
});

// Returns: AccountDashboardStats
interface AccountDashboardStats {
  total_cafes: number;
  published_cafes: number;
  total_orders: number;
  total_revenue: number;
  date_from: string;
  date_to: string;
}
```

### Menu Management

#### `toggle_menu_item_stop_list`
Toggle menu item availability (stop-list).

```typescript
// RPC Call
const { data, error } = await supabase.rpc('toggle_menu_item_stop_list', {
  p_item_id: itemId,
  p_is_available: false, // true to make available, false for stop-list
  p_owner_user_id: userId // optional
});

// Returns: MenuItem
```

## REST API Endpoints

For CRUD operations, use Supabase's auto-generated REST API:

### Accounts
```typescript
// Get account
const { data } = await supabase
  .from('accounts')
  .select('*')
  .eq('owner_user_id', userId)
  .single();

// Update account
const { data } = await supabase
  .from('accounts')
  .update({ company_name: 'New Name', inn: '1234567890' })
  .eq('id', accountId);
```

### Cafes
```typescript
// Create cafe
const { data } = await supabase
  .from('cafes')
  .insert({
    account_id: accountId,
    name: 'My Cafe',
    address: '123 Main St',
    status: 'draft',
    mode: 'closed'
  });

// Update cafe
const { data } = await supabase
  .from('cafes')
  .update({ name: 'Updated Name', description: 'New description' })
  .eq('id', cafeId);

// Get cafe
const { data } = await supabase
  .from('cafes')
  .select('*')
  .eq('id', cafeId)
  .single();
```

### Menu Categories
```typescript
// Create category
const { data } = await supabase
  .from('menu_categories')
  .insert({
    cafe_id: cafeId,
    name: 'Coffee',
    sort_order: 0,
    is_visible: true
  });

// Get categories
const { data } = await supabase
  .from('menu_categories')
  .select('*')
  .eq('cafe_id', cafeId)
  .order('sort_order', { ascending: true });
```

### Menu Items
```typescript
// Create menu item
const { data } = await supabase
  .from('menu_items')
  .insert({
    cafe_id: cafeId,
    category_id: categoryId,
    category: 'drinks',
    name: 'Cappuccino',
    description: 'Classic cappuccino',
    price_credits: 250,
    is_active: true
  });

// Get menu items
const { data } = await supabase
  .from('menu_items')
  .select('*, menu_categories(*)')
  .eq('cafe_id', cafeId)
  .order('sort_order', { ascending: true });
```

### Menu Modifiers
```typescript
// Create modifiers
const { data } = await supabase
  .from('menu_modifiers')
  .insert([
    {
      menu_item_id: itemId,
      group_name: 'Volume',
      modifier_name: 'Small',
      price_change: 0,
      is_required: true,
      allow_multiple: false,
      sort_order: 0
    },
    {
      menu_item_id: itemId,
      group_name: 'Volume',
      modifier_name: 'Large',
      price_change: 50,
      is_required: true,
      allow_multiple: false,
      sort_order: 1
    }
  ]);
```

## Real-time Subscriptions

### New Orders
Subscribe to new orders for a cafe:

```typescript
const channel = supabase
  .channel('orders')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'orders',
      filter: `cafe_id=eq.${cafeId}`
    },
    (payload) => {
      console.log('New order:', payload.new);
      // Play sound, show notification, update UI
    }
  )
  .subscribe();
```

### Order Status Updates
Subscribe to order status changes:

```typescript
const channel = supabase
  .channel('order_updates')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'orders',
      filter: `cafe_id=eq.${cafeId}`
    },
    (payload) => {
      console.log('Order updated:', payload.new);
      // Update UI
    }
  )
  .subscribe();
```

## Row Level Security (RLS)

All tables have RLS enabled. Key policies:

### Accounts
- Owners can view/update their own account
- Admins can view all accounts

### Cafes
- Public can view published cafes
- Owners can view/manage their own cafes (all statuses)
- Admins can view/manage all cafes

### Menu Categories & Items
- Public can view items from published cafes
- Owners can manage items from their cafes

### Orders
- Owners can view/update orders for their cafes
- Customers can view their own orders
- Anonymous users can create orders (guest checkout)

## Error Handling

All RPC functions throw exceptions with descriptive messages:

```typescript
try {
  const { data, error } = await supabase.rpc('submit_cafe_for_moderation', {
    p_cafe_id: cafeId
  });
  
  if (error) throw error;
} catch (error) {
  // Common errors:
  // - 'Cafe not found'
  // - 'Unauthorized: not your cafe'
  // - 'Cafe is not ready for publication'
  // - 'Only pending requests can be approved'
  console.error(error.message);
}
```

## Migration Files

1. `20260201120000_owner_admin_panel_foundation.sql` - Core tables, RLS policies, helper functions
2. `20260201130000_owner_order_management.sql` - Order management functions

Apply migrations in order using Supabase CLI:
```bash
supabase db reset
# or
supabase migration up
```

## Next Steps

For frontend implementation:
1. Create TypeScript types matching these interfaces
2. Build server actions in Next.js for RPC calls
3. Implement React components for UI
4. Set up real-time subscriptions for orders
5. Add error handling and loading states

See `owner_admin_panel_roadmap.plan.md` for complete implementation roadmap.
