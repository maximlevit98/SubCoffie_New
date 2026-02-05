# Real Payments - Implementation Guide (When Ready)

**Date**: 2026-02-05  
**Status**: 🔴 BLOCKED - Complete security audit first

---

## ⚠️ STOP! Read This First

**DO NOT PROCEED** until ALL items in `REAL_PAYMENT_SECURITY_AUDIT.md` are complete.

**Estimated Time**: 2-3 months minimum

**Current Recommendation**: Launch MVP with mock payments first

---

## 📋 Prerequisites Checklist

Before you can enable real payments, verify:

### Critical Security (BLOCKING)
- [ ] Read `REAL_PAYMENT_SECURITY_AUDIT.md` completely
- [ ] All 5 critical security issues resolved:
  - [ ] 1. API keys moved to Edge Function secrets
  - [ ] 2. Webhook signature verification implemented
  - [ ] 3. Webhooks made idempotent
  - [ ] 4. Transaction locking implemented
  - [ ] 5. Edge Functions deployed and tested

### Legal & Compliance (BLOCKING)
- [ ] Payment provider contracts signed
- [ ] Terms of Service updated
- [ ] Privacy Policy updated
- [ ] PCI DSS SAQ-A completed
- [ ] Business licenses obtained

### Testing (BLOCKING)
- [ ] All tests in Phase 3 passed
- [ ] Beta testing completed
- [ ] Load testing completed
- [ ] Rollback plan tested

### Operations (RECOMMENDED)
- [ ] Monitoring and alerting configured
- [ ] Customer support documentation ready
- [ ] Daily reconciliation system ready
- [ ] On-call rotation established

---

## 🚀 Step-by-Step Implementation

Once all prerequisites are complete, follow these steps:

### Step 1: Configure Secrets

```bash
cd SubscribeCoffieBackend

# Set Stripe secrets
supabase secrets set STRIPE_SECRET_KEY=sk_test_your_test_key_here
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_secret_here

# Set YooKassa secrets
supabase secrets set YOOKASSA_SECRET_KEY=your_yookassa_key_here
supabase secrets set YOOKASSA_SHOP_ID=your_shop_id_here

# Keep real payments disabled for now
supabase secrets set ENABLE_REAL_PAYMENTS=false

# Verify secrets
supabase secrets list
```

---

### Step 2: Deploy Edge Functions

```bash
# Deploy payment creation function
supabase functions deploy create-payment-intent

# Deploy Stripe webhook handler
supabase functions deploy stripe-webhook

# Deploy YooKassa webhook handler
supabase functions deploy yookassa-webhook

# Verify deployment
supabase functions list
```

---

### Step 3: Configure Webhooks in Provider Dashboards

#### Stripe Webhook Setup
1. Go to https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. URL: `https://your-project-ref.supabase.co/functions/v1/stripe-webhook`
4. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `payment_intent.canceled`
   - `charge.refunded`
5. Copy webhook signing secret
6. Update secret:
```bash
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_actual_secret_from_stripe
```

#### YooKassa Webhook Setup
1. Go to YooKassa Dashboard → Settings → Webhooks
2. URL: `https://your-project-ref.supabase.co/functions/v1/yookassa-webhook`
3. Enable events:
   - `payment.succeeded`
   - `payment.failed`
   - `payment.canceled`
   - `refund.succeeded`
4. Verify signature setup

---

### Step 4: Test in Test Mode

```bash
# Test payment intent creation
curl -X POST https://your-project-ref.supabase.co/functions/v1/create-payment-intent \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_id": "test-wallet-uuid",
    "amount": 100,
    "idempotency_key": "test-key-1"
  }'

# Verify response has:
# - success: true
# - transaction_id: UUID
# - client_secret: pi_xxx_secret_xxx (Stripe) or payment URL (YooKassa)
```

**Test Checklist**:
- [ ] Payment intent creates successfully
- [ ] Duplicate call with same idempotency_key returns same transaction_id
- [ ] Webhook processing works
- [ ] Wallet credits on successful payment
- [ ] No duplicate credits on webhook retry
- [ ] Failed payments handled gracefully
- [ ] Rate limiting works (11th payment fails)

---

### Step 5: Enable Real Payments (Test Mode First)

```bash
# Enable real payments in test mode
supabase secrets set ENABLE_REAL_PAYMENTS=true

# Verify still using test keys
supabase secrets list | grep STRIPE_SECRET_KEY
# Should show: sk_test_...
```

**Test with Real iOS App**:
1. Update iOS app with production Supabase URL
2. Test full payment flow:
   - Select wallet
   - Enter amount
   - Tap "Top Up"
   - Use Stripe test card: `4242 4242 4242 4242`
   - Verify wallet credits

**Test Scenarios**:
- [ ] Successful payment flow
- [ ] Failed payment (use card `4000 0000 0000 0002`)
- [ ] Network timeout (airplane mode during payment)
- [ ] Duplicate payment (tap "Pay" twice quickly)
- [ ] Webhook retry (manually resend from Stripe Dashboard)

---

### Step 6: Monitor Test Transactions

```sql
-- Check recent transactions
select 
  id,
  user_id,
  amount_credits,
  status,
  provider_transaction_id,
  idempotency_key,
  created_at
from payment_transactions
where created_at > now() - interval '1 day'
order by created_at desc;

-- Check webhook events
select 
  provider,
  event_type,
  event_id,
  processed_at,
  created_at
from payment_webhook_events
where created_at > now() - interval '1 day'
order by created_at desc;

-- Verify no duplicates
select 
  idempotency_key, 
  count(*) 
from payment_transactions 
group by idempotency_key 
having count(*) > 1;
-- Should return 0 rows
```

---

### Step 7: Switch to Live Keys (PRODUCTION)

⚠️ **WARNING**: This enables REAL MONEY transactions

```bash
# ONLY after all testing passes
# ONLY after legal/compliance approval
# ONLY after monitoring/alerting configured

# Switch to live Stripe keys
supabase secrets set STRIPE_SECRET_KEY=sk_live_your_live_key_here
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_live_secret_here

# Switch to live YooKassa keys
supabase secrets set YOOKASSA_SECRET_KEY=live_your_live_key_here

# Verify
supabase secrets list

# Real payments are now ENABLED
```

**Update Webhook URLs** in provider dashboards to production URLs.

---

### Step 8: Enable in iOS App

```swift
// Update WalletService.swift
// Remove .disabled from PaymentService.swift

// Ensure idempotency key generation:
func topUpWallet(walletId: UUID, amount: Int) async throws {
    let userId = try await AuthService.shared.currentUserId()
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let uuid = UUID().uuidString
    let idempotencyKey = "\(userId)_\(timestamp)_\(uuid)"
    
    // Call real payment Edge Function
    let response = try await SupabaseAPIClient.shared
        .functions.invoke("create-payment-intent", options: [
            "wallet_id": walletId.uuidString,
            "amount": amount,
            "idempotency_key": idempotencyKey
        ])
    
    // Handle response
}
```

**iOS Testing**:
- [ ] Build and test on TestFlight
- [ ] Test with REAL cards (small amounts <$1)
- [ ] Verify wallet credits
- [ ] Test error scenarios
- [ ] Submit to App Store Review

---

### Step 9: Soft Launch

**Week 1: Internal Testing**
- [ ] Team tests with real money (<$10 each)
- [ ] Monitor all transactions
- [ ] Fix any issues immediately

**Week 2-3: Beta Users**
- [ ] Invite 10-20 beta testers
- [ ] Real transactions ($1-$10)
- [ ] Collect feedback
- [ ] Monitor closely

**Week 4+: Gradual Rollout**
- [ ] Enable for 10% of users
- [ ] Monitor for 1 week
- [ ] Increase to 25%
- [ ] Monitor for 1 week
- [ ] Increase to 50%
- [ ] Monitor for 1 week
- [ ] Enable for 100%

---

### Step 10: Post-Launch Monitoring

**Daily Tasks** (First 2 weeks):
- [ ] Check transaction success rate (should be >95%)
- [ ] Check webhook processing (should be <1 min)
- [ ] Check reconciliation (DB vs provider dashboards)
- [ ] Review error logs
- [ ] Respond to support tickets

**Weekly Tasks**:
- [ ] Run full reconciliation report
- [ ] Review commission revenue
- [ ] Analyze payment patterns
- [ ] Update documentation as needed

**Monthly Tasks**:
- [ ] Security audit
- [ ] Cost analysis
- [ ] Provider relationship review
- [ ] Legal compliance check

---

## 🔄 Rollback Procedure

If critical issues arise, you can quickly disable real payments:

```bash
# Step 1: Disable real payments
supabase secrets set ENABLE_REAL_PAYMENTS=false

# Step 2: Edge Functions will now reject new payments

# Step 3: Existing pending payments will complete
# (Allow 24 hours for webhooks to process)

# Step 4: Announce to users
# "Payment processing temporarily unavailable"

# Step 5: Investigate and fix issues

# Step 6: Re-enable when ready
```

---

## 📊 Success Metrics

### Technical Metrics
- Payment success rate: >95%
- Webhook processing time: <1 minute
- Duplicate transactions: 0
- API error rate: <1%

### Business Metrics
- Average top-up amount
- Top-up frequency per user
- Commission revenue
- Failed payment reasons

### Security Metrics
- Webhook signature verification: 100%
- Rate limit triggers
- Fraudulent transaction attempts
- PCI compliance status

---

## 🚨 Emergency Contacts

### Stripe Support
- Dashboard: https://dashboard.stripe.com
- Email: support@stripe.com
- Phone: [Your account rep]

### YooKassa Support
- Dashboard: https://yookassa.ru
- Email: support@yookassa.ru
- Phone: [Your account rep]

### Internal Team
- On-call engineer: [Phone]
- Product owner: [Phone]
- Legal contact: [Phone]

---

## 📚 Related Documentation

- `REAL_PAYMENT_SECURITY_AUDIT.md` - Complete security audit
- `REAL_PAYMENT_QUICK_REFERENCE.md` - Quick overview
- `REAL_PAYMENT_INTEGRATION_CHECKLIST.md` - Detailed checklist
- `PAYMENT_SECURITY.md` - Security best practices
- `PRODUCTION_CHECKLIST.md` - Full deployment checklist

---

## ✅ Final Checklist Before Going Live

### Security
- [ ] All 5 critical issues from audit resolved
- [ ] PCI DSS SAQ-A completed
- [ ] Webhook signature verification working
- [ ] Idempotency tested end-to-end
- [ ] Rate limiting tested
- [ ] API keys in Edge Function secrets (not DB)

### Legal
- [ ] Stripe contract signed
- [ ] YooKassa contract signed (if using)
- [ ] Terms of Service updated
- [ ] Privacy Policy updated
- [ ] Business licenses obtained

### Testing
- [ ] All test scenarios passed
- [ ] Beta testing completed
- [ ] Load testing completed
- [ ] Rollback procedure tested

### Operations
- [ ] Monitoring configured
- [ ] Alerting configured
- [ ] On-call rotation established
- [ ] Customer support ready
- [ ] Reconciliation system ready

### Product
- [ ] Users notified about real payments
- [ ] Help documentation updated
- [ ] FAQ updated
- [ ] Marketing materials ready

---

## 🎯 Current Status

**Status**: 🔴 NOT READY - Security audit incomplete

**Blockers**:
1. Critical security issues not resolved
2. Legal contracts not signed
3. Testing not completed
4. Monitoring not configured

**Recommendation**: Keep mock payments, complete security audit first

**Timeline**: 2-3 months to production-ready

---

*Last Updated: 2026-02-05*  
*Next Review: After security issues resolved*
