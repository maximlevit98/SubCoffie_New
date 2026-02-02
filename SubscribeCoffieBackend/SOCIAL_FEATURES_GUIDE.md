# Social Features Implementation Guide

## Overview
This guide describes the social features implementation for SubscribeCoffie, including reviews, favorites, friends, and shared orders (split bills).

## Backend Implementation

### Database Schema

#### Tables Created (Migration: 20260213000000_social_features.sql)

1. **user_reviews** - User reviews for cafes and menu items
   - Support for both cafe and menu item reviews
   - Rating (1-5 stars)
   - Comment and photos
   - Verified purchase badge
   - Helpful count tracking

2. **review_helpfulness** - Track which users found reviews helpful

3. **user_favorites** - User favorites for cafes and menu items
   - Support for both cafe and menu item favorites
   - Timestamp tracking

4. **user_friends** - Friend connections between users
   - Status: pending, accepted, blocked
   - Bidirectional friendship tracking

5. **shared_orders** - Shared orders for group payments
   - Order splitting functionality
   - Payment tracking per participant

6. **shared_order_participants** - Participants in shared orders
   - Individual payment amounts
   - Payment status tracking

### RPC Functions

#### Reviews
- `submit_review(p_user_id, p_cafe_id, p_menu_item_id, p_order_id, p_rating, p_comment, p_photos)`
- `mark_review_helpful(p_review_id, p_user_id, p_is_helpful)`
- `get_cafe_reviews(p_cafe_id, p_limit, p_offset)`

#### Favorites
- `toggle_favorite(p_user_id, p_cafe_id, p_menu_item_id)`
- `get_user_favorites(p_user_id, p_type)`

#### Friends
- `send_friend_request(p_user_id, p_friend_id)`
- `respond_to_friend_request(p_request_id, p_user_id, p_accept)`
- `get_user_friends(p_user_id, p_status)`

#### Shared Orders
- `create_shared_order(p_order_id, p_initiator_user_id, p_participants)`
- `pay_shared_order_share(p_participant_id, p_user_id, p_wallet_id)`

### Row Level Security (RLS)

All tables have RLS policies enabled:
- Users can only view their own data
- Reviews are publicly viewable when active
- Friend requests can be responded to by the recipient
- Shared order participants can only see orders they're involved in

## iOS Implementation

### Models (SocialModels.swift)

#### Review Models
- `Review` - Review entity
- `ReviewSubmission` - For creating new reviews
- `CafeReviewsSummary` - Aggregated review data
- `ReviewWithUser` - Review with user information

#### Favorite Models
- `Favorite` - Favorite entity
- `FavoriteCafe` - Favorite cafe with details
- `FavoriteMenuItem` - Favorite menu item with details
- `UserFavorites` - User's favorites collection

#### Friend Models
- `Friend` - Friend relationship entity
- `FriendInfo` - Friend information with status
- `FriendStatus` - Enum: pending, accepted, blocked

#### Shared Order Models
- `SharedOrder` - Shared order entity
- `SharedOrderParticipant` - Participant in shared order
- `SharedOrderStatus` - Enum: pending, confirmed, cancelled
- `ParticipantPaymentStatus` - Enum: pending, paid, declined

### Service (SocialService.swift)

The `SocialService` class provides all API calls for social features:

```swift
@StateObject private var socialService = SocialService()

// Reviews
await socialService.submitReview(cafeId: cafeId, rating: 5, comment: "Great!")
let reviews = await socialService.getCafeReviews(cafeId: cafeId)
await socialService.markReviewHelpful(reviewId: id, isHelpful: true)

// Favorites
let isFavorited = await socialService.toggleFavorite(cafeId: cafeId)
let favorites = await socialService.getUserFavorites()
let isFavorited = await socialService.checkIfFavorited(cafeId: cafeId)

// Friends
await socialService.sendFriendRequest(friendId: friendId)
await socialService.respondToFriendRequest(requestId: id, accept: true)
let friends = await socialService.getUserFriends()

// Shared Orders
let sharedOrderId = await socialService.createSharedOrder(orderId: id, participants: [])
let allPaid = await socialService.paySharedOrderShare(participantId: id, walletId: walletId)
```

### Views

#### ReviewView.swift
1. **SubmitReviewView** - Form to submit a review
   - Star rating selector
   - Comment text field
   - Photo upload support
   - Verified purchase badge
   
2. **CafeReviewsView** - List of reviews for a cafe
   - Average rating display
   - Individual review cards
   - Helpful button
   
3. **ReviewCardView** - Individual review display
   - User avatar
   - Rating stars
   - Comment and photos
   - Helpful count

#### FavoritesView.swift
1. **FavoritesView** - Main favorites view
   - Segmented control: Cafes / Menu Items
   - Lists of favorites
   
2. **FavoriteCafesListView** - List of favorite cafes
3. **FavoriteMenuItemsListView** - List of favorite menu items
4. **FavoriteToggleButton** - Reusable heart button component

#### GroupOrderView.swift
1. **CreateSharedOrderView** - Create a group order
   - Add participants
   - Assign payment amounts
   - Validate total amount
   
2. **FriendsListView** - Manage friends
   - Accepted friends list
   - Pending requests with accept/decline
   
3. **AddParticipantView** - Select friend to add to order
4. **FriendRequestCardView** - Friend request card with actions

#### UserReviewsView.swift
1. **UserReviewsView** - User's own reviews
2. **ProfileStatisticsView** - Statistics widget showing:
   - Number of reviews
   - Number of favorites
   - Number of friends

## Integration Guide

### Step 1: Run Database Migration

```bash
cd SubscribeCoffieBackend
supabase db push
```

### Step 2: Add Social Features to Navigation

Update your app's navigation to include:

```swift
// In TabView or NavigationView
NavigationLink("Favorites", destination: FavoritesView())
NavigationLink("Friends", destination: FriendsListView())
NavigationLink("My Reviews", destination: UserReviewsView())
```

### Step 3: Add Review Button After Order

In `OrderStatusView.swift`, when order status is "issued":

```swift
Button("Leave Review") {
    showReviewSheet = true
}
.sheet(isPresented: $showReviewSheet) {
    SubmitReviewView(
        cafeId: order.cafeId,
        menuItemId: nil,
        orderId: order.id,
        cafeName: order.cafeName,
        itemName: nil
    )
}
```

### Step 4: Add Favorite Buttons

In `CafeView.swift`:

```swift
// In toolbar or header
FavoriteToggleButton(cafeId: cafe.id, menuItemId: nil)
```

In menu item cards:

```swift
FavoriteToggleButton(cafeId: nil, menuItemId: menuItem.id)
```

### Step 5: Add Split Bill Option

In `CheckoutView.swift` or order confirmation screen:

```swift
Button("Split with Friends") {
    showGroupOrderSheet = true
}
.sheet(isPresented: $showGroupOrderSheet) {
    CreateSharedOrderView(
        orderId: order.id,
        totalAmount: order.totalAmountCredits
    )
}
```

### Step 6: Update Profile View

Add to `ProfileView.swift`:

```swift
// Statistics section
ProfileStatisticsView()

// Navigation links
NavigationLink("My Reviews", destination: UserReviewsView())
NavigationLink("Favorites", destination: FavoritesView())
NavigationLink("Friends", destination: FriendsListView())
```

### Step 7: Add Reviews to Cafe Detail

In `CafeView.swift`:

```swift
NavigationLink("Reviews (\(reviewsCount))") {
    CafeReviewsView(cafeId: cafe.id, cafeName: cafe.name)
}
```

## Features Summary

### ✅ Reviews
- [x] Submit reviews with rating and comment
- [x] View cafe reviews with average rating
- [x] Mark reviews as helpful
- [x] Verified purchase badges
- [x] Photo support (infrastructure ready)
- [x] User's own reviews view

### ✅ Favorites
- [x] Add/remove cafes from favorites
- [x] Add/remove menu items from favorites
- [x] View all favorites (segmented by type)
- [x] Favorite toggle button component

### ✅ Friends
- [x] Send friend requests
- [x] Accept/decline friend requests
- [x] View friends list
- [x] Friend status tracking

### ✅ Shared Orders (Split Bills)
- [x] Create group orders
- [x] Add participants from friends list
- [x] Assign payment amounts per participant
- [x] Pay individual shares
- [x] Track payment status
- [x] Confirm when all participants paid

## Security Considerations

1. **RLS Policies**: All tables have Row Level Security enabled
2. **User Verification**: Reviews linked to orders show "verified purchase" badge
3. **Friend Requests**: Users can only respond to requests sent to them
4. **Shared Orders**: Only participants can view and pay for their share
5. **Data Privacy**: Users can only see their own favorites and friend lists

## Analytics Views

Two analytics views are created for admin/cafe owners:

1. **cafe_ratings_summary** - Aggregated ratings per cafe
2. **popular_items_by_favorites** - Most favorited menu items

## Future Enhancements

- [ ] Photo upload to Supabase Storage
- [ ] Push notifications for friend requests
- [ ] Push notifications for shared order payment reminders
- [ ] Social feed showing friends' reviews
- [ ] Review replies from cafe owners
- [ ] Friend recommendations
- [ ] Share orders via deep links
- [ ] Review moderation for admins

## Testing

### Manual Testing Checklist

#### Reviews
- [ ] Submit a review for a cafe
- [ ] Submit a review for a menu item
- [ ] View reviews on cafe detail page
- [ ] Mark a review as helpful
- [ ] View your own reviews

#### Favorites
- [ ] Add cafe to favorites
- [ ] Remove cafe from favorites
- [ ] Add menu item to favorites
- [ ] Remove menu item from favorites
- [ ] View favorites list

#### Friends
- [ ] Send friend request
- [ ] Accept friend request
- [ ] Decline friend request
- [ ] View friends list

#### Shared Orders
- [ ] Create group order
- [ ] Add participants
- [ ] Assign payment amounts
- [ ] Pay your share
- [ ] Verify order confirmed when all paid

## Troubleshooting

### Reviews not showing
- Check RLS policies are enabled
- Verify review status is 'active'
- Check user authentication

### Favorites not persisting
- Verify user_id matches authenticated user
- Check unique constraint on favorites table

### Friend requests not working
- Ensure both users exist in auth.users
- Check friend_id is valid UUID
- Verify bidirectional friendship logic

### Shared orders failing
- Verify total amounts match
- Check all participants have valid user_ids
- Ensure wallet has sufficient balance

## Support

For issues or questions, check:
- Migration file: `20260213000000_social_features.sql`
- Service implementation: `SocialService.swift`
- View implementations: `ReviewView.swift`, `FavoritesView.swift`, `GroupOrderView.swift`
