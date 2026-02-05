# Real Payment Integration - Quick Reference

**Status**: ❌ NOT READY FOR PRODUCTION  
**Timeline**: 2-3 months  
**Risk**: 🔴 CRITICAL

---

## 🚨 TL;DR

**DO NOT enable `20260202010000_real_payment_integration.sql.disabled`**

**Critical Issues**:
1. ❌ API keys stored in database (PCI violation)
2. ❌ No idempotency (duplicate charges possible)
3. ❌ Webhooks not idempotent (duplicate credits)
4. ❌ No webhook signature verification (security breach)
5. ❌ No Edge Functions (everything in DB is insecure)

**Safe Alternative**: Keep mock payments enabled (current state)

---

## ✅ What's Already Safe

### Idempotency Migration (SAFE TO APPLY)
```bash
# This is safe even without enabling real payments
✅ 20260205000006_add_payment_idempotency.sql
```

**What it adds**:
- `idempotency_key` column to `payment_transactions`
- Rate limiting (10 payments/hour)
- Updated `mock_wallet_topup` with idempotency support

**Apply it**:
```bash
cd SubscribeCoffieBackend
supabase db reset  # Applies all migrations including new one
```

---

## 🔧 How to Use Idempotency (Even with Mock Payments)

### Client-Side (iOS)
```swift
// WalletService.swift

func topUpWallet(walletId: UUID, amount: Int) async throws -> TopUpResponse {
    // ✅ Generate idempotency key
    let userId = try await AuthService.shared.currentUserId()
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let uuid = UUID().uuidString
    let idempotencyKey = "\(userId)_\(timestamp)_\(uuid)"
    
    // ✅ Call RPC with idempotency key
    let response: TopUpResponse = try await supabase
        .rpc("mock_wallet_topup",
            params: [
                "p_wallet_id": walletId.uuidString,
                "p_amount": amount,
                "p_idempotency_key": idempotencyKey
            ])
        .execute()
        .value
    
    return response
}
```

**Benefits**:
- Network retry = same result (no duplicate charges)
- User taps "Pay" twice = same result
- App crash during payment = can retry safely

---

## 📋 Before Enabling Real Payments

### Phase 1: Security (BLOCKING)
- [ ] Create Edge Functions (`create-payment-intent`, `payment-webhook`)
- [ ] Move API keys from DB to Edge Function secrets
- [ ] Implement webhook signature verification
- [ ] Make `confirm_payment` idempotent (return success if already done)
- [ ] Add `SELECT FOR UPDATE` locking in payment RPCs

### Phase 2: Testing (BLOCKING)
- [ ] Test idempotency: same key = same transaction
- [ ] Test concurrency: 2 webhooks at once = only 1 processes
- [ ] Test Stripe test mode end-to-end
- [ ] Test webhook retry scenarios

### Phase 3: Legal (BLOCKING)
- [ ] Sign Stripe contract
- [ ] Update Terms of Service (payment terms, refunds)
- [ ] Update Privacy Policy (payment data processing)
- [ ] Verify PCI DSS compliance (likely SAQ-A with Stripe SDK)

### Phase 4: Operations
- [ ] Set up monitoring/alerts
- [ ] Create daily reconciliation job
- [ ] Document customer support procedures

---

## 📊 Estimated Timeline

| Phase | Duration | Critical Path |
|-------|----------|---------------|
| Security hardening | 5 days | ✅ BLOCKING |
| Edge Functions | 5 days | ✅ BLOCKING |
| Testing | 4 days | ✅ BLOCKING |
| Legal/contracts | 2-4 weeks | ✅ BLOCKING |
| Beta testing | 2 weeks | ⚠️ Recommended |
| Soft launch | 4 weeks | ⚠️ Recommended |
| **TOTAL** | **2-3 months** | |

---

## 🎯 Recommended Approach

### Option A: MVP Launch with Mock Payments (RECOMMENDED)
1. ✅ Keep mock payments enabled
2. ✅ Apply idempotency migration
3. ✅ Launch MVP
4. ⏳ Work on real payments in parallel
5. ⏳ Switch to real payments in v1.1

**Pros**:
- Launch faster
- Zero financial risk
- Can test UX/demand first

**Cons**:
- No real revenue yet
- Can't charge real money

### Option B: Delay MVP, Enable Real Payments First
1. ⏳ Fix all blocking issues (2-3 months)
2. ⏳ Complete legal/compliance
3. ⏳ Beta test thoroughly
4. ✅ Launch MVP with real payments

**Pros**:
- Revenue from day 1

**Cons**:
- 2-3 month delay
- Higher risk

---

## 🔐 Security Checklist (Quick)

```bash
# ❌ NEVER do this:
STRIPE_SECRET_KEY="sk_test_..." # In database or .env in git

# ✅ Always do this:
supabase secrets set STRIPE_SECRET_KEY=sk_test_...  # Edge Function secrets
```

**Golden Rules**:
1. ✅ API keys in Edge Function secrets (NEVER in database)
2. ✅ Verify webhook signatures (Stripe SDK)
3. ✅ Use idempotency keys (client-generated)
4. ✅ Make RPCs idempotent (return success if already done)
5. ✅ Store minimal data (no card numbers, CVV, etc.)
6. ✅ Rate limit (10/hour per user)
7. ✅ Daily reconciliation (DB vs provider dashboard)

---

## 📞 Next Steps

### For Product Owner
1. **Decide**: MVP with mock payments OR delay for real payments?
2. **If real payments**: Allocate 2-3 months + budget for contracts
3. **If mock payments**: Launch MVP, enable real payments in v1.1

### For Tech Lead
1. ✅ **Apply idempotency migration now** (safe, improves mock payments)
2. ❌ **Keep real_payment_integration.sql.disabled**
3. 📖 **Review full checklist**: `REAL_PAYMENT_INTEGRATION_CHECKLIST.md`
4. 🛠️ **If proceeding**: Start with Edge Functions implementation

### For Legal/Finance
1. Review payment provider contracts (Stripe, YooKassa)
2. Update Terms of Service (refund policy, fees)
3. Review PCI DSS requirements
4. Set up business entity for payment processing

---

## 📚 Documentation

- **Full Checklist**: `REAL_PAYMENT_INTEGRATION_CHECKLIST.md` (detailed, 7 phases)
- **Idempotency Migration**: `supabase/migrations/20260205000006_add_payment_idempotency.sql`
- **Edge Function Examples**:
  - `supabase/functions/create-payment-intent/index.ts`
  - `supabase/functions/payment-webhook/index.ts`
- **Stripe Docs**: https://stripe.com/docs/webhooks/best-practices
- **YooKassa Docs**: https://yookassa.ru/developers/payments/idempotence

---

## ❓ FAQ

**Q: Can I test real payments in development?**  
A: Yes, use Stripe test mode (`sk_test_...`). No real money, but full flow.

**Q: How do I know if payment is idempotent?**  
A: If you call RPC twice with same `idempotency_key`, you get same `transaction_id` back.

**Q: What if webhook arrives twice?**  
A: After fixing blocking issues, both will succeed (idempotent). Currently, would cause duplicate credits (NOT SAFE).

**Q: Can I enable for just one user?**  
A: Not with current migration. Would need feature flag logic.

**Q: How much does Stripe charge?**  
A: ~2.9% + 30¢ per transaction. YooKassa: ~2-3% (Russia).

**Q: Do I need PCI certification?**  
A: With Stripe SDK (client-side), likely just SAQ-A (self-assessment, not full audit).

---

**Last Updated**: 2026-02-05  
**Reviewed By**: AI Agent (Prompt 7)  
**Status**: ⚠️ DRAFT - Pending Product/Legal Review
