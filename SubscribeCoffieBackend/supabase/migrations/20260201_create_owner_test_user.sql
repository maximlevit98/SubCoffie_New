-- Owner Admin Panel - Test User Setup
-- This creates a permanent test user for the Owner Admin Panel
-- Email: levitm@algsoft.ru
-- Password: 1234567890
-- Role: owner
--
-- Note: In Supabase, users are created via auth.users
-- This script should be run manually or via Supabase Admin API
--
-- For local development, you can create this user via Supabase Studio:
-- 1. Go to http://localhost:54323 (Supabase Studio)
-- 2. Navigate to Authentication > Users
-- 3. Click "Add User"
-- 4. Email: levitm@algsoft.ru
-- 5. Password: 1234567890
-- 6. Confirm email automatically
--
-- After creating the user in auth.users, this migration sets the role in profiles

DO $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get user ID (user must be created in Supabase Auth first)
  SELECT id INTO v_user_id 
  FROM auth.users 
  WHERE email = 'levitm@algsoft.ru'
  LIMIT 1;

  -- If user exists, set their role in profiles
  IF v_user_id IS NOT NULL THEN
    -- Update role in profiles table
    UPDATE profiles 
    SET role = 'owner' 
    WHERE id = v_user_id;
    
    IF NOT FOUND THEN
      -- If profile doesn't exist, create it
      INSERT INTO profiles (id, role, created_at)
      VALUES (v_user_id, 'owner', NOW())
      ON CONFLICT (id) DO UPDATE SET role = 'owner';
    END IF;
    
    RAISE NOTICE 'User role set to owner for email: levitm@algsoft.ru';
  ELSE
    RAISE NOTICE 'User not found. Please create user first in Supabase Auth.';
  END IF;
END $$;

-- Create a test account for this owner
INSERT INTO accounts (owner_user_id, company_name, created_at)
SELECT 
  id,
  'Test Owner Company',
  NOW()
FROM auth.users
WHERE email = 'levitm@algsoft.ru'
ON CONFLICT DO NOTHING;

-- Optional: Create a test cafe for this owner
INSERT INTO cafes (
  account_id,
  name,
  address,
  status,
  phone,
  email,
  created_at
)
SELECT 
  a.id,
  'Test Coffee Point',
  'Москва, ул. Тестовая, д. 1',
  'draft',
  '+7 (999) 123-45-67',
  'test@coffeepoint.ru',
  NOW()
FROM accounts a
JOIN auth.users u ON u.id = a.owner_user_id
WHERE u.email = 'levitm@algsoft.ru'
ON CONFLICT DO NOTHING;

COMMENT ON TABLE profiles IS 'Owner test user: levitm@algsoft.ru / password: 1234567890';
