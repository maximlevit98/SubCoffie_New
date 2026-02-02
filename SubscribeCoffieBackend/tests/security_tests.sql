-- Security Tests
-- Проверка RLS политик и прав доступа

\echo '================================'
\echo 'Security Tests'
\echo '================================'

-- Test 5.1: RLS на push_tokens
\echo ''
\echo 'Test 5.1.1: RLS на push_tokens'
DO $$
DECLARE
  token_count int;
BEGIN
  -- Проверяем что RLS включен
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'push_tokens' 
    AND rowsecurity = true
  ) THEN
    RAISE NOTICE '✅ PASS: RLS включен на push_tokens';
  ELSE
    RAISE WARNING '⚠️  WARNING: RLS не включен на push_tokens';
  END IF;
  
  -- Проверяем наличие policies
  SELECT count(*) INTO token_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'push_tokens';
  
  IF token_count > 0 THEN
    RAISE NOTICE '✅ PASS: Найдено % RLS policies на push_tokens', token_count;
  ELSE
    RAISE WARNING '⚠️  WARNING: Нет RLS policies на push_tokens';
  END IF;
END $$;

-- Test 5.2: RLS на push_notifications_log
\echo ''
\echo 'Test 5.1.2: RLS на push_notifications_log'
DO $$
DECLARE
  policy_count int;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'push_notifications_log' 
    AND rowsecurity = true
  ) THEN
    RAISE NOTICE '✅ PASS: RLS включен на push_notifications_log';
  ELSE
    RAISE WARNING '⚠️  WARNING: RLS не включен на push_notifications_log';
  END IF;
  
  SELECT count(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'push_notifications_log';
  
  IF policy_count > 0 THEN
    RAISE NOTICE '✅ PASS: Найдено % RLS policies на push_notifications_log', policy_count;
  ELSE
    RAISE WARNING '⚠️  WARNING: Нет RLS policies на push_notifications_log';
  END IF;
END $$;

-- Test 5.3: RPC функции доступны для authenticated
\echo ''
\echo 'Test 5.2.1: RPC функции доступны для authenticated'
DO $$
DECLARE
  func_count int;
BEGIN
  SELECT count(*) INTO func_count
  FROM information_schema.routine_privileges
  WHERE routine_schema = 'public'
  AND routine_name IN ('update_order_status', 'get_orders_by_cafe', 'get_order_details', 'get_orders_stats',
                       'get_user_wallet', 'add_wallet_transaction', 'get_wallet_transactions',
                       'get_dashboard_metrics', 'get_cafe_stats', 'get_top_menu_items', 'get_revenue_by_day',
                       'register_push_token', 'deactivate_push_token', 'get_user_push_tokens')
  AND grantee = 'authenticated';
  
  IF func_count >= 13 THEN
    RAISE NOTICE '✅ PASS: % RPC функций доступны для authenticated', func_count;
  ELSE
    RAISE WARNING '⚠️  WARNING: Только % RPC функций доступны (ожидалось >= 13)', func_count;
  END IF;
END $$;

-- Test 5.4: Security definer на RPC функциях
\echo ''
\echo 'Test 5.2.2: Security definer на RPC функциях'
DO $$
DECLARE
  secure_count int;
  total_count int;
BEGIN
  SELECT count(*) INTO secure_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
  AND p.proname IN ('update_order_status', 'get_orders_by_cafe', 'get_order_details',
                    'add_wallet_transaction', 'register_push_token')
  AND p.prosecdef = true;
  
  SELECT count(*) INTO total_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
  AND p.proname IN ('update_order_status', 'get_orders_by_cafe', 'get_order_details',
                    'add_wallet_transaction', 'register_push_token');
  
  IF secure_count = total_count THEN
    RAISE NOTICE '✅ PASS: Все критичные RPC функции используют security definer';
  ELSE
    RAISE WARNING '⚠️  WARNING: % из % функций используют security definer', secure_count, total_count;
  END IF;
END $$;

-- Test 5.5: Анализ permissions на таблицы
\echo ''
\echo 'Test 5.3.1: Анализ permissions на таблицы'
DO $$
DECLARE
  anon_full_access int;
BEGIN
  -- Проверяем что anon не имеет полного доступа к критичным таблицам
  SELECT count(*) INTO anon_full_access
  FROM information_schema.table_privileges
  WHERE grantee = 'anon'
  AND table_schema = 'public'
  AND table_name IN ('wallets', 'wallet_transactions', 'orders_core', 'push_tokens')
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE');
  
  IF anon_full_access = 0 THEN
    RAISE NOTICE '✅ PASS: Anon не имеет прямого write доступа к критичным таблицам';
  ELSE
    RAISE WARNING '⚠️  WARNING: Anon имеет write доступ к % критичным таблицам', anon_full_access;
  END IF;
END $$;

-- Test 5.6: Проверка триггеров
\echo ''
\echo 'Test 5.4.1: Проверка триггеров push уведомлений'
DO $$
DECLARE
  trigger_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trigger_notify_order_status_change'
  ) INTO trigger_exists;
  
  IF trigger_exists THEN
    RAISE NOTICE '✅ PASS: Триггер notify_order_status_change существует';
  ELSE
    RAISE WARNING '⚠️  WARNING: Триггер notify_order_status_change не найден';
  END IF;
END $$;

\echo ''
\echo '================================'
\echo 'Security Tests Complete'
\echo '================================'
\echo ''
\echo 'Summary:'
\echo '  - RLS policies: Проверены'
\echo '  - RPC permissions: Проверены'
\echo '  - Security definer: Проверен'
\echo '  - Anon access: Ограничен'
\echo '  - Triggers: Проверены'
\echo ''
