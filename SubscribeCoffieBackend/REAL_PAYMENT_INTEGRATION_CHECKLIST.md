# Real Payment Integration Checklist (P1)

**Date**: 2026-02-05 (Prompt 7)  
**Priority**: P1 (Real Money - HIGH RISK)  
**Status**: ⚠️ CRITICAL SECURITY REVIEW REQUIRED

**File**: `20260202010000_real_payment_integration.sql.disabled`

---

## ⚠️ CRITICAL WARNINGS

**This migration enables REAL MONEY transactions**:
- ❌ DO NOT enable without complete security audit
- ❌ DO NOT enable without legal/finance approval
- ❌ DO NOT enable without PCI DSS compliance review
- ❌ DO NOT store sensitive card data (EVER)
- ❌ DO NOT expose API keys in database

**Current Status**: SAFE (disabled + mock payments only)

---

## 🔍 Security Analysis

### ❌ CRITICAL ISSUES FOUND

#### 1. **Storing API Keys in Database** (PCI DSS VIOLATION)
**Location**: `payment_provider_config.api_key_encrypted`

**Problem**:
```sql
api_key_encrypted text, -- ❌ STORING API KEYS IN DATABASE
```

**Why this is critical**:
- Even encrypted, storing provider API keys violates security best practices
- Database backups would contain keys
- RLS bypass = full exposure
- Supabase admin has access to all data

**Solution**:
```
✅ Store API keys in Supabase Edge Function secrets
✅ Use Supabase Vault for encrypted secrets
✅ Never store in database tables
```

**Implementation**:
```typescript
// Edge Function (NOT database)
const YOOKASSA_API_KEY = Deno.env.get('YOOKASSA_SECRET_KEY');
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY');
```

#### 2. **No Idempotency Keys** (CRITICAL)
**Location**: `create_payment_intent`, `confirm_payment`

**Problem**:
- No idempotency protection
- Network retry = duplicate charges
- Webhook replays = duplicate credits

**Solution**:
```sql
-- Add idempotency_key column
alter table public.payment_transactions
  add column if not exists idempotency_key text unique;

-- Add to all payment RPCs
create or replace function public.create_payment_intent(
  p_wallet_id uuid,
  p_amount int,
  p_payment_method_id uuid default null,
  p_idempotency_key text default null  -- ✅ ADD THIS
)
```

**Stripe Reference**:
```typescript
// Client generates idempotency key
const idempotencyKey = `${userId}_${Date.now()}_${crypto.randomUUID()}`;

// Edge Function uses it
const paymentIntent = await stripe.paymentIntents.create({
  amount: amountInCents,
  currency: 'rub',
}, {
  idempotencyKey: idempotencyKey  // ✅ Stripe handles deduplication
});
```

#### 3. **Webhook Not Idempotent** (HIGH RISK)
**Location**: `process_webhook_event`, `confirm_payment`

**Problem**:
```sql
if v_status = 'completed' then
  raise exception 'Transaction already completed';  -- ❌ THROWS ERROR
end if;
```

**Issues**:
- Webhook retry after success = error
- Should return success (idempotent)
- No locking for concurrent webhooks

**Solution**:
```sql
create or replace function public.confirm_payment(
  p_transaction_id uuid,
  p_provider_transaction_id text,
  p_provider_payment_intent_id text default null,
  p_idempotency_key text default null  -- ✅ ADD
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_wallet_id uuid;
  v_amount_credited int;
  v_status text;
  v_already_processed boolean;
begin
  -- ✅ Check idempotency first
  if p_idempotency_key is not null then
    select (status = 'completed') into v_already_processed
    from public.payment_transactions
    where id = p_transaction_id;
    
    if v_already_processed then
      -- ✅ Return success (idempotent - already processed)
      return jsonb_build_object(
        'success', true,
        'message', 'Already processed (idempotent)',
        'transaction_id', p_transaction_id,
        'status', 'completed'
      );
    end if;
  end if;
  
  -- ✅ Use SELECT FOR UPDATE to prevent concurrent processing
  select wallet_id, (amount_credits - commission_credits), status
  into v_wallet_id, v_amount_credited, v_status
  from public.payment_transactions
  where id = p_transaction_id
  FOR UPDATE NOWAIT;  -- ✅ Fail fast if locked
  
  if v_status = 'completed' then
    -- ✅ Already processed, return success (idempotent)
    return jsonb_build_object('success', true, 'message', 'Already processed');
  end if;
  
  -- ... rest of processing
end;
$$;
```

#### 4. **Missing Webhook Signature Verification** (CRITICAL)
**Location**: `process_webhook_event`

**Problem**:
- No webhook signature validation
- Anyone can POST fake events
- = Free money exploit

**Solution**:
```typescript
// Edge Function: Verify webhook signature FIRST
async function verifyWebhookSignature(
  request: Request,
  body: string,
  provider: 'stripe' | 'yookassa'
): Promise<boolean> {
  const signature = request.headers.get('stripe-signature') || 
                    request.headers.get('x-yookassa-signature');
  
  if (!signature) return false;
  
  if (provider === 'stripe') {
    try {
      stripe.webhooks.constructEvent(
        body,
        signature,
        STRIPE_WEBHOOK_SECRET  // ✅ From env, not DB
      );
      return true;
    } catch (err) {
      return false;
    }
  }
  
  // YooKassa verification
  // ...
}

// In webhook handler
if (!await verifyWebhookSignature(request, rawBody, provider)) {
  return new Response('Invalid signature', { status: 401 });
}
```

#### 5. **Sensitive Data in Logs** (PCI DSS VIOLATION)
**Location**: `payment_webhook_events.payload`

**Problem**:
```sql
payload jsonb not null,  -- ❌ Stores full webhook payload
```

**Risk**:
- Webhooks may contain sensitive data
- Full payload stored forever
- Logs = PCI scope

**Solution**:
```sql
-- Store only necessary fields, sanitize payload
create or replace function public.process_webhook_event(
  p_provider text,
  p_event_type text,
  p_event_id text,
  p_payload jsonb
)
returns jsonb
as $$
declare
  v_sanitized_payload jsonb;
begin
  -- ✅ Strip sensitive fields before storing
  v_sanitized_payload := p_payload - 'card' - 'bank_card' - 'cvv' - 'pan';
  
  insert into public.payment_webhook_events (provider, event_type, event_id, payload)
  values (p_provider, p_event_type, p_event_id, v_sanitized_payload);
  
  -- ...
end;
$$;
```

#### 6. **Missing Rate Limiting** (FRAUD RISK)
**Location**: All payment RPCs

**Problem**:
- No rate limiting
- Can spam payment attempts
- = Fraud / DoS

**Solution**:
```sql
-- Add rate limiting table
create table if not exists public.payment_rate_limits (
  user_id uuid not null,
  attempt_count int default 0,
  window_start timestamptz not null default now(),
  constraint payment_rate_limits_pk primary key (user_id, window_start)
);

-- Check in create_payment_intent
declare
  v_attempt_count int;
begin
  -- ✅ Check rate limit (e.g., 10 per hour)
  select count(*) into v_attempt_count
  from public.payment_transactions
  where user_id = auth.uid()
    and created_at > now() - interval '1 hour';
  
  if v_attempt_count >= 10 then
    raise exception 'Rate limit exceeded. Try again later.';
  end if;
  
  -- ...
end;
```

#### 7. **No Reconciliation System** (FINANCIAL RISK)
**Problem**:
- No daily reconciliation checks
- Provider balance ≠ DB balance
- Silent failures undetected

**Solution**:
- Create reconciliation Edge Function
- Daily cron job
- Compare DB totals vs provider dashboard
- Alert on mismatch

---

## 📋 Pre-Production Checklist

### Phase 1: Security Hardening ⚠️

- [ ] **Remove API keys from database**
  - Move to Edge Function secrets
  - Use Supabase Vault
  - Delete `api_key_encrypted` column

- [ ] **Add idempotency keys**
  - Add `idempotency_key` column to `payment_transactions`
  - Add `UNIQUE` constraint
  - Update all payment RPCs to accept key
  - Generate keys on client: `${userId}_${timestamp}_${uuid}`

- [ ] **Implement webhook signature verification**
  - Create Edge Function for webhooks
  - Verify Stripe signatures (`stripe.webhooks.constructEvent`)
  - Verify YooKassa signatures (HMAC SHA-256)
  - Reject unsigned webhooks

- [ ] **Make webhooks idempotent**
  - Update `confirm_payment` to return success if already processed
  - Use `SELECT FOR UPDATE NOWAIT` for locking
  - Store webhook `event_id` to detect duplicates

- [ ] **Sanitize logged data**
  - Strip sensitive fields from webhook payloads
  - Never log card numbers, CVV, full tokens
  - Implement PII redaction

- [ ] **Add rate limiting**
  - Max 10 payment attempts per hour per user
  - Max 3 failed attempts per card per day
  - Implement exponential backoff

- [ ] **Transaction isolation**
  - Use database transactions for payment confirmation
  - Ensure wallet credit is atomic with status update
  - Handle partial failures gracefully

### Phase 2: PCI DSS Compliance 🔒

- [ ] **Data Storage Audit**
  - ✅ NO full card numbers (PAN) stored
  - ✅ NO CVV/CVC stored
  - ✅ NO magnetic stripe data
  - ✅ Only store: last 4 digits, brand, expiry
  - Use provider tokens (`pm_xxx`, `payment_method_id`)

- [ ] **Encryption Requirements**
  - All payment API calls over HTTPS/TLS 1.2+
  - Webhook endpoints HTTPS only
  - No sensitive data in URLs or query params

- [ ] **Access Control**
  - Payment config: Admin only
  - Webhook logs: Admin only
  - Transaction history: User + Admin only
  - No anon access to payment functions

- [ ] **Audit Logging**
  - Log all payment attempts
  - Log all webhook events
  - Log admin access to payment data
  - Retention: 90 days minimum

- [ ] **PCI SAQ (Self-Assessment Questionnaire)**
  - Determine PCI level (depends on volume)
  - Complete SAQ-A if using Stripe/YooKassa SDKs
  - Annual compliance review

### Phase 3: Testing 🧪

- [ ] **Idempotency Tests**
  ```sql
  -- Test: Duplicate payment intent creation
  SELECT public.create_payment_intent(
    wallet_id, 100, null, 'test-idempotency-key-1'
  );
  
  -- Should return same transaction_id
  SELECT public.create_payment_intent(
    wallet_id, 100, null, 'test-idempotency-key-1'
  );
  
  -- Test: Duplicate webhook processing
  SELECT public.process_webhook_event(
    'stripe', 'payment_intent.succeeded', 'evt_test_123', '{}'::jsonb
  );
  
  -- Should return success without duplicate credit
  SELECT public.process_webhook_event(
    'stripe', 'payment_intent.succeeded', 'evt_test_123', '{}'::jsonb
  );
  ```

- [ ] **Concurrency Tests**
  - Simulate 2 webhooks arriving simultaneously
  - Verify only one processes
  - No duplicate wallet credits

- [ ] **Failure Tests**
  - Network timeout during payment
  - Webhook retry after initial failure
  - Edge Function crash mid-transaction
  - Provider API error handling

- [ ] **Rate Limit Tests**
  - 11 payments in 1 hour = rate limit error
  - 4 failed attempts = temporary block
  - Verify limits reset correctly

- [ ] **Provider Integration Tests**
  - Stripe test mode: Create payment intent
  - Stripe test mode: Webhook delivery
  - YooKassa test mode: Create payment
  - YooKassa test mode: Webhook delivery

### Phase 4: Legal & Compliance 📜

- [ ] **Contracts**
  - Sign contract with Stripe (if using)
  - Sign contract with YooKassa (if using)
  - Verify terms allow your business model

- [ ] **Terms of Service**
  - Update ToS with payment terms
  - Refund policy
  - Charge dispute process
  - Currency and fees disclosure

- [ ] **Privacy Policy**
  - Disclose payment data processing
  - List payment providers as processors
  - GDPR compliance (if EU customers)
  - Data retention policy

- [ ] **Business Licenses**
  - Payment processing license (if required)
  - Russian legal entity (for YooKassa)
  - Tax registration
  - AML/KYC if required

### Phase 5: Monitoring & Operations 📊

- [ ] **Alerting**
  - Payment failure rate > 5%
  - Webhook processing delay > 5 min
  - Daily reconciliation mismatch
  - Rate limit triggers
  - API errors from providers

- [ ] **Dashboards**
  - Real-time payment volume
  - Success/failure rates
  - Average transaction value
  - Top-up frequency
  - Commission revenue

- [ ] **Reconciliation**
  - Daily: Compare DB totals vs provider dashboards
  - Weekly: Full transaction audit
  - Monthly: Financial close
  - Automated mismatch detection

- [ ] **Customer Support**
  - Payment support playbook
  - Refund process documented
  - Failed payment troubleshooting
  - Contact info for urgent issues

### Phase 6: Edge Functions Implementation 🔧

Payment processing MUST be in Edge Functions (NOT database RPCs):

```typescript
// supabase/functions/create-payment-intent/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@12.0.0';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
});

serve(async (req) => {
  const { walletId, amount, paymentMethodId, idempotencyKey } = await req.json();
  
  // ✅ Idempotency check in DB
  const { data: existingTx } = await supabase
    .from('payment_transactions')
    .select('*')
    .eq('idempotency_key', idempotencyKey)
    .single();
  
  if (existingTx) {
    return new Response(JSON.stringify({
      success: true,
      transaction_id: existingTx.id,
      client_secret: existingTx.metadata.client_secret
    }));
  }
  
  // ✅ Create payment intent with Stripe
  const paymentIntent = await stripe.paymentIntents.create({
    amount: amount * 100, // Convert to cents
    currency: 'rub',
    payment_method: paymentMethodId,
    confirmation_method: 'manual',
    confirm: false,
    metadata: {
      wallet_id: walletId,
      idempotency_key: idempotencyKey
    }
  }, {
    idempotencyKey: idempotencyKey  // ✅ Stripe-level idempotency
  });
  
  // ✅ Store in DB
  const { data: transaction } = await supabase.rpc('create_payment_intent', {
    p_wallet_id: walletId,
    p_amount: amount,
    p_idempotency_key: idempotencyKey,
    p_provider_payment_intent_id: paymentIntent.id
  });
  
  return new Response(JSON.stringify({
    success: true,
    transaction_id: transaction.id,
    client_secret: paymentIntent.client_secret
  }));
});
```

```typescript
// supabase/functions/payment-webhook/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@12.0.0';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

serve(async (req) => {
  const body = await req.text();
  const signature = req.headers.get('stripe-signature')!;
  
  // ✅ CRITICAL: Verify signature FIRST
  let event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    return new Response('Invalid signature', { status: 401 });
  }
  
  // ✅ Log event (idempotent)
  const { data: webhook } = await supabase.rpc('process_webhook_event', {
    p_provider: 'stripe',
    p_event_type: event.type,
    p_event_id: event.id,
    p_payload: sanitizePayload(event.data.object)
  });
  
  // ✅ Process based on event type
  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object;
    
    await supabase.rpc('confirm_payment', {
      p_transaction_id: paymentIntent.metadata.transaction_id,
      p_provider_transaction_id: paymentIntent.id,
      p_idempotency_key: event.id  // ✅ Use event ID as idempotency key
    });
  }
  
  return new Response(JSON.stringify({ received: true }));
});

function sanitizePayload(obj: any): any {
  // ✅ Strip sensitive fields
  const { card, bank_card, cvv, pan, ...safe } = obj;
  return safe;
}
```

### Phase 7: Rollout Strategy 🚀

- [ ] **Stage 1: Internal Testing (1 week)**
  - Test mode only
  - Internal team testing
  - Verify all flows

- [ ] **Stage 2: Beta Testing (2 weeks)**
  - Invite 10-20 beta testers
  - Real test transactions (<$1)
  - Collect feedback

- [ ] **Stage 3: Soft Launch (1 month)**
  - Enable for new users only
  - Monitor closely
  - Quick rollback plan ready

- [ ] **Stage 4: Full Launch**
  - Enable for all users
  - Announce feature
  - Monitor 24/7 for first week

---

## 🔴 BLOCKING ISSUES (MUST FIX BEFORE ENABLE)

1. ❌ **API keys in database** → Move to Edge Function secrets
2. ❌ **No idempotency keys** → Add to all payment RPCs
3. ❌ **Webhooks not idempotent** → Fix `confirm_payment` to handle duplicates
4. ❌ **No webhook signature verification** → Implement in Edge Function
5. ❌ **No Edge Functions** → Create `create-payment-intent` and `payment-webhook`

---

## 🟡 HIGH PRIORITY (Should fix)

6. ⚠️ **Sensitive data in logs** → Sanitize webhook payloads
7. ⚠️ **No rate limiting** → Add per-user limits
8. ⚠️ **No reconciliation** → Create daily check job
9. ⚠️ **No transaction locking** → Add `SELECT FOR UPDATE`
10. ⚠️ **Missing PCI audit** → Complete SAQ-A

---

## 🟢 RECOMMENDED (Nice to have)

11. 📝 **Enhanced monitoring** → Datadog/Sentry integration
12. 📝 **Fraud detection** → Unusual activity alerts
13. 📝 **Multi-currency** → Support USD, EUR (future)
14. 📝 **Subscription billing** → Recurring payments (future)

---

## 📚 References

### Stripe Best Practices
- [Idempotent Requests](https://stripe.com/docs/api/idempotent_requests)
- [Webhook Best Practices](https://stripe.com/docs/webhooks/best-practices)
- [PCI Compliance](https://stripe.com/docs/security/guide)

### YooKassa Documentation
- [Идемпотентность](https://yookassa.ru/developers/payments/idempotence)
- [Вебхуки](https://yookassa.ru/developers/using-api/webhooks)
- [Безопасность](https://yookassa.ru/developers/security)

### PCI DSS
- [PCI SSC](https://www.pcisecuritystandards.org/)
- [SAQ Types](https://www.pcisecuritystandards.org/document_library/)

---

## ⏱️ Estimated Timeline

- **Phase 1 (Security)**: 3-5 days
- **Phase 2 (PCI)**: 1-2 days
- **Phase 3 (Testing)**: 3-4 days
- **Phase 4 (Legal)**: 2-4 weeks (external dependencies)
- **Phase 5 (Monitoring)**: 2-3 days
- **Phase 6 (Edge Functions)**: 4-5 days
- **Phase 7 (Rollout)**: 4-6 weeks

**Total**: ~2-3 months minimum

---

## 🚨 RECOMMENDATION

**DO NOT ENABLE THIS MIGRATION**

**Reasons**:
1. Critical security vulnerabilities (API keys, no idempotency)
2. Missing Edge Function implementation
3. No webhook signature verification
4. Legal/compliance not addressed
5. High financial/reputational risk

**Alternative Approach**:
1. Keep mock payments for MVP launch
2. Fix all blocking issues first
3. Implement Edge Functions
4. Complete legal/compliance
5. Beta test thoroughly
6. Gradual rollout

**Timeline to production-ready**: 2-3 months minimum

---

**Status**: ❌ NOT READY FOR PRODUCTION  
**Risk Level**: 🔴 CRITICAL  
**Recommendation**: Keep `.disabled`, fix issues first
