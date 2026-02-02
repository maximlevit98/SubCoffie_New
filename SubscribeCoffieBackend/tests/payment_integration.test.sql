-- Payment Integration Tests
-- Тесты для функций интеграции платежей (mock версия)

\echo '================================'
\echo 'Testing Payment Integration RPC Functions'
\echo '================================'

-- Test 2.1.1: mock_wallet_topup - успешное пополнение CityPass
\echo ''
\echo 'Test 2.1.1: mock_wallet_topup - успешное пополнение CityPass'
DO $$
DECLARE
  test_user_id uuid;
  test_wallet_id uuid;
  test_payment_method_id uuid;
  result jsonb;
  commission_amount decimal;
BEGIN
  -- Создаем тестового пользователя
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_payment@example.com')
  RETURNING id INTO test_user_id;
  
  -- Создаем CityPass кошелек
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type)
  VALUES (test_user_id, 0, 'citypass')
  RETURNING id INTO test_wallet_id;
  
  -- Создаем mock метод оплаты
  INSERT INTO public.payment_methods (user_id, card_last4, card_brand, payment_provider, is_default)
  VALUES (test_user_id, '4242', 'visa', 'mock', true)
  RETURNING id INTO test_payment_method_id;
  
  -- Пополняем кошелек на 1000 кредитов
  SELECT mock_wallet_topup(test_wallet_id, 1000, test_payment_method_id) INTO result;
  
  -- Проверяем результат
  IF (result->>'success')::boolean = true THEN
    RAISE NOTICE '✅ PASS: Пополнение выполнено успешно';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Пополнение не выполнено';
  END IF;
  
  -- Проверяем что комиссия рассчитана правильно (для CityPass должна быть 5-10%)
  commission_amount := (result->>'commission')::decimal;
  IF commission_amount >= 50 AND commission_amount <= 100 THEN
    RAISE NOTICE '✅ PASS: Комиссия рассчитана корректно: % кредитов', commission_amount;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверная комиссия: % (ожидалось 50-100)', commission_amount;
  END IF;
  
  -- Проверяем что транзакция создана
  IF EXISTS (
    SELECT 1 FROM public.payment_transactions 
    WHERE id = (result->>'transaction_id')::uuid 
    AND status = 'completed'
  ) THEN
    RAISE NOTICE '✅ PASS: Транзакция создана со статусом completed';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Транзакция не создана';
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
END $$;

-- Test 2.1.2: mock_wallet_topup - пополнение Cafe Wallet
\echo ''
\echo 'Test 2.1.2: mock_wallet_topup - пополнение Cafe Wallet (меньшая комиссия)'
DO $$
DECLARE
  test_user_id uuid;
  test_cafe_id uuid;
  test_wallet_id uuid;
  test_payment_method_id uuid;
  result jsonb;
  commission_amount decimal;
BEGIN
  -- Создаем тестового пользователя и кафе
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_cafe_wallet@example.com')
  RETURNING id INTO test_user_id;
  
  INSERT INTO public.cafes (name, address, description)
  VALUES ('Test Cafe', '123 Test St', 'Test description')
  RETURNING id INTO test_cafe_id;
  
  -- Создаем Cafe Wallet
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type, cafe_id)
  VALUES (test_user_id, 0, 'cafe_wallet', test_cafe_id)
  RETURNING id INTO test_wallet_id;
  
  -- Создаем mock метод оплаты
  INSERT INTO public.payment_methods (user_id, card_last4, card_brand, payment_provider, is_default)
  VALUES (test_user_id, '4242', 'visa', 'mock', true)
  RETURNING id INTO test_payment_method_id;
  
  -- Пополняем кошелек на 1000 кредитов
  SELECT mock_wallet_topup(test_wallet_id, 1000, test_payment_method_id) INTO result;
  
  -- Проверяем результат
  IF (result->>'success')::boolean = true THEN
    RAISE NOTICE '✅ PASS: Пополнение Cafe Wallet выполнено успешно';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Пополнение не выполнено';
  END IF;
  
  -- Проверяем что комиссия меньше (для Cafe Wallet должна быть 3-5%)
  commission_amount := (result->>'commission')::decimal;
  IF commission_amount >= 30 AND commission_amount <= 50 THEN
    RAISE NOTICE '✅ PASS: Комиссия для Cafe Wallet ниже: % кредитов', commission_amount;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверная комиссия для Cafe Wallet: %', commission_amount;
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
  DELETE FROM public.cafes WHERE id = test_cafe_id;
END $$;

-- Test 2.1.3: validate_wallet_for_order - проверка доступности кошелька для заказа
\echo ''
\echo 'Test 2.1.3: validate_wallet_for_order - CityPass работает везде'
DO $$
DECLARE
  test_user_id uuid;
  test_cafe_id uuid;
  test_wallet_id uuid;
  is_valid boolean;
BEGIN
  -- Создаем пользователя, кафе и CityPass кошелек
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_validation@example.com')
  RETURNING id INTO test_user_id;
  
  INSERT INTO public.cafes (name, address)
  VALUES ('Any Cafe', '456 Test St')
  RETURNING id INTO test_cafe_id;
  
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type)
  VALUES (test_user_id, 1000, 'citypass')
  RETURNING id INTO test_wallet_id;
  
  -- Проверяем что CityPass работает в любом кафе
  SELECT validate_wallet_for_order(test_wallet_id, test_cafe_id) INTO is_valid;
  
  IF is_valid = true THEN
    RAISE NOTICE '✅ PASS: CityPass валиден для любого кафе';
  ELSE
    RAISE EXCEPTION '❌ FAIL: CityPass должен работать везде';
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
  DELETE FROM public.cafes WHERE id = test_cafe_id;
END $$;

-- Test 2.1.4: validate_wallet_for_order - Cafe Wallet только для своего кафе
\echo ''
\echo 'Test 2.1.4: validate_wallet_for_order - Cafe Wallet только для привязанного кафе'
DO $$
DECLARE
  test_user_id uuid;
  test_cafe1_id uuid;
  test_cafe2_id uuid;
  test_wallet_id uuid;
  is_valid boolean;
BEGIN
  -- Создаем пользователя и два кафе
  INSERT INTO auth.users (id, email) 
  VALUES (gen_random_uuid(), 'test_cafe_validation@example.com')
  RETURNING id INTO test_user_id;
  
  INSERT INTO public.cafes (name, address)
  VALUES ('Cafe 1', '111 Test St')
  RETURNING id INTO test_cafe1_id;
  
  INSERT INTO public.cafes (name, address)
  VALUES ('Cafe 2', '222 Test St')
  RETURNING id INTO test_cafe2_id;
  
  -- Создаем Cafe Wallet привязанный к Cafe 1
  INSERT INTO public.wallets (user_id, balance_credits, wallet_type, cafe_id)
  VALUES (test_user_id, 1000, 'cafe_wallet', test_cafe1_id)
  RETURNING id INTO test_wallet_id;
  
  -- Проверяем что кошелек работает в своем кафе
  SELECT validate_wallet_for_order(test_wallet_id, test_cafe1_id) INTO is_valid;
  
  IF is_valid = true THEN
    RAISE NOTICE '✅ PASS: Cafe Wallet валиден для привязанного кафе';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Cafe Wallet должен работать в своем кафе';
  END IF;
  
  -- Проверяем что кошелек НЕ работает в другом кафе
  SELECT validate_wallet_for_order(test_wallet_id, test_cafe2_id) INTO is_valid;
  
  IF is_valid = false THEN
    RAISE NOTICE '✅ PASS: Cafe Wallet не валиден для чужого кафе';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Cafe Wallet не должен работать в чужом кафе';
  END IF;
  
  -- Очистка
  DELETE FROM auth.users WHERE id = test_user_id;
  DELETE FROM public.cafes WHERE id IN (test_cafe1_id, test_cafe2_id);
END $$;

-- Test 2.1.5: calculate_commission - расчет комиссии для разных типов операций
\echo ''
\echo 'Test 2.1.5: calculate_commission - проверка расчета комиссий'
DO $$
DECLARE
  citypass_commission decimal;
  cafe_wallet_commission decimal;
  direct_order_commission decimal;
BEGIN
  -- Расчет комиссии для пополнения CityPass
  SELECT calculate_commission(1000, 'citypass_topup', 'citypass') INTO citypass_commission;
  
  IF citypass_commission >= 50 AND citypass_commission <= 100 THEN
    RAISE NOTICE '✅ PASS: Комиссия CityPass (5-10%%): % кредитов', citypass_commission;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверная комиссия CityPass: %', citypass_commission;
  END IF;
  
  -- Расчет комиссии для пополнения Cafe Wallet
  SELECT calculate_commission(1000, 'cafe_wallet_topup', 'cafe_wallet') INTO cafe_wallet_commission;
  
  IF cafe_wallet_commission >= 30 AND cafe_wallet_commission <= 50 THEN
    RAISE NOTICE '✅ PASS: Комиссия Cafe Wallet (3-5%%): % кредитов', cafe_wallet_commission;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверная комиссия Cafe Wallet: %', cafe_wallet_commission;
  END IF;
  
  -- Расчет комиссии для прямого заказа
  SELECT calculate_commission(1000, 'direct_order', NULL) INTO direct_order_commission;
  
  IF direct_order_commission >= 150 AND direct_order_commission <= 200 THEN
    RAISE NOTICE '✅ PASS: Комиссия прямого заказа (15-20%%): % кредитов', direct_order_commission;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверная комиссия прямого заказа: %', direct_order_commission;
  END IF;
  
  -- Проверяем что комиссия для Cafe Wallet меньше чем для CityPass
  IF cafe_wallet_commission < citypass_commission THEN
    RAISE NOTICE '✅ PASS: Комиссия Cafe Wallet меньше чем CityPass';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Комиссия Cafe Wallet должна быть меньше';
  END IF;
END $$;

\echo ''
\echo '================================'
\echo 'Payment Integration Tests Complete'
\echo '================================'
