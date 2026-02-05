# Wallet Payment Integration - Order Creation

**Date**: 2026-02-05  
**Status**: ✅ COMPLETE  
**Priority**: P0 (Payment flow)

---

## 🎯 What Was Implemented

### Backend (Supabase)

**File**: `supabase/migrations/20260205100000_order_wallet_payment.sql`

#### Changes to `create_order` RPC:

1. **Added `p_wallet_id` parameter** (optional, UUID)
   - Required when `p_payment_method = 'wallet'`
   - Null for card/cash payments

2. **Wallet Validation**
   - Validates wallet exists and belongs to user
   - Calls `validate_wallet_for_order(p_wallet_id, p_cafe_id)` to check compatibility
   - Returns clear error: `"Wallet cannot be used at this cafe..."`

3. **Balance Check**
   - Reads `balance_credits` from wallets table
   - Compares with order total
   - Returns clear error: `"Insufficient funds. Balance: X credits, Required: Y credits"`

4. **Atomic Balance Deduction**
   - Updates `wallets.balance_credits` atomically
   - Creates `payment_transactions` record (type: 'order_payment', status: 'completed')
   - Creates `wallet_transactions` audit record

5. **Enhanced Response**
   - Returns `wallet_balance_after` (new balance after deduction)
   - Returns `transaction_id` (UUID of payment transaction)

6. **Error Messages**
   - `"Wallet ID required for wallet payments"` - Missing wallet_id
   - `"Wallet not found"` - Invalid wallet_id
   - `"Wallet does not belong to you"` - Wrong owner
   - `"Wallet cannot be used at this cafe..."` - Wrong wallet type
   - `"Insufficient funds. Balance: X, Required: Y"` - Not enough credits

### iOS App

#### 1. **OrderService.swift** Updated

**New Error Enum**:
```swift
enum OrderServiceError: LocalizedError {
    case walletIdRequired
    case insufficientFunds(balance: Int, required: Int)
    case invalidWallet
    case walletNotFound
    case orderCreationFailed(message: String)
}
```

**Updated `createOrder` function**:
- Added `walletId: UUID?` parameter
- Validates `walletId` is provided for wallet payments
- Passes `p_wallet_id` to RPC
- Parses error messages from backend
- Maps backend errors to `OrderServiceError` cases

**Updated Response Model**:
```swift
struct CreateOrderResponse: Decodable {
    let walletBalanceAfter: Int?  // ✅ NEW
    let transactionId: UUID?  // ✅ NEW
}
```

#### 2. **CheckoutView.swift** Updated

**Added `realWalletStore` parameter**:
```swift
let realWalletStore: RealWalletStore?  // ✅ NEW
```

**Updated `handleCheckout` function**:
- Gets `walletId` from `realWalletStore.selectedWallet?.id`
- Passes `walletId` to `OrderService.createOrder()`
- Handles `OrderServiceError` with specific error messages
- Refreshes wallets after successful order
- Shows balance after payment in logs

#### 3. **ContentView.swift** Updated

- Passes `realWalletStore` to `CheckoutView`

---

## 🔄 Flow Diagram

### Order Creation with Wallet Payment

```
User taps "Оформить" in CheckoutView
    ↓
Get selected wallet_id from RealWalletStore
    ↓
Call OrderService.createOrder(walletId: walletId)
    ↓
iOS sends RPC: create_order(p_wallet_id: "xxx")
    ↓
Backend validates wallet:
    ├─ Wallet exists? ✅
    ├─ Belongs to user? ✅
    ├─ validate_wallet_for_order? ✅
    └─ Balance >= total? ✅
    ↓
Backend deducts balance:
    ├─ UPDATE wallets SET balance_credits = balance - total
    ├─ INSERT INTO payment_transactions (order_payment)
    └─ INSERT INTO wallet_transactions (audit)
    ↓
Backend creates order:
    └─ INSERT INTO orders_core (wallet_id, payment_status='paid')
    ↓
Returns: order_id, wallet_balance_after, transaction_id
    ↓
iOS refreshes wallets (new balance shown)
    ↓
Navigate to OrderStatusView
```

### Error Handling Flow

```
Backend error: "Insufficient funds. Balance: 100, Required: 500"
    ↓
iOS parses error message
    ↓
Maps to OrderServiceError.insufficientFunds(balance: 100, required: 500)
    ↓
Shows alert: "Insufficient funds. Balance: 100 credits, Required: 500 credits"
    ↓
User can top-up wallet or cancel
```

---

## 📊 Database Changes

### New Column

```sql
ALTER TABLE public.orders_core 
ADD COLUMN wallet_id UUID REFERENCES public.wallets(id);
```

**Purpose**: Store which wallet was used for payment

### New Transactions

**payment_transactions**:
```sql
INSERT INTO payment_transactions (
  user_id, wallet_id, order_id, amount_credits,
  transaction_type = 'order_payment', status = 'completed'
)
```

**wallet_transactions** (audit):
```sql
INSERT INTO wallet_transactions (
  wallet_id, amount = -subtotal, type = 'order_payment',
  balance_before, balance_after, reference_id = transaction_id
)
```

---

## ✅ Testing Checklist

### Backend Testing (SQL)

```sql
-- 1. Test wallet validation
SELECT create_order(
  p_cafe_id := '<cafe-uuid>',
  p_wallet_id := '<wallet-uuid>',
  p_payment_method := 'wallet',
  ...
);

-- 2. Check balance deduction
SELECT balance_credits FROM wallets WHERE id = '<wallet-uuid>';

-- 3. Check transaction created
SELECT * FROM payment_transactions 
WHERE wallet_id = '<wallet-uuid>' 
ORDER BY created_at DESC LIMIT 1;

-- 4. Check audit record
SELECT * FROM wallet_transactions 
WHERE wallet_id = '<wallet-uuid>' 
ORDER BY created_at DESC LIMIT 1;

-- 5. Test insufficient funds
-- (set balance to 10, try to order 500)

-- 6. Test wrong wallet type
-- (use cafe wallet for different cafe)
```

### iOS Testing

**Test Scenarios**:

1. **Happy Path**:
   - [ ] Select CityPass wallet
   - [ ] Add items to cart (total: 500₽)
   - [ ] Wallet balance: 1000₽
   - [ ] Tap "Оформить"
   - [ ] Order created successfully ✅
   - [ ] New balance: 500₽ ✅

2. **Insufficient Funds**:
   - [ ] Wallet balance: 100₽
   - [ ] Cart total: 500₽
   - [ ] Tap "Оформить"
   - [ ] Error: "Insufficient funds. Balance: 100, Required: 500" ✅

3. **Wrong Wallet Type**:
   - [ ] Use Cafe Wallet (bound to Cafe A)
   - [ ] Try to order from Cafe B
   - [ ] Error: "Wallet cannot be used at this cafe..." ✅

4. **No Wallet Selected**:
   - [ ] No selected wallet in RealWalletStore
   - [ ] Tap "Оформить"
   - [ ] Error: "Wallet ID required for wallet payments" ✅

5. **Balance Updates**:
   - [ ] Complete order
   - [ ] Wallet balance refreshed automatically ✅
   - [ ] New balance shown in wallet views ✅

---

## 🔑 Key Implementation Details

### Backend Security

1. **User ID from `auth.uid()`** - Cannot be spoofed
2. **Wallet ownership verified** - `wallet.user_id = auth.uid()`
3. **Atomic balance update** - Single UPDATE statement
4. **Transaction audit trail** - Both payment_transactions and wallet_transactions
5. **Clear error messages** - Easy to parse on client side

### iOS Error Handling

**Error Parsing**:
```swift
// Backend: "Insufficient funds. Balance: 100 credits, Required: 500 credits"
// iOS: OrderServiceError.insufficientFunds(balance: 100, required: 500)

if errorMessage.contains("Insufficient funds") {
    // Extract balance and required from error message
    throw OrderServiceError.insufficientFunds(balance: balance, required: required)
}
```

**User-Friendly Messages**:
- All errors have `localizedDescription`
- Specific errors have structured data (balance, required)
- Generic fallback for unexpected errors

---

## 📝 API Contract

### Request

```typescript
create_order(
  p_cafe_id: UUID,
  p_order_type: 'now' | 'preorder' | 'subscription',
  p_slot_time: timestamp,
  p_customer_name: string,
  p_customer_phone: string,
  p_customer_notes: string | null,
  p_payment_method: 'wallet' | 'card' | 'cash',
  p_wallet_id: UUID | null,  // ✅ NEW (required if payment_method='wallet')
  p_items: jsonb
)
```

### Response (Success)

```json
{
  "order_id": "xxx-xxx-xxx",
  "order_number": "12345",
  "total_credits": 500,
  "status": "new",
  "wallet_balance_after": 500,  // ✅ NEW
  "transaction_id": "yyy-yyy-yyy"  // ✅ NEW
}
```

### Response (Error)

```json
{
  "error": "Insufficient funds. Balance: 100 credits, Required: 500 credits"
}
```

**Possible Errors**:
- `"Wallet ID required for wallet payments"`
- `"Wallet not found"`
- `"Wallet does not belong to you"`
- `"Wallet cannot be used at this cafe. Please use CityPass or create a Cafe Wallet for this cafe."`
- `"Insufficient funds. Balance: X credits, Required: Y credits"`

---

## 🚀 Deployment Steps

### 1. Backend

```bash
cd SubscribeCoffieBackend
supabase db reset  # Apply migration 20260205100000_order_wallet_payment.sql
```

### 2. iOS

```bash
cd SubscribeCoffieClean
# Build & Run (Cmd+R)
```

### 3. Verify

```sql
-- Check migration applied
SELECT * FROM supabase_migrations.schema_migrations 
WHERE version = '20260205100000' 
ORDER BY version DESC;

-- Check create_order function updated
\df+ public.create_order

-- Test wallet payment
SELECT create_order(
  p_cafe_id := '<test-cafe-id>',
  p_wallet_id := '<test-wallet-id>',
  p_payment_method := 'wallet',
  p_order_type := 'now',
  p_slot_time := null,
  p_customer_name := 'Test User',
  p_customer_phone := '+79999999999',
  p_customer_notes := null,
  p_items := '[{"menu_item_id": "<item-id>", "quantity": 1}]'::jsonb
);
```

---

## 📚 Related Files

**Backend**:
- `supabase/migrations/20260205100000_order_wallet_payment.sql` - ✅ NEW
- `supabase/migrations/20260201000002_wallet_types_mock_payments.sql` - validate_wallet_for_order
- `supabase/migrations/20260203000001_rpc_security_hardening_orders.sql` - Original create_order

**iOS**:
- `Helpers/OrderService.swift` - ✅ UPDATED (wallet_id, errors)
- `Views/CheckoutView.swift` - ✅ UPDATED (realWalletStore, error handling)
- `Stores/RealWalletStore.swift` - Wallet management
- `ContentView.swift` - ✅ UPDATED (pass realWalletStore)

---

## ✨ Next Steps

**Phase 1** (✅ DONE):
- [x] Backend: Add wallet payment to create_order
- [x] iOS: Pass wallet_id in OrderService
- [x] iOS: Handle errors in CheckoutView

**Phase 2** (TODO):
- [ ] Add bonus/cashback support in order payment
- [ ] Add refund support (restore wallet balance)
- [ ] Add order history with wallet transactions

**Phase 3** (Future):
- [ ] Multiple wallets per order (split payment)
- [ ] Wallet-to-wallet transfers
- [ ] Scheduled payments

---

**Status**: ✅ COMPLETE  
**Date**: 2026-02-05  
**Ready for**: Testing & Production Deployment
