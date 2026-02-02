# Loyalty Program & Gamification Implementation

## Overview

Complete implementation of the loyalty program and gamification system for SubscribeCoffie, including:

- **4 loyalty levels** (Bronze, Silver, Gold, Platinum) with progressive benefits
- **13 achievements** covering various user activities
- **Points system** with automatic awarding and level progression
- **Streak tracking** for consecutive daily orders
- **Leaderboard** to foster competition
- **iOS app integration** with beautiful dashboard
- **Admin panel** for management and monitoring

---

## Backend Implementation

### Database Migration: `20260210000000_loyalty_program.sql`

#### Tables Created

1. **`loyalty_levels`** - Defines loyalty tiers
   - `level_name`: Bronze, Silver, Gold, Platinum
   - `level_order`: 1-4 for ordering
   - `points_required`: Points threshold for each level
   - `cashback_percent`: Cashback rate (2%, 5%, 10%, 15%)
   - `benefits`: JSONB array of benefits
   - `badge_color`: Hex color for UI display

2. **`user_loyalty`** - User's loyalty status
   - `current_level_id`: Reference to loyalty_levels
   - `total_points`: Accumulated points
   - `points_to_next_level`: Progress indicator
   - `lifetime_orders`: Total orders completed
   - `lifetime_spend_credits`: Total amount spent
   - `current_streak_days`: Consecutive days with orders
   - `longest_streak_days`: Best streak ever achieved
   - `last_order_date`: Date of last order (for streak calculation)

3. **`achievements`** - Available achievements
   - `achievement_key`: Unique identifier (e.g., 'first_order', 'week_streak')
   - `title`: Display name
   - `description`: What the achievement is for
   - `icon`: Emoji/icon for display
   - `points_reward`: Points awarded when unlocked
   - `achievement_type`: order_count, cafe_count, spend, streak, special
   - `requirement_value`: Threshold to unlock (e.g., 10 for "10 orders")
   - `is_hidden`: Whether to show before unlocking

4. **`user_achievements`** - Unlocked achievements
   - Links users to achievements they've earned
   - `unlocked_at`: Timestamp of unlock
   - `notified`: Whether push notification was sent

5. **`loyalty_points_history`** - Audit trail
   - All points additions/deductions
   - Reason tracking (order_completed, achievement_unlocked, level_upgrade, admin_adjustment)
   - Links to orders and achievements

#### RPC Functions

##### User-Facing Functions

1. **`initialize_user_loyalty(p_user_id)`**
   - Called automatically for new users
   - Sets up Bronze level with 0 points

2. **`get_loyalty_dashboard(p_user_id)`**
   - Returns complete dashboard data:
     - User loyalty status
     - Current level details
     - Unlocked achievements (with dates)
     - Locked achievements (visible ones)
     - Recent points history (last 20)

3. **`get_loyalty_leaderboard(p_limit)`**
   - Returns top users by points
   - Includes rank, points, level, lifetime orders

##### Internal Functions

4. **`calculate_loyalty_points(p_order_amount)`**
   - Formula: 1 point per 10 credits spent
   - Minimum 1 point per order

5. **`award_loyalty_points(p_user_id, p_points, p_reason, ...)`**
   - Adds points to user total
   - Creates history entry
   - Triggers level upgrade check

6. **`check_and_upgrade_loyalty_level(p_user_id)`**
   - Automatically promotes users to higher levels
   - Awards bonus points on level up (100 × level_order)
   - Updates points_to_next_level

7. **`check_and_unlock_achievements(p_user_id)`**
   - Evaluates all achievement criteria
   - Unlocks eligible achievements
   - Awards points for each unlock

#### Triggers

**`trigger_order_issued_loyalty`** - On orders_core (AFTER INSERT/UPDATE)
- Only fires when status changes to 'issued'
- Awards points based on order amount
- Updates lifetime_orders and lifetime_spend_credits
- Calculates and updates streaks
- Checks for time-based achievements (Night Owl, Morning Person)
- Triggers achievement check

### Default Loyalty Levels

| Level | Points Required | Cashback | Benefits |
|-------|----------------|----------|----------|
| Bronze | 0 | 2% | Welcome bonus, Birthday surprise |
| Silver | 500 | 5% | Priority support |
| Gold | 1,500 | 10% | Free delivery (>500₽), Exclusive items |
| Platinum | 5,000 | 15% | Free delivery (all), VIP support, Early access |

### Default Achievements

#### Order Milestones
- **First Order** (☕, 50 pts) - Made your first order
- **Coffee Lover** (☕☕, 100 pts) - 5 orders
- **Regular** (☕☕☕, 200 pts) - 10 orders
- **Coffee Addict** (🏆, 500 pts) - 50 orders
- **Coffee Master** (👑, 1000 pts) - 100 orders

#### Exploration
- **Cafe Explorer** (🗺️, 150 pts) - Visited 5 different cafes
- **Cafe Connoisseur** (🌟, 300 pts) - Visited 10 different cafes

#### Spending
- **Big Spender** (💰, 400 pts) - Spent 10,000 credits total

#### Streaks
- **Week Warrior** (🔥, 250 pts) - 7 days in a row
- **Monthly Champion** (🔥🔥, 1000 pts) - 30 days in a row

#### Special
- **Early Adopter** (🚀, 500 pts, hidden) - One of the first users
- **Night Owl** (🦉, 100 pts) - Ordered after 10 PM
- **Morning Person** (🌅, 100 pts) - Ordered before 7 AM

---

## iOS Implementation

### Models: `LoyaltyModels.swift`

Domain models for:
- `LoyaltyLevel` - Level definitions with computed properties (color, icon)
- `UserLoyalty` - User's loyalty status with progress calculation
- `Achievement` - Achievement definitions with display helpers
- `UserAchievement` - Unlocked achievements
- `LoyaltyPointsHistory` - Points history with display formatting
- `LoyaltyDashboard` - Complete dashboard response
- `LeaderboardEntry` - Leaderboard row

Includes Supabase DTOs and domain mapping.

### Service: `LoyaltyService.swift`

API client for loyalty operations:
- `getLoyaltyDashboard(userId)` - Fetch complete dashboard
- `getLoyaltyLevels()` - Get all levels
- `getAchievements()` - Get all achievements
- `getUserAchievements(userId)` - Get user's unlocked achievements
- `getPointsHistory(userId, limit)` - Get points history
- `getLeaderboard(limit)` - Get top users
- `initializeLoyalty(userId)` - Initialize for new user
- `checkAchievements(userId)` - Manually trigger achievement check

### View: `LoyaltyDashboardView.swift`

Beautiful SwiftUI dashboard featuring:

#### Current Level Card
- Large level icon (🥉🥈🥇💎)
- Level name with brand color
- Total points
- Level-specific benefits list

#### Progress Card
- Visual progress bar to next level
- Points remaining
- Percentage complete
- "Max level reached" indicator for Platinum

#### Stats Card (4-grid)
- Total orders (cup icon, blue)
- Lifetime spend (creditcard icon, green)
- Current streak (flame icon, orange)
- Longest streak (trophy icon, purple)

#### Achievements Section
- **Unlocked achievements**: Full color with unlock date
- **Locked achievements**: Grayed out, showing requirements
- Each shows: icon, title, description, points reward, progress

#### Points History
- Chronological list of points changes
- Reason for each change
- Positive (green ↑) vs. negative (red ↓)
- Timestamps
- Related order/achievement notes

### Integration with ProfileView

Added new section in profile:
- Gradient background (accent → purple)
- Star icon + "Программа лояльности"
- Tap to open full dashboard
- Sheet presentation

---

## Admin Panel Implementation

### Queries: `lib/supabase/queries/loyalty.ts`

TypeScript API for admin operations:
- `getLoyaltyLevels()` - Fetch all levels
- `updateLoyaltyLevel(levelId, updates)` - Modify level settings
- `getAchievements()` - Fetch all achievements
- `createAchievement(achievement)` - Add new achievement
- `updateAchievement(achievementId, updates)` - Edit achievement
- `deleteAchievement(achievementId)` - Remove achievement
- `getUserLoyaltyStats(userId)` - User's loyalty profile
- `getUserAchievements(userId)` - User's unlocked achievements
- `getLeaderboard(limit)` - Top users
- `getLoyaltyStatsSummary()` - Overview stats
- `getRecentPointsActivity(limit)` - Recent points changes
- `awardBonusPoints(userId, points, notes)` - Admin point adjustment

### Page: `app/admin/loyalty/page.tsx`

Comprehensive admin dashboard with:

#### Stats Overview (3 cards)
- Total enrolled users
- Total achievements unlocked
- Active loyalty levels

#### Level Distribution
- Visual bar chart
- Shows user count and percentage per level
- Gradient bar styling

#### Loyalty Levels Grid
- 4-column grid of level cards
- Each card shows: icon, name, points, cashback, benefits

#### Leaderboard (Top 20)
- Table with rank, user ID, level, points, orders
- Special styling for top 3 (medals)
- Color-coded levels

#### Achievements Table
- Filterable by type (order_count, cafe_count, streak, etc.)
- Shows: icon, title, description, type, requirement, points, visibility
- Badge styling for types and status

### Components

1. **`LoyaltyLevelCard.tsx`**
   - Visual card for each level
   - Color-coded based on badge_color
   - Icon, points, cashback, benefits

2. **`AchievementsTable.tsx`**
   - Filterable table of achievements
   - Type-based filtering
   - Badge styling

3. **`LeaderboardTable.tsx`**
   - Top users ranking
   - Medal icons for top 3
   - Level color coding

---

## Features & Mechanics

### Points System

**Earning Points:**
- 1 point per 10 credits spent (rounded down, min 1)
- Bonus points on level up (100 × new level order)
- Achievement unlocks (varies by achievement)
- Admin can award bonus points manually

**Example:**
- Order for 250₽ → 25 points
- Unlock "Coffee Lover" → +100 points
- Level up to Silver → +200 points
- **Total: 325 points**

### Level Progression

- **Automatic**: System checks after every order
- **Progressive benefits**: Higher levels get all lower-level benefits plus more
- **Cashback increases**: 2% → 5% → 10% → 15%
- **Bonus on upgrade**: Encourages progression

### Streak Tracking

- **Daily basis**: One order per day to maintain streak
- **Same-day orders**: Don't break or extend streak
- **Reset on skip**: Missing a day resets to 1
- **Historical tracking**: `longest_streak_days` preserved

**Example:**
```
Day 1: Order → streak = 1
Day 2: Order → streak = 2
Day 3: No order → streak resets
Day 4: Order → streak = 1 (but longest_streak = 2)
```

### Achievement System

**Types:**
1. **order_count**: Total orders completed
2. **cafe_count**: Unique cafes visited
3. **spend**: Total credits spent
4. **streak**: Consecutive daily orders
5. **special**: Time-based or manual unlocks

**Automatic Checking:**
- After every order completion
- Checks all eligible achievements
- Awards points immediately
- Can be manually triggered via RPC

### Time-Based Achievements

Special achievements unlocked by order time:
- **Night Owl**: Order between 22:00-23:59
- **Morning Person**: Order between 00:00-06:59

These are checked in the order trigger.

---

## Usage Examples

### Backend (SQL)

```sql
-- Get user's loyalty dashboard
SELECT * FROM get_loyalty_dashboard('user-uuid-here');

-- Award bonus points
SELECT award_loyalty_points(
  'user-uuid',
  500,
  'admin_adjustment',
  NULL,
  NULL,
  'Bonus for being awesome!'
);

-- Check leaderboard
SELECT * FROM get_loyalty_leaderboard(50);
```

### iOS (Swift)

```swift
// Load dashboard
let dashboard = try await LoyaltyService().getLoyaltyDashboard(userId: userId)

// Show in UI
LoyaltyDashboardView(userId: userId)

// Check for new achievements (optional, automatic via backend)
let result = try await LoyaltyService().checkAchievements(userId: userId)
print("Unlocked \(result.unlocked_count) new achievements!")
```

### Admin (TypeScript)

```typescript
// Load loyalty overview
const levels = await getLoyaltyLevels();
const stats = await getLoyaltyStatsSummary();
const leaderboard = await getLeaderboard(100);

// Award bonus points to user
await awardBonusPoints(
  'user-uuid',
  1000,
  'Community contest winner'
);

// Create custom achievement
await createAchievement({
  achievement_key: 'holiday_special',
  title: 'Holiday Hero',
  description: 'Ordered during holiday event',
  icon: '🎄',
  points_reward: 250,
  achievement_type: 'special',
  is_hidden: false
});
```

---

## Testing & Verification

### Database Testing

```sql
-- Initialize test user
SELECT initialize_user_loyalty('test-user-uuid');

-- Simulate order (trigger points and achievements)
INSERT INTO orders_core (user_id, cafe_id, paid_credits, status)
VALUES ('test-user-uuid', 'cafe-uuid', 250, 'issued');

-- Check results
SELECT * FROM user_loyalty WHERE user_id = 'test-user-uuid';
SELECT * FROM loyalty_points_history WHERE user_id = 'test-user-uuid';
SELECT * FROM user_achievements WHERE user_id = 'test-user-uuid';
```

### iOS Testing

1. Run app in simulator
2. Navigate to Profile
3. Tap "Программа лояльности"
4. Verify dashboard loads
5. Check all sections render correctly

### Admin Testing

1. Navigate to `/admin/loyalty`
2. Verify stats load
3. Check level cards display
4. Test achievement filtering
5. View leaderboard

---

## Future Enhancements

**Suggested additions (not implemented):**

1. **Push Notifications**
   - Alert when new achievement unlocked
   - Notify on level up
   - Remind about breaking streak

2. **Social Features**
   - Share achievements
   - Challenge friends
   - Team competitions

3. **Custom Rewards**
   - Redeem points for discounts
   - Exchange points for free items
   - Special perks at high levels

4. **Analytics Dashboard**
   - Engagement metrics
   - Most popular achievements
   - Average time to each level

5. **Seasonal Events**
   - Limited-time achievements
   - Bonus point periods
   - Special challenges

---

## Files Created

### Backend
- `supabase/migrations/20260210000000_loyalty_program.sql`

### iOS
- `Models/LoyaltyModels.swift`
- `Helpers/LoyaltyService.swift`
- `Views/LoyaltyDashboardView.swift`
- Updated: `Views/ProfileView.swift`

### Admin
- `lib/supabase/queries/loyalty.ts`
- `app/admin/loyalty/page.tsx`
- `app/admin/loyalty/LoyaltyLevelCard.tsx`
- `app/admin/loyalty/AchievementsTable.tsx`
- `app/admin/loyalty/LeaderboardTable.tsx`

---

## Deployment Checklist

- [x] Database migration created
- [x] RPC functions implemented
- [x] Triggers configured
- [x] iOS models created
- [x] iOS service implemented
- [x] iOS UI implemented
- [x] Admin queries created
- [x] Admin UI created
- [ ] Run database migration: `supabase db push`
- [ ] Test with real user data
- [ ] Verify triggers fire on orders
- [ ] Test iOS app integration
- [ ] Test admin panel
- [ ] Set up monitoring for points/achievements
- [ ] Document for team

---

## Support

For issues or questions:
1. Check database logs: `supabase db logs`
2. Verify RLS policies allow access
3. Check iOS network requests in console
4. Review admin error messages
5. Refer to this documentation

---

**Implementation Date:** January 30, 2026
**Status:** ✅ Complete
**Version:** 1.0
