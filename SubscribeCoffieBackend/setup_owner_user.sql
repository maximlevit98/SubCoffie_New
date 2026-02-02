-- Create permanent test user for Owner Admin Panel
-- Email: levitm@algsoft.ru
-- Password: 1234567890

-- Insert user into auth.users (Supabase Auth)
-- Note: This uses Supabase's internal auth schema

DO $$
DECLARE
  v_user_id uuid;
  v_encrypted_password text;
BEGIN
  -- Check if user already exists
  SELECT id INTO v_user_id 
  FROM auth.users 
  WHERE email = 'levitm@algsoft.ru';

  IF v_user_id IS NULL THEN
    -- Generate new UUID for user
    v_user_id := gen_random_uuid();
    
    -- Create user with encrypted password
    -- Password: 1234567890
    -- This is a hashed version of the password
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      is_super_admin,
      role
    ) VALUES (
      v_user_id,
      '00000000-0000-0000-0000-000000000000',
      'levitm@algsoft.ru',
      crypt('1234567890', gen_salt('bf')),
      NOW(),
      NOW(),
      NOW(),
      '{"provider":"email","providers":["email"]}',
      '{}',
      false,
      'authenticated'
    );

    RAISE NOTICE 'Created user: levitm@algsoft.ru with ID: %', v_user_id;
  ELSE
    RAISE NOTICE 'User already exists with ID: %', v_user_id;
  END IF;

  -- Set user role to owner
  INSERT INTO user_roles (user_id, role)
  VALUES (v_user_id, 'owner')
  ON CONFLICT (user_id) DO UPDATE SET role = 'owner';

  RAISE NOTICE 'Set role to owner for user: %', v_user_id;

  -- Create account for this owner
  INSERT INTO accounts (id, owner_user_id, company_name, created_at)
  VALUES (
    gen_random_uuid(),
    v_user_id,
    'Algsoft Coffee Company',
    NOW()
  )
  ON CONFLICT (owner_user_id) DO NOTHING;

  RAISE NOTICE 'Created account for owner';

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error: %', SQLERRM;
END $$;
