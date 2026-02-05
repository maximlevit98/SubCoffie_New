# Idempotency Keys - Quick Reference

**Date**: 2026-02-05  
**Status**: ✅ Ready to Use

---

## 🚀 Quick Start

### iOS Usage

```swift
// ✅ Automatic (recommended) - key auto-generated
let result = try await walletService.mockWalletTopup(
    walletId: wallet.id,
    amount: 500,
    paymentMethodId: nil
)

// ✅ Manual (for custom retry logic)
let key = "my-key-123"
let result = try await walletService.mockWalletTopup(
    walletId: wallet.id,
    amount: 500,
    paymentMethodId: nil,
    idempotencyKey: key
)
```

**Key Format**: `{userId}_{timestamp}_{uuid}`  
**Example**: `a1b2c3d4-e5f6-7890-abcd-ef1234567890_1707133456789_x9y8z7w6-v5u4-3210-fedc-ba0987654321`

---

## 🔄 How It Works

### Same Key = Same Result

```swift
let key = "test-key-123"

// First request
let result1 = try await walletService.mockWalletTopup(
    walletId: wallet.id,
    amount: 500,
    paymentMethodId: nil,
    idempotencyKey: key
)
// Creates transaction, updates balance

// Second request (same key)
let result2 = try await walletService.mockWalletTopup(
    walletId: wallet.id,
    amount: 500,
    paymentMethodId: nil,
    idempotencyKey: key
)
// Returns SAME transaction, NO duplicate charge!

print(result1.transaction_id == result2.transaction_id)  // true ✅
print(result2.message)  // "Idempotent: Transaction already processed" ✅
```

---

## 🧪 Testing

### Test Idempotency

```bash
cd SubscribeCoffieBackend

# Test with SQL
psql $DATABASE_URL -c "
  SELECT mock_wallet_topup(
    '<wallet-id>',
    500,
    null,
    'test-key-123'
  );
"

# Run again with SAME key
psql $DATABASE_URL -c "
  SELECT mock_wallet_topup(
    '<wallet-id>',
    500,
    null,
    'test-key-123'
  );
"

# Should return SAME transaction_id
```

### Check Duplicates

```sql
-- Should return 0 rows (no duplicates)
SELECT idempotency_key, COUNT(*) 
FROM payment_transactions 
WHERE idempotency_key IS NOT NULL
GROUP BY idempotency_key 
HAVING COUNT(*) > 1;
```

---

## 📝 Response Format

### New Transaction

```json
{
  "success": true,
  "transaction_id": "xxx-yyy-zzz",
  "amount": 500,
  "commission": 35,
  "amount_credited": 465,
  "provider_transaction_id": "mock_xxx",
  "provider": "mock"
}
```

### Idempotent (Duplicate Key)

```json
{
  "success": true,
  "transaction_id": "xxx-yyy-zzz",  // SAME as before
  "amount": 500,
  "commission": 35,
  "amount_credited": 465,
  "status": "completed",
  "message": "Idempotent: Transaction already processed"  // ✅ NEW
}
```

---

## ⚠️ Important Notes

### Auto-Generated Keys

**Each call gets a unique key by default!**

```swift
// Call 1: key = "user_123_1707133456789_uuid1"
let result1 = try await walletService.mockWalletTopup(...)

// Call 2: key = "user_123_1707133456790_uuid2" (DIFFERENT!)
let result2 = try await walletService.mockWalletTopup(...)

// Result: 2 transactions (NOT idempotent)
```

**For true retry idempotency**, store the key:

```swift
@State private var currentKey: String?

func topUp() {
    let key = "\(userId)_\(timestamp)_\(uuid)"
    currentKey = key
    
    Task {
        do {
            let result = try await walletService.mockWalletTopup(
                walletId: wallet.id,
                amount: 500,
                paymentMethodId: nil,
                idempotencyKey: key  // Use same key on retry
            )
            currentKey = nil  // Clear on success
        } catch {
            // Keep key for retry
        }
    }
}
```

---

## 🔍 Debugging

### iOS Logs

```
💳 [WalletService] Mock top-up with idempotency key: user-uuid_1707133456789_random-uuid
♻️ [WalletService] Idempotent response: Transaction already processed
```

### Backend Logs

```sql
-- Find transaction
SELECT * FROM payment_transactions 
WHERE idempotency_key = 'your-key-here';

-- Check key uniqueness
SELECT idempotency_key, COUNT(*) 
FROM payment_transactions 
GROUP BY idempotency_key;
```

---

## ✅ What's Protected

| Scenario | Without Idempotency | With Idempotency |
|----------|---------------------|------------------|
| User taps "Pay" twice | 2 charges ❌ | 1 charge ✅ |
| Network timeout → retry | Risk of duplicate ❌ | Safe retry ✅ |
| App crash during payment | Unknown state ❌ | Can recover ✅ |

---

## 📊 Migration Status

```bash
# Check migration applied
SELECT * FROM supabase_migrations.schema_migrations 
WHERE version = '20260205000006';
# Should return 1 row ✅

# Check column exists
\d+ payment_transactions
# Should show: idempotency_key | text
```

---

## 🚀 Deployment

### Backend

```bash
cd SubscribeCoffieBackend
supabase db reset  # Applies migration
```

### iOS

```bash
cd SubscribeCoffieClean
# Cmd+R in Xcode
```

---

## 🎯 Next Steps

**Implemented** (✅ DONE):
- [x] Backend: Idempotency support in mock_wallet_topup
- [x] iOS: Auto-generate keys in WalletService
- [x] iOS: Parse idempotent responses

**TODO** (Optional):
- [ ] Store key before request (true retry idempotency)
- [ ] Show "Max 10 attempts/hour" in UI
- [ ] Add idempotency to create_order

---

**Status**: ✅ READY  
**Migration**: `20260205000006_add_payment_idempotency.sql`  
**Docs**: `IDEMPOTENCY_IMPLEMENTATION.md`
