# 🚨 PAYMENT INTEGRATION - CRITICAL SECURITY NOTICE

## ⚠️ CURRENT STATUS: DEMO-ONLY MODE (REAL PAYMENTS DISABLED)

This file documents the current state of payment integration and **critical safeguards** to prevent accidental enabling of real payments.

---

## 📊 Current Architecture

### Payment Tables (Active):
```
✅ wallets - user balances (mock credits)
✅ payment_methods - saved payment methods (stored, not charged)
✅ payment_transactions - transaction history (completed instantly)
✅ wallet_transactions - wallet operation log
✅ wallet_networks - cafe network wallet configuration
```

### Mock Payment Flow (Active):
1. User initiates top-up via `mock_wallet_topup()` RPC
2. Credits added instantly (no real charge)
3. Transaction logged with `provider='mock'`
4. Commission calculated (for business logic testing)
5. Wallet balance updated immediately

### Real Payment Integration (DISABLED):
```
❌ Migration: 20260202010000_real_payment_integration.sql.disabled
❌ Tables: payment_provider_config, payment_webhook_events (NOT CREATED)
❌ Edge Function: create-payment/index.ts (DEPLOYED BUT NOT USED)
❌ Webhooks: yookassa-webhook, stripe-webhook (NOT CONFIGURED)
```

---

## 🛡️ Security Safeguards

### 1. File System Protection

**Migration File:**
```bash
# Current state (SAFE)
supabase/migrations/20260202010000_real_payment_integration.sql.disabled

# ❌ NEVER rename without full security review
```

**Verification:**
```bash
# Check migration is disabled
ls -1 supabase/migrations/*real_payment*.sql* | grep disabled
```

### 2. Environment Variables (Not Set)

**These MUST NOT be set in production until review:**
```bash
# ❌ DO NOT SET THESE YET
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
YOOKASSA_SHOP_ID=
YOOKASSA_SECRET_KEY=
```

**Current Safe State:**
```bash
# ✅ These are set (safe for mock mode)
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
ENABLE_MOCK_PAYMENTS=true
ENABLE_REAL_PAYMENTS=false
```

### 3. Feature Flag Protection

**In env.production.template:**
```bash
ENABLE_MOCK_PAYMENTS=true
ENABLE_REAL_PAYMENTS=false  # ❌ DO NOT CHANGE WITHOUT APPROVAL
```

### 4. Database State Protection

**These tables DO NOT exist (by design):**
```sql
-- ❌ NOT CREATED (migration disabled)
payment_provider_config
payment_webhook_events
```

**Verification:**
```sql
-- Should return empty or error (GOOD)
SELECT * FROM public.payment_provider_config;
-- ERROR:  relation "public.payment_provider_config" does not exist
```

---

## 🔐 Pre-Production Checklist (MUST complete before enabling)

### Phase 1: Legal & Business (Not Started)
- [ ] Payment provider contracts signed (YooKassa/Stripe)
- [ ] Merchant account verified and approved
- [ ] Commission rates finalized and documented
- [ ] Refund policy defined
- [ ] Terms of Service updated with payment terms
- [ ] Privacy policy updated (PCI DSS compliance)

### Phase 2: Security Review (Not Started)
- [ ] RLS policies audited for all payment tables
- [ ] Edge function security review completed
- [ ] Webhook signature verification tested
- [ ] SQL injection prevention verified
- [ ] Rate limiting configured for payment endpoints
- [ ] Penetration testing completed
- [ ] Security audit by external party

### Phase 3: Technical Implementation (Blocked by Phase 1 & 2)
- [ ] Enable migration (rename `.disabled` → `.sql`)
- [ ] Run migration on staging environment
- [ ] Deploy Edge Functions with test credentials
- [ ] Configure webhooks in provider dashboards
- [ ] Test full payment flow (test cards only)
- [ ] Verify webhook delivery and processing
- [ ] Test refund flow
- [ ] Monitor logs for 48 hours

### Phase 4: Production Rollout (Blocked by Phase 3)
- [ ] Switch to live API keys (NOT test keys)
- [ ] Update webhook URLs to production
- [ ] Enable `ENABLE_REAL_PAYMENTS=true`
- [ ] Test with minimum amounts (10 RUB)
- [ ] Monitor first 100 transactions manually
- [ ] Set up alerting for failures
- [ ] Document rollback procedure

---

## 🚫 What NOT to Do

### ❌ NEVER Do These Without Approval:

1. **Rename migration file**
   ```bash
   # ❌ FORBIDDEN
   mv 20260202010000_real_payment_integration.sql.disabled \
      20260202010000_real_payment_integration.sql
   ```

2. **Set real payment secrets in env**
   ```bash
   # ❌ FORBIDDEN
   supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
   ```

3. **Change feature flag**
   ```bash
   # ❌ FORBIDDEN
   ENABLE_REAL_PAYMENTS=true
   ```

4. **Manually create payment tables**
   ```sql
   -- ❌ FORBIDDEN
   CREATE TABLE public.payment_provider_config ...
   ```

5. **Call real payment Edge Functions**
   ```typescript
   // ❌ FORBIDDEN (without migration)
   supabase.functions.invoke('create-payment', { ... })
   ```

---

## ✅ What IS Safe to Do

### ✅ SAFE Operations:

1. **Use mock payments**
   ```sql
   SELECT public.mock_wallet_topup(
     wallet_id::uuid,
     1000, -- amount in credits
     NULL  -- no real payment method
   );
   ```

2. **Test commission calculation**
   ```sql
   SELECT public.calculate_commission(1000, 'topup', 'citypass');
   ```

3. **View transaction history**
   ```sql
   SELECT * FROM public.payment_transactions
   WHERE user_id = auth.uid();
   ```

4. **Update wallet balances (admin only)**
   ```sql
   -- For testing/demos only
   UPDATE public.wallets
   SET balance_credits = 10000
   WHERE user_id = 'test-user-uuid';
   ```

---

## 📄 Documentation Structure

### Current Payment Docs:
1. **PAYMENT_SECURITY.md** (this file) - Security and status
2. **PAYMENT_SETUP.md** - Provider setup guide (for future)
3. **PAYMENT_INTEGRATION.md** - Technical integration docs
4. **PAYMENT_INTEGRATION_SUMMARY.md** - Architecture overview

### Read Order:
1. **Start here** - PAYMENT_SECURITY.md
2. **When ready to enable** - Check Pre-Production Checklist
3. **For implementation** - PAYMENT_SETUP.md → PAYMENT_INTEGRATION.md

---

## 🔍 Audit Trail

### Security Audits:
- **2026-02-03**: Initial security review completed ✅
  - No secrets in codebase ✅
  - Migration disabled by default ✅
  - RLS policies reviewed ✅
  - Demo-only mode confirmed ✅

### Changes Log:
- **2026-02-03**: Created PAYMENT_SECURITY.md
- **2026-02-03**: Verified `.disabled` status
- **2026-02-03**: Confirmed environment variable safety

---

## 📞 Escalation

### Before Enabling Real Payments:

**Required Approvals:**
1. **Technical Lead** - Security review sign-off
2. **Product Owner** - Business requirements confirmed
3. **Legal/Finance** - Contracts and compliance verified

**Contact:**
- Technical questions: Backend team
- Business questions: Product team
- Security concerns: Security team

---

## ⚡ Emergency Rollback

### If Real Payments Accidentally Enabled:

```bash
# 1. IMMEDIATE: Disable feature flag
supabase secrets set ENABLE_REAL_PAYMENTS=false

# 2. Remove secrets
supabase secrets unset STRIPE_SECRET_KEY
supabase secrets unset YOOKASSA_SECRET_KEY

# 3. Disable migration (if run)
# Create rollback migration:
supabase/migrations/$(date +%Y%m%d%H%M%S)_rollback_real_payments.sql

# 4. Notify:
# - Technical lead
# - Security team
# - Payment provider (pause webhooks)
```

---

## 🎯 Summary

**Current State:** ✅ **SAFE** - Demo-only mode  
**Real Payments:** ❌ **DISABLED** - Multiple safeguards in place  
**Next Action:** Complete Pre-Production Checklist phases 1-4  
**Approval Required:** Yes (Technical + Business + Legal)  

**DO NOT ENABLE REAL PAYMENTS WITHOUT COMPLETING CHECKLIST.**

---

**Last Updated:** 2026-02-03  
**Status:** Demo-Only (Production-Safe)  
**Next Review:** Before pilot launch (TBD)
