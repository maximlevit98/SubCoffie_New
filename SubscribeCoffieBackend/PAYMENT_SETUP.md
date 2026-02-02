# Payment Provider Setup Guide

This guide walks you through setting up YooKassa and Stripe payment integrations for SubscribeCoffie.

## Table of Contents

1. [YooKassa Setup (Russian Market)](#yookassa-setup)
2. [Stripe Setup (International)](#stripe-setup)
3. [Supabase Configuration](#supabase-configuration)
4. [Testing](#testing)
5. [Going Live](#going-live)

---

## YooKassa Setup

### 1. Create YooKassa Account

1. Go to [YooKassa](https://yookassa.ru/)
2. Sign up for a merchant account
3. Complete KYC verification (business documents required)
4. Wait for account approval (typically 1-3 business days)

### 2. Get API Credentials

1. Log in to [YooKassa Dashboard](https://yookassa.ru/my)
2. Go to **Settings** → **API Keys**
3. Create a new API key or use existing one
4. Note down:
   - **Shop ID** (e.g., `123456`)
   - **Secret Key** (e.g., `live_xxx...` or `test_xxx...`)

### 3. Configure Webhook

1. In YooKassa Dashboard, go to **Settings** → **Notifications**
2. Add webhook URL:
   ```
   https://your-project.supabase.co/functions/v1/yookassa-webhook
   ```
3. Select events to receive:
   - ✅ `payment.succeeded`
   - ✅ `payment.canceled`
   - ✅ `payment.waiting_for_capture` (if using two-step payments)
   - ✅ `refund.succeeded` (if implementing refunds)

4. Save configuration

### 4. Test Mode

YooKassa provides test mode for development:

**Test Credentials:**
- Use test API keys (start with `test_`)
- No real money is charged

**Test Cards:**
- **Success:** `5555 5555 5555 4477`
  - CVV: Any 3 digits
  - Expiry: Any future date
  
- **Decline:** `5555 5555 5555 5559`
  - CVV: Any 3 digits
  - Expiry: Any future date

- **3DS Success:** `4111 1111 1111 1111`
  - Requires 3DS authentication
  - Use any CVV and future expiry

---

## Stripe Setup

### 1. Create Stripe Account

1. Go to [Stripe](https://stripe.com/)
2. Sign up for an account
3. Complete business verification
4. Activate your account

### 2. Get API Credentials

1. Log in to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Go to **Developers** → **API Keys**
3. Note down:
   - **Publishable Key** (starts with `pk_test_` or `pk_live_`)
   - **Secret Key** (starts with `sk_test_` or `sk_live_`)

### 3. Configure Webhook

1. In Stripe Dashboard, go to **Developers** → **Webhooks**
2. Click **Add endpoint**
3. Enter webhook URL:
   ```
   https://your-project.supabase.co/functions/v1/stripe-webhook
   ```
4. Select events to receive:
   - ✅ `payment_intent.succeeded`
   - ✅ `payment_intent.payment_failed`
   - ✅ `payment_intent.canceled`
   - ✅ `charge.refunded` (if implementing refunds)

5. Click **Add endpoint**
6. Copy the **Signing Secret** (starts with `whsec_`)

### 4. Test Mode

Stripe provides test mode by default:

**Test Cards:**
- **Success:** `4242 4242 4242 4242`
  - CVV: Any 3 digits
  - Expiry: Any future date
  - ZIP: Any 5 digits

- **Decline:** `4000 0000 0000 0002`
  - Simulates card decline

- **3DS Required:** `4000 0025 0000 3155`
  - Requires 3DS authentication

- **Insufficient Funds:** `4000 0000 0000 9995`
  - Simulates insufficient funds

---

## Supabase Configuration

### 1. Deploy Edge Functions

```bash
cd SubscribeCoffieBackend
./scripts/deploy_payment_functions.sh
```

Or manually:

```bash
supabase functions deploy create-payment --no-verify-jwt
supabase functions deploy yookassa-webhook --no-verify-jwt
supabase functions deploy stripe-webhook --no-verify-jwt
```

### 2. Set Environment Variables

In Supabase Dashboard → **Settings** → **Edge Functions** → **Secrets**:

**For YooKassa:**
```bash
YOOKASSA_SHOP_ID=your_shop_id
YOOKASSA_SECRET_KEY=your_secret_key
```

**For Stripe:**
```bash
STRIPE_SECRET_KEY=sk_test_xxx_or_sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
```

Or using CLI:

```bash
# YooKassa
supabase secrets set YOOKASSA_SHOP_ID=your_shop_id
supabase secrets set YOOKASSA_SECRET_KEY=your_secret_key

# Stripe
supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
```

### 3. Run Migration

```bash
cd SubscribeCoffieBackend
supabase db push
```

Or manually apply migration:

```sql
-- Run the migration file
\i supabase/migrations/20260202000000_real_payment_integration.sql
```

### 4. Activate Payment Provider

**For YooKassa:**

```sql
UPDATE public.payment_provider_config
SET 
  is_active = true,
  shop_id = 'your_shop_id',
  test_mode = true -- Set to false for production
WHERE provider_name = 'yookassa';

-- Deactivate other providers
UPDATE public.payment_provider_config
SET is_active = false
WHERE provider_name != 'yookassa';
```

**For Stripe:**

```sql
UPDATE public.payment_provider_config
SET 
  is_active = true,
  test_mode = true -- Set to false for production
WHERE provider_name = 'stripe';

-- Deactivate other providers
UPDATE public.payment_provider_config
SET is_active = false
WHERE provider_name != 'stripe';
```

### 5. Verify Configuration

```sql
-- Check active provider
SELECT * FROM public.payment_provider_config WHERE is_active = true;

-- Check commission rates
SELECT * FROM public.commission_config WHERE active = true;
```

---

## Testing

### 1. Test Mock Payments (Default)

In iOS app, mock payments are enabled by default:

```swift
// WalletTopUpView.swift
@State private var useRealPayments = false // Mock mode
```

Test flow:
1. Open wallet top-up screen
2. Enter amount
3. Click "Пополнить" (Top Up)
4. Payment completes immediately
5. Wallet balance updated

### 2. Test Real Payments (Test Mode)

Enable real payments:

```swift
// WalletTopUpView.swift
@State private var useRealPayments = true // Real payment mode
```

**YooKassa Test Flow:**
1. Open wallet top-up screen
2. Toggle "Использовать реальные платежи" (Use real payments)
3. Enter amount
4. Click "Оплатить" (Pay)
5. Redirected to YooKassa payment page
6. Enter test card: `5555 5555 5555 4477`
7. Complete payment
8. Redirected back to app
9. Wallet balance updated

**Stripe Test Flow:**
1. Open wallet top-up screen
2. Toggle "Использовать реальные платежи"
3. Enter amount
4. Click "Оплатить"
5. Enter test card: `4242 4242 4242 4242`
6. Complete payment
7. Wallet balance updated

### 3. Test Webhooks

**Using Provider's Test Tools:**

**YooKassa:**
1. Go to YooKassa Dashboard → **Settings** → **Notifications**
2. Click "Send test notification"
3. Check webhook logs in Supabase

**Stripe:**
1. Go to Stripe Dashboard → **Developers** → **Webhooks**
2. Click your webhook endpoint
3. Click "Send test webhook"
4. Select event type (e.g., `payment_intent.succeeded`)
5. Check webhook logs in Supabase

**Check Webhook Logs:**

```sql
SELECT * FROM public.payment_webhook_events
ORDER BY created_at DESC
LIMIT 10;
```

### 4. Monitor Transactions

```sql
-- View recent transactions
SELECT 
  id,
  transaction_type,
  amount_credits,
  commission_credits,
  status,
  provider_transaction_id,
  created_at
FROM public.payment_transactions
ORDER BY created_at DESC
LIMIT 10;

-- Check failed transactions
SELECT * FROM public.payment_transactions
WHERE status = 'failed'
ORDER BY created_at DESC;
```

---

## Going Live

### 1. Switch to Production Mode

**YooKassa:**
1. Replace test API key with live API key
2. Update Supabase secrets:
   ```bash
   supabase secrets set YOOKASSA_SECRET_KEY=live_xxx
   ```
3. Update database:
   ```sql
   UPDATE public.payment_provider_config
   SET test_mode = false
   WHERE provider_name = 'yookassa';
   ```

**Stripe:**
1. Replace test API key with live API key
2. Update Supabase secrets:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
   ```
3. Create new webhook endpoint with live mode URL
4. Update webhook secret:
   ```bash
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_live_xxx
   ```
5. Update database:
   ```sql
   UPDATE public.payment_provider_config
   SET test_mode = false
   WHERE provider_name = 'stripe';
   ```

### 2. Update iOS App

Remove or hide the test mode toggle:

```swift
// WalletTopUpView.swift
@State private var useRealPayments = true // Always use real payments in production

// Remove toggle from UI or hide it
```

### 3. Test with Small Amounts

Before full launch:
1. Test with minimum amounts (e.g., 10 RUB)
2. Verify webhook delivery
3. Check transaction completion
4. Confirm wallet balance updates

### 4. Monitor Production

Set up monitoring:

```sql
-- Create view for daily revenue
CREATE VIEW daily_revenue AS
SELECT 
  DATE(completed_at) as date,
  COUNT(*) as transaction_count,
  SUM(amount_credits) as total_amount,
  SUM(commission_credits) as total_commission
FROM public.payment_transactions
WHERE status = 'completed'
GROUP BY DATE(completed_at)
ORDER BY date DESC;

-- Query daily revenue
SELECT * FROM daily_revenue LIMIT 30;
```

### 5. Set Up Alerts

Monitor for issues:
- Failed payment rate > 5%
- Webhook delivery failures
- Unusual transaction patterns

---

## Troubleshooting

### Webhook Not Received

**Check:**
1. Webhook URL is correct
2. Edge Function is deployed
3. Secrets are set correctly
4. Provider's webhook configuration is active

**Debug:**
```bash
# Check Edge Function logs
supabase functions logs yookassa-webhook
supabase functions logs stripe-webhook
```

### Payment Stuck in Pending

**Manually confirm:**
```sql
SELECT public.confirm_payment(
  'transaction-uuid'::uuid,
  'provider-transaction-id',
  'provider-payment-intent-id'
);
```

### Commission Not Calculated

**Check commission config:**
```sql
SELECT * FROM public.commission_config WHERE active = true;
```

**Update if needed:**
```sql
UPDATE public.commission_config
SET commission_percent = 7.0
WHERE operation_type = 'citypass_topup';
```

---

## Security Checklist

- [ ] API keys stored in Supabase secrets (not in code)
- [ ] Webhook signature verification enabled
- [ ] RLS policies enabled on all tables
- [ ] Test mode disabled in production
- [ ] HTTPS enforced for all endpoints
- [ ] Regular security audits scheduled

---

## Support

- **YooKassa Support:** support@yookassa.ru
- **Stripe Support:** https://support.stripe.com/
- **Supabase Support:** https://supabase.com/support

---

## Next Steps

After setup:
1. Test thoroughly in test mode
2. Monitor webhook delivery
3. Review transaction logs
4. Prepare for production launch
5. Set up monitoring and alerts

For detailed API documentation, see [PAYMENT_INTEGRATION.md](./PAYMENT_INTEGRATION.md)
