# Subscription Model - Quick Start Guide

## Overview

The subscription model allows users to subscribe to monthly or yearly plans (Basic, Premium, VIP) that provide benefits like cashback, free delivery, and priority support.

**Current Status:** MVP with mock payments (no real payment gateway integration)

## Quick Setup

### 1. Apply Database Migration

```bash
cd SubscribeCoffieBackend
supabase migration up
```

This creates:
- `subscription_plans` table with 3 default plans
- `user_subscriptions` table for user subscriptions
- `subscription_benefits` table for plan benefits
- `subscription_payments` table for payment history
- RPC functions for subscription operations

### 2. Verify Migration

```sql
-- Check plans
SELECT * FROM subscription_plans;

-- Check benefits
SELECT * FROM subscription_benefits;

-- Test getting plans via RPC
SELECT * FROM get_subscription_plans();
```

You should see 3 plans:
- **Basic** (₽299/month): 5% cashback
- **Premium** (₽599/month): 10% cashback + free delivery
- **VIP** (₽1499/month): 15% cashback + free delivery + priority support + exclusive promos

## iOS Integration

The subscription UI is already integrated into the ProfileView:

1. Open the app
2. Navigate to Profile (bottom tab)
3. Tap on "Подписка" section (orange gradient card with crown icon)
4. Browse available plans
5. Subscribe to a plan (mock payment)
6. View subscription status and benefits

### Files Added/Modified

**New Files:**
- `SubscribeCoffieClean/.../Models/SubscriptionModels.swift`
- `SubscribeCoffieClean/.../Helpers/SubscriptionService.swift`
- `SubscribeCoffieClean/.../Views/SubscriptionPlansView.swift`

**Modified Files:**
- `SubscribeCoffieClean/.../Views/ProfileView.swift` (added subscription section)

## Using the Subscription System

### Subscribe a User (Mock Payment)

```sql
-- Subscribe user to Premium plan
SELECT subscribe_user(
  'user-uuid-here',
  (SELECT id FROM subscription_plans WHERE name = 'premium'),
  NULL  -- no payment method for mock
);

-- Response:
-- {
--   "success": true,
--   "subscription_id": "new-subscription-uuid",
--   "payment_id": "payment-uuid",
--   "period_end": "2026-03-01T00:00:00Z",
--   "amount_paid": 59900
-- }
```

### Check User Subscription

```sql
SELECT get_user_subscription('user-uuid-here');

-- Returns full subscription details with plan and benefits
```

### Check User Benefits (for order processing)

```sql
SELECT check_subscription_benefits('user-uuid-here');

-- Returns:
-- {
--   "has_subscription": true,
--   "subscription_id": "uuid",
--   "plan_id": "uuid",
--   "period_end": "2026-03-01T00:00:00Z",
--   "benefits": [
--     {
--       "benefit_type": "cashback",
--       "benefit_value": "10",
--       ...
--     }
--   ]
-- }
```

### Cancel Subscription

```sql
SELECT cancel_subscription(
  'subscription-uuid',
  'Too expensive'  -- optional reason
);

-- Subscription remains active until current period ends
```

## Testing in iOS Simulator

1. **View Plans:**
   - Open app → Profile → Tap "Подписка"
   - See all 3 plans with benefits listed

2. **Subscribe:**
   - Tap "Подписаться" on any plan
   - Confirm in dialog
   - Mock payment completes instantly
   - See "Активная подписка" card at top

3. **View Benefits:**
   - Current plan name displayed
   - Days remaining shown
   - All benefits listed with icons

4. **Cancel:**
   - Tap "Отменить подписку"
   - Add optional reason
   - Subscription stays active until period end

## Mock Payment Behavior

**Important:** All payments are simulated in MVP!

- No real money is charged
- Payment status is always "completed"
- Transaction IDs have 'mock_' prefix
- UI displays "DEMO MODE" badge

**When moving to production:**
1. Integrate Stripe or YooKassa
2. Update `subscribe_user` RPC to call payment API
3. Add webhook handlers
4. Remove demo badge from UI

## Common Use Cases

### Use Case 1: Apply Cashback to Order

```sql
-- In your order creation logic
DO $$
DECLARE
  v_benefits JSONB;
  v_cashback_percent INTEGER;
  v_order_amount INTEGER;
  v_cashback_amount INTEGER;
BEGIN
  -- Check benefits
  SELECT check_subscription_benefits('user-uuid') INTO v_benefits;
  
  IF (v_benefits->>'has_subscription')::boolean THEN
    -- Get cashback percentage
    SELECT (benefit->>'benefit_value')::integer INTO v_cashback_percent
    FROM jsonb_array_elements((v_benefits->>'benefits')::jsonb) AS benefit
    WHERE benefit->>'benefit_type' = 'cashback'
    LIMIT 1;
    
    -- Calculate cashback (e.g., 10% of order)
    v_order_amount := 50000; -- 500 rubles in credits
    v_cashback_amount := (v_order_amount * v_cashback_percent) / 100;
    
    -- Credit to user wallet
    -- UPDATE wallets SET bonus_balance = bonus_balance + v_cashback_amount ...
    
    RAISE NOTICE 'Applied % cashback: % credits', v_cashback_percent, v_cashback_amount;
  END IF;
END $$;
```

### Use Case 2: Check Free Delivery

```sql
-- Check if user has free delivery benefit
SELECT EXISTS (
  SELECT 1
  FROM check_subscription_benefits('user-uuid'),
  jsonb_array_elements((check_subscription_benefits->>'benefits')::jsonb) AS benefit
  WHERE benefit->>'benefit_type' = 'free_delivery'
) AS has_free_delivery;
```

### Use Case 3: Auto-Expire Subscriptions (Cron Job)

```sql
-- Run daily via cron or pg_cron
SELECT expire_subscriptions();

-- Returns count of expired subscriptions
```

## Admin Operations

### View All Active Subscriptions

```sql
SELECT 
  us.id,
  p.full_name,
  sp.name_ru AS plan,
  us.status,
  us.current_period_end,
  us.auto_renew
FROM user_subscriptions us
JOIN profiles p ON us.user_id = p.id
JOIN subscription_plans sp ON us.plan_id = sp.id
WHERE us.status = 'active'
ORDER BY us.current_period_end;
```

### Create Custom Plan

```sql
INSERT INTO subscription_plans (
  name, name_ru, description_ru, price_credits, billing_period, display_order
) VALUES (
  'enterprise',
  'Корпоративный',
  'Для компаний и корпоративных клиентов',
  299900,  -- 2999 rubles
  'monthly',
  4
) RETURNING id;

-- Then add benefits
INSERT INTO subscription_benefits (
  plan_id, benefit_type, benefit_name_ru, benefit_value, description_ru
) VALUES
  (<plan-id>, 'cashback', '20% Кэшбек', '20', 'Максимальный кэшбек'),
  (<plan-id>, 'priority_support', 'VIP Поддержка', '24/7', 'Персональный менеджер');
```

### Subscription Analytics

```sql
-- Count by plan
SELECT 
  sp.name_ru,
  COUNT(*) AS subscribers,
  SUM(sp.price_credits) / 100 AS monthly_revenue
FROM user_subscriptions us
JOIN subscription_plans sp ON us.plan_id = sp.id
WHERE us.status = 'active'
GROUP BY sp.name_ru, sp.price_credits;

-- Churn rate (cancelled this month)
SELECT 
  COUNT(*) AS cancelled_this_month
FROM user_subscriptions
WHERE cancelled_at >= date_trunc('month', CURRENT_DATE)
  AND cancelled_at < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month';
```

## Troubleshooting

### Issue: "User already has an active subscription"

**Cause:** User trying to subscribe while already subscribed

**Solution:** Cancel existing subscription first, or upgrade flow (not implemented yet)

### Issue: "Plan not found or inactive"

**Cause:** Plan ID doesn't exist or is_active = false

**Solution:** Check plan exists and is active:
```sql
SELECT id, name, is_active FROM subscription_plans;
```

### Issue: RPC functions not found

**Cause:** Migration not applied

**Solution:**
```bash
supabase migration up
supabase db reset  # if needed
```

## Next Steps

1. **Test the flow** in iOS simulator
2. **Integrate with orders** to apply cashback
3. **Add analytics** to admin panel
4. **Plan real payment integration** for production launch

## Related Documentation

- [SUBSCRIPTION_MODEL_IMPLEMENTATION.md](./SUBSCRIPTION_MODEL_IMPLEMENTATION.md) - Full technical documentation
- Migration file: `supabase/migrations/20260223000000_subscriptions.sql`

## Support

For issues or questions:
- Check migration logs in `/logs/`
- Test RPC functions directly in database
- Review iOS console for API errors
