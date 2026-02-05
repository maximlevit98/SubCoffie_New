# Real Payments Security Audit & Implementation Plan

**Date**: 2026-02-05  
**Priority**: P1 (CRITICAL - Real Money)  
**Status**: 🔴 NOT READY FOR PRODUCTION

---

## 🎯 Executive Summary

This document provides a comprehensive security audit of the real payment integration and a step-by-step plan to enable it safely.

**Current Status**: ✅ **SAFE** - Mock payments only, real payment migration disabled

**Timeline to Enable Real Payments**: **2-3 months minimum**

**Recommendation**: **DO NOT ENABLE YET** - Critical security issues must be resolved first

---

## 🔍 Security Audit Results

### ✅ What's Already Safe

1. **Idempotency Migration Applied** ✅
   - File: `20260205000006_add_payment_idempotency.sql`
   - Adds `idempotency_key` column to `payment_transactions`
   - Implements idempotency in `mock_wallet_topup`
   - Rate limiting (10 payments/hour)
   - **Status**: Applied and working

2. **Mock Payment System** ✅
   - No real money involved
   - Safe for MVP testing
   - User-facing UX complete
   - **Status**: Production-ready

3. **Wallet Balance Deduction** ✅
   - Implemented in `create_order` RPC
   - Atomic transaction handling
   - Proper error messages
   - **Status**: Production-ready

4. **Transaction History** ✅
   - Full audit trail
   - iOS UI complete
   - Pull-to-refresh and pagination
   - **Status**: Production-ready

### ❌ Critical Security Issues (BLOCKING)

#### Issue 1: API Keys Stored in Database
**Severity**: 🔴 CRITICAL (PCI DSS VIOLATION)

**Location**: `20260202010000_real_payment_integration.sql.disabled`
```sql
create table payment_provider_config (
  api_key_encrypted text  -- ❌ STORING API KEYS IN DATABASE
);
```

**Why this is critical**:
- Database backups contain keys
- RLS bypass = full API key exposure
- Violates PCI DSS requirements
- Supabase admins have access

**Solution**: Move to Edge Function secrets
```bash
# ✅ Correct approach
supabase secrets set STRIPE_SECRET_KEY=sk_test_...
supabase secrets set YOOKASSA_SECRET_KEY=...
```

**Files to Update**:
- Delete `payment_provider_config` table
- Update Edge Functions to use `Deno.env.get()`
- Remove all API key references from database

---

#### Issue 2: No Webhook Signature Verification
**Severity**: 🔴 CRITICAL (FREE MONEY EXPLOIT)

**Problem**: Anyone can POST fake webhook events to credit wallets

**Current Code** (`payment-webhook/index.ts`):
```typescript
// ❌ NO SIGNATURE VERIFICATION
serve(async (req) => {
  const body = await req.json();
  // Directly process without verification
});
```

**Attack Scenario**:
```bash
# Attacker sends fake webhook:
curl -X POST https://your-api.supabase.co/functions/v1/payment-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "payment_intent.succeeded",
    "data": {
      "object": {
        "metadata": {
          "wallet_id": "attacker-wallet-id"
        },
        "amount": 1000000
      }
    }
  }'
# Result: Free money credited to attacker's wallet
```

**Solution**: Verify signatures FIRST
```typescript
// ✅ Correct approach
import Stripe from 'stripe';

serve(async (req) => {
  const body = await req.text();
  const signature = req.headers.get('stripe-signature');
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
  
  // ✅ VERIFY SIGNATURE FIRST
  let event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    return new Response('Invalid signature', { status: 401 });
  }
  
  // Now safe to process
});
```

---

#### Issue 3: Webhooks Not Idempotent
**Severity**: 🔴 CRITICAL (DUPLICATE CREDITS)

**Problem**: Webhook retry after success = duplicate wallet credits

**Current Code**:
```sql
if v_status = 'completed' then
  raise exception 'Transaction already completed';  -- ❌ THROWS ERROR
end if;
```

**Issue**: Should return success (idempotent), not error

**Solution**: Make `confirm_payment` idempotent
```sql
-- ✅ Correct approach
if v_status = 'completed' then
  return jsonb_build_object(
    'success', true,
    'message', 'Already processed (idempotent)',
    'transaction_id', p_transaction_id
  );
end if;
```

---

#### Issue 4: Missing Transaction Locking
**Severity**: 🔴 CRITICAL (RACE CONDITION)

**Problem**: Two webhooks arriving simultaneously can both process

**Solution**: Use `SELECT FOR UPDATE NOWAIT`
```sql
-- ✅ Correct approach
select wallet_id, amount_credits, status
into v_wallet_id, v_amount, v_status
from public.payment_transactions
where id = p_transaction_id
FOR UPDATE NOWAIT;  -- ✅ Lock row, fail fast if already locked
```

---

#### Issue 5: No Edge Function Implementation
**Severity**: 🔴 CRITICAL (INSECURE)

**Problem**: Real payment logic currently in database RPCs (insecure)

**Required Edge Functions**:
1. `create-payment-intent` - Create Stripe/YooKassa payment
2. `payment-webhook` - Process provider webhooks
3. `confirm-payment` - Confirm and credit wallet

**Why Edge Functions are required**:
- Secure API key storage (secrets)
- Webhook signature verification
- Provider SDK access
- Better error handling
- Separation of concerns

---

### ⚠️ High Priority Issues (Should Fix)

#### Issue 6: Sensitive Data in Logs
**Severity**: ⚠️ HIGH (PCI DSS)

```sql
create table payment_webhook_events (
  payload jsonb not null  -- ⚠️ Stores full webhook payload
);
```

**Solution**: Sanitize before storing
```typescript
function sanitizePayload(payload: any) {
  const { card, bank_card, cvv, pan, ...safe } = payload;
  return safe;
}
```

---

#### Issue 7: No Rate Limiting on Payment Attempts
**Severity**: ⚠️ HIGH (FRAUD RISK)

**Solution**: Implement in `create_payment_intent`
```sql
select count(*) into v_attempt_count
from public.payment_transactions
where user_id = auth.uid()
  and created_at > now() - interval '1 hour';

if v_attempt_count >= 10 then
  raise exception 'Rate limit exceeded. Try again later.';
end if;
```

---

#### Issue 8: No Daily Reconciliation
**Severity**: ⚠️ HIGH (FINANCIAL RISK)

**Problem**: No automated check that DB totals match provider dashboards

**Solution**: Create reconciliation Edge Function
```typescript
// supabase/functions/daily-reconciliation/index.ts
// - Fetch totals from Stripe/YooKassa API
// - Compare with DB totals
// - Alert on mismatch
```

---

## 📋 Implementation Plan

### Phase 1: Security Hardening (5-7 days)

#### Task 1.1: Remove API Keys from Database
- [ ] Create backup of current migration
- [ ] Remove `payment_provider_config` table
- [ ] Update Edge Functions to use secrets
- [ ] Test local development with `.env` file
- [ ] Document secret management

**Files to modify**:
- `20260202010000_real_payment_integration.sql.disabled`
- `supabase/functions/create-payment-intent/index.ts`
- `supabase/functions/payment-webhook/index.ts`

---

#### Task 1.2: Implement Webhook Signature Verification
- [ ] Add signature verification to Stripe webhook
- [ ] Add signature verification to YooKassa webhook
- [ ] Test with invalid signatures (should reject)
- [ ] Test with valid signatures (should accept)
- [ ] Document webhook setup in provider dashboards

**Code to implement**:
```typescript
// Stripe
const event = stripe.webhooks.constructEvent(body, signature, webhookSecret);

// YooKassa
const hmac = crypto.createHmac('sha256', YOOKASSA_SECRET);
hmac.update(body);
const expectedSignature = hmac.digest('hex');
if (signature !== expectedSignature) {
  return new Response('Invalid signature', { status: 401 });
}
```

---

#### Task 1.3: Make Webhooks Idempotent
- [ ] Update `confirm_payment` to return success if already processed
- [ ] Add `SELECT FOR UPDATE NOWAIT` locking
- [ ] Store webhook `event_id` to detect duplicates
- [ ] Test concurrent webhook processing
- [ ] Test webhook retry scenarios

**SQL to implement**:
```sql
-- Check if already processed
if v_status = 'completed' then
  return jsonb_build_object('success', true, 'message', 'Already processed');
end if;

-- Lock transaction row
FOR UPDATE NOWAIT;
```

---

#### Task 1.4: Add Transaction Locking
- [ ] Add `FOR UPDATE NOWAIT` to all payment RPCs
- [ ] Test concurrent payment attempts
- [ ] Handle lock timeout gracefully
- [ ] Add retry logic in Edge Functions

---

#### Task 1.5: Implement Edge Functions
- [ ] Create `create-payment-intent` Edge Function
- [ ] Create `payment-webhook` Edge Function
- [ ] Create `confirm-payment` Edge Function
- [ ] Test local deployment
- [ ] Deploy to staging environment
- [ ] Configure secrets

**Files to create/update**:
- `supabase/functions/create-payment-intent/index.ts` ✅ (exists, needs updates)
- `supabase/functions/payment-webhook/index.ts` ✅ (exists, needs signature verification)
- `supabase/functions/stripe-webhook/index.ts` ✅ (exists, needs updates)
- `supabase/functions/yookassa-webhook/index.ts` ✅ (exists, needs updates)

---

### Phase 2: PCI DSS Compliance (2-3 days)

#### Task 2.1: Data Storage Audit
- [ ] Verify NO full card numbers (PAN) stored
- [ ] Verify NO CVV/CVC stored
- [ ] Verify NO magnetic stripe data stored
- [ ] Only store: last 4 digits, brand, expiry
- [ ] Use provider tokens only

**Checklist**:
```sql
-- ✅ Safe to store:
card_last_four text
card_brand text
card_exp_month int
card_exp_year int
payment_method_token text  -- Stripe pm_xxx or YooKassa token

-- ❌ NEVER store:
card_number  -- NO
cvv          -- NO
cvv2         -- NO
mag_stripe   -- NO
```

---

#### Task 2.2: Sanitize Webhook Logs
- [ ] Implement payload sanitization
- [ ] Remove card data before storing
- [ ] Remove CVV before storing
- [ ] Test with real webhook payloads
- [ ] Verify no PII in logs

---

#### Task 2.3: Access Control Audit
- [ ] Payment config: Admin only
- [ ] Webhook logs: Admin only
- [ ] Transaction history: User + Admin only
- [ ] No anon access to payment functions
- [ ] Verify RLS policies

---

#### Task 2.4: Complete PCI SAQ-A
- [ ] Determine PCI level (depends on volume)
- [ ] Complete Self-Assessment Questionnaire
- [ ] Document compliance measures
- [ ] Annual review process

---

### Phase 3: Testing (4-5 days)

#### Task 3.1: Idempotency Tests
```bash
# Test 1: Duplicate payment intent creation
# Same idempotency_key should return same transaction_id

# Test 2: Duplicate webhook processing
# Same event_id should return success without duplicate credit
```

- [ ] Test duplicate RPC calls with same idempotency key
- [ ] Test duplicate webhook events
- [ ] Verify same transaction_id returned
- [ ] Verify no duplicate wallet credits

---

#### Task 3.2: Concurrency Tests
- [ ] Simulate 2 webhooks arriving simultaneously
- [ ] Verify only one processes
- [ ] Verify no duplicate wallet credits
- [ ] Test lock timeout scenarios

---

#### Task 3.3: Failure Tests
- [ ] Network timeout during payment
- [ ] Webhook retry after initial failure
- [ ] Edge Function crash mid-transaction
- [ ] Provider API error handling
- [ ] Database connection loss

---

#### Task 3.4: Rate Limit Tests
- [ ] 11 payments in 1 hour = rate limit error
- [ ] 4 failed attempts = temporary block
- [ ] Verify limits reset correctly
- [ ] Test multiple users simultaneously

---

#### Task 3.5: Provider Integration Tests (Stripe)
- [ ] Create payment intent in test mode
- [ ] Confirm payment intent
- [ ] Simulate webhook delivery
- [ ] Test failed payment scenario
- [ ] Test refund scenario

---

#### Task 3.6: Provider Integration Tests (YooKassa)
- [ ] Create payment in test mode
- [ ] Confirm payment
- [ ] Simulate webhook delivery
- [ ] Test failed payment scenario
- [ ] Test refund scenario

---

### Phase 4: Legal & Compliance (2-4 weeks)

#### Task 4.1: Provider Contracts
- [ ] Sign contract with Stripe (if using)
- [ ] Sign contract with YooKassa (if using)
- [ ] Verify terms allow your business model
- [ ] Review fee structure
- [ ] Understand dispute process

---

#### Task 4.2: Terms of Service
- [ ] Update ToS with payment terms
- [ ] Add refund policy
- [ ] Add charge dispute process
- [ ] Currency and fees disclosure
- [ ] Cancellation policy

---

#### Task 4.3: Privacy Policy
- [ ] Disclose payment data processing
- [ ] List payment providers as processors
- [ ] GDPR compliance (if EU customers)
- [ ] Data retention policy
- [ ] User data export/deletion

---

#### Task 4.4: Business Licenses
- [ ] Payment processing license (if required)
- [ ] Russian legal entity (for YooKassa)
- [ ] Tax registration
- [ ] AML/KYC if required

---

### Phase 5: Monitoring & Operations (2-3 days)

#### Task 5.1: Alerting Setup
- [ ] Payment failure rate > 5%
- [ ] Webhook processing delay > 5 min
- [ ] Daily reconciliation mismatch
- [ ] Rate limit triggers
- [ ] API errors from providers

**Tools**: Sentry, Datadog, or Supabase Dashboard

---

#### Task 5.2: Create Dashboards
- [ ] Real-time payment volume
- [ ] Success/failure rates
- [ ] Average transaction value
- [ ] Top-up frequency
- [ ] Commission revenue
- [ ] Webhook processing times

---

#### Task 5.3: Implement Reconciliation
- [ ] Create `daily-reconciliation` Edge Function
- [ ] Fetch totals from Stripe API
- [ ] Fetch totals from YooKassa API
- [ ] Compare with DB totals
- [ ] Alert on mismatch > 1%
- [ ] Set up daily cron job

---

#### Task 5.4: Customer Support Documentation
- [ ] Payment support playbook
- [ ] Refund process documentation
- [ ] Failed payment troubleshooting
- [ ] Contact info for urgent issues
- [ ] Escalation procedures

---

### Phase 6: iOS Integration (2-3 days)

#### Task 6.1: Enable PaymentService
- [ ] Rename `PaymentService.swift.disabled` to `.swift`
- [ ] Update to use new Edge Functions
- [ ] Add idempotency key generation
- [ ] Test payment flow end-to-end
- [ ] Update error handling

---

#### Task 6.2: Update WalletTopUpView
- [ ] Replace mock payment with real payment
- [ ] Add payment method selection
- [ ] Add Stripe SDK integration
- [ ] Test payment confirmation
- [ ] Handle errors gracefully

---

#### Task 6.3: Testing
- [ ] Test full payment flow in test mode
- [ ] Test failed payment scenarios
- [ ] Test network timeout scenarios
- [ ] Test idempotency (tap "Pay" twice)
- [ ] Verify wallet credits correctly

---

### Phase 7: Gradual Rollout (4-6 weeks)

#### Stage 1: Internal Testing (1 week)
- [ ] Test mode only
- [ ] Internal team testing
- [ ] Verify all flows
- [ ] Fix bugs

---

#### Stage 2: Beta Testing (2 weeks)
- [ ] Invite 10-20 beta testers
- [ ] Real test transactions (<$1)
- [ ] Collect feedback
- [ ] Monitor closely

---

#### Stage 3: Soft Launch (1 month)
- [ ] Enable for new users only
- [ ] Monitor 24/7
- [ ] Quick rollback plan ready
- [ ] Daily metrics review

---

#### Stage 4: Full Launch
- [ ] Enable for all users
- [ ] Announce feature
- [ ] Monitor 24/7 for first week
- [ ] Celebrate! 🎉

---

## 📊 Estimated Timeline

| Phase | Duration | Critical Path |
|-------|----------|---------------|
| Security Hardening | 5-7 days | ✅ BLOCKING |
| PCI DSS Compliance | 2-3 days | ✅ BLOCKING |
| Testing | 4-5 days | ✅ BLOCKING |
| Legal/Contracts | 2-4 weeks | ✅ BLOCKING |
| Monitoring Setup | 2-3 days | ⚠️ Recommended |
| iOS Integration | 2-3 days | ✅ BLOCKING |
| Gradual Rollout | 4-6 weeks | ⚠️ Recommended |
| **TOTAL** | **8-12 weeks** | |

---

## 🔐 Security Checklist Before Enable

### Critical (Must Complete)
- [ ] API keys moved to Edge Function secrets (NOT in database)
- [ ] Webhook signature verification implemented and tested
- [ ] Webhooks made idempotent (return success if already processed)
- [ ] Transaction locking implemented (`SELECT FOR UPDATE NOWAIT`)
- [ ] Edge Functions deployed and tested
- [ ] Idempotency keys working end-to-end
- [ ] Rate limiting implemented and tested
- [ ] PCI DSS data storage audit complete
- [ ] Legal contracts signed
- [ ] Terms of Service updated
- [ ] Privacy Policy updated

### High Priority (Should Complete)
- [ ] Sensitive data sanitization implemented
- [ ] Daily reconciliation system created
- [ ] Monitoring and alerting configured
- [ ] Customer support documentation ready
- [ ] Rollback plan documented
- [ ] Incident response plan ready

### Recommended
- [ ] Beta testing completed
- [ ] Performance testing completed
- [ ] Load testing completed
- [ ] Multi-currency support (future)
- [ ] Subscription billing (future)

---

## 🚨 Current Recommendation

### ✅ SAFE FOR MVP LAUNCH (Current State)

**Keep as-is**:
- Mock payments enabled
- Idempotency migration applied
- Real payment migration disabled
- Launch MVP with demo payments

**Benefits**:
- Zero financial risk
- No PCI DSS compliance needed
- Fast MVP launch
- Can test market/demand

**Timeline**: Ready now

---

### ⏳ ENABLE REAL PAYMENTS LATER (Recommended)

**After completing**:
- All blocking security issues fixed
- Legal/compliance complete
- Beta testing successful
- Monitoring/operations ready

**Timeline**: 2-3 months minimum

---

## 📚 Documentation Files

- `REAL_PAYMENT_QUICK_REFERENCE.md` - Quick overview and status
- `REAL_PAYMENT_INTEGRATION_CHECKLIST.md` - Detailed 7-phase checklist
- `REAL_PAYMENT_IMPLEMENTATION_SUMMARY.md` - Implementation summary
- `PAYMENT_SECURITY.md` - Security best practices
- `PRODUCTION_CHECKLIST.md` - Full deployment checklist
- `supabase/functions/SECRETS_TEMPLATE.md` - Secret management guide

---

## 🎯 Next Steps

### For Product Owner
1. **Decision**: Launch MVP with mock payments OR delay 2-3 months for real payments?
2. **If mock payments**: Approve MVP launch, plan real payments for v1.1
3. **If real payments**: Allocate 2-3 months + budget for contracts + team

### For Tech Lead
1. ✅ **Keep current setup** - Mock payments are safe
2. ❌ **DO NOT enable** `20260202010000_real_payment_integration.sql.disabled`
3. 📖 **Review this audit** with team
4. 🛠️ **If proceeding**: Start with Phase 1 (Security Hardening)

### For Legal/Finance
1. Review payment provider contracts
2. Update Terms of Service (refund policy, fees)
3. Review PCI DSS requirements
4. Set up business entity for payment processing

---

**Status**: 🔴 NOT READY FOR PRODUCTION  
**Risk Level**: CRITICAL  
**Recommendation**: Keep mock payments, enable real payments in v1.1

---

*Last Updated: 2026-02-05*  
*Next Review: After legal/compliance approval*
