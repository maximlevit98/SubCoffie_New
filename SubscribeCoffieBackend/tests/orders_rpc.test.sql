-- Orders RPC Tests
-- Тесты для RPC функций управления заказами

\echo '================================'
\echo 'Testing Orders RPC Functions'
\echo '================================'

-- Test 1.1.1: update_order_status - успешное обновление
\echo ''
\echo 'Test 1.1.1: update_order_status - успешное обновление статуса'
DO $$
DECLARE
  result jsonb;
  events_count int;
BEGIN
  -- Обновляем статус тестового заказа
  result := update_order_status(
    '55555555-5555-5555-5555-555555555555'::uuid,
    'paid',
    NULL
  );
  
  -- Проверяем результат
  IF (result->>'status')::text = 'paid' AND (result->>'old_status')::text = 'created' THEN
    RAISE NOTICE '✅ PASS: Статус успешно обновлен';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверный результат обновления статуса';
  END IF;
  
  -- Проверяем что создалась запись в order_events
  SELECT count(*) INTO events_count 
  FROM public.order_events 
  WHERE order_id = '55555555-5555-5555-5555-555555555555' AND status = 'paid';
  
  IF events_count > 0 THEN
    RAISE NOTICE '✅ PASS: Запись в order_events создана';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Запись в order_events не создана';
  END IF;
END $$;

-- Test 1.1.2: update_order_status - несуществующий заказ
\echo ''
\echo 'Test 1.1.2: update_order_status - несуществующий заказ'
DO $$
DECLARE
  result jsonb;
BEGIN
  BEGIN
    result := update_order_status(
      '99999999-9999-9999-9999-999999999999'::uuid,
      'paid',
      NULL
    );
    RAISE EXCEPTION '❌ FAIL: Должна была выброситься ошибка для несуществующего заказа';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Order not found%' THEN
        RAISE NOTICE '✅ PASS: Корректная ошибка для несуществующего заказа';
      ELSE
        RAISE EXCEPTION '❌ FAIL: Неверная ошибка: %', SQLERRM;
      END IF;
  END;
END $$;

-- Test 1.1.3: update_order_status - невалидный статус
\echo ''
\echo 'Test 1.1.3: update_order_status - невалидный статус'
DO $$
DECLARE
  result jsonb;
BEGIN
  BEGIN
    result := update_order_status(
      '66666666-6666-6666-6666-666666666666'::uuid,
      'invalid_status',
      NULL
    );
    RAISE EXCEPTION '❌ FAIL: Должна была выброситься ошибка для невалидного статуса';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Invalid status%' THEN
        RAISE NOTICE '✅ PASS: Корректная ошибка для невалидного статуса';
      ELSE
        RAISE EXCEPTION '❌ FAIL: Неверная ошибка: %', SQLERRM;
      END IF;
  END;
END $$;

-- Test 1.1.4: get_orders_by_cafe - все заказы
\echo ''
\echo 'Test 1.1.4: get_orders_by_cafe - получение всех заказов'
DO $$
DECLARE
  orders_count int;
BEGIN
  SELECT count(*) INTO orders_count
  FROM get_orders_by_cafe(NULL, NULL, 100, 0);
  
  IF orders_count >= 3 THEN
    RAISE NOTICE '✅ PASS: Получено % заказов (ожидалось >= 3)', orders_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Получено недостаточно заказов: %', orders_count;
  END IF;
END $$;

-- Test 1.1.5: get_orders_by_cafe - фильтр по кафе
\echo ''
\echo 'Test 1.1.5: get_orders_by_cafe - фильтр по cafe_id'
DO $$
DECLARE
  orders_count int;
BEGIN
  SELECT count(*) INTO orders_count
  FROM get_orders_by_cafe(
    '11111111-1111-1111-1111-111111111111'::uuid,
    NULL,
    100,
    0
  );
  
  IF orders_count = 2 THEN
    RAISE NOTICE '✅ PASS: Получено 2 заказа для Test Cafe 1';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Ожидалось 2 заказа, получено %', orders_count;
  END IF;
END $$;

-- Test 1.1.6: get_orders_by_cafe - фильтр по статусу
\echo ''
\echo 'Test 1.1.6: get_orders_by_cafe - фильтр по status'
DO $$
DECLARE
  orders_count int;
BEGIN
  SELECT count(*) INTO orders_count
  FROM get_orders_by_cafe(NULL, 'preparing', 100, 0);
  
  IF orders_count >= 1 THEN
    RAISE NOTICE '✅ PASS: Найдены заказы со статусом preparing';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Не найдены заказы со статусом preparing';
  END IF;
END $$;

-- Test 1.1.7: get_order_details - успешное получение
\echo ''
\echo 'Test 1.1.7: get_order_details - получение деталей заказа'
DO $$
DECLARE
  result jsonb;
  items_count int;
  events_count int;
BEGIN
  result := get_order_details('66666666-6666-6666-6666-666666666666'::uuid);
  
  -- Проверяем наличие order
  IF result->'order' IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Order данные присутствуют';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Order данные отсутствуют';
  END IF;
  
  -- Проверяем наличие items
  items_count := jsonb_array_length(result->'items');
  IF items_count > 0 THEN
    RAISE NOTICE '✅ PASS: Получено % items', items_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Items отсутствуют';
  END IF;
  
  -- Проверяем наличие events
  events_count := jsonb_array_length(result->'events');
  IF events_count > 0 THEN
    RAISE NOTICE '✅ PASS: Получено % events', events_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Events отсутствуют';
  END IF;
END $$;

-- Test 1.1.8: get_order_details - несуществующий заказ
\echo ''
\echo 'Test 1.1.8: get_order_details - несуществующий заказ'
DO $$
DECLARE
  result jsonb;
BEGIN
  BEGIN
    result := get_order_details('99999999-9999-9999-9999-999999999999'::uuid);
    RAISE EXCEPTION '❌ FAIL: Должна была выброситься ошибка';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%Order not found%' THEN
        RAISE NOTICE '✅ PASS: Корректная ошибка для несуществующего заказа';
      ELSE
        RAISE EXCEPTION '❌ FAIL: Неверная ошибка: %', SQLERRM;
      END IF;
  END;
END $$;

-- Test 1.1.9: get_orders_stats - общая статистика
\echo ''
\echo 'Test 1.1.9: get_orders_stats - получение статистики'
DO $$
DECLARE
  result jsonb;
  total_orders int;
BEGIN
  result := get_orders_stats(NULL, NULL, NULL);
  
  total_orders := (result->>'total_orders')::int;
  
  IF total_orders >= 3 THEN
    RAISE NOTICE '✅ PASS: Статистика получена, total_orders = %', total_orders;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверное количество заказов в статистике';
  END IF;
  
  -- Проверяем наличие by_status
  IF result->'by_status' IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Статистика по статусам присутствует';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Статистика по статусам отсутствует';
  END IF;
END $$;

\echo ''
\echo '================================'
\echo 'Orders RPC Tests Complete'
\echo '================================'
