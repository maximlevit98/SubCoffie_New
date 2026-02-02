# Real-time Updates & Social Features Implementation

## Overview

This document describes the implementation of two major features from the development roadmap:
1. **Real-time Order Updates** (Phase 2.5)
2. **Social Features** (Phase 2.4)

---

## 1. Real-time Order Updates

### Backend Implementation

**File:** `supabase/migrations/20260214_realtime_config.sql`

#### Features Implemented:

1. **Realtime Publication**
   - Enabled Supabase realtime for the `orders` table
   - Orders table now broadcasts changes to subscribed clients

2. **RPC Functions**
   - `subscribe_to_order_updates(order_id)` - Returns channel information for subscribing to specific order updates
   
3. **Database Triggers**
   - `notify_order_update()` - Automatically notifies subscribers when order status changes
   - Trigger fires on `UPDATE` of `status` column in `orders` table

4. **Views**
   - `active_orders_realtime` - Materialized view showing active orders with cafe and items details
   - Optimized for real-time queries with proper indexing

5. **Row Level Security (RLS)**
   - Users can only view their own active orders
   - Proper authentication checks in place

### iOS Implementation

#### File: `Helpers/RealtimeOrderService.swift`

**Classes:**

1. **`RealtimeOrderService`**
   - Subscribes to updates for a single order
   - Uses Supabase Realtime Channels v2
   - Automatically updates order state when changes occur
   - Provides connection status monitoring
   - Clean unsubscribe on deinit

2. **`ActiveOrdersRealtimeService`**
   - Manages multiple active orders for a user
   - Subscribes to all user's orders
   - Fetches initial state and updates in real-time
   - Connection status tracking

**Features:**
- Live connection indicator
- Error handling and reconnection
- Automatic cleanup on view dismissal
- Thread-safe with `@MainActor`

#### File: `Views/ActiveOrdersView.swift`

**Views Implemented:**

1. **`ActiveOrdersView`**
   - Main view for displaying all active orders
   - Shows "Live" indicator when connected
   - Pull-to-refresh support
   - Empty state handling

2. **`ActiveOrderCard`**
   - Card component for each order
   - Displays order status, timeline, and total
   - Status badge with color coding

3. **`OrderStatusTimeline`**
   - Visual timeline showing order progress
   - States: Placed → Preparing → Ready
   - Color-coded based on current status

4. **`OrderDetailRealtimeView`**
   - Detailed view of a single order with real-time updates
   - Shows order details and status
   - Live indicator with animation
   - Ready-at timestamp display

**Features:**
- Real-time status updates without manual refresh
- Clean UI with proper loading states
- Status badges with appropriate colors
- Timeline visualization
- Tap to see order details

---

## 2. Social Features

### Backend Implementation

**File:** `supabase/migrations/20260213_social_features.sql`

#### Database Tables:

1. **`user_reviews`**
   - User reviews for cafes and menu items
   - Rating (1-5 stars) with optional comment
   - Linked to orders for verified reviews
   - Constraint: One review per user per cafe/item
   - Indexes on user_id, cafe_id, menu_item_id, rating

2. **`user_favorites`**
   - User favorite cafes and menu items
   - Quick access to preferred items
   - Constraint: One favorite per user per cafe/item
   - Indexes on user_id, cafe_id, menu_item_id

3. **`user_friends`**
   - Friend relationships between users
   - Status: pending, accepted, rejected, blocked
   - Bidirectional friendship tracking
   - Prevents self-friendship

4. **`shared_orders`**
   - Group orders with split billing
   - Tracks contribution amounts per participant
   - Status: pending, accepted, paid, cancelled
   - Links participants to orders

#### RPC Functions:

1. **`submit_review(cafe_id, menu_item_id, order_id, rating, comment)`**
   - Submit or update a review
   - Validates rating (1-5)
   - Handles upserts automatically
   - Returns success status and review ID

2. **`toggle_favorite(cafe_id, menu_item_id)`**
   - Add or remove favorites
   - Returns favorite status
   - Idempotent operation

3. **`invite_friend_to_order(order_id, friend_user_id, contribution_amount)`**
   - Create split payment invitation
   - Validates order ownership
   - Sets contribution amount

4. **`get_user_reviews(user_id)`**
   - Fetch all reviews by a user
   - Joins with cafe and menu_item names
   - Ordered by creation date

5. **`get_cafe_reviews(cafe_id)`**
   - Fetch all reviews for a cafe
   - Calculates average rating
   - Ordered by creation date

6. **`get_user_favorites(user_id)`**
   - Fetch all favorites for a user
   - Joins with cafe and menu_item names
   - Ordered by creation date

#### Security:

- Full Row Level Security (RLS) on all tables
- Users can only view/edit their own data
- Public reviews visible to all
- Proper authentication checks

### iOS Implementation

#### File: `Views/ReviewView.swift`

**Views:**

1. **`ReviewSubmissionView`**
   - Form for submitting reviews
   - 5-star rating system with tap interaction
   - Text editor for comments (500 char limit)
   - Character counter
   - Async submission with loading state
   - Error handling

2. **`ReviewsListView`**
   - List of reviews for a cafe or menu item
   - Average rating card at top
   - Individual review cards
   - Loading and empty states

3. **`AverageRatingCard`**
   - Large rating number display
   - Star visualization
   - Review count

4. **`ReviewCard`**
   - Individual review display
   - Star rating
   - Comment text
   - Relative timestamp

**Service:**

- `ReviewService` - Handles all review operations
- Async/await networking
- Error handling
- State management with `@Published` properties

#### File: `Views/FavoritesView.swift`

**Views:**

1. **`FavoritesView`**
   - Main favorites view with tabs
   - Segmented control: Cafes / Items
   - Pull-to-refresh
   - Loading and empty states

2. **`FavoriteCafesListView`**
   - List of favorite cafes
   - Scrollable with proper spacing

3. **`FavoriteItemsListView`**
   - List of favorite menu items
   - Scrollable with proper spacing

4. **`FavoriteCafeCard`**
   - Card displaying favorite cafe
   - Cafe icon
   - Name and timestamp
   - Heart button to remove

5. **`FavoriteItemCard`**
   - Card displaying favorite menu item
   - Item icon
   - Name and timestamp
   - Heart button to remove

6. **`FavoriteButton`**
   - Reusable heart button component
   - Use in cafe and menu item views
   - Animated heart fill/unfill
   - Spring animation on tap
   - Automatically checks favorite status

**Service:**

- `FavoritesService` - Manages favorites
- Toggle favorite functionality
- Check favorite status
- Load user favorites with separation

#### File: `Views/GroupOrderView.swift`

**Views:**

1. **`GroupOrderInviteView`**
   - Form to invite friends to split order
   - Order total display
   - Split method selection:
     - Split equally
     - Custom amounts
   - Friend selection list
   - Custom amount input per friend
   - Validation and error handling

2. **`FriendSelectionRow`**
   - Row for selecting a friend
   - Checkbox interaction
   - Custom amount input field
   - Shows friend name and phone

3. **`GroupOrderStatusView`**
   - View showing split payment status
   - List of participants
   - Payment status per participant
   - Loading and empty states

4. **`SharedOrderCard`**
   - Card showing participant info
   - Contribution amount
   - Payment status badge
   - Timestamp

5. **`StatusBadgeShared`**
   - Status badge for shared orders
   - Color-coded by status
   - States: Pending, Accepted, Paid, Cancelled

**Services:**

- `GroupOrderService` - Manages group orders
  - Load shared orders
  - Invite friends to order
  - Track payment status

- `FriendsService` - Manages user friends
  - Load friends list
  - (Placeholder for future friend management)

**Models:**

- `SharedOrder` - Represents a split payment
- `SharedOrderStatus` - Enum for payment status
- `Friend` - Represents a user friend

---

## Integration Guide

### Using Real-time Updates

```swift
import SwiftUI

struct MyOrderView: View {
    @StateObject private var realtimeService = RealtimeOrderService()
    let order: Order
    
    var body: some View {
        VStack {
            if realtimeService.isConnected {
                Text("Live")
                    .foregroundColor(.green)
            }
            
            if let currentOrder = realtimeService.currentOrder {
                Text("Status: \(currentOrder.status)")
            }
        }
        .task {
            await realtimeService.subscribeToOrder(order)
        }
        .onDisappear {
            Task {
                await realtimeService.unsubscribe()
            }
        }
    }
}
```

### Using Reviews

```swift
// Show review submission
ReviewSubmissionView(
    cafeId: cafe.id,
    menuItemId: nil,
    orderId: order.id,
    targetName: cafe.name
)

// Show reviews list
ReviewsListView(cafeId: cafe.id, menuItemId: nil)
```

### Using Favorites

```swift
// Add favorite button to any view
FavoriteButton(cafeId: cafe.id, menuItemId: nil)

// Show user's favorites
FavoritesView(userId: currentUserId)
```

### Using Group Orders

```swift
// Invite friends to split order
GroupOrderInviteView(order: order)

// Show split payment status
GroupOrderStatusView(orderId: order.id)
```

---

## Database Migration

To apply these features to your database:

```bash
# Apply real-time configuration
supabase migration up 20260214_realtime_config.sql

# Apply social features
supabase migration up 20260213_social_features.sql
```

Or run all migrations:

```bash
supabase db reset
```

---

## Testing Checklist

### Real-time Updates

- [ ] Create an order from iOS app
- [ ] Update order status from admin panel
- [ ] Verify iOS app updates status automatically
- [ ] Check "Live" indicator appears
- [ ] Test with multiple orders
- [ ] Test connection loss/recovery

### Reviews

- [ ] Submit a review for a cafe
- [ ] Submit a review for a menu item
- [ ] View reviews list
- [ ] Update an existing review
- [ ] Check average rating calculation
- [ ] Test character limit (500)

### Favorites

- [ ] Add cafe to favorites
- [ ] Add menu item to favorites
- [ ] Remove from favorites
- [ ] View favorites list
- [ ] Test favorite button animation
- [ ] Check favorites persist after app restart

### Group Orders

- [ ] Create a group order invitation
- [ ] Test split equally
- [ ] Test custom amounts
- [ ] Invite multiple friends
- [ ] View split payment status
- [ ] Test validation (total matches order amount)

---

## Next Steps

1. **Push Notifications**
   - Add push notifications for order status changes
   - Notify users when friends invite them to split orders
   - Notify when someone reviews your cafe

2. **Friends Management**
   - Complete friend request flow
   - Friend search functionality
   - Friend suggestions

3. **Enhanced Reviews**
   - Photo upload for reviews
   - Review helpfulness voting
   - Report inappropriate reviews

4. **Social Sharing**
   - Share favorite cafes with friends
   - Share orders on social media
   - Invite friends to join app

5. **Analytics**
   - Track review engagement
   - Monitor favorite trends
   - Analyze group order patterns

---

## API Reference

### Real-time Endpoints

```typescript
// Subscribe to order updates
const channel = supabase.channel(`orders:${orderId}`)
  .on('postgres_changes', {
    event: 'UPDATE',
    schema: 'public',
    table: 'orders',
    filter: `id=eq.${orderId}`
  }, payload => {
    console.log('Order updated:', payload)
  })
  .subscribe()
```

### Social Features RPC Calls

```typescript
// Submit review
await supabase.rpc('submit_review', {
  p_cafe_id: cafeId,
  p_rating: 5,
  p_comment: 'Great coffee!'
})

// Toggle favorite
await supabase.rpc('toggle_favorite', {
  p_cafe_id: cafeId
})

// Invite friend to order
await supabase.rpc('invite_friend_to_order', {
  p_order_id: orderId,
  p_friend_user_id: friendId,
  p_contribution_amount: 250
})
```

---

## Performance Considerations

### Real-time

- Real-time connections are maintained per view
- Automatic cleanup on view dismissal
- Use `active_orders_realtime` view for optimized queries
- Consider rate limiting for frequent updates

### Social Features

- Reviews and favorites use indexes for fast queries
- Average ratings calculated on-demand (consider caching for high-traffic cafes)
- RLS policies ensure data privacy
- Consider pagination for large review lists

---

## Known Limitations

1. **Real-time**
   - Requires stable network connection
   - May have slight delay (1-2 seconds)
   - Limited to authenticated users

2. **Social Features**
   - Friends system is basic (can be enhanced)
   - No photo uploads for reviews yet
   - Group orders require manual payment tracking
   - No notification system yet

---

## Support

For issues or questions:
- Check Supabase logs: `supabase logs`
- Review RLS policies if access issues occur
- Ensure migrations are applied in order
- Check iOS console for real-time connection errors

---

**Implementation Date:** January 30, 2026  
**Version:** 1.0  
**Status:** ✅ Complete
