-- Test Data Seeding
-- Создает тестовые данные для unit тестов RPC функций

-- Очистка тестовых данных (если есть)
DELETE FROM public.order_items WHERE order_id IN (SELECT id FROM public.orders_core WHERE customer_phone LIKE 'test-%');
DELETE FROM public.order_events WHERE order_id IN (SELECT id FROM public.orders_core WHERE customer_phone LIKE 'test-%');
DELETE FROM public.orders_core WHERE customer_phone LIKE 'test-%';
DELETE FROM public.wallet_transactions WHERE wallet_id IN (SELECT id FROM public.wallets WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE 'test%@test.com'));
DELETE FROM public.wallets WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE 'test%@test.com');
DELETE FROM public.menu_items WHERE cafe_id IN (SELECT id FROM public.cafes WHERE name LIKE 'Test Cafe%');
DELETE FROM public.cafes WHERE name LIKE 'Test Cafe%';

-- Создаем тестовое кафе
INSERT INTO public.cafes (id, name, address, latitude, longitude, phone, email, rating, mode)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Test Cafe 1', 'Test Address 1', 55.7558, 37.6173, '+79991234567', 'test1@cafe.com', 4.5, 'standard'),
  ('22222222-2222-2222-2222-222222222222', 'Test Cafe 2', 'Test Address 2', 55.7558, 37.6173, '+79991234568', 'test2@cafe.com', 4.8, 'standard')
ON CONFLICT (id) DO NOTHING;

-- Создаем тестовые позиции меню
INSERT INTO public.menu_items (id, cafe_id, name, category, price_credits, is_available, prep_time_sec)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Coffee', 'hot_drinks', 100, true, 180),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'Test Cake', 'desserts', 150, true, 0),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'Test Latte', 'hot_drinks', 120, true, 200)
ON CONFLICT (id) DO NOTHING;

-- Создаем тестовые пользователи (для кошельков)
-- Примечание: В реальной БД это должно быть через auth.users
-- Для тестов используем mock UUID
DO $$
DECLARE
  test_user_1 uuid := '33333333-3333-3333-3333-333333333333';
  test_user_2 uuid := '44444444-4444-4444-4444-444444444444';
  test_wallet_1 uuid;
  test_wallet_2 uuid;
BEGIN
  -- Создаем кошельки если не существуют
  INSERT INTO public.wallets (user_id, balance, bonus_balance, lifetime_topup)
  VALUES (test_user_1, 500, 50, 1000)
  ON CONFLICT (user_id) DO UPDATE
  SET balance = 500, bonus_balance = 50, lifetime_topup = 1000
  RETURNING id INTO test_wallet_1;

  INSERT INTO public.wallets (user_id, balance, bonus_balance, lifetime_topup)
  VALUES (test_user_2, 0, 0, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET balance = 0, bonus_balance = 0, lifetime_topup = 0
  RETURNING id INTO test_wallet_2;

  -- Создаем тестовые заказы
  INSERT INTO public.orders_core (id, cafe_id, customer_phone, status, subtotal_credits, bonus_used, paid_credits, created_at)
  VALUES
    ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'test-user-1', 'created', 250, 0, 250, now() - interval '2 days'),
    ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'test-user-1', 'paid', 300, 50, 250, now() - interval '1 day'),
    ('77777777-7777-7777-7777-777777777777', '22222222-2222-2222-2222-222222222222', 'test-user-2', 'preparing', 120, 0, 120, now() - interval '1 hour')
  ON CONFLICT (id) DO NOTHING;

  -- Создаем order items
  INSERT INTO public.order_items (order_id, menu_item_id, title, category, quantity, unit_credits, line_total)
  VALUES
    ('55555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Coffee', 'hot_drinks', 2, 100, 200),
    ('55555555-5555-5555-5555-555555555555', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Test Cake', 'desserts', 1, 150, 150),
    ('66666666-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Coffee', 'hot_drinks', 3, 100, 300),
    ('77777777-7777-7777-7777-777777777777', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Test Latte', 'hot_drinks', 1, 120, 120)
  ON CONFLICT DO NOTHING;

  -- Создаем order events
  INSERT INTO public.order_events_core (order_id, status, created_at)
  VALUES
    ('55555555-5555-5555-5555-555555555555', 'created', now() - interval '2 days'),
    ('66666666-6666-6666-6666-666666666666', 'created', now() - interval '1 day'),
    ('66666666-6666-6666-6666-666666666666', 'paid', now() - interval '1 day' + interval '5 minutes'),
    ('77777777-7777-7777-7777-777777777777', 'created', now() - interval '1 hour'),
    ('77777777-7777-7777-7777-777777777777', 'paid', now() - interval '50 minutes'),
    ('77777777-7777-7777-7777-777777777777', 'preparing', now() - interval '40 minutes')
  ON CONFLICT DO NOTHING;
END $$;

-- Подтверждение
SELECT 'Test data seeded successfully' AS result;
SELECT count(*) AS test_cafes FROM public.cafes WHERE name LIKE 'Test Cafe%';
SELECT count(*) AS test_orders FROM public.orders WHERE customer_phone LIKE 'test-%';
SELECT count(*) AS test_wallets FROM public.wallets WHERE user_id IN ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444');
