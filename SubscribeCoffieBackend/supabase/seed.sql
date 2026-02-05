-- ============================================================================
-- SEED DATA для разработки
-- ============================================================================
-- Этот скрипт автоматически создаёт тестовые данные после db reset
-- Включает: тестового owner пользователя, аккаунт, кофейни и меню
-- ============================================================================

DO $$
DECLARE
  v_admin_user_id uuid;
  v_owner_user_id uuid;
  v_account_id uuid;
  v_cafe_id uuid;
  v_cafe2_id uuid;
BEGIN
  RAISE NOTICE '🌱 Starting seed data creation...';

  -- ============================================================================
  -- 1. Создать admin пользователя
  -- ============================================================================
  
  RAISE NOTICE '👑 Creating admin user...';
  
  -- Проверяем, существует ли уже admin
  SELECT id INTO v_admin_user_id 
  FROM auth.users 
  WHERE email = 'admin@coffie.local';

  IF v_admin_user_id IS NULL THEN
    -- Создаём admin пользователя
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      confirmation_sent_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      is_super_admin,
      confirmation_token,
      email_change,
      email_change_token_new,
      email_change_token_current,
      recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      gen_random_uuid(),
      'authenticated',
      'authenticated',
      'admin@coffie.local',
      crypt('Admin123!', gen_salt('bf')), -- password: Admin123!
      NOW(),
      NOW(),
      NOW(),
      NOW(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"System Admin"}',
      FALSE,
      '',
      '',
      '',
      '',
      ''
    )
    RETURNING id INTO v_admin_user_id;

    RAISE NOTICE '✅ Admin user created: %', v_admin_user_id;
  ELSE
    RAISE NOTICE 'ℹ️  Admin user already exists: %', v_admin_user_id;
  END IF;

  -- Создать/обновить профиль admin с ролью admin
  INSERT INTO public.profiles (id, email, full_name, role, created_at, updated_at)
  VALUES (
    v_admin_user_id,
    'admin@coffie.local',
    'System Admin',
    'admin',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    role = 'admin',
    full_name = 'System Admin',
    updated_at = NOW();

  RAISE NOTICE '✅ Admin profile created with admin role';

  -- ============================================================================
  -- 2. Создать тестового owner пользователя через auth.users
  -- ============================================================================
  
  -- Проверяем, существует ли уже пользователь
  SELECT id INTO v_owner_user_id 
  FROM auth.users 
  WHERE email = 'levitm@algsoft.ru';

  IF v_owner_user_id IS NULL THEN
    RAISE NOTICE '👤 Creating test owner user...';
    
    -- Создаём пользователя напрямую в auth.users (только для локальной разработки!)
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      confirmation_sent_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      is_super_admin,
      confirmation_token,
      email_change,
      email_change_token_new,
      email_change_token_current,
      recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      gen_random_uuid(),
      'authenticated',
      'authenticated',
      'levitm@algsoft.ru',
      crypt('1234567890', gen_salt('bf')), -- password: 1234567890
      NOW(),
      NOW(),
      NOW(),
      NOW(),
      '{"provider":"email","providers":["email"]}',
      '{}',
      false,
      '',
      '',
      '',
      '',
      ''
    )
    RETURNING id INTO v_owner_user_id;

    RAISE NOTICE '✅ Test owner user created: %', v_owner_user_id;
  ELSE
    RAISE NOTICE '✅ Test owner user already exists: %', v_owner_user_id;
  END IF;

  -- ============================================================================
  -- 2. Создать профиль с ролью owner
  -- ============================================================================
  
  INSERT INTO public.profiles (id, role, full_name, phone, created_at)
  VALUES (v_owner_user_id, 'owner', 'Maxim Levit', '+79991234567', NOW())
  ON CONFLICT (id) DO UPDATE 
  SET role = 'owner', full_name = 'Maxim Levit';

  RAISE NOTICE '✅ Profile created with owner role';

  -- ============================================================================
  -- 3. Создать аккаунт владельца
  -- ============================================================================
  
  INSERT INTO public.accounts (
    id,
    owner_user_id,
    company_name,
    inn,
    legal_address,
    contact_phone,
    contact_email,
    created_at
  ) VALUES (
    gen_random_uuid(),
    v_owner_user_id,
    'Test Coffee Company LLC',
    '1234567890',
    'Москва, ул. Тестовая, д. 1',
    '+7 (999) 123-45-67',
    'levitm@algsoft.ru',
    NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_account_id;

  IF v_account_id IS NULL THEN
    SELECT id INTO v_account_id 
    FROM public.accounts 
    WHERE owner_user_id = v_owner_user_id 
    LIMIT 1;
  END IF;

  RAISE NOTICE '✅ Account created: %', v_account_id;

  -- ============================================================================
  -- 4. Создать тестовые кофейни
  -- ============================================================================
  
  -- Кофейня 1: Полностью настроенная
  INSERT INTO public.cafes (
    id,
    account_id,
    name,
    address,
    status,
    phone,
    email,
    description,
    latitude,
    longitude,
    mode,
    eta_minutes,
    max_active_orders,
    supports_citypass,
    opening_time,
    closing_time,
    logo_url,
    cover_url,
    created_at
  ) VALUES (
    'e2bcac65-e503-416e-a428-97b4712d270b',
    v_account_id,
    'Test Coffee Point',
    'Москва, Тверская ул., д. 5',
    'published',
    '+7 (495) 123-45-67',
    'coffee@test.ru',
    'Уютная кофейня в центре Москвы с авторским кофе',
    55.7558,
    37.6173,
    'open',
    15,
    10,
    true,
    '08:00',
    '22:00',
    'https://placehold.co/200x200/png?text=Logo',
    'https://placehold.co/800x400/png?text=Cover',
    NOW()
  )
  ON CONFLICT (id) DO UPDATE 
  SET status = 'published', mode = 'open', account_id = v_account_id
  RETURNING id INTO v_cafe_id;

  RAISE NOTICE '✅ Cafe 1 created: % (%)', v_cafe_id, 'Test Coffee Point';

  -- Кофейня 2: В состоянии draft
  INSERT INTO public.cafes (
    id,
    account_id,
    name,
    address,
    status,
    phone,
    email,
    description,
    latitude,
    longitude,
    mode,
    eta_minutes,
    max_active_orders,
    supports_citypass,
    opening_time,
    closing_time,
    created_at
  ) VALUES (
    gen_random_uuid(),
    v_account_id,
    'Coffee Lab (Draft)',
    'Москва, Арбат ул., д. 15',
    'draft',
    '+7 (495) 987-65-43',
    'lab@test.ru',
    'Экспериментальная кофейня (в разработке)',
    55.7522,
    37.6156,
    'closed',
    20,
    5,
    false,
    '09:00',
    '21:00',
    NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_cafe2_id;

  RAISE NOTICE '✅ Cafe 2 created: % (%)', v_cafe2_id, 'Coffee Lab (Draft)';

  -- ============================================================================
  -- 5. Создать меню для первой кофейни
  -- ============================================================================
  
  -- Категория: Эспрессо напитки
  INSERT INTO public.menu_items (
    cafe_id, name, title, description, category, price_credits, 
    is_available, sort_order, prep_time_sec
  ) VALUES
    (v_cafe_id, 'Эспрессо', 'Эспрессо', 'Классический итальянский эспрессо', 'drinks', 150, true, 1, 180),
    (v_cafe_id, 'Американо', 'Американо', 'Эспрессо с горячей водой', 'drinks', 180, true, 2, 180),
    (v_cafe_id, 'Капучино', 'Капучино', 'Эспрессо с молочной пеной', 'drinks', 220, true, 3, 240),
    (v_cafe_id, 'Латте', 'Латте', 'Кофе с большим количеством молока', 'drinks', 240, true, 4, 240),
    (v_cafe_id, 'Флэт Уайт', 'Флэт Уайт', 'Двойной эспрессо с микропеной', 'drinks', 260, true, 5, 240)
  ON CONFLICT DO NOTHING;

  -- Категория: Альтернатива
  INSERT INTO public.menu_items (
    cafe_id, name, title, description, category, price_credits, 
    is_available, sort_order, prep_time_sec
  ) VALUES
    (v_cafe_id, 'Фильтр кофе', 'Фильтр кофе', 'Свежезаваренный фильтр кофе', 'drinks', 200, true, 6, 300),
    (v_cafe_id, 'Кемекс', 'Кемекс', 'Кофе, заваренный в кемексе', 'drinks', 350, true, 7, 360),
    (v_cafe_id, 'Аэропресс', 'Аэропресс', 'Кофе из аэропресса', 'drinks', 280, true, 8, 300)
  ON CONFLICT DO NOTHING;

  -- Категория: Холодные напитки
  INSERT INTO public.menu_items (
    cafe_id, name, title, description, category, price_credits, 
    is_available, sort_order, prep_time_sec
  ) VALUES
    (v_cafe_id, 'Колд брю', 'Колд брю', 'Холодный кофе медленной экстракции', 'drinks', 280, true, 9, 60),
    (v_cafe_id, 'Айс латте', 'Айс латте', 'Латте со льдом', 'drinks', 260, true, 10, 180),
    (v_cafe_id, 'Фраппе', 'Фраппе', 'Взбитый холодный кофе', 'drinks', 290, true, 11, 240)
  ON CONFLICT DO NOTHING;

  -- Категория: Еда
  INSERT INTO public.menu_items (
    cafe_id, name, title, description, category, price_credits, 
    is_available, sort_order, prep_time_sec
  ) VALUES
    (v_cafe_id, 'Круассан классический', 'Круассан классический', 'Свежевыпеченный французский круассан', 'food', 180, true, 20, 60),
    (v_cafe_id, 'Круассан с шоколадом', 'Круассан с шоколадом', 'Круассан с бельгийским шоколадом', 'food', 220, true, 21, 60),
    (v_cafe_id, 'Чизкейк', 'Чизкейк', 'Нежный чизкейк Нью-Йорк', 'food', 350, true, 22, 60),
    (v_cafe_id, 'Сэндвич с курицей', 'Сэндвич с курицей', 'Сэндвич с куриной грудкой и овощами', 'food', 380, true, 23, 300),
    (v_cafe_id, 'Панини ветчина-сыр', 'Панини ветчина-сыр', 'Горячий панини с ветчиной и сыром', 'food', 360, true, 24, 240)
  ON CONFLICT DO NOTHING;

  RAISE NOTICE '✅ Menu items created (16 items)';

  -- ============================================================================
  -- 6. Создать тестовый заказ
  -- ============================================================================
  
  DECLARE
    v_order_id uuid;
    v_espresso_id uuid;
    v_croissant_id uuid;
  BEGIN
    -- Получить ID позиций меню
    SELECT id INTO v_espresso_id FROM public.menu_items 
    WHERE cafe_id = v_cafe_id AND name = 'Эспрессо' LIMIT 1;
    
    SELECT id INTO v_croissant_id FROM public.menu_items 
    WHERE cafe_id = v_cafe_id AND name = 'Круассан классический' LIMIT 1;

    IF v_espresso_id IS NOT NULL AND v_croissant_id IS NOT NULL THEN
      -- Создать заказ
      INSERT INTO public.orders_core (
        cafe_id,
        customer_user_id,
        user_id,
        order_type,
        customer_name,
        customer_phone,
        customer_notes,
        payment_method,
        status,
        payment_status,
        subtotal_credits,
        total_credits,
        paid_credits,
        created_at
      ) VALUES (
        v_cafe_id,
        v_owner_user_id, -- для теста используем owner как клиента
        v_owner_user_id,
        'now',
        'Test Customer',
        '+79991234567',
        'Тестовый заказ для демо',
        'wallet',
        'created',
        'paid',
        330, -- 150 + 180
        330,
        330,
        NOW() - INTERVAL '1 hour' -- заказ был час назад
      )
      RETURNING id INTO v_order_id;

      -- Добавить позиции заказа
      INSERT INTO public.order_items (
        order_id, menu_item_id, item_name, base_price_credits, 
        quantity, title, unit_credits, category, total_price_credits
      ) VALUES
        (v_order_id, v_espresso_id, 'Эспрессо', 150, 1, 'Эспрессо', 150, 'drinks', 150),
        (v_order_id, v_croissant_id, 'Круассан классический', 180, 1, 'Круассан классический', 180, 'food', 180);

      RAISE NOTICE '✅ Test order created: % (330 credits)', v_order_id;
    END IF;
  END;

  -- ============================================================================
  -- Финальное сообщение
  -- ============================================================================
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 ============================================';
  RAISE NOTICE '🎉 SEED DATA УСПЕШНО СОЗДАН!';
  RAISE NOTICE '🎉 ============================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Учетные данные для входа:';
  RAISE NOTICE '   Email: levitm@algsoft.ru';
  RAISE NOTICE '   Password: 1234567890';
  RAISE NOTICE '';
  RAISE NOTICE '🏪 Создано:';
  RAISE NOTICE '   - 1 owner пользователь';
  RAISE NOTICE '   - 1 аккаунт владельца';
  RAISE NOTICE '   - 2 кофейни (1 published, 1 draft)';
  RAISE NOTICE '   - 16 позиций меню';
  RAISE NOTICE '   - 1 тестовый заказ';
  RAISE NOTICE '';
  RAISE NOTICE '🌐 Ссылки:';
  RAISE NOTICE '   - Admin Panel: http://localhost:3000';
  RAISE NOTICE '   - Supabase Studio: http://localhost:54323';
  RAISE NOTICE '';

END $$;

-- ============================================================================
-- DEV-ONLY: Mock Payment Functions
-- ============================================================================
-- These functions simulate instant payment processing without real money
-- Required for: local development, demos, testing
-- Production: These functions should NOT exist in production
-- See: PAYMENT_SECURITY.md and seed_dev_mock_payments.sql
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🚨 Loading DEV-ONLY mock payment functions...';
END $$;

-- ============================================================================
-- MOCK PAYMENT FUNCTIONS
-- ============================================================================
-- NOTE: mock_wallet_topup is now defined in migration:
--       20260205000006_add_payment_idempotency.sql
-- This provides idempotency support and is the canonical version.
-- ============================================================================

-- Function: mock_direct_order_payment
CREATE OR REPLACE FUNCTION public.mock_direct_order_payment(
  p_order_id uuid,
  p_amount int,
  p_payment_method_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_commission int;
  v_transaction_id uuid;
  v_mock_provider_id text;
BEGIN
  SELECT user_id INTO v_user_id FROM public.orders_core WHERE id = p_order_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  v_commission := public.calculate_commission(p_amount, 'direct_order');
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  INSERT INTO public.payment_transactions (
    user_id, order_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, provider_transaction_id, completed_at
  ) VALUES (
    v_user_id, p_order_id, p_amount, v_commission,
    'order_payment', p_payment_method_id, 'completed', v_mock_provider_id, NOW()
  ) RETURNING id INTO v_transaction_id;

  UPDATE public.orders_core
  SET payment_status = 'paid', updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true, 'transaction_id', v_transaction_id,
    'amount', p_amount, 'commission', v_commission,
    'provider_transaction_id', v_mock_provider_id,
    'provider', 'mock', 'mock_mode', true
  );
END;
$$;


-- GRANT EXECUTE ON FUNCTION public.mock_wallet_topup(uuid, int, uuid) TO authenticated, anon;  -- Now in migration
GRANT EXECUTE ON FUNCTION public.mock_direct_order_payment(uuid, int, uuid) TO authenticated, anon;

-- COMMENT ON FUNCTION public.mock_wallet_topup IS '🚨 DEV-ONLY: Mock simulation of wallet top-up (instant, no real money)';  -- Now in migration
COMMENT ON FUNCTION public.mock_direct_order_payment IS '🚨 DEV-ONLY: Mock simulation of direct payment (instant, no real money)';

DO $$
BEGIN
  RAISE NOTICE '✅ Mock payment functions loaded (DEV environment only)';
  RAISE NOTICE '⚠️  These provide instant credits WITHOUT real money';
END $$;

-- ============================================================================
-- END OF SEED DATA
-- ============================================================================
-- Admin user now created at the beginning of seed script with proper role
-- ============================================================================