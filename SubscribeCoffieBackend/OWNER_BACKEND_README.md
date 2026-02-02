# Owner Admin Panel - Backend

Complete backend implementation for the Owner Admin Panel, providing cafe owners with full control over their locations, menus, and orders.

## 🎯 Status: ✅ Production Ready

The backend foundation has been fully implemented and tested. All Phase 1 requirements from the implementation roadmap are complete.

## 📚 Quick Links

- **[Quickstart Guide](./OWNER_BACKEND_QUICKSTART.md)** - Get started in 5 minutes
- **[API Contract](./OWNER_API_CONTRACT.md)** - Complete API reference
- **[TypeScript Types](./types/owner-admin-panel.ts)** - Type definitions
- **[Implementation Summary](./OWNER_BACKEND_IMPLEMENTATION_SUMMARY.md)** - What was built
- **[Test Suite](./tests/owner_admin_panel_tests.sql)** - Automated tests

## 🚀 Quick Start

### 1. Apply Migrations

```bash
cd SubscribeCoffieBackend
supabase db reset
```

### 2. Run Tests

```bash
psql -h localhost -U postgres -d postgres -f tests/owner_admin_panel_tests.sql
```

### 3. Start Using the API

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(URL, KEY);

// Create owner account
const { data: account } = await supabase.rpc('get_or_create_owner_account', {
  p_user_id: userId,
  p_company_name: 'My Coffee Business'
});

// Get cafes
const { data: cafes } = await supabase.rpc('get_owner_cafes', {
  p_user_id: userId
});
```

See the [Quickstart Guide](./OWNER_BACKEND_QUICKSTART.md) for complete examples.

## 📦 What's Included

### Database Schema

✅ **8 tables** created/enhanced:
- `accounts` - Owner organizations
- `cafes` - Cafe locations (enhanced with status workflow)
- `menu_categories` - Category organization
- `menu_items` - Menu products (enhanced with modifiers support)
- `menu_modifiers` - Size, milk, add-ons
- `orders` - Customer orders (enhanced with owner features)
- `cafe_publication_history` - Moderation audit trail
- Related tables: `order_items`, `order_events`

### API Functions

✅ **16 RPC functions**:

**Account Management**
- `get_or_create_owner_account()` - Initialize owner
- `get_owner_cafes()` - List owned cafes

**Cafe Operations**
- `get_cafe_publication_checklist()` - Readiness check
- `submit_cafe_for_moderation()` - Publish workflow
- `duplicate_cafe()` - Clone cafe with menu

**Order Management**
- `owner_update_order_status()` - Status transitions
- `owner_cancel_order()` - Cancel with refund
- `get_cafe_orders()` - Filtered order list
- `get_order_details()` - Complete order info
- `get_cafe_orders_by_status()` - Kanban data

**Analytics**
- `get_cafe_dashboard_stats()` - Cafe metrics
- `get_account_dashboard_stats()` - Account metrics

**Menu**
- `toggle_menu_item_stop_list()` - Availability toggle

### Security

✅ **Row Level Security** on all tables:
- Owners see only their data
- Customers see only their orders
- Public sees only published cafes
- Admins see everything

✅ **Function Security**:
- Authorization checks in every function
- Ownership validation
- No cross-cafe data leakage

### Documentation

✅ **Complete documentation**:
- API contract with TypeScript examples
- Type definitions for all entities
- Step-by-step quickstart guide
- Implementation summary
- Test suite with 10 automated tests

## 🏗️ Architecture

### Two-Level Structure

```
Owner Account (Organization)
└── Cafe 1
    ├── Menu Categories
    │   └── Menu Items
    │       └── Modifiers
    └── Orders
└── Cafe 2
    └── ...
```

### Publication Workflow

```
Draft → Moderation → Published
  ↓                      ↓
Rejected              Paused
  ↓
Draft
```

### Order Status Machine

```
Created → Accepted → In progress → Ready → Picked up
   ↓         ↓           ↓
Canceled ← ← ← ← ← ← ← ←
```

## 🔧 Technical Stack

- **Database**: PostgreSQL (Supabase)
- **Authentication**: Supabase Auth
- **Real-time**: Supabase Realtime
- **API**: Supabase Auto-generated REST + Custom RPC
- **Types**: TypeScript

## 📊 Test Results

```
✅ Test 1: Account Creation - PASSED
✅ Test 2: Cafe Creation - PASSED
✅ Test 3: Menu Categories - PASSED
✅ Test 4: Menu Items - PASSED
✅ Test 5: Menu Modifiers - PASSED
✅ Test 6: Publication Checklist - PASSED
✅ Test 7: Duplicate Cafe - PASSED
✅ Test 8: Order Management - PASSED
✅ Test 9: Dashboard Stats - PASSED
✅ Test 10: RLS Policies - PASSED

=== ALL TESTS PASSED ===
```

## 🎨 Frontend Integration

Ready to integrate with:
- ✅ Next.js App Router
- ✅ React components
- ✅ Server Actions
- ✅ Real-time subscriptions

Example server action:

```typescript
'use server';
import { createServerClient } from '@/lib/supabase/server';

export async function getCafes(userId: string) {
  const supabase = createServerClient();
  
  const { data, error } = await supabase.rpc('get_owner_cafes', {
    p_user_id: userId
  });
  
  if (error) throw error;
  return data;
}
```

## 🔐 Environment Variables

Required for frontend:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## 📝 API Example

### Create Complete Cafe Setup

```typescript
// 1. Create account
const { data: account } = await supabase.rpc('get_or_create_owner_account', {
  p_user_id: userId,
  p_company_name: 'My Coffee'
});

// 2. Create cafe
const { data: cafe } = await supabase
  .from('cafes')
  .insert({
    account_id: account.id,
    name: 'Downtown Coffee',
    address: '123 Main St',
    status: 'draft'
  })
  .select()
  .single();

// 3. Add menu items
await supabase.from('menu_items').insert([
  { cafe_id: cafe.id, name: 'Cappuccino', price_credits: 250, category: 'drinks' },
  { cafe_id: cafe.id, name: 'Latte', price_credits: 280, category: 'drinks' },
  { cafe_id: cafe.id, name: 'Croissant', price_credits: 180, category: 'food' }
]);

// 4. Check readiness
const { data: checklist } = await supabase.rpc('get_cafe_publication_checklist', {
  p_cafe_id: cafe.id
});

// 5. Submit for moderation
const { data: published } = await supabase.rpc('submit_cafe_for_moderation', {
  p_cafe_id: cafe.id
});
```

## 🔄 Real-time Orders

```typescript
const channel = supabase
  .channel('orders')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'orders',
    filter: `cafe_id=eq.${cafeId}`
  }, (payload) => {
    console.log('New order!', payload.new);
  })
  .subscribe();
```

## 🐛 Troubleshooting

### "Unauthorized" error
- Check user has `role = 'owner'` in profiles
- Verify cafe belongs to user's account

### Real-time not working
- Enable Real-time in Supabase dashboard
- Check RLS policies allow table access

### Tests failing
- Ensure migrations are applied in order
- Run `supabase db reset` to clean state

## 📈 Performance

- **Indexes**: 15+ indexes for optimal query performance
- **RLS**: Efficient policies using EXISTS subqueries
- **Pagination**: All list endpoints support limits/offsets
- **Aggregations**: Single-query stats calculations

## 🛣️ Roadmap

### ✅ Phase 1: Backend Foundation (COMPLETE)
- Database schema
- RLS policies
- API functions
- Documentation

### 🔜 Phase 2: Frontend Foundation
- Next.js routing
- Component structure
- Layouts

### 🔜 Phase 3: MVP Features
- Dashboard
- Menu management
- Order Kanban
- Publication flow

### 🔜 Phase 4: Advanced Features
- Financials
- Analytics
- Reports

## 🤝 Contributing

This is part of the SubscribeCoffie project. Follow the existing patterns:

1. All tables must have RLS enabled
2. All functions must validate ownership
3. Use TypeScript for type safety
4. Add tests for new features
5. Document all public APIs

## 📄 License

Part of SubscribeCoffie project.

## 🔗 Related Projects

- **iOS App** - `SubscribeCoffieClean/`
- **Admin Panel** - Coming soon
- **Customer Web** - Coming soon

---

**Built with ❤️ for cafe owners**

Need help? Check the [Quickstart Guide](./OWNER_BACKEND_QUICKSTART.md) or [API Contract](./OWNER_API_CONTRACT.md).
