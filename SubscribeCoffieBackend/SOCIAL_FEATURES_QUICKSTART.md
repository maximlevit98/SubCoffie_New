# Social Features Quick Start Guide

## 🚀 Quick Setup (5 minutes)

### 1. Apply Database Migration

```bash
cd SubscribeCoffieBackend
supabase db reset  # or supabase db push
```

### 2. Run Tests (Optional)

```bash
supabase db test tests/social_features.test.sql
```

### 3. Integration Checklist

Add to your iOS app:

#### In CafeView.swift
```swift
// Add favorite button in toolbar
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        FavoriteToggleButton(cafeId: cafe.id, menuItemId: nil)
    }
}

// Add reviews section
Section("Reviews") {
    NavigationLink {
        CafeReviewsView(cafeId: cafe.id, cafeName: cafe.name)
    } label: {
        HStack {
            Image(systemName: "star.fill")
            Text("See Reviews")
        }
    }
}
```

#### In OrderStatusView.swift (after order completed)
```swift
if order.status == "issued" {
    Button("Leave a Review") {
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
}
```

#### In CheckoutView.swift (add split bill option)
```swift
Button("Split Bill with Friends") {
    showGroupOrderSheet = true
}
.sheet(isPresented: $showGroupOrderSheet) {
    CreateSharedOrderView(
        orderId: orderId,
        totalAmount: totalAmount
    )
}
```

#### In ProfileView.swift
```swift
// Add statistics
ProfileStatisticsView()
    .padding()

// Add navigation links
List {
    NavigationLink("My Reviews", destination: UserReviewsView())
    NavigationLink("Favorites", destination: FavoritesView())
    NavigationLink("Friends", destination: FriendsListView())
}
```

## 📱 Usage Examples

### Reviews

```swift
@StateObject private var socialService = SocialService()

// Submit a review
let reviewId = try await socialService.submitReview(
    cafeId: cafe.id,
    rating: 5,
    comment: "Amazing coffee!"
)

// Get cafe reviews
let reviews = try await socialService.getCafeReviews(cafeId: cafe.id)
print("Average rating: \(reviews.averageRating ?? 0)")
print("Total reviews: \(reviews.totalReviews)")

// Mark review as helpful
try await socialService.markReviewHelpful(
    reviewId: review.id,
    isHelpful: true
)
```

### Favorites

```swift
// Toggle favorite
let isFavorited = try await socialService.toggleFavorite(cafeId: cafe.id)
print("Is favorited: \(isFavorited)")

// Get all favorites
let favorites = try await socialService.getUserFavorites()
print("Favorite cafes: \(favorites.cafes.count)")
print("Favorite items: \(favorites.menuItems.count)")

// Check if already favorited
let isFavorited = try await socialService.checkIfFavorited(cafeId: cafe.id)
```

### Friends

```swift
// Send friend request
try await socialService.sendFriendRequest(friendId: friendId)

// Accept friend request
try await socialService.respondToFriendRequest(
    requestId: requestId,
    accept: true
)

// Get friends list
let friends = try await socialService.getUserFriends(status: "accepted")
print("Friends count: \(friends.count)")

// Get pending requests
let pendingRequests = try await socialService.getUserFriends(status: "pending")
```

### Shared Orders (Split Bills)

```swift
// Create shared order
let participants = [
    SharedOrderParticipantInput(
        userId: friend1Id,
        shareAmountCredits: 250
    ),
    SharedOrderParticipantInput(
        userId: friend2Id,
        shareAmountCredits: 250
    )
]

let sharedOrderId = try await socialService.createSharedOrder(
    orderId: order.id,
    participants: participants
)

// Pay your share
let allPaid = try await socialService.paySharedOrderShare(
    participantId: participantId,
    walletId: wallet.id
)

if allPaid {
    print("All participants have paid! Order confirmed.")
}
```

## 🎯 Common Use Cases

### 1. Add Review Button After Order Completion

```swift
struct OrderCompletedView: View {
    let order: Order
    @State private var showReviewSheet = false
    
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Order Completed!")
                .font(.title)
            
            Button("Leave a Review") {
                showReviewSheet = true
            }
            .buttonStyle(.borderedProminent)
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
    }
}
```

### 2. Favorite Heart Button on Menu Items

```swift
struct MenuItemCard: View {
    let item: MenuItem
    
    var body: some View {
        HStack {
            // Item details
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                Text(item.description ?? "")
                    .font(.caption)
            }
            
            Spacer()
            
            // Favorite button
            FavoriteToggleButton(
                cafeId: nil,
                menuItemId: item.id
            )
        }
    }
}
```

### 3. Split Bill Flow

```swift
struct OrderSummaryView: View {
    let order: Order
    @State private var showSplitOptions = false
    
    var body: some View {
        VStack {
            // Order summary
            Text("Total: \(order.totalAmountCredits) ₽")
            
            // Payment options
            Button("Pay Full Amount") {
                // Pay full amount
            }
            
            Button("Split with Friends") {
                showSplitOptions = true
            }
        }
        .sheet(isPresented: $showSplitOptions) {
            CreateSharedOrderView(
                orderId: order.id,
                totalAmount: order.totalAmountCredits
            )
        }
    }
}
```

### 4. Display Reviews on Cafe Page

```swift
struct CafeDetailView: View {
    let cafe: Cafe
    @StateObject private var socialService = SocialService()
    @State private var reviewsSummary: CafeReviewsSummary?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Cafe info
                Text(cafe.name)
                    .font(.largeTitle)
                
                // Reviews summary
                if let summary = reviewsSummary {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", summary.averageRating ?? 0))
                        Text("(\(summary.totalReviews) reviews)")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("See All Reviews") {
                        CafeReviewsView(
                            cafeId: cafe.id,
                            cafeName: cafe.name
                        )
                    }
                }
            }
        }
        .task {
            do {
                reviewsSummary = try await socialService.getCafeReviews(
                    cafeId: cafe.id,
                    limit: 5
                )
            } catch {
                print("Error loading reviews: \(error)")
            }
        }
    }
}
```

## 🔧 Customization

### Custom Review Rating Colors

```swift
// In ReviewView.swift, modify star colors
Image(systemName: star <= rating ? "star.fill" : "star")
    .foregroundColor(star <= rating ? .orange : .gray) // Change from .yellow to .orange
```

### Custom Favorite Icon

```swift
// In FavoritesView.swift, modify favorite icon
Image(systemName: isFavorited ? "bookmark.fill" : "bookmark") // Change from heart to bookmark
    .foregroundColor(isFavorited ? .blue : .gray)
```

### Custom Friend Request Actions

```swift
// Add custom actions in FriendRequestCardView
HStack {
    Button("Block") {
        // Block user
    }
    Button("Decline") { /* ... */ }
    Button("Accept") { /* ... */ }
}
```

## 📊 Analytics Integration

### Track Social Features Usage

```swift
// In SocialService.swift, add analytics

func submitReview(...) async throws -> UUID {
    let reviewId = try await /* ... */
    
    // Track event
    Analytics.track("review_submitted", properties: [
        "cafe_id": cafeId?.uuidString ?? "",
        "rating": rating,
        "has_comment": comment != nil
    ])
    
    return reviewId
}

func toggleFavorite(...) async throws -> Bool {
    let isFavorited = try await /* ... */
    
    // Track event
    Analytics.track(isFavorited ? "favorite_added" : "favorite_removed", properties: [
        "cafe_id": cafeId?.uuidString ?? "",
        "item_id": menuItemId?.uuidString ?? ""
    ])
    
    return isFavorited
}
```

## 🐛 Debugging

### Enable Detailed Logging

```swift
// In SocialService.swift
private func debugLog(_ message: String) {
    #if DEBUG
    print("[SocialService] \(message)")
    #endif
}

func submitReview(...) async throws -> UUID {
    debugLog("Submitting review for cafe: \(cafeId?.uuidString ?? "N/A")")
    // ...
}
```

### Test with Mock Data

```swift
#if DEBUG
extension SocialService {
    static var preview: SocialService {
        let service = SocialService()
        service.favorites = UserFavorites(
            cafes: [/* mock cafes */],
            menuItems: [/* mock items */]
        )
        return service
    }
}
#endif
```

## 📝 Notes

- All social features require user authentication
- Reviews can only be submitted by authenticated users
- Shared orders require all participants to be friends
- Favorites are private to each user
- Friend requests must be accepted before users can interact

## 🎉 You're Ready!

Your social features are now fully implemented. Users can:
- ⭐ Leave reviews with ratings and comments
- ❤️ Add cafes and menu items to favorites
- 👥 Connect with friends
- 💰 Split bills on group orders

For more details, see `SOCIAL_FEATURES_GUIDE.md`
