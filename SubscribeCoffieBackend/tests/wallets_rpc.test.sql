-- Wallets RPC Tests
-- Тесты для RPC функций управления кошельками

\echo '================================'
\echo 'Testing Wallets RPC Functions'
\echo '================================'

-- Test 1.2.1: get_user_wallet - существующий кошелек
\echo ''
\echo 'Test 1.2.1: get_user_wallet - получение существующего кошелька'
DO $$
DECLARE
  result jsonb;
  balance int;
BEGIN
  result := get_user_wallet('33333333-3333-3333-3333-333333333333'::uuid);
  
  balance := (result->>'balance')::int;
  
  IF balance = 500 THEN
    RAISE NOTICE '✅ PASS: Кошелек получен, balance = 500';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный баланс: %', balance;
  END IF;
  
  -- Проверяем наличие всех полей
  IF result->>'bonus_balance' IS NOT NULL AND result->>'lifetime_topup' IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Все поля присутствуют';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Отсутствуют обязательные поля';
  END IF;
END $$;

-- Test 1.2.2: get_user_wallet - создание нового кошелька
\echo ''
\echo 'Test 1.2.2: get_user_wallet - создание нового кошелька'
DO $$
DECLARE
  result jsonb;
  new_user_id uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
BEGIN
  result := get_user_wallet(new_user_id);
  
  IF (result->>'balance')::int = 0 THEN
    RAISE NOTICE '✅ PASS: Новый кошелек создан с нулевым балансом';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный начальный баланс';
  END IF;
END $$;

-- Test 1.2.3: add_wallet_transaction - топап
\echo ''
\echo 'Test 1.2.3: add_wallet_transaction - транзакция topup'
DO $$
DECLARE
  result jsonb;
  new_balance int;
  wallet_before jsonb;
  balance_before int;
BEGIN
  -- Получаем баланс до операции
  wallet_before := get_user_wallet('44444444-4444-4444-4444-444444444444'::uuid);
  balance_before := (wallet_before->>'balance')::int;
  
  -- Добавляем транзакцию
  result := add_wallet_transaction(
    '44444444-4444-4444-4444-444444444444'::uuid,
    200,
    'topup',
    'Test topup transaction'
  );
  
  new_balance := (result->'wallet'->>'balance')::int;
  
  IF new_balance = balance_before + 200 THEN
    RAISE NOTICE '✅ PASS: Баланс увеличен на 200 (было: %, стало: %)', balance_before, new_balance;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный баланс после topup';
  END IF;
END $$;

-- Test 1.2.4: add_wallet_transaction - бонус
\echo ''
\echo 'Test 1.2.4: add_wallet_transaction - транзакция bonus'
DO $$
DECLARE
  result jsonb;
  wallet_after jsonb;
  bonus_balance int;
BEGIN
  result := add_wallet_transaction(
    '44444444-4444-4444-4444-444444444444'::uuid,
    50,
    'bonus',
    'Test bonus transaction'
  );
  
  bonus_balance := (result->'wallet'->>'bonus_balance')::int;
  
  IF bonus_balance >= 50 THEN
    RAISE NOTICE '✅ PASS: Бонусный баланс увеличен';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Бонусный баланс не увеличился';
  END IF;
END $$;

-- Test 1.2.5: add_wallet_transaction - payment (списание)
\echo ''
\echo 'Test 1.2.5: add_wallet_transaction - транзакция payment'
DO $$
DECLARE
  result jsonb;
  wallet_before jsonb;
  wallet_after jsonb;
  balance_before int;
  balance_after int;
BEGIN
  wallet_before := get_user_wallet('33333333-3333-3333-3333-333333333333'::uuid);
  balance_before := (wallet_before->>'balance')::int;
  
  result := add_wallet_transaction(
    '33333333-3333-3333-3333-333333333333'::uuid,
    100,
    'payment',
    'Test payment transaction'
  );
  
  balance_after := (result->'wallet'->>'balance')::int;
  
  IF balance_after = balance_before - 100 THEN
    RAISE NOTICE '✅ PASS: Баланс уменьшен на 100 (было: %, стало: %)', balance_before, balance_after;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный баланс после payment';
  END IF;
END $$;

-- Test 1.2.6: add_wallet_transaction - невалидный тип
\echo ''
\echo 'Test 1.2.6: add_wallet_transaction - невалидный тип транзакции'
DO $$
DECLARE
  result jsonb;
BEGIN
  BEGIN
    result := add_wallet_transaction(
      '33333333-3333-3333-3333-333333333333'::uuid,
      100,
      'invalid_type',
      'Test'
    );
    RAISE EXCEPTION '❌ FAIL: Должна была выброситься ошибка';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Invalid transaction type%' THEN
        RAISE NOTICE '✅ PASS: Корректная ошибка для невалидного типа';
      ELSE
        RAISE EXCEPTION '❌ FAIL: Неверная ошибка: %', SQLERRM;
      END IF;
  END;
END $$;

-- Test 1.2.7: get_wallet_transactions - получение истории
\echo ''
\echo 'Test 1.2.7: get_wallet_transactions - получение истории транзакций'
DO $$
DECLARE
  tx_count int;
  tx_record record;
BEGIN
  -- Получаем транзакции
  SELECT count(*) INTO tx_count
  FROM get_wallet_transactions(
    '44444444-4444-4444-4444-444444444444'::uuid,
    50,
    0
  );
  
  IF tx_count >= 2 THEN
    RAISE NOTICE '✅ PASS: Получено % транзакций', tx_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Недостаточно транзакций: %', tx_count;
  END IF;
  
  -- Проверяем наличие полей balance_before/after в транзакциях
  SELECT * INTO tx_record
  FROM get_wallet_transactions(
    '44444444-4444-4444-4444-444444444444'::uuid,
    1,
    0
  )
  LIMIT 1;
  
  IF tx_record.balance_before IS NOT NULL AND tx_record.balance_after IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Поля balance_before/after присутствуют (before: %, after: %)', 
      tx_record.balance_before, tx_record.balance_after;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Отсутствуют поля balance_before/after';
  END IF;
  
  -- Проверяем что balance_after корректно рассчитан
  IF tx_record.type IN ('topup', 'bonus', 'refund', 'admin_credit') THEN
    IF tx_record.balance_after = tx_record.balance_before + tx_record.amount THEN
      RAISE NOTICE '✅ PASS: balance_after корректно рассчитан для type=%', tx_record.type;
    ELSE
      RAISE EXCEPTION '❌ FAIL: Неверный расчет balance_after';
    END IF;
  ELSIF tx_record.type IN ('payment', 'admin_debit') THEN
    IF tx_record.balance_after = tx_record.balance_before - abs(tx_record.amount) THEN
      RAISE NOTICE '✅ PASS: balance_after корректно рассчитан для type=%', tx_record.type;
    ELSE
      RAISE EXCEPTION '❌ FAIL: Неверный расчет balance_after';
    END IF;
  END IF;
END $$;

-- Test 1.2.7b: add_wallet_transaction - проверка order_id и actor_user_id
\echo ''
\echo 'Test 1.2.7b: add_wallet_transaction - с order_id и actor_user_id'
DO $$
DECLARE
  result jsonb;
  test_order_id uuid := '11111111-1111-1111-1111-111111111111';
  test_actor_id uuid := '22222222-2222-2222-2222-222222222222';
  tx_id uuid;
  tx_order_id uuid;
  tx_actor_id uuid;
BEGIN
  -- Добавляем транзакцию с дополнительными параметрами
  result := add_wallet_transaction(
    '44444444-4444-4444-4444-444444444444'::uuid,
    75,
    'admin_credit',
    'Admin adjustment with tracking',
    test_order_id,  -- order_id
    test_actor_id   -- actor_user_id
  );
  
  tx_id := (result->>'transaction_id')::uuid;
  
  -- Проверяем что order_id и actor_user_id сохранились
  SELECT order_id, actor_user_id INTO tx_order_id, tx_actor_id
  FROM public.wallet_transactions
  WHERE id = tx_id;
  
  IF tx_order_id = test_order_id AND tx_actor_id = test_actor_id THEN
    RAISE NOTICE '✅ PASS: order_id и actor_user_id корректно сохранены';
  ELSE
    RAISE EXCEPTION '❌ FAIL: order_id или actor_user_id не сохранились';
  END IF;
END $$;

-- Test 1.2.8: get_wallets_stats - общая статистика
\echo ''
\echo 'Test 1.2.8: get_wallets_stats - получение статистики по кошелькам'
DO $$
DECLARE
  result jsonb;
  total_wallets int;
BEGIN
  result := get_wallets_stats();
  
  total_wallets := (result->>'total_wallets')::int;
  
  IF total_wallets >= 2 THEN
    RAISE NOTICE '✅ PASS: Статистика получена, total_wallets = %', total_wallets;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверное количество кошельков';
  END IF;
  
  -- Проверяем наличие полей
  IF result->>'total_balance' IS NOT NULL AND result->>'avg_balance' IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Все поля статистики присутствуют';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Отсутствуют поля статистики';
  END IF;
END $$;

\echo ''
\echo '================================'
\echo 'Wallets RPC Tests Complete'
\echo '================================'
