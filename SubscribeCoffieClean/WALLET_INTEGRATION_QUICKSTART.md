# Real Wallet Integration - Quick Start

**Date**: 2026-02-05  
**Status**: ✅ Ready to test

---

## 🚀 Quick Start Testing

### 1. Build & Run (30 seconds)
```bash
cd SubscribeCoffieClean
open SubscribeCoffieClean.xcodeproj

# Build for simulator (Cmd+B)
# Run (Cmd+R)
```

### 2. Test Scenarios (5 minutes)

#### Scenario A: New User (First Time)
```
1. Launch app
2. Login with test user or register
3. Should see "Wallet Choice" screen
4. Tap "Create CityPass"
   → Creates wallet in Supabase
   → Shows top-up screen
5. Top-up 500₽
   → Calls mock_wallet_topup RPC
   → Balance updates
6. Proceed to map → Select cafe
7. Kill app → Relaunch
   → Should restore to last cafe ✅
```

#### Scenario B: Create Cafe Wallet
```
1. From map/cafe → Tap wallet icon (top-right)
2. Tap "Create Cafe Wallet"
3. Select a cafe from list
   → Creates cafe_wallet in Supabase
   → Bound to that cafe
4. Top-up amount
5. Kill app → Relaunch
   → Should go directly to bound cafe ✅
```

#### Scenario C: Wallet Persistence
```
1. Login → Wallets loaded
2. Select CityPass
3. Kill app (swipe up in app switcher)
4. Relaunch
   → CityPass still selected ✅
   → AppStorage: sc_selected_wallet_id preserved
```

---

## 🔍 Debugging

### Check Wallet Loading
```swift
// In ContentView bootstrap():
await realWalletStore.loadWallets()
print("✅ Loaded \(realWalletStore.wallets.count) wallets")
print("Selected: \(realWalletStore.selectedWallet?.displayTitle ?? "none")")
```

### Check AppStorage
```swift
// In RealWalletStore:
print("💾 AppStorage wallet_id: \(selectedWalletId)")
print("💾 AppStorage wallet_type: \(selectedWalletType)")
```

### Check RPC Calls
```swift
// In WalletService:
print("📡 Calling get_user_wallets for user: \(userId)")
print("📡 Response: \(wallets.count) wallets")
```

---

## ✅ Expected Behavior

### On First Launch:
1. User logs in
2. `realWalletStore.loadWallets()` called
3. Returns empty array (no wallets yet)
4. `determineStartScreen()` returns `.walletChoice`
5. User creates wallet → Success

### On Second Launch:
1. User logs in
2. `realWalletStore.loadWallets()` called
3. Returns 1+ wallets
4. `restoreSelectedWallet()` finds saved ID in AppStorage
5. Wallet auto-selected
6. `determineStartScreen()` returns `.cafe` or `.map`

### After Top-Up:
1. User tops up 500₽
2. `performTopUp()` calls `mock_wallet_topup` RPC
3. Success → `onTopUpSuccess()` callback
4. `realWalletStore.refreshWallets()` called
5. Balance updated immediately

---

## 🐛 Common Issues

### Issue: "Wallets not loading"
**Cause**: User not authenticated or RPCs not available

**Fix**:
```swift
// Check auth
guard let userId = authService.userId else {
    print("❌ User not authenticated")
    return
}

// Check RPC
do {
    let wallets = try await walletService.getUserWallets(userId: userId)
    print("✅ RPC works: \(wallets.count) wallets")
} catch {
    print("❌ RPC failed: \(error)")
}
```

### Issue: "Selected wallet not persisting"
**Cause**: AppStorage keys not saving

**Fix**:
```swift
// Check if keys are saved
UserDefaults.standard.string(forKey: "sc_selected_wallet_id") // Should not be empty
UserDefaults.standard.string(forKey: "sc_selected_wallet_type") // Should be "citypass" or "cafe_wallet"
```

### Issue: "Balance not updating after top-up"
**Cause**: Callback not called or refreshWallets not working

**Fix**:
```swift
// Ensure callback is passed
WalletTopUpView(wallet: wallet, onTopUpSuccess: {
    Task {
        print("🔄 Refreshing wallets...")
        await realWalletStore.refreshWallets()
        print("✅ Wallets refreshed")
    }
})
```

---

## 📊 Test Checklist

- [ ] First launch → walletChoice screen shown
- [ ] Create CityPass → wallet created in Supabase
- [ ] Top-up → balance updates
- [ ] Kill app → wallet selection persists
- [ ] Create Cafe Wallet → bound to cafe
- [ ] Relaunch → auto-nav to bound cafe
- [ ] Logout → wallet selection cleared
- [ ] Login again → wallets reloaded

---

## 🔧 Backend Verification

### Check Wallets in Supabase:
```sql
-- Check user wallets
SELECT id, user_id, wallet_type, balance_credits, cafe_id
FROM public.wallets
WHERE user_id = '<user-uuid>'
ORDER BY created_at DESC;

-- Check wallet transactions
SELECT wallet_id, amount, type, balance_after
FROM public.wallet_transactions
WHERE wallet_id = '<wallet-uuid>'
ORDER BY created_at DESC;
```

### Test RPCs Directly:
```sql
-- Get user wallets
SELECT get_user_wallets('<user-uuid>');

-- Create CityPass
SELECT create_citypass_wallet('<user-uuid>');

-- Mock top-up
SELECT mock_wallet_topup('<wallet-uuid>', 500, NULL);
```

---

## 📝 Summary

**What to Test**:
1. ✅ Wallet creation (CityPass & Cafe)
2. ✅ Wallet loading from Supabase
3. ✅ Wallet selection persistence (AppStorage)
4. ✅ Top-up flow with auto-refresh
5. ✅ Navigation based on wallet type

**Expected Results**:
- No crashes
- Wallets load on every app launch
- Selection persists across app restarts
- Balance updates immediately after top-up

**If All Tests Pass**: Integration complete! 🎉

---

**Next**: Test in simulator, then proceed to CartView/ProfileView/CheckoutView migration
