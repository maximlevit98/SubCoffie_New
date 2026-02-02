# Integration Tests Checklist

## Test 4.1: Admin → Backend → iOS Pipeline

### Test 4.1.1: Order Status Change Flow
**Components**: Admin Panel, Backend RPC, iOS Real-time

Setup:
- [ ] Supabase running
- [ ] Admin Panel running
- [ ] iOS Simulator running (if possible)
- [ ] Test order exists in DB

Steps:
1. **Backend**: Создать тестовый заказ через SQL:
```sql
INSERT INTO public.orders_core (id, cafe_id, customer_phone, status, paid_credits, subtotal_credits)
VALUES ('test-order-integration', '11111111-1111-1111-1111-111111111111', 'test-integration', 'created', 100, 100);
```

2. **Admin**: 
- [ ] Открыть `/admin/orders`
- [ ] Найти заказ `test-order-integration`
- [ ] Открыть детали
- [ ] Изменить статус на "paid"

3. **Backend**: Проверить что создалась запись в order_events:
```sql
SELECT * FROM public.order_events WHERE order_id = 'test-order-integration' ORDER BY created_at DESC LIMIT 1;
```
- [ ] Статус = 'paid'
- [ ] created_at установлен

4. **iOS**: (если Real-time подключен)
- [ ] В Xcode Console проверить лог:
  ```
  🔄 [Realtime] Order UPDATE event received
  ```

**Expected**: Изменение в Admin → обновление в Backend → событие в iOS

**Result**: [ ] PASS / [ ] FAIL / [ ] PARTIAL (iOS not connected)
**Notes**: _______________________________________________

---

### Test 4.1.2: Wallet Transaction Flow
**Components**: Admin Panel, Backend RPC, iOS Wallet Sync

Setup:
- [ ] Test user exists in DB
- [ ] Wallet exists for test user

Steps:
1. **Backend**: Получить текущий баланс:
```sql
SELECT * FROM public.wallets WHERE user_id = '33333333-3333-3333-3333-333333333333';
```
- [ ] Записать баланс: _______

2. **Admin**:
- [ ] Открыть `/admin/wallets`
- [ ] Найти кошелек test user
- [ ] Открыть управление
- [ ] Начислить 200 кредитов
- [ ] Причина: "Integration test"

3. **Backend**: Проверить обновление:
```sql
SELECT * FROM public.wallets WHERE user_id = '33333333-3333-3333-3333-333333333333';
```
- [ ] Баланс увеличился на 200
```sql
SELECT * FROM public.wallet_transactions 
WHERE wallet_id = (SELECT id FROM public.wallets WHERE user_id = '33333333-3333-3333-3333-333333333333')
ORDER BY created_at DESC LIMIT 1;
```
- [ ] Транзакция создана
- [ ] transaction_type = 'topup' или 'admin_credit'

4. **iOS**: (если Wallet Sync подключен)
- [ ] Проверить что баланс обновился

**Expected**: Админ начисляет → Backend обновляет → iOS синхронизирует

**Result**: [ ] PASS / [ ] FAIL / [ ] PARTIAL (iOS not connected)
**Notes**: _______________________________________________

---

## Test 4.2: Data Consistency

### Test 4.2.1: Order Data Consistency
Steps:
1. **Backend**: Создать заказ с items:
```sql
INSERT INTO public.orders_core (id, cafe_id, customer_phone, status, paid_credits, subtotal_credits)
VALUES ('test-consistency-1', '11111111-1111-1111-1111-111111111111', 'test-cons', 'paid', 250, 250);

INSERT INTO public.order_items (order_id, menu_item_id, title, category, quantity, unit_credits, line_total)
VALUES 
  ('test-consistency-1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Item 1', 'hot_drinks', 2, 100, 200),
  ('test-consistency-1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Test Item 2', 'desserts', 1, 50, 50);
```

2. **Admin**: Проверить данные:
- [ ] Открыть `/admin/orders/test-consistency-1`
- [ ] Проверить что итого = 250
- [ ] Проверить что отображается 2 позиции
- [ ] Проверить что сумма items = 250

3. **Backend**: Проверить через RPC:
```sql
SELECT * FROM get_order_details('test-consistency-1');
```
- [ ] Все данные присутствуют

**Expected**: Данные консистентны между Backend и Admin

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

### Test 4.2.2: Wallet Balance Consistency
Steps:
1. **Backend**: Получить начальный баланс
2. **Backend**: Добавить транзакции:
```sql
SELECT add_wallet_transaction(
  '33333333-3333-3333-3333-333333333333'::uuid,
  100,
  'topup',
  'Test topup'
);

SELECT add_wallet_transaction(
  '33333333-3333-3333-3333-333333333333'::uuid,
  50,
  'payment',
  'Test payment'
);
```

3. **Backend**: Проверить баланс:
```sql
SELECT * FROM get_user_wallet('33333333-3333-3333-3333-333333333333');
```
- [ ] Баланс = начальный + 100 - 50

4. **Admin**: Проверить в UI:
- [ ] Открыть `/admin/wallets/{userId}`
- [ ] Баланс совпадает с Backend
- [ ] Транзакции отображаются

**Expected**: Баланс консистентен, транзакции отображаются

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

## Test 4.3: End-to-End Scenarios

### Test 4.3.1: Complete Order Lifecycle
Steps:
1. **Backend**: Создать заказ "created"
2. **Admin**: created → paid
3. **Backend**: Проверить event
4. **Admin**: paid → preparing
5. **Backend**: Проверить event
6. **Admin**: preparing → ready
7. **Backend**: Проверить event
8. **Admin**: ready → issued
9. **Backend**: Проверить event

- [ ] Каждый переход создает event
- [ ] История статусов корректная
- [ ] Нет дублирующихся events

**Expected**: Полный lifecycle работает корректно

**Result**: [ ] PASS / [ ] FAIL
**Notes**: _______________________________________________

---

## Test 4.4: Performance Integration

### Test 4.4.1: Response Time (Admin → Backend)
Tools: Browser DevTools Network tab

Steps:
1. **Admin**: Открыть `/admin/orders`
2. **DevTools**: Network → Filter: "rpc"
3. **Admin**: Изменить статус заказа
4. **DevTools**: Проверить время запроса к `update_order_status`

- [ ] Время < 500ms

**Expected**: RPC вызовы быстрые

**Result**: [ ] PASS / [ ] FAIL
**Time**: _____ ms
**Notes**: _______________________________________________

---

### Test 4.4.2: Real-time Latency (Backend → iOS)
**Only if iOS Real-time connected**

Steps:
1. **iOS**: Открыть ActiveOrdersView
2. **Admin**: Изменить статус
3. **Measurement**: Время от клика в Admin до лога в Xcode Console

- [ ] Latency < 1 второй

**Expected**: Real-time обновления быстрые

**Result**: [ ] PASS / [ ] FAIL / [ ] N/A
**Latency**: _____ ms
**Notes**: _______________________________________________

---

## Summary

**Total Tests**: 7
**Passed**: _____ / 7
**Failed**: _____ / 7
**Partial**: _____ / 7

**Overall Status**: [ ] PASS / [ ] FAIL / [ ] PARTIAL

**Critical Issues Found**: _______________________________

**Pipeline Health**:
- [ ] Admin → Backend: ✅ Working
- [ ] Backend → iOS: ⚠️ Partial / ❌ Not tested
- [ ] Data Consistency: ✅ Verified

**Notes**: ______________________________________________
