-- Analytics Tests
-- Тесты для аналитических view и RPC функций

\echo '================================'
\echo 'Testing Analytics Views and RPC'
\echo '================================'

-- Test 1.3.1: cafe_analytics view
\echo ''
\echo 'Test 1.3.1: cafe_analytics view - агрегация данных по кафе'
DO $$
DECLARE
  cafe1_orders int;
  cafe1_revenue bigint;
BEGIN
  SELECT total_orders, total_revenue 
  INTO cafe1_orders, cafe1_revenue
  FROM public.cafe_analytics
  WHERE cafe_id = '11111111-1111-1111-1111-111111111111';
  
  IF cafe1_orders >= 2 THEN
    RAISE NOTICE '✅ PASS: Cafe 1 имеет % заказов', cafe1_orders;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверное количество заказов для Cafe 1';
  END IF;
  
  IF cafe1_revenue > 0 THEN
    RAISE NOTICE '✅ PASS: Cafe 1 имеет выручку % кр.', cafe1_revenue;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Отсутствует выручка для Cafe 1';
  END IF;
END $$;

-- Test 1.3.2: popular_menu_items view
\echo ''
\echo 'Test 1.3.2: popular_menu_items view - популярные позиции'
DO $$
DECLARE
  top_item_quantity bigint;
BEGIN
  SELECT total_quantity INTO top_item_quantity
  FROM public.popular_menu_items
  ORDER BY total_quantity DESC NULLS LAST
  LIMIT 1;
  
  IF top_item_quantity >= 1 THEN
    RAISE NOTICE '✅ PASS: Топовая позиция имеет quantity = %', top_item_quantity;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверное количество для топовой позиции';
  END IF;
END $$;

-- Test 1.3.3: get_dashboard_metrics - метрики dashboard
\echo ''
\echo 'Test 1.3.3: get_dashboard_metrics - получение метрик'
DO $$
DECLARE
  result jsonb;
  all_time_orders int;
BEGIN
  result := get_dashboard_metrics(NULL);
  
  all_time_orders := (result->'all_time'->>'orders')::int;
  
  IF all_time_orders >= 3 THEN
    RAISE NOTICE '✅ PASS: All time orders = %', all_time_orders;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Недостаточно заказов в метриках';
  END IF;
  
  -- Проверяем структуру
  IF result->'today' IS NOT NULL AND 
     result->'this_week' IS NOT NULL AND
     result->'this_month' IS NOT NULL AND
     result->'all_time' IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Все временные периоды присутствуют';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Отсутствуют временные периоды';
  END IF;
END $$;

-- Test 1.3.4: get_dashboard_metrics - фильтр по кафе
\echo ''
\echo 'Test 1.3.4: get_dashboard_metrics - фильтр по cafe_id'
DO $$
DECLARE
  result jsonb;
  cafe1_orders int;
BEGIN
  result := get_dashboard_metrics('11111111-1111-1111-1111-111111111111'::uuid);
  
  cafe1_orders := (result->'all_time'->>'orders')::int;
  
  IF cafe1_orders = 2 THEN
    RAISE NOTICE '✅ PASS: Cafe 1 имеет 2 заказа в метриках';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверное количество заказов для Cafe 1: %', cafe1_orders;
  END IF;
END $$;

-- Test 1.3.5: get_top_menu_items - топ позиций
\echo ''
\echo 'Test 1.3.5: get_top_menu_items - получение топа'
DO $$
DECLARE
  items_count int;
BEGIN
  SELECT count(*) INTO items_count
  FROM get_top_menu_items(NULL, 10, now() - interval '7 days');
  
  IF items_count > 0 THEN
    RAISE NOTICE '✅ PASS: Получено % позиций в топе', items_count;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Топ позиций пуст';
  END IF;
END $$;

-- Test 1.3.6: get_revenue_by_day - выручка по дням
\echo ''
\echo 'Test 1.3.6: get_revenue_by_day - получение выручки по дням'
DO $$
DECLARE
  days_count int;
BEGIN
  SELECT count(*) INTO days_count
  FROM get_revenue_by_day(NULL, 30);
  
  IF days_count > 0 THEN
    RAISE NOTICE '✅ PASS: Получено % дней с данными', days_count;
  ELSE
    RAISE WARNING '⚠️  WARNING: Нет данных по дням (возможно заказы старые)';
  END IF;
END $$;

-- Test 1.3.7: get_cafe_stats - статистика за период
\echo ''
\echo 'Test 1.3.7: get_cafe_stats - статистика кафе за период'
DO $$
DECLARE
  result jsonb;
  total_orders int;
BEGIN
  result := get_cafe_stats(
    '11111111-1111-1111-1111-111111111111'::uuid,
    now() - interval '7 days',
    now()
  );
  
  total_orders := (result->'orders'->>'total')::int;
  
  IF total_orders >= 2 THEN
    RAISE NOTICE '✅ PASS: Статистика за период получена, orders = %', total_orders;
  ELSE
    RAISE EXCEPTION '❌ FAIL: Неверное количество заказов в статистике';
  END IF;
  
  -- Проверяем структуру
  IF result->'orders' IS NOT NULL AND 
     result->'revenue' IS NOT NULL AND
     result->'customers' IS NOT NULL THEN
    RAISE NOTICE '✅ PASS: Все разделы статистики присутствуют';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Отсутствуют разделы статистики';
  END IF;
END $$;

\echo ''
\echo '================================'
\echo 'Analytics Tests Complete'
\echo '================================'
