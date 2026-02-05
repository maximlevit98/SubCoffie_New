# ⚠️ DEPRECATED: Demo Wallet Stores

## Status: DEPRECATED (2026-02-05)

These demo wallet stores have been replaced by `RealWalletStore` which loads wallets from Supabase.

### Deprecated Files:
1. `Models/WalletStore.swift` - Demo CityPass wallet (UserDefaults)
2. `Stores/CafeWalletStore.swift` - Demo Cafe wallet (UserDefaults)

### Replacement:
- **`Stores/RealWalletStore.swift`** - Manages real wallets from Supabase using `WalletService`

### Migration:
- ✅ `ContentView` updated to use `RealWalletStore`
- ✅ `WalletTopUpView` updated to work with real `Wallet` model
- ✅ AppStorage used for wallet selection persistence (`sc_selected_wallet_id`, `sc_selected_wallet_type`)
- ✅ Wallet loading on auth and bootstrap
- ✅ Auto-refresh after top-up

### Old Demo Stores (Keep for backward compat):
These are still instantiated in `ContentView` but marked as deprecated:
```swift
@StateObject private var wallet = WalletStore() // ⚠️ DEPRECATED
@StateObject private var cafeWallet = CafeWalletStore() // ⚠️ DEPRECATED
```

They are still used by:
- `CartView` (for bonus calculations) - TODO: migrate to real wallets
- `ProfileView` (for display) - TODO: migrate to real wallets
- Legacy top-up flows - TODO: remove

### TODO: Complete Migration
- [ ] Update `CartView` to use `RealWalletStore` for bonus calculations
- [ ] Update `ProfileView` to display real wallets
- [ ] Update `CheckoutView` to use real wallets for payment
- [ ] Remove legacy `WalletStore` and `CafeWalletStore` completely

### How Real Wallets Work:
1. User logs in → `RealWalletStore.loadWallets()` called
2. Wallets loaded from Supabase via `WalletService.getUserWallets()`
3. User selects wallet → saved to AppStorage (`selected_wallet_id`)
4. User top-ups → `WalletService.mockWalletTopup()` → refreshes wallets
5. Selected wallet persists between sessions via AppStorage

### Key Differences:
| Feature | Demo Stores | RealWalletStore |
|---------|-------------|-----------------|
| **Storage** | UserDefaults | Supabase |
| **Data** | Mock | Real |
| **Multi-wallet** | No | Yes (CityPass + Cafe wallets) |
| **Persistence** | Local only | Server + local selection |
| **Sync** | Manual | Auto-refresh |

### Testing:
```swift
// OLD (demo):
wallet.topUpDemo(credits: 500)

// NEW (real):
let newWallet = try await realWalletStore.createCityPassWallet()
realWalletStore.selectWallet(newWallet)
```

---

**Date**: 2026-02-05  
**Status**: ✅ RealWalletStore integrated, demo stores kept for backward compat  
**Next**: Complete migration of CartView, ProfileView, CheckoutView
