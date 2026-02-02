#!/bin/bash

# Скрипт для создания/обновления тестовых пользователей в Supabase Auth
# Использование: ./create_test_users.sh

echo "🔐 Создание тестовых пользователей..."

psql postgresql://postgres:postgres@127.0.0.1:54322/postgres << 'EOF'

-- Удаляем существующих тестовых пользователей (если нужно)
-- DELETE FROM auth.users WHERE email IN ('admin@coffie.local', 'owner@coffie.local');

-- Обновляем пароль для админа (если существует)
UPDATE auth.users
SET 
  encrypted_password = crypt('admin123', gen_salt('bf')),
  email_confirmed_at = NOW(),
  raw_user_meta_data = '{"role":"admin"}',
  updated_at = NOW()
WHERE email = 'admin@coffie.local';

-- Создаём админа если не существует
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@coffie.local',
  crypt('admin123', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"admin"}',
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'admin@coffie.local'
);

-- Обновляем пароль для владельца (если существует)
UPDATE auth.users
SET 
  encrypted_password = crypt('owner123', gen_salt('bf')),
  email_confirmed_at = NOW(),
  raw_user_meta_data = '{"role":"cafe_owner"}',
  updated_at = NOW()
WHERE email = 'owner@coffie.local';

-- Создаём владельца если не существует
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'owner@coffie.local',
  crypt('owner123', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"cafe_owner"}',
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'owner@coffie.local'
);

-- Показываем созданных пользователей
SELECT 
  email,
  email_confirmed_at IS NOT NULL as confirmed,
  raw_user_meta_data->>'role' as role,
  created_at
FROM auth.users
WHERE email IN ('admin@coffie.local', 'owner@coffie.local')
ORDER BY email;

EOF

echo ""
echo "✅ Готово!"
echo ""
echo "📋 Credentials:"
echo ""
echo "👨‍💼 Администратор:"
echo "   Email:    admin@coffie.local"
echo "   Password: admin123"
echo ""
echo "🏪 Владелец кафе:"
echo "   Email:    owner@coffie.local"
echo "   Password: owner123"
echo ""
echo "🌐 Login URL: http://localhost:3000/login"
echo ""
