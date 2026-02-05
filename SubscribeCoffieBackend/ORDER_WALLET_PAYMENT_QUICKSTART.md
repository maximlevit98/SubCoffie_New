# Order Wallet Payment - Quick Reference

**Date**: 2026-02-05  
**Status**: ✅ Ready to Test

---

## 🚀 Quick Start

### Backend Deployment

```bash
cd SubscribeCoffieBackend
supabase db reset
```

**Migration Applied**: `20260205100000_order_wallet_payment.sql`

### iOS Build

```bash
cd SubscribeCoffieClean
# Cmd+R in Xcode
```

---

## 📝 API Usage

### iOS Code Example

```swift
// Get selected wallet
guard let walletId = realWalletStore.selectedWallet?.id else {
    throw OrderServiceError.walletIdRequired
}

// Create order with wallet payment
let result = try await OrderService.shared.createOrder(
    cafeId: cafe.id,
    orderType: "now",
    customerName: "John Doe",
    customerPhone: "+79991234567",
    customerNotes: nil,
    paymentMethod: "wallet",
    walletId: walletId,  // ✅ Required for wallet payments
    items: items
)

print("Order ID: \(result.orderId)")
print("Balance after: \(result.walletBalanceAfter ?? 0) credits")
```

### Backend RPC

```sql
SELECT create_order(
  p_cafe_id := 'xxx-xxx-xxx',
  p_wallet_id := 'yyy-yyy-yyy',  -- ✅ NEW
  p_payment_method := 'wallet',
  p_order_type := 'now',
  p_slot_time := null,
  p_customer_name := 'Test User',
  p_customer_phone := '+79999999999',
  p_customer_notes := null,
  p_items := '[{"menu_item_id": "zzz-zzz-zzz", "quantity": 2}]'::jsonb
);
```

**Response**:
```json
{
  "order_id": "xxx",
  "order_number": "12345",
  "total_credits": 500,
  "status": "new",
  "wallet_balance_after": 1500,  // ✅ NEW
  "transaction_id": "yyy"  // ✅ NEW
}
```

---

## ⚠️ Error Messages

| Error Message | Meaning | Solution |
|---------------|---------|----------|
| `"Wallet ID required for wallet payments"` | No wallet_id provided | Pass wallet_id parameter |
| `"Wallet not found"` | Invalid wallet_id | Use valid wallet from user's wallets |
| `"Wallet does not belong to you"` | Wrong owner | Use user's own wallet |
| `"Wallet cannot be used at this cafe..."` | Wrong wallet type | Use CityPass or create Cafe Wallet |
| `"Insufficient funds. Balance: X, Required: Y"` | Not enough credits | Top-up wallet first |

---

## 🧪 Test Scenarios

### 1. Happy Path

```
Wallet balance: 2000₽
Order total: 500₽
Result: Order created ✅
New balance: 1500₽ ✅
```

### 2. Insufficient Funds

```
Wallet balance: 100₽
Order total: 500₽
Result: Error ❌
Message: "Insufficient funds. Balance: 100, Required: 500"
```

### 3. Wrong Wallet Type

```
Wallet: Cafe Wallet (Cafe A)
Order: Cafe B
Result: Error ❌
Message: "Wallet cannot be used at this cafe..."
```

### 4. Success with Balance Update

```swift
// Before order
realWalletStore.selectedWallet?.balanceCredits // 2000

// Create order (500₽)
let result = try await OrderService.createOrder(...)

// After order
await realWalletStore.refreshWallets()
realWalletStore.selectedWallet?.balanceCredits // 1500 ✅
```

---

## 🔍 Debugging

### Check Wallet Balance

```sql
SELECT id, wallet_type, balance_credits 
FROM wallets 
WHERE user_id = '<user-id>';
```

### Check Transaction

```sql
SELECT * FROM payment_transactions 
WHERE order_id = '<order-id>';
```

### Check Audit Trail

```sql
SELECT * FROM wallet_transactions 
WHERE wallet_id = '<wallet-id>' 
ORDER BY created_at DESC 
LIMIT 5;
```

### iOS Logs

```
📦 [OrderService] Creating order for cafe xxx
💳 [CheckoutView] Using wallet: yyy
✅ [CheckoutView] Order created successfully
💰 [CheckoutView] Wallet balance after: 1500 credits
```

---

## 📊 Database Schema

### orders_core (NEW COLUMN)

```sql
wallet_id UUID REFERENCES wallets(id)  -- ✅ NEW
```

### payment_transactions (NEW RECORD)

```sql
transaction_type = 'order_payment'
status = 'completed'
wallet_id = '<wallet-id>'
order_id = '<order-id>'
amount_credits = 500
commission_credits = 0
```

### wallet_transactions (AUDIT)

```sql
type = 'order_payment'
amount = -500  -- Negative for deduction
balance_before = 2000
balance_after = 1500
reference_id = '<transaction-id>'
```

---

## 🎯 Key Changes

### Backend

✅ `create_order` accepts `p_wallet_id`  
✅ Validates wallet with `validate_wallet_for_order`  
✅ Checks balance before order  
✅ Deducts balance atomically  
✅ Creates payment transaction  
✅ Returns `wallet_balance_after`  

### iOS

✅ `OrderService` passes `walletId`  
✅ `OrderServiceError` enum for errors  
✅ `CheckoutView` uses `RealWalletStore`  
✅ Auto-refreshes wallet after order  
✅ User-friendly error messages  

---

## 🚀 Production Checklist

- [ ] Migration applied (`supabase db reset`)
- [ ] iOS app updated (OrderService + CheckoutView)
- [ ] Test happy path (order with sufficient balance)
- [ ] Test insufficient funds error
- [ ] Test wrong wallet type error
- [ ] Test balance updates after order
- [ ] Verify transaction records created
- [ ] Verify audit trail (wallet_transactions)

---

**Status**: ✅ COMPLETE  
**Next**: Test in simulator and verify end-to-end flow
