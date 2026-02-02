# Owner Admin Panel - Frontend Foundation

## Overview

This implementation provides the frontend foundation for the Owner Admin Panel, including routing, navigation, and the Cafe Switcher component as specified in the plan.

## Architecture

The Owner Admin Panel follows a **two-level structure**:

1. **Account Level** - Managing all cafes owned by the account
2. **Cafe Level** - Managing a specific cafe

## Routes Structure

```
/admin/owner/
├── dashboard/                    # Account Dashboard
├── cafes/
│   ├── page.tsx                 # List of all cafes
│   ├── new/page.tsx             # Create new cafe
│   └── [id]/page.tsx            # Edit cafe
├── finances/page.tsx            # Account finances
├── notifications/page.tsx       # Notifications
├── settings/page.tsx            # Account settings
└── cafe/[cafeId]/
    ├── dashboard/               # Cafe Dashboard
    ├── orders/                  # Orders Management (Kanban)
    ├── menu/                    # Menu Management
    ├── storefront/              # Storefront (logo, cover, description)
    ├── finances/                # Cafe Finances
    ├── settings/                # Cafe Settings
    └── publication/             # Publication Checklist
```

## Components

### CafeSwitcher

**Location:** `components/CafeSwitcher.tsx`

A dropdown component that allows owners to switch between their cafes while maintaining the current page context.

**Features:**
- Shows current cafe name and status badge
- Dropdown with all owner's cafes
- Status badges with color coding (draft, moderation, published, paused, rejected)
- "Create new cafe" action
- Context-preserving navigation (e.g., switching from Cafe A's menu to Cafe B's menu)

**Usage:**
```tsx
<CafeSwitcher 
  currentCafeId={cafeId} 
  cafes={cafes} 
/>
```

### OwnerSidebar

**Location:** `components/OwnerSidebar.tsx`

Navigation sidebar that adapts based on context (Account vs Cafe level).

**Features:**
- Switches between Account and Cafe navigation
- Active state highlighting
- Badge counters (unread notifications, active orders, etc.)
- Disabled state for unavailable sections

**Usage:**
```tsx
// Account Level
<OwnerSidebar 
  currentContext="account" 
  cafesCount={5}
  unreadNotifications={3}
/>

// Cafe Level
<OwnerSidebar 
  currentContext="cafe" 
  cafeId={cafeId}
  activeOrdersCount={12}
/>
```

## Status Colors

### Cafe Status
- **Draft** - `bg-blue-100 text-blue-800` (Черновик)
- **Moderation** - `bg-yellow-100 text-yellow-800` (На модерации)
- **Published** - `bg-green-100 text-green-800` (Опубликовано)
- **Paused** - `bg-gray-100 text-gray-800` (Приостановлено)
- **Rejected** - `bg-red-100 text-red-800` (Отклонено)

## Implementation Details

### Account Dashboard
- Welcome block with CTA to create first cafe
- Stats cards (cafes count, today's orders, today's revenue)
- Cafe summary cards with quick actions
- Recent orders table (across all cafes)

### Cafes List
- Grid view of all cafes
- Status badges
- Quick actions (Open panel, Edit, Menu)
- Empty state with CTA

### Cafe Dashboard
- Header with Cafe Switcher
- Stats cards (active orders, today's orders, revenue, status)
- Recent orders for this cafe
- Context verification (ensures user owns the cafe)

### Navigation Flow

1. Owner logs in → Redirected to `/admin/owner/dashboard`
2. Owner clicks on a cafe → Goes to `/admin/owner/cafe/{cafeId}/dashboard`
3. Owner switches cafe → URL updates to new cafeId, page context preserved
4. Owner can navigate back to account level at any time

## Security

All cafe-level pages verify:
1. User is authenticated
2. User owns the cafe they're trying to access
3. Redirect to account dashboard if verification fails

## Database Functions

The implementation uses the existing `get_owner_cafes` RPC function:

```sql
-- Returns all cafes owned by the current user
supabase.rpc('get_owner_cafes')
```

## Next Steps (From Plan)

The following features are marked as "coming soon" and ready for implementation:

### Phase 3: Menu Management
- Categories with drag-and-drop
- Menu items CRUD
- Modifiers (groups and items)
- Stop-list management

### Phase 4: Order Management
- Kanban board (5 columns)
- Real-time updates
- Status changes
- QR code scanning
- Cancel & refund

### Phase 5: Publication Flow
- Checklist with progress bar
- Moderation workflow
- Status timeline
- Publish/pause actions

### Phase 6: Cafe Creation
- Multi-step form (4 steps)
- Basic info, working hours, pre-order slots, storefront
- Form validation
- Redirect to menu management

## File Structure

```
subscribecoffie-admin/
├── components/
│   ├── CafeSwitcher.tsx
│   └── OwnerSidebar.tsx
├── app/admin/owner/
│   ├── layout.tsx              # Owner auth wrapper
│   ├── dashboard/page.tsx      # Account dashboard
│   ├── cafes/
│   │   ├── page.tsx           # Cafes list
│   │   ├── new/page.tsx       # Create cafe
│   │   └── [id]/page.tsx      # Edit cafe
│   ├── finances/page.tsx
│   ├── notifications/page.tsx
│   ├── settings/page.tsx
│   └── cafe/[cafeId]/
│       ├── dashboard/page.tsx
│       ├── orders/page.tsx
│       ├── menu/page.tsx
│       ├── storefront/page.tsx
│       ├── finances/page.tsx
│       ├── settings/page.tsx
│       └── publication/page.tsx
```

## Testing

To test the implementation:

1. Start the development server:
   ```bash
   cd subscribecoffie-admin
   npm run dev
   ```

2. Login as an owner user

3. Navigate to `/admin/owner/dashboard`

4. Test navigation through Account and Cafe levels

5. Test Cafe Switcher functionality (if you have multiple cafes)

## Notes

- The legacy `/cafe-owner` panel still exists for backward compatibility
- Both panels are accessible from the admin layout sidebar
- The new Owner Panel is the recommended interface going forward
- All placeholder pages show "coming soon" and are ready for feature implementation
