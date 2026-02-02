# Recommendation System Implementation

## Overview

The recommendation system provides personalized menu item and cafe recommendations to users based on their order history, preferences, and collaborative filtering.

## Implementation Date

2026-02-12

## Components

### Backend (Database)

#### Migration: `20260212000000_recommendations.sql`

**Tables Created:**

1. **`user_preferences`**
   - Stores learned user preferences from order history
   - Fields:
     - `id` (UUID): Primary key
     - `user_id` (UUID): Reference to auth.users
     - `favorite_cafe_ids` (UUID[]): Array of frequently visited cafes
     - `favorite_category` (TEXT): Most ordered menu category
     - `preferred_order_time` (TIME): Typical order time
     - `avg_order_value_credits` (INT): Average order value
     - `last_updated` (TIMESTAMP): Last update timestamp
     - `created_at` (TIMESTAMP): Creation timestamp
   - RLS: Users can view their own preferences, admins can view all

2. **`trending_items` (VIEW)**
   - Shows popular menu items from last 7 days
   - Columns:
     - Menu item details (id, name, description, price)
     - Cafe details (cafe_id, cafe_name, cafe_address)
     - Popularity metrics (order_count, unique_customers)
     - Temporal data (last_ordered_at)
   - Automatically calculated based on orders

**RPC Functions:**

1. **`update_user_preferences(p_user_id UUID)`**
   - Updates user preferences based on order history
   - Calculates:
     - Top 3 most visited cafes
     - Most ordered category
     - Average order value
     - Preferred order time
   - Called automatically by trigger on order completion

2. **`get_personalized_recommendations(p_user_id UUID, p_limit INT)`**
   - Returns personalized menu item recommendations
   - Uses multiple strategies:
     - **Trending items in favorite cafes** (highest priority)
     - **Items in favorite category** (medium priority)
     - **Collaborative filtering** - items ordered by similar users
     - **New items in favorite cafes** (lower priority)
   - Each recommendation includes:
     - Menu item details
     - Cafe information
     - Recommendation reason
     - Relevance score
   - Filters out already ordered items
   - Price-aware: Only recommends items ≤ 1.5x user's average order value

3. **`get_cafe_recommendations(p_user_id UUID, p_limit INT)`**
   - Returns personalized cafe recommendations
   - Strategies:
     - **Popular with similar users** (highest priority)
     - **Great selection in favorite category**
     - **Newly added cafes**
   - Each recommendation includes:
     - Cafe details (id, name, address, location)
     - Recommendation reason
     - Relevance score

**Triggers:**

- **`trigger_update_preferences_on_order`**
  - Automatically updates user preferences when order is issued
  - Ensures preferences stay up-to-date

**Permissions:**
- All tables and functions accessible to authenticated users
- Read-only for regular users
- Full access for admins

### iOS App

#### New Files:

1. **`Models/RecommendationModels.swift`**
   - `PersonalizedRecommendation`: Menu item recommendation with reason
   - `CafeRecommendation`: Cafe recommendation with reason
   - `UserPreferences`: User preference data
   - `TrendingItem`: Trending menu item data

2. **`Helpers/RecommendationService.swift`**
   - Service class for recommendation operations
   - Methods:
     - `getPersonalizedRecommendations(userId:limit:)` → [PersonalizedRecommendation]
     - `getCafeRecommendations(userId:limit:)` → [CafeRecommendation]
     - `getTrendingItems(limit:)` → [TrendingItem]
     - `getUserPreferences(userId:)` → UserPreferences?
     - `updateUserPreferences(userId:)` → Void

3. **`Views/RecommendationsView.swift`**
   - `CafeRecommendationsView`: Horizontal scroll of recommended cafes
   - `TrendingItemsView`: Horizontal scroll of trending items
   - `RecommendationCard`: Card for cafe recommendation
   - `TrendingItemCard`: Card for trending item

#### Updated Files:

1. **`Views/MapSelectionView.swift`**
   - Added recommendation service integration
   - Shows two sections:
     - **"Рекомендуем попробовать"** - Personalized cafe recommendations
     - **"Сейчас в тренде"** - Trending items across all cafes
   - Loads recommendations on view appear
   - Handles tapping on recommendations to navigate to cafes

2. **`Views/CafeView.swift`**
   - Added personalized menu item recommendations section
   - **"Попробуйте что-то новое"** section shows items recommended for this cafe
   - Recommendations displayed with special purple-themed cards
   - Shows recommendation reason
   - Integrates with cart - can add items directly
   - Only shows recommendations for current cafe

3. **`Helpers/SupabaseAPIClient.swift`**
   - Added `getCurrentUserId()` method
   - Retrieves current user ID from Supabase session

4. **`Helpers/NetworkError.swift`**
   - Added `.invalidResponse(String)` case

## Features

### For Users

1. **Personalized Menu Recommendations**
   - See items you might like based on your order history
   - Discover new items in your favorite categories
   - Get recommendations from cafes you love
   - See what similar users are ordering

2. **Cafe Discovery**
   - Find new cafes popular with users like you
   - Discover cafes with great selection in your favorite category
   - See newly added cafes

3. **Trending Items**
   - See what's popular right now
   - Discover trending items from last 7 days
   - View order counts and popularity metrics

### Recommendation Reasons

Users see clear reasons for each recommendation:
- "Popular in your favorite cafe"
- "Trending in your favorite category"
- "Popular with users like you"
- "New in your favorite cafe"
- "Great [category] selection"
- "Newly added cafe"

### Smart Filtering

- **No duplicate recommendations**: Already ordered items are filtered out
- **Price-aware**: Only recommends items within user's typical price range (≤ 1.5x average)
- **Availability**: Only shows available items from active cafes
- **Relevance scoring**: Recommendations sorted by relevance score

## Data Privacy

- All RLS policies ensure users can only see their own preferences
- Collaborative filtering uses anonymized data
- No personal data exposed in recommendations

## Performance

- **Trending items view**: Pre-calculated, fast queries
- **User preferences**: Cached and updated asynchronously
- **Recommendation queries**: Optimized with indexes and limits
- **Non-blocking**: Recommendations load in background, don't block UI

## Testing

### Backend Testing

```sql
-- Test user preferences update
SELECT update_user_preferences('user-uuid-here');

-- Test personalized recommendations
SELECT * FROM get_personalized_recommendations('user-uuid-here', 10);

-- Test cafe recommendations
SELECT * FROM get_cafe_recommendations('user-uuid-here', 5);

-- View trending items
SELECT * FROM trending_items LIMIT 10;

-- Check user preferences
SELECT * FROM user_preferences WHERE user_id = 'user-uuid-here';
```

### iOS Testing

1. **New User Experience**
   - New users see trending items (no personalized recommendations yet)
   - After first order, preferences are created

2. **Regular User Experience**
   - Personalized cafe recommendations on main screen
   - Trending items below recommendations
   - Cafe-specific recommendations in menu

3. **Anonymous Users**
   - Only see trending items
   - No personalized recommendations

## Future Enhancements

### Phase 2 (Planned):

1. **Machine Learning Model**
   - Python microservice with scikit-learn
   - More sophisticated collaborative filtering
   - Content-based filtering using item descriptions

2. **Enhanced Recommendations**
   - Time-based recommendations (morning coffee, lunch specials)
   - Weather-based recommendations (hot/cold beverages)
   - Event-based recommendations (new cafe openings)

3. **Push Notifications**
   - "Your favorite cafe has a new item!"
   - "Trending now near you: [Item Name]"
   - "Cafe you might like just opened nearby"

4. **A/B Testing**
   - Test different recommendation strategies
   - Measure conversion rates
   - Optimize relevance scoring

5. **Social Features**
   - "Friends also liked this"
   - Share favorite items
   - Create item collections

## Metrics

Track these metrics to measure success:

1. **Engagement**
   - Click-through rate on recommendations
   - Conversion rate (view → order)
   - Time spent viewing recommendations

2. **Business Impact**
   - Orders from recommendations vs. regular browsing
   - Discovery rate (new cafes/items tried)
   - Average order value from recommendations

3. **Quality**
   - User feedback on recommendations
   - Relevance score accuracy
   - Recommendation diversity

## Architecture

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│   iOS App                       │
│  ┌──────────────────────────┐  │
│  │ MapSelectionView         │  │
│  │  - Cafe Recommendations  │  │
│  │  - Trending Items        │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ CafeView                 │  │
│  │  - Item Recommendations  │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ RecommendationService    │  │
│  └──────────────────────────┘  │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│   Supabase Backend              │
│  ┌──────────────────────────┐  │
│  │ RPC Functions            │  │
│  │  - get_personalized_recs │  │
│  │  - get_cafe_recs         │  │
│  │  - update_preferences    │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ Tables & Views           │  │
│  │  - user_preferences      │  │
│  │  - trending_items        │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ Triggers                 │  │
│  │  - Auto-update prefs     │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

## Recommendation Algorithm

### Personalized Recommendations

1. **Score Calculation**:
   - Favorite cafe items: Base score 100 + (order_count × 2)
   - Favorite category items: Base score 80 + order_count
   - Collaborative filtering: Base score 60 + unique_users
   - New items: Base score 40

2. **Filtering**:
   - Remove already ordered items
   - Filter by price range (≤ 1.5x average)
   - Only available items
   - Deduplicate by item ID

3. **Ranking**:
   - Sort by relevance score (descending)
   - Return top N items

### Cafe Recommendations

1. **Score Calculation**:
   - Similar users: Base score = unique_users × 10
   - Category selection: Base score = item_count × 5
   - New cafes: Base score 30

2. **Filtering**:
   - Remove already visited cafes
   - Only active cafes
   - Deduplicate by cafe ID

3. **Ranking**:
   - Sort by relevance score (descending)
   - Return top N cafes

## Troubleshooting

### No Recommendations Showing

1. Check if user has order history
2. Verify RPC functions are working
3. Check RLS policies allow access
4. Ensure trending_items view has data

### Incorrect Recommendations

1. Check if user_preferences is up to date
2. Verify order history is correct
3. Review relevance score calculations
4. Check if filters are too restrictive

### Performance Issues

1. Check database indexes
2. Verify view is materialized (if needed)
3. Review query execution plans
4. Consider caching recommendations

## Deployment

1. **Run Migration**:
   ```bash
   supabase db push
   ```

2. **Verify Tables**:
   ```sql
   \dt user_preferences
   \dv trending_items
   ```

3. **Test RPC Functions**:
   ```sql
   SELECT * FROM get_personalized_recommendations('test-user-id', 5);
   ```

4. **Deploy iOS App**:
   - Ensure all new files are included in build
   - Test on device
   - Verify recommendations display correctly

## Conclusion

The recommendation system is now fully implemented with:
- ✅ Backend database schema and functions
- ✅ iOS models and service layer
- ✅ UI components for displaying recommendations
- ✅ Integration with existing views
- ✅ Automatic preference updates
- ✅ Privacy and security (RLS)
- ✅ Performance optimizations

Users will now see personalized, relevant recommendations that help them discover new cafes and menu items based on their preferences and behavior.
