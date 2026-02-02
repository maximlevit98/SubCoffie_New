# iOS Manual Test Checklist

## Preparation
- [ ] Supabase running: `supabase status`
- [ ] iOS Simulator running
- [ ] App installed and launched
- [ ] Check Xcode Console logs

---

## Test 3.1: Real-time Order Updates

### Test 3.1.1: Подписка на заказы (компиляция)
**File**: `ActiveOrdersView.swift`

Steps:
- [ ] Открыть проект в Xcode
- [ ] Найти `ActiveOrdersView.swift`
- [ ] Проверить что файл существует
- [ ] Проверить что импортирован `RealtimeOrderService`
- [ ] Проверить наличие `@StateObject private var realtimeService`
- [ ] Проверить наличие `.task { await realtimeService.subscribeToOrders() }`

**Expected**: Файлы существуют, код компилируется без ошибок.

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

### Test 3.1.2: Real-time обновление статуса (интеграция)
**Setup Required**:
- iOS: Откройте `ActiveOrdersView` (если реализован в навигации)
- Admin: Откройте `/admin/orders/{id}`
- Нужен активный заказ

Steps:
- [ ] В iOS найти экран с активными заказами (если есть)
- [ ] В Xcode Console проверить логи:
  ```
  📡 [Realtime] Subscribing to orders for phone: ...
  ✅ [Realtime] Connected to orders channel
  ```
- [ ] В Admin Panel изменить статус заказа
- [ ] В Xcode Console проверить логи:
  ```
  🔄 [Realtime] Order UPDATE event received
  📦 [Realtime] Order {id} status changed to {status}
  ```
- [ ] Проверить что в iOS UI обновился (если view добавлен в навигацию)

**Expected**: Real-time обновления приходят, логи показывают подключение и события.

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A (view not integrated)
**Notes**: _______________________________________________

---

## Test 3.2: Wallet Synchronization

### Test 3.2.1: Синхронизация кошелька (компиляция)
**File**: `WalletSyncService.swift`

Steps:
- [ ] Открыть `WalletSyncService.swift`
- [ ] Проверить что файл существует
- [ ] Проверить наличие метода `syncWallet(userId:)`
- [ ] Проверить наличие метода `topUp(userId:amount:)`
- [ ] Проверить наличие метода `getTransactions(userId:limit:)`
- [ ] Проверить `@Published` properties: `balance`, `bonusBalance`, `lifetimeTopup`

**Expected**: Файл существует, API корректное, компилируется.

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

### Test 3.2.2: Загрузка баланса (логи)
**File**: `WalletHistoryView.swift`

Steps:
- [ ] Открыть `WalletHistoryView.swift`
- [ ] Проверить наличие `@StateObject private var syncService`
- [ ] В Xcode Console проверить логи после запуска:
  ```
  🔄 [Wallet Sync] Starting sync for user: ...
  ✅ [Wallet Sync] Success: balance=..., bonus=...
  ```

**Expected**: Логи показывают успешную синхронизацию.

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A (view not integrated)
**Notes**: _______________________________________________

---

### Test 3.2.3: История транзакций (компиляция)
**File**: `WalletHistoryView.swift`

Steps:
- [ ] Открыть `WalletHistoryView.swift`
- [ ] Проверить наличие `TransactionCard`
- [ ] Проверить отображение полей:
  - [ ] Тип транзакции (topup, bonus, payment, etc.)
  - [ ] Иконка
  - [ ] Сумма с + или −
  - [ ] Дата
  - [ ] balance_after
- [ ] Проверить логи в Console:
  ```
  📜 [Wallet Sync] Fetching transactions
  ✅ [Wallet Sync] Fetched N transactions
  ```

**Expected**: View корректно отображает транзакции, логи показывают загрузку.

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A (view not integrated)
**Notes**: _______________________________________________

---

## Test 3.3: Integration with Main App

### Test 3.3.1: Navigation to ActiveOrdersView
Steps:
- [ ] Запустить приложение
- [ ] Проверить есть ли навигация к `ActiveOrdersView`
- [ ] Если есть - открыть
- [ ] Если нет - отметить N/A

**Expected**: View доступен через навигацию или отмечен N/A.

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A
**Notes**: _______________________________________________

---

### Test 3.3.2: Navigation to WalletHistoryView
Steps:
- [ ] Запустить приложение
- [ ] Проверить есть ли навигация к `WalletHistoryView`
- [ ] Если есть - открыть
- [ ] Если нет - отметить N/A

**Expected**: View доступен через навигацию или отмечен N/A.

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A
**Notes**: _______________________________________________

---

## Test 3.4: Error Handling

### Test 3.4.1: Network failure (Real-time)
Steps:
- [ ] Остановить Supabase: `supabase stop`
- [ ] В Xcode Console проверить логи:
  ```
  ❌ [Realtime] Failed to subscribe: ...
  ```
- [ ] Запустить Supabase: `supabase start`
- [ ] Проверить переподключение

**Expected**: Логи показывают ошибку и переподключение.

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

### Test 3.4.2: Network failure (Wallet Sync)
Steps:
- [ ] Остановить Supabase
- [ ] Попытаться синхронизировать кошелек
- [ ] В Xcode Console проверить:
  ```
  ❌ [Wallet Sync] Failed: ...
  ```
- [ ] Запустить Supabase
- [ ] Повторить синхронизацию
- [ ] Проверить успешную синхронизацию

**Expected**: Ошибка логируется, после восстановления работает.

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

## Test 3.5: Code Quality

### Test 3.5.1: Compilation
Steps:
- [ ] Открыть проект в Xcode
- [ ] Product → Build (⌘B)
- [ ] Проверить что нет ошибок компиляции
- [ ] Проверить что нет warnings (или минимальные)

**Expected**: Проект компилируется без ошибок.

**Result**: [ ] PASS / [ ] FAIL
**Warnings**: _______________________________________________

---

### Test 3.5.2: SwiftLint (если настроен)
Steps:
- [ ] Запустить SwiftLint: `swiftlint`
- [ ] Проверить новые файлы:
  - `RealtimeOrderService.swift`
  - `ActiveOrdersView.swift`
  - `WalletSyncService.swift`
  - `WalletHistoryView.swift`
- [ ] Исправить критичные warnings

**Expected**: Нет критичных проблем с линтингом.

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A (SwiftLint not configured)
**Notes**: _______________________________________________

---

## Test 3.6: Logging & Debugging

### Test 3.6.1: Logger usage
Steps:
- [ ] В Xcode Console фильтровать по "[Realtime]"
- [ ] Проверить что логи читаемые и информативные
- [ ] Фильтровать по "[Wallet Sync]"
- [ ] Проверить что логи помогают отладке

**Expected**: Логирование работает, сообщения понятные.

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

## Summary

**Total Tests**: 13
**Passed**: _____ / 13
**Failed**: _____ / 13
**N/A**: _____ / 13

**Overall Status**: [ ] PASS / [ ] FAIL

**Critical Issues Found**: _______________________________

**Integration Status**:
- [ ] Views integrated into main navigation
- [ ] Views exist but not integrated (ready for integration)
- [ ] Views need additional work before integration

**Notes**: ______________________________________________
