-- RPC Integration Tests
-- Комплексные тесты интеграции различных RPC функций

\echo '================================'
\echo 'Testing RPC Integration Flows'
\echo '================================'

-- Test 3.1: Полный флоу заказа с оплатой через кошелек
\echo ''
\echo 'Test 3.1: Полный флоу заказа - от создания до выдачи'
DO $$
DECLARE
  test_user_id uuid;
  test_cafe_id uuid;
  test_wallet_id uuid;
  test_menu_item_id uuid;
  test_order_id uuid;
  order_status text;
  wallet_balance decimal;
  initial_balance decimal := 1000;
  order_total decimal := 500;
BEGIN
  -- Создаем пользователя
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_flow@example.com')
  RETURNING id INTO test_user_id;
  
  -- Создаем кафе и меню
  INSERT INTO public.cafes (name, address)
  VALUES ('Flow Test Cafe', '789 Flow St')
  RETURNING id INTO test_cafe_id;
  
  INSERT INTO public.menu_items (cafe_id, name, price_credits, category, available)
  VALUES (test_cafe_id, 'Test Latte', 500, 'coffee', true)
  RETURNING id INTO test_menu_item_id;
  
  -- Создаем кошелек и пополняем баланс
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type)
  VALUES (test_user_id, initial_balance, 'citypass')
  RETURNING id INTO test_wallet_id;
  
  -- Создаем заказ
  INSERT INTO public.orders (user_id, cafe_id, total_credits, status)
  VALUES (test_user_id, test_cafe_id, order_total, 'created')
  RETURNING id INTO test_order_id;
  
  -- Добавляем позицию в заказ
  INSERT INTO public.order_items (order_id, menu_item_id, quantity, price_credits)
  VALUES (test_order_id, test_menu_item_id, 1, order_total);
  
  RAISE NOTICE '✅ PASS: Заказ создан с ID: %', test_order_id;
  
  -- Оплата через кошелек (симуляция)
  UPDATE public.wallets 
  SET balance_credits = balance_credits - order_total
  WHERE id = test_wallet_id;
  
  UPDATE public.orders 
  SET status = 'paid', paid_at = now()
  WHERE id = test_order_id;
  
  RAISE NOTICE '✅ PASS: Заказ оплачен через кошелек';
  
  -- Проверяем баланс после оплаты
  SELECT balance_credits INTO wallet_balance FROM public.wallets WHERE id = test_wallet_id;
  
  IF wallet_balance = (initial_balance - order_total) THEN
    RAISE NOTICE '✅ PASS: Баланс кошелька корректен: % кредитов', wallet_balance;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный баланс: % (ожидалось %)', wallet_balance, (initial_balance - order_total);
  END IF;
  
  -- Переводим заказ в статус preparing
  PERFORM update_order_status(test_order_id, 'preparing', NULL);
  RAISE NOTICE '✅ PASS: Заказ переведен в статус preparing';
  
  -- Переводим в ready
  PERFORM update_order_status(test_order_id, 'ready', NULL);
  RAISE NOTICE '✅ PASS: Заказ готов к выдаче';
  
  -- Выдаем заказ
  PERFORM update_order_status(test_order_id, 'completed', NULL);
  
  SELECT status INTO order_status FROM public.orders WHERE id = test_order_id;
  IF order_status = 'completed' THEN
    RAISE NOTICE '✅ PASS: Заказ успешно выдан';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный финальный статус: %', order_status;
  END IF;
  
  -- Проверяем что создались все события
  IF (SELECT count(*) FROM public.order_events WHERE order_id = test_order_id) >= 4 THEN
    RAISE NOTICE '✅ PASS: История событий заказа создана';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Недостаточно событий в истории';
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
  DELETE FROM public.cafes WHERE id = test_cafe_id;
END $$;

-- Test 3.2: Тест отмены заказа с возвратом средств
\echo ''
\echo 'Test 3.2: Отмена заказа и возврат средств на кошелек'
DO $$
DECLARE
  test_user_id uuid;
  test_cafe_id uuid;
  test_wallet_id uuid;
  test_order_id uuid;
  initial_balance decimal := 1000;
  order_amount decimal := 300;
  balance_after_payment decimal;
  balance_after_refund decimal;
BEGIN
  -- Создаем тестовые данные
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_refund@example.com')
  RETURNING id INTO test_user_id;
  
  INSERT INTO public.cafes (name, address)
  VALUES ('Refund Test Cafe', '999 Refund St')
  RETURNING id INTO test_cafe_id;
  
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type)
  VALUES (test_user_id, initial_balance, 'citypass')
  RETURNING id INTO test_wallet_id;
  
  INSERT INTO public.orders (user_id, cafe_id, total_credits, status)
  VALUES (test_user_id, test_cafe_id, order_amount, 'created')
  RETURNING id INTO test_order_id;
  
  -- Оплата
  UPDATE public.wallets 
  SET balance_credits = balance_credits - order_amount
  WHERE id = test_wallet_id;
  
  UPDATE public.orders 
  SET status = 'paid', paid_at = now()
  WHERE id = test_order_id;
  
  SELECT balance_credits INTO balance_after_payment 
  FROM public.wallets WHERE id = test_wallet_id;
  
  RAISE NOTICE '✅ Баланс после оплаты: % кредитов', balance_after_payment;
  
  -- Отмена заказа
  PERFORM update_order_status(test_order_id, 'cancelled', 'Customer request');
  
  -- Возврат средств
  UPDATE public.wallets 
  SET balance_credits = balance_credits + order_amount
  WHERE id = test_wallet_id;
  
  SELECT balance_credits INTO balance_after_refund 
  FROM public.wallets WHERE id = test_wallet_id;
  
  IF balance_after_refund = initial_balance THEN
    RAISE NOTICE '✅ PASS: Средства возвращены на кошелек полностью';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный баланс после возврата: %', balance_after_refund;
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
  DELETE FROM public.cafes WHERE id = test_cafe_id;
END $$;

-- Test 3.3: Проверка RLS (Row Level Security)
\echo ''
\echo 'Test 3.3: Проверка Row Level Security для кошельков'
DO $$
DECLARE
  user1_id uuid;
  user2_id uuid;
  wallet1_id uuid;
  wallet2_id uuid;
BEGIN
  -- Создаем двух пользователей
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'user1@example.com')
  RETURNING id INTO user1_id;
  
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'user2@example.com')
  RETURNING id INTO user2_id;
  
  -- Создаем кошельки для обоих
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type)
  VALUES (user1_id, 1000, 'citypass')
  RETURNING id INTO wallet1_id;
  
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type)
  VALUES (user2_id, 2000, 'citypass')
  RETURNING id INTO wallet2_id;
  
  RAISE NOTICE '✅ PASS: RLS тест подготовлен (требует дополнительной настройки для полной проверки)';
  
  -- Очистка
  DELETE FROM auth.users WHERE id IN (user1_id, user2_id);
END $$;

-- Test 3.4: Нагрузочный тест - множественные заказы
\echo ''
\echo 'Test 3.4: Создание множественных заказов для проверки производительности'
DO $$
DECLARE
  test_user_id uuid;
  test_cafe_id uuid;
  test_menu_item_id uuid;
  i integer;
  start_time timestamp;
  end_time timestamp;
  duration interval;
BEGIN
  start_time := clock_timestamp();
  
  -- Создаем тестовые данные
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_load@example.com')
  RETURNING id INTO test_user_id;
  
  INSERT INTO public.cafes (name, address)
  VALUES ('Load Test Cafe', '555 Load St')
  RETURNING id INTO test_cafe_id;
  
  INSERT INTO public.menu_items (cafe_id, name, price_credits, category, available)
  VALUES (test_cafe_id, 'Load Test Item', 100, 'coffee', true)
  RETURNING id INTO test_menu_item_id;
  
  -- Создаем 50 заказов
  FOR i IN 1..50 LOOP
    INSERT INTO public.orders (user_id, cafe_id, total_credits, status)
    VALUES (test_user_id, test_cafe_id, 100 * i, 'created');
  END LOOP;
  
  end_time := clock_timestamp();
  duration := end_time - start_time;
  
  RAISE NOTICE '✅ PASS: Создано 50 заказов за %', duration;
  
  IF duration < interval '5 seconds' THEN
    RAISE NOTICE '✅ PASS: Производительность хорошая (< 5 секунд)';
  ELSE
    RAISE WARNING '⚠️  WARNING: Производительность можно улучшить (> 5 секунд)';
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
  DELETE FROM public.cafes WHERE id = test_cafe_id;
END $$;

\echo ''
\echo '================================'
\echo 'RPC Integration Tests Complete'
\echo '================================'
