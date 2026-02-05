# Transaction History - Quick Reference

## 🚀 Quick Start

### View Transaction History

1. Open app and log in
2. Navigate to **Profile** (bottom tab)
3. Tap **"История транзакций"**
4. View all wallet transactions

## 📱 Features at a Glance

### Transaction Types

| Type | Icon | Color | Display |
|------|------|-------|---------|
| Top-up | ↓ | Green | +500 ₽ |
| Order Payment | 🛒 | Blue | -350 ₽ |
| Refund | ↩️ | Orange | +350 ₽ |

### Transaction Status

| Status | Badge | Color |
|--------|-------|-------|
| Completed | Завершено | Green ✅ |
| Pending | В обработке | Orange ⏳ |
| Failed | Ошибка | Red ❌ |

## 🎯 User Actions

### Pull-to-Refresh
```
Swipe down → Shows loading → Refreshes transactions
```

### Load More
```
Scroll to bottom → Tap "Загрузить ещё" → Loads next 20 transactions
```

### Transaction Details
Each transaction shows:
- **Type**: Пополнение / Оплата заказа / Возврат
- **Date**: Сегодня, 14:30 / Вчера, 09:15 / 15 янв, 18:45
- **Status**: Badge with color
- **Amount**: +/- amount in rubles
- **Commission**: If applicable

## 🧪 Testing Scenarios

### Test 1: View Transactions
```
✅ Navigate to Profile
✅ Tap "История транзакций"
✅ Verify transactions are displayed
✅ Verify wallet header shows correct balance
```

### Test 2: Empty State
```
✅ Select wallet with no transactions
✅ Verify empty state message appears
✅ Verify icon and description are shown
```

### Test 3: Transaction Display
```
✅ Verify top-ups show green icon and + amount
✅ Verify order payments show blue icon and - amount
✅ Verify refunds show orange icon and + amount
✅ Verify status badges are color-coded
✅ Verify dates are formatted correctly
```

### Test 4: Pagination
```
✅ Scroll to bottom of list
✅ Tap "Загрузить ещё"
✅ Verify next 20 transactions load
✅ Verify loading indicator appears
```

### Test 5: Pull-to-Refresh
```
✅ Swipe down on transaction list
✅ Verify refresh indicator appears
✅ Verify transactions reload
```

## 🔧 Technical References

### WalletService Method
```swift
await WalletService().getUserTransactionHistory(
    userId: userId,
    limit: 20,
    offset: 0
)
```

### Navigate to Transaction History
```swift
// From ProfileView
Button("История транзакций") {
    showTransactionHistory = true
}
.sheet(isPresented: $showTransactionHistory) {
    if let selectedWallet = realWalletStore.selectedWallet {
        TransactionHistoryView(wallet: selectedWallet)
    }
}
```

## 📊 Data Model

```swift
struct PaymentTransaction {
    let id: UUID
    let amountCredits: Int
    let commissionCredits: Int
    let transactionType: String  // "topup", "order_payment", "refund"
    let status: String            // "completed", "pending", "failed"
    let createdAt: Date
    
    var displayType: String       // Localized display name
    var displayStatus: String     // Localized status
}
```

## 🎨 UI Components

### TransactionHistoryView
- Main view for transaction history
- Shows wallet header with balance
- Lists all transactions with pagination
- Supports pull-to-refresh

### TransactionRowView
- Individual transaction display
- Shows icon, type, date, status, amount

## 🔍 Troubleshooting

### No transactions showing
- ✅ Check if wallet has any transactions
- ✅ Verify user is authenticated
- ✅ Check network connection
- ✅ Pull-to-refresh to reload

### Transactions not loading
- ✅ Check console for error messages
- ✅ Verify RPC function `get_user_transaction_history` exists
- ✅ Check Supabase connection

### Wrong wallet transactions
- ✅ Verify correct wallet is selected
- ✅ Check wallet ID in header matches

## 📁 Files

### iOS App
- `Views/TransactionHistoryView.swift` - Main view
- `Views/ProfileView.swift` - Profile with transaction link
- `Helpers/WalletService.swift` - Service methods
- `Models/WalletModels.swift` - Data models

### Backend
- `supabase/migrations/20260123150000_wallet_transactions.sql` - Transaction schema
- RPC: `get_user_transaction_history` - Fetch transactions

## 📚 Related Guides

- [Transaction History Implementation](TRANSACTION_HISTORY_IMPLEMENTATION.md) - Full documentation
- [Wallet Integration Summary](../SubscribeCoffieClean/WALLET_INTEGRATION_SUMMARY.md) - Wallet setup
- [Order Wallet Payment](ORDER_WALLET_PAYMENT_IMPLEMENTATION.md) - Payment flow

---

**Quick Tips:**
- 🔄 Pull-to-refresh to see latest transactions
- 📄 Load more for older transactions
- 🎨 Status badges are color-coded for quick scanning
- 📅 Dates show "Today" or "Yesterday" for recent transactions

*Last updated: 2026-02-05*
