-- Complete setup for Owner Admin Panel test user
-- Run this after Supabase is started

-- Step 1: Create user in auth.users with proper Supabase format
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  invited_at,
  confirmation_token,
  confirmation_sent_at,
  recovery_token,
  recovery_sent_at,
  email_change_token_new,
  email_change,
  email_change_sent_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  created_at,
  updated_at,
  phone,
  phone_confirmed_at,
  phone_change,
  phone_change_token,
  phone_change_sent_at,
  email_change_token_current,
  email_change_confirm_status,
  banned_until,
  reauthentication_token,
  reauthentication_sent_at,
  is_sso_user,
  deleted_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid,
  'authenticated',
  'authenticated',
  'levitm@algsoft.ru',
  '$2a$10$XYZ123ABC456DEF789GHI'::text, -- Placeholder, will be updated
  NOW(),
  NULL,
  '',
  NULL,
  '',
  NULL,
  '',
  '',
  NULL,
  NULL,
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  false,
  NOW(),
  NOW(),
  NULL,
  NULL,
  '',
  '',
  NULL,
  '',
  0,
  NULL,
  '',
  NULL,
  false,
  NULL
)
ON CONFLICT (id) DO UPDATE SET
  email = 'levitm@algsoft.ru',
  email_confirmed_at = NOW(),
  updated_at = NOW();

-- Step 2: Create identity
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid,
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid,
  '{"sub":"a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d","email":"levitm@algsoft.ru"}'::jsonb,
  'email',
  NOW(),
  NOW(),
  NOW()
)
ON CONFLICT (provider, id) DO NOTHING;

-- Step 3: Set user role
INSERT INTO user_roles (user_id, role, created_at)
VALUES ('a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid, 'owner', NOW())
ON CONFLICT (user_id) DO UPDATE SET role = 'owner';

-- Step 4: Create account
INSERT INTO accounts (id, owner_user_id, company_name, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid,
  'Algsoft Coffee Company',
  NOW(),
  NOW()
)
ON CONFLICT (owner_user_id) DO NOTHING;

-- Step 5: Create a test cafe
INSERT INTO cafes (
  id,
  account_id,
  name,
  address,
  status,
  phone,
  email,
  description,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid(),
  a.id,
  'Coffee Point Test',
  'Москва, ул. Тестовая, 1',
  'published',
  '+7 (999) 123-45-67',
  'test@coffeepoint.ru',
  'Тестовая кофейня для Owner Admin Panel',
  NOW(),
  NOW()
FROM accounts a
WHERE a.owner_user_id = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid
ON CONFLICT DO NOTHING;

-- Verify setup
DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Owner Admin Panel Test User Created!';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Email: levitm@algsoft.ru';
  RAISE NOTICE 'Password: 1234567890';
  RAISE NOTICE 'User ID: a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';
  RAISE NOTICE 'Role: owner';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Login at: http://localhost:3001/login';
  RAISE NOTICE 'Dashboard: http://localhost:3001/admin/owner/dashboard';
  RAISE NOTICE '============================================';
END $$;
