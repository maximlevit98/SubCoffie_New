# Subscription Model Implementation

## Overview

This document describes the implementation of the subscription-based pricing model for SubscribeCoffie. The subscription system allows users to subscribe to monthly or yearly plans that provide various benefits like cashback, free delivery, and priority support.

## Database Schema

### Tables Created

#### 1. `subscription_plans`
Stores available subscription plans (Basic, Premium, VIP).

**Columns:**
- `id` (UUID): Primary key
- `name` (TEXT): Plan identifier (e.g., 'basic', 'premium', 'vip')
- `name_ru` (TEXT): Russian display name
- `description` (TEXT): English description
- `description_ru` (TEXT): Russian description
- `price_credits` (INTEGER): Price in credits (100 credits = 1 ruble)
- `billing_period` (TEXT): 'monthly' or 'yearly'
- `is_active` (BOOLEAN): Whether the plan is available
- `display_order` (INTEGER): Display order in UI
- `created_at`, `updated_at` (TIMESTAMPTZ): Timestamps

#### 2. `user_subscriptions`
Tracks user subscriptions.

**Columns:**
- `id` (UUID): Primary key
- `user_id` (UUID): References profiles
- `plan_id` (UUID): References subscription_plans
- `status` (TEXT): 'active', 'cancelled', 'expired', 'suspended'
- `payment_method_id` (UUID): References payment_methods
- `started_at` (TIMESTAMPTZ): Subscription start date
- `current_period_start` (TIMESTAMPTZ): Current billing period start
- `current_period_end` (TIMESTAMPTZ): Current billing period end
- `cancelled_at` (TIMESTAMPTZ): Cancellation date (nullable)
- `cancel_reason` (TEXT): Cancellation reason (nullable)
- `auto_renew` (BOOLEAN): Whether to auto-renew
- `created_at`, `updated_at` (TIMESTAMPTZ): Timestamps

**Constraints:**
- Only one active subscription per user

#### 3. `subscription_benefits`
Defines benefits for each plan.

**Columns:**
- `id` (UUID): Primary key
- `plan_id` (UUID): References subscription_plans
- `benefit_type` (TEXT): 'cashback', 'free_delivery', 'priority_support', 'exclusive_promos', 'discount', 'other'
- `benefit_name` (TEXT): English benefit name
- `benefit_name_ru` (TEXT): Russian benefit name
- `benefit_value` (TEXT): Numeric or text value (e.g., "10" for 10% cashback)
- `description` (TEXT): English description
- `description_ru` (TEXT): Russian description
- `display_order` (INTEGER): Display order
- `is_active` (BOOLEAN): Whether the benefit is active
- `created_at` (TIMESTAMPTZ): Timestamp

#### 4. `subscription_payments`
Tracks subscription payment history.

**Columns:**
- `id` (UUID): Primary key
- `subscription_id` (UUID): References user_subscriptions
- `user_id` (UUID): References profiles
- `amount_credits` (INTEGER): Payment amount
- `payment_method_id` (UUID): References payment_methods
- `status` (TEXT): 'pending', 'completed', 'failed', 'refunded'
- `provider_transaction_id` (TEXT): Transaction ID from payment provider
- `period_start`, `period_end` (TIMESTAMPTZ): Billing period
- `paid_at` (TIMESTAMPTZ): Payment date
- `failed_reason` (TEXT): Failure reason if applicable
- `created_at` (TIMESTAMPTZ): Timestamp

## RPC Functions

### 1. `get_subscription_plans()`
Returns all active subscription plans with their benefits.

**Returns:** Array of plans with nested benefits as JSONB

**Usage:**
```sql
SELECT * FROM get_subscription_plans();
```

### 2. `subscribe_user(p_user_id UUID, p_plan_id UUID, p_payment_method_id UUID DEFAULT NULL)`
Subscribes a user to a plan.

**Parameters:**
- `p_user_id`: User UUID
- `p_plan_id`: Plan UUID
- `p_payment_method_id`: Payment method UUID (optional, mock for MVP)

**Returns:** JSONB with:
```json
{
  "success": true,
  "subscription_id": "uuid",
  "payment_id": "uuid",
  "period_end": "2026-03-01T00:00:00Z",
  "amount_paid": 29900
}
```

**Usage:**
```sql
SELECT subscribe_user(
  'user-uuid',
  'plan-uuid',
  NULL  -- mock payment for MVP
);
```

### 3. `cancel_subscription(p_subscription_id UUID, p_cancel_reason TEXT DEFAULT NULL)`
Cancels a user's subscription (remains active until period end).

**Parameters:**
- `p_subscription_id`: Subscription UUID
- `p_cancel_reason`: Optional cancellation reason

**Returns:** JSONB with success/error message

**Usage:**
```sql
SELECT cancel_subscription(
  'subscription-uuid',
  'Too expensive'
);
```

### 4. `check_subscription_benefits(p_user_id UUID)`
Checks what benefits a user has from their active subscription.

**Parameters:**
- `p_user_id`: User UUID

**Returns:** JSONB with:
```json
{
  "has_subscription": true,
  "subscription_id": "uuid",
  "plan_id": "uuid",
  "period_end": "2026-03-01T00:00:00Z",
  "benefits": [
    {
      "benefit_type": "cashback",
      "benefit_name": "10% Cashback",
      "benefit_value": "10",
      ...
    }
  ]
}
```

### 5. `get_user_subscription(p_user_id UUID)`
Gets user's current subscription with full details.

**Returns:** JSONB with subscription, plan, and benefits

### 6. `expire_subscriptions()`
Expires subscriptions that have passed their end date (for cron job).

**Returns:** Integer count of expired subscriptions

## Default Plans

### Basic Plan (₽299/month)
- 5% Cashback on all orders

### Premium Plan (₽599/month)
- 10% Cashback on all orders
- Free Delivery

### VIP Plan (₽1499/month)
- 15% Cashback on all orders
- Free Delivery
- Priority Support (24/7)
- Exclusive Promotions

## iOS Implementation

### Models
- `SubscriptionModels.swift`: Data models for plans, subscriptions, and benefits

### Service
- `SubscriptionService.swift`: API service for subscription operations

### Views
- `SubscriptionPlansView.swift`: Main view for browsing and subscribing to plans
- Integrated into `ProfileView.swift` with a subscription section

### Key Features
- Browse available subscription plans
- View current subscription status
- Subscribe to a plan (mock payment for MVP)
- Cancel subscription
- View benefits and remaining days
- Demo mode badge indicating mock payments

## Mock Payment Implementation

For the MVP (local development), all payments are simulated:

1. **No Real Payment Gateway**: No Stripe/YooKassa integration yet
2. **Mock Transactions**: All transactions are marked as 'completed' immediately
3. **Test Data**: `provider_transaction_id` uses 'mock_' prefix
4. **Demo Badge**: UI displays "DEMO MODE" badge on subscription screens

## Future Enhancements

When moving to production:

1. **Real Payment Integration**:
   - Integrate Stripe or YooKassa SDK
   - Replace mock payment flow with real API calls
   - Implement webhook handlers for payment confirmations

2. **Apple In-App Purchase**:
   - Add StoreKit integration for iOS
   - Handle subscription receipts
   - Sync with backend

3. **Auto-Renewal**:
   - Implement cron job to call `expire_subscriptions()`
   - Add notification system for renewal reminders
   - Handle failed payment retries

4. **Analytics**:
   - Track subscription conversion rates
   - Monitor churn and retention
   - A/B test different pricing strategies

## Row Level Security (RLS)

All tables have RLS enabled:

- **Subscription Plans**: Public read, admin write
- **User Subscriptions**: Users see their own, admins see all
- **Subscription Benefits**: Public read for active plans
- **Subscription Payments**: Users see their own, admins see all

## Integration with Orders

The subscription benefits (especially cashback) should be integrated with the order flow:

```sql
-- Example: Check if user has cashback benefit when creating order
DO $$
DECLARE
  v_benefits JSONB;
  v_cashback_percent INTEGER;
BEGIN
  -- Check benefits
  SELECT check_subscription_benefits('user-uuid') INTO v_benefits;
  
  -- If has cashback benefit, apply it to order
  IF (v_benefits->>'has_subscription')::boolean THEN
    v_cashback_percent := (v_benefits->'benefits'->0->>'benefit_value')::integer;
    -- Apply cashback logic to order
  END IF;
END $$;
```

## Testing

### SQL Tests
Create tests in `/SubscribeCoffieBackend/tests/`:

1. Test subscription creation
2. Test benefit checking
3. Test cancellation
4. Test expiration logic

### iOS Tests
Add unit tests for:

1. SubscriptionService API calls
2. SubscriptionModels decoding
3. SubscriptionPlansView UI states

## Deployment

### Database Migration
```bash
# Apply migration
supabase migration up

# Verify tables
psql -c "\d+ subscription_plans"
psql -c "\d+ user_subscriptions"
```

### Backend
Migration is automatically applied via Supabase migration system.

### iOS
1. Add new Swift files to Xcode project
2. Update project dependencies if needed
3. Test subscription flow in simulator

## Support

For questions or issues:
- Check migration logs in `/logs/`
- Review RPC function implementations
- Test with mock data in development environment
