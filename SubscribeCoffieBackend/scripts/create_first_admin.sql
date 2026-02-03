-- ═══════════════════════════════════════════════════════════════════════════════
-- CREATE FIRST ADMIN USER
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- This script creates the first admin user for the platform.
-- Run this ONCE after initial migration.
--
-- Date: 2026-02-04
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- Step 1: Check if admin already exists
DO $$
DECLARE
  existing_admin_id UUID;
BEGIN
  SELECT id INTO existing_admin_id
  FROM auth.users
  WHERE email = 'admin@coffie.local';
  
  IF existing_admin_id IS NOT NULL THEN
    RAISE NOTICE '⚠️  Admin user already exists with email: admin@coffie.local';
    RAISE NOTICE '🆔 User ID: %', existing_admin_id;
    RAISE NOTICE '';
    RAISE NOTICE '💡 If you forgot the password, reset it in Supabase Studio:';
    RAISE NOTICE '   http://127.0.0.1:54323 → Authentication → Users → Reset Password';
    RAISE NOTICE '';
    RAISE EXCEPTION 'Admin already exists. Aborting to prevent duplicate.';
  END IF;
END $$;

-- Step 2: Insert user into auth.users (Supabase Auth)
-- Password: Admin123! (change this in production!)
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  recovery_sent_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@coffie.local',
  crypt('Admin123!', gen_salt('bf')),  -- Password: Admin123!
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"System Admin"}',
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
)
RETURNING id, email;

-- Step 2: Update profile role to 'admin'
-- The trigger should create profile automatically, but we ensure role is set
UPDATE public.profiles
SET 
  role = 'admin',
  full_name = 'System Admin',
  updated_at = NOW()
WHERE email = 'admin@coffie.local';

-- Step 3: Verify admin was created
DO $$
DECLARE
  admin_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO admin_count
  FROM public.profiles
  WHERE email = 'admin@coffie.local' AND role = 'admin';
  
  IF admin_count > 0 THEN
    RAISE NOTICE '✅ Admin user created successfully!';
    RAISE NOTICE '📧 Email: admin@coffie.local';
    RAISE NOTICE '🔑 Password: Admin123!';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Change the password after first login in production!';
  ELSE
    RAISE WARNING '❌ Failed to create admin user. Please check manually.';
  END IF;
END $$;

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOGIN CREDENTIALS
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Email: admin@coffie.local
-- Password: Admin123!
--
-- ⚠️  SECURITY: Change this password immediately after first login in production!
-- ═══════════════════════════════════════════════════════════════════════════════
