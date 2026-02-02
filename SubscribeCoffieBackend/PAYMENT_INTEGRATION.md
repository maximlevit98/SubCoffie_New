# Payment Integration Guide

## Overview

This document describes the real payment integration implementation for SubscribeCoffie, supporting both YooKassa (Russian market) and Stripe (international expansion).

## Architecture

### Components

1. **Database Layer** (`20260202000000_real_payment_integration.sql`)
   - Payment provider configuration
   - Payment transactions tracking
   - Webhook event logging
   - Transaction status management

2. **Edge Functions**
   - `create-payment`: Creates payment intents with providers
   - `yookassa-webhook`: Handles YooKassa payment notifications
   - `stripe-webhook`: Handles Stripe payment notifications

3. **iOS App**
   - `PaymentService.swift`: Payment processing logic
   - `WalletService.swift`: Wallet and transaction management
   - `WalletTopUpView.swift`: UI for wallet top-up with payment

## Payment Flow

### 1. User Initiates Payment

```swift
// iOS App
let intent = try await walletService.createPaymentIntent(
    walletId: wallet.id,
    amount: 1000, // 1000 RUB
    paymentMethodId: nil,
    description: "Wallet Top-Up"
)
```

### 2. Create Payment Intent

The `create-payment` Edge Function:
- Creates a pending transaction in the database
- Calls the active payment provider API (YooKassa or Stripe)
- Returns payment details to the client

**YooKassa Response:**
```json
{
  "success": true,
  "transaction_id": "uuid",
  "provider": "yookassa",
  "confirmation_url": "https://yoomoney.ru/checkout/...",
  "payment_id": "2a5d8...",
  "amount": 1000,
  "commission": 70,
  "amount_credited": 930
}
```

**Stripe Response:**
```json
{
  "success": true,
  "transaction_id": "uuid",
  "provider": "stripe",
  "client_secret": "pi_xxx_secret_yyy",
  "payment_intent_id": "pi_xxx",
  "amount": 1000,
  "commission": 70,
  "amount_credited": 930
}
```

### 3. User Completes Payment

**YooKassa:**
- User is redirected to YooKassa payment page (via SFSafariViewController)
- User enters card details and confirms payment
- YooKassa sends webhook to our server

**Stripe:**
- iOS app uses Stripe SDK to collect payment details
- Payment is processed client-side
- Stripe sends webhook to our server

### 4. Webhook Processing

The webhook handler:
1. Verifies webhook signature
2. Logs the event in `payment_webhook_events`
3. Calls `confirm_payment()` or `fail_payment()` RPC function
4. Updates transaction status
5. Credits wallet balance (if successful)

### 5. Status Polling (iOS)

While payment is processing, the app polls transaction status:

```swift
let status = try await walletService.getTransactionStatus(transactionId: transactionId)
// status: "pending" | "completed" | "failed"
```

## Configuration

### Environment Variables

Set these in Supabase Dashboard → Settings → Edge Functions:

**YooKassa:**
```bash
YOOKASSA_SHOP_ID=your_shop_id
YOOKASSA_SECRET_KEY=your_secret_key
```

**Stripe:**
```bash
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
```

### Database Configuration

Activate payment provider:

```sql
-- Activate YooKassa
UPDATE public.payment_provider_config
SET 
  is_active = true,
  shop_id = 'your_shop_id',
  api_key_encrypted = 'your_encrypted_key',
  webhook_secret = 'your_webhook_secret',
  test_mode = true -- Set to false for production
WHERE provider_name = 'yookassa';
```

### Webhook URLs

Configure these URLs in your payment provider dashboard:

**YooKassa:**
```
https://your-project.supabase.co/functions/v1/yookassa-webhook
```

**Stripe:**
```
https://your-project.supabase.co/functions/v1/stripe-webhook
```

## Testing

### Mock Payments (Default)

By default, the system uses mock payments for testing:

```swift
// In WalletTopUpView
@State private var useRealPayments = false // Toggle to enable real payments
```

Mock payments:
- Complete immediately
- No real money is charged
- Useful for development and testing

### Test Mode

Both YooKassa and Stripe support test mode:

**YooKassa Test Cards:**
- Success: `5555 5555 5555 4477`
- Decline: `5555 5555 5555 5559`

**Stripe Test Cards:**
- Success: `4242 4242 4242 4242`
- Decline: `4000 0000 0000 0002`

### Local Testing

1. Run Supabase locally:
```bash
cd SubscribeCoffieBackend
supabase start
```

2. Deploy Edge Functions:
```bash
supabase functions deploy create-payment
supabase functions deploy yookassa-webhook
supabase functions deploy stripe-webhook
```

3. Run migrations:
```bash
supabase db push
```

4. Test webhook locally with ngrok:
```bash
ngrok http 54321
# Use ngrok URL in payment provider dashboard
```

## Commission Rates

Configured in `commission_config` table:

| Operation Type | Default Rate |
|---------------|--------------|
| CityPass Top-Up | 7% |
| Cafe Wallet Top-Up | 4% |
| Direct Order Payment | 17% |

Update rates:

```sql
UPDATE public.commission_config
SET commission_percent = 5.0
WHERE operation_type = 'citypass_topup';
```

## Security

### Webhook Verification

**YooKassa:**
- Uses Basic Auth with shop_id:secret_key
- Validates event signature

**Stripe:**
- Uses webhook signing secret
- Verifies `stripe-signature` header

### API Key Storage

- API keys are stored encrypted in `payment_provider_config`
- Only accessible via Edge Functions (service role)
- Never exposed to client

### RLS Policies

- Users can only view their own transactions
- Admins can view all transactions
- Payment provider config is admin-only

## Monitoring

### Transaction Status

Query transaction history:

```sql
SELECT * FROM public.payment_transactions
WHERE user_id = 'user-uuid'
ORDER BY created_at DESC;
```

### Webhook Events

View webhook logs:

```sql
SELECT * FROM public.payment_webhook_events
WHERE processed = false
ORDER BY created_at DESC;
```

### Failed Payments

Monitor failed payments:

```sql
SELECT 
  t.id,
  t.user_id,
  t.amount_credits,
  t.provider_error_code,
  t.provider_error_message,
  t.created_at
FROM public.payment_transactions t
WHERE t.status = 'failed'
  AND t.created_at > now() - interval '24 hours'
ORDER BY t.created_at DESC;
```

## Troubleshooting

### Payment Stuck in "Pending"

1. Check webhook events:
```sql
SELECT * FROM public.payment_webhook_events
WHERE event_id = 'provider-event-id';
```

2. Manually confirm payment (admin only):
```sql
SELECT public.confirm_payment(
  'transaction-uuid',
  'provider-transaction-id',
  'provider-payment-intent-id'
);
```

### Webhook Not Received

1. Verify webhook URL in provider dashboard
2. Check Edge Function logs in Supabase Dashboard
3. Test webhook with provider's test tool
4. Ensure webhook secret is correct

### Payment Failed

1. Check error in transaction:
```sql
SELECT provider_error_code, provider_error_message
FROM public.payment_transactions
WHERE id = 'transaction-uuid';
```

2. Common errors:
   - `insufficient_funds`: User's card has insufficient funds
   - `card_declined`: Card was declined by bank
   - `expired_card`: Card has expired
   - `invalid_cvc`: Invalid CVC code

## Migration from Mock to Real Payments

1. **Deploy Edge Functions**
```bash
supabase functions deploy create-payment
supabase functions deploy yookassa-webhook
```

2. **Configure Payment Provider**
```sql
UPDATE public.payment_provider_config
SET 
  is_active = true,
  shop_id = 'your_shop_id',
  api_key_encrypted = 'your_key',
  test_mode = true
WHERE provider_name = 'yookassa';
```

3. **Update iOS App**
- Set `useRealPayments = true` in `WalletTopUpView`
- Or add UI toggle for users to choose

4. **Test with Test Cards**
- Use provider's test cards
- Verify webhook delivery
- Check transaction status

5. **Go Live**
```sql
UPDATE public.payment_provider_config
SET test_mode = false
WHERE provider_name = 'yookassa';
```

## Future Enhancements

### Planned Features

1. **Refunds**
   - Implement refund RPC function
   - Add refund UI in admin panel
   - Handle refund webhooks

2. **Recurring Payments**
   - Save payment methods for reuse
   - Implement subscription billing
   - Auto-renewal logic

3. **Apple Pay / Google Pay**
   - Integrate native payment methods
   - Faster checkout experience

4. **Payment Analytics**
   - Revenue dashboard
   - Conversion funnel
   - Failed payment analysis

## Support

For issues or questions:
- Check Supabase Edge Function logs
- Review webhook event logs
- Contact payment provider support
- Review this documentation

## References

- [YooKassa API Documentation](https://yookassa.ru/developers/api)
- [Stripe API Documentation](https://stripe.com/docs/api)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
