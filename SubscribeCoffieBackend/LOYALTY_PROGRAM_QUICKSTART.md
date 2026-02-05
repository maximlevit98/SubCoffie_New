# Loyalty Program - Quick Reference

**TL;DR**: Complete loyalty system with 2 options - Full Gamification or Simple Cashback

---

## 🚀 Quick Start (Full Loyalty)

```bash
# 1. Apply migration (30 seconds)
cd SubscribeCoffieBackend
supabase db reset

# 2. Verify
psql -h localhost -p 54322 -U postgres -d postgres -c "\dt loyalty_*"

# 3. Done! Backend is ready
```

**What You Get:**
- ✅ 4 loyalty levels (Bronze → Platinum) with 2-15% cashback
- ✅ 13 achievements (☕ First Order, 🔥 Week Warrior, etc.)
- ✅ Points: 1 point per 10 credits spent
- ✅ Streaks: Track daily order streaks
- ✅ Leaderboard: Top users by points
- ✅ Auto-awards points on orders

---

## 🎯 Two Options

### Option A: Full Loyalty (Recommended)
**File**: `20260210000000_loyalty_program.sql` ✅ Ready

**Features**:
- 4 levels with increasing benefits
- 13 achievements  
- Points & streaks
- Leaderboard
- Gamification

**Timeline**: 6-8 hours (backend + iOS + admin)

---

### Option B: Simple Cashback
**File**: `20260210000001_simple_cashback.sql.disabled`

**Features**:
- Bonus credits in wallet
- 5% CityPass, 3% Cafe
- Auto-awarded
- No levels/achievements

**Timeline**: 2-3 hours

---

## 📊 Default Loyalty Levels

| Level | Points | Cashback | Benefits |
|-------|--------|----------|----------|
| **🥉 Bronze** | 0 | 2% | Welcome bonus, Birthday |
| **🥈 Silver** | 500 | 5% | Priority support |
| **🥇 Gold** | 1,500 | 10% | Free delivery (>500₽), Exclusive items |
| **💎 Platinum** | 5,000 | 15% | Free delivery (all), VIP support, Early access |

---

## 🏆 Default Achievements

**Order Milestones:**
- ☕ First Order (50 pts)
- ☕☕ Coffee Lover - 5 orders (100 pts)
- ☕☕☕ Regular - 10 orders (200 pts)
- 🏆 Coffee Addict - 50 orders (500 pts)
- 👑 Coffee Master - 100 orders (1000 pts)

**Exploration:**
- 🗺️ Cafe Explorer - 5 cafes (150 pts)
- 🌟 Cafe Connoisseur - 10 cafes (300 pts)

**Spending:**
- 💰 Big Spender - 10,000₽ (400 pts)

**Streaks:**
- 🔥 Week Warrior - 7 days (250 pts)
- 🔥🔥 Monthly Champion - 30 days (1000 pts)

**Special:**
- 🚀 Early Adopter (500 pts, hidden)
- 🦉 Night Owl - Order after 10 PM (100 pts)
- 🌅 Morning Person - Order before 7 AM (100 pts)

---

## 💡 How It Works

### Points Formula
```
points = max(1, order_amount / 10)
```

**Examples:**
- Order 100₽ → 10 points
- Order 250₽ → 25 points
- Order 50₽ → 5 points (min 1)

### Bonus Points
- **Achievement unlock**: Varies (50-1000 points)
- **Level upgrade**: 100 × new_level_order
  - Bronze → Silver: +200 points
  - Silver → Gold: +300 points
  - Gold → Platinum: +400 points

### Streak Tracking
- **Daily basis**: One order per day maintains streak
- **Same day**: Multiple orders don't extend streak
- **Break**: Missing a day resets to 1
- **Longest**: Always preserved

---

## 🔧 RPCs (Backend)

### User-Facing
```sql
-- Get complete dashboard
SELECT get_loyalty_dashboard('user-uuid');

-- Get leaderboard
SELECT * FROM get_loyalty_leaderboard(50);

-- Manually check achievements (optional, auto-triggers)
SELECT check_and_unlock_achievements('user-uuid');
```

### Admin
```sql
-- Award bonus points
SELECT admin_award_bonus_points(
  'user-uuid',
  500,
  'Community contest winner'
);

-- Initialize new user
SELECT initialize_user_loyalty('user-uuid');
```

### Internal (Auto-Called)
- `calculate_loyalty_points(amount)` - Points formula
- `award_loyalty_points(...)` - Add points + history
- `check_and_upgrade_loyalty_level(...)` - Auto-promote

---

## 📱 iOS Integration

### 1. Restore Service
```bash
cp _disabled_backup/LoyaltyService.swift.disabled \
   SubscribeCoffieClean/Helpers/LoyaltyService.swift
```

### 2. Add to Profile
```swift
// ProfileView.swift
Button("Программа лояльности") {
    showLoyaltyDashboard = true
}
.sheet(isPresented: $showLoyaltyDashboard) {
    LoyaltyDashboardView(userId: userId)
}
```

### 3. Load Dashboard
```swift
let dashboard = try await LoyaltyService()
    .getLoyaltyDashboard(userId: userId)
```

---

## 🖥️ Admin Panel

### Queries (`lib/supabase/queries/loyalty.ts`)
```typescript
// Get levels
const levels = await getLoyaltyLevels();

// Get leaderboard
const top = await getLeaderboard(100);

// Award bonus points
await awardBonusPoints(userId, 1000, 'Contest winner');
```

### Page (`app/admin/loyalty/page.tsx`)
- Stats overview
- Level distribution
- Leaderboard table
- Achievements table
- Manual point award form

---

## ✅ Testing

### Quick Test
```bash
psql -h localhost -p 54322 -U postgres -d postgres <<EOF
BEGIN;

-- Initialize test user
SELECT initialize_user_loyalty('test-uuid');

-- Simulate order
INSERT INTO orders_core (user_id, cafe_id, paid_credits, status)
VALUES ('test-uuid', (SELECT id FROM cafes LIMIT 1), 250, 'issued');

-- Check points awarded
SELECT * FROM user_loyalty WHERE user_id = 'test-uuid';

-- Check achievements
SELECT a.title, ua.unlocked_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = 'test-uuid';

ROLLBACK;
EOF
```

**Expected Result:**
- ✅ User loyalty created (Bronze, 25 points from 250₽ order)
- ✅ "First Order" achievement unlocked (+50 points)
- ✅ Total: 75 points

---

## 🚨 Common Issues

### Issue: Loyalty not initializing for new users
**Solution**: Add to signup flow:
```swift
// After user registration
try await LoyaltyService().initializeLoyalty(userId: newUserId)
```

### Issue: Points not awarding on orders
**Check**:
1. Trigger exists: `\df trigger_order_issued_loyalty`
2. Order status is 'issued'
3. User has loyalty record: `SELECT * FROM user_loyalty WHERE user_id = ?`

### Issue: Achievements not unlocking
**Manual trigger**:
```sql
SELECT check_and_unlock_achievements('user-uuid');
```

---

## 📊 Monitoring

### Key Metrics
```sql
-- Total enrolled users
SELECT count(*) FROM user_loyalty;

-- Total points awarded
SELECT sum(points_change) FROM loyalty_points_history
WHERE points_change > 0;

-- Total achievements unlocked
SELECT count(*) FROM user_achievements;

-- Level distribution
SELECT ll.level_name, count(ul.id)
FROM user_loyalty ul
JOIN loyalty_levels ll ON ul.current_level_id = ll.id
GROUP BY ll.level_name, ll.level_order
ORDER BY ll.level_order;

-- Top users
SELECT * FROM get_loyalty_leaderboard(10);
```

---

## 🔄 Simple Cashback Alternative

**If Full Loyalty is too complex:**

```bash
# 1. Enable cashback migration
mv supabase/migrations/20260210000001_simple_cashback.sql.disabled \
   supabase/migrations/20260210000001_simple_cashback.sql

# 2. Apply
supabase db reset

# 3. Done!
```

**What You Get:**
- Adds `bonus_balance_credits` to wallets
- Auto-awards 5% cashback on orders (CityPass)
- 3% for Cafe Wallets
- Much simpler (2 hours vs 8 hours)

**Usage:**
```sql
-- Get cashback config
SELECT * FROM get_cashback_config();

-- Get user stats
SELECT get_user_cashback_stats('user-uuid');
```

---

## 📞 Quick Decision Guide

**Choose Full Loyalty if:**
- ✅ You want high user engagement
- ✅ You have 6-8 hours for implementation
- ✅ You want gamification

**Choose Simple Cashback if:**
- ✅ You need to launch fast (2 hours)
- ✅ You want minimal complexity
- ✅ You prefer immediate value

**Can migrate Cashback → Loyalty later!**

---

## 📚 Full Documentation

- **Detailed Guide**: `LOYALTY_PROGRAM_DEPLOYMENT_GUIDE.md`
- **Original Spec**: `LOYALTY_PROGRAM_IMPLEMENTATION.md`
- **Migration**: `supabase/migrations/20260210000000_loyalty_program.sql`
- **Cashback Alt**: `supabase/migrations/20260210000001_simple_cashback.sql.disabled`

---

**Status**: ✅ READY TO DEPLOY  
**Recommendation**: Full Loyalty for best engagement  
**Alternative**: Simple Cashback for quick launch  
**Timeline**: 2-8 hours depending on choice
