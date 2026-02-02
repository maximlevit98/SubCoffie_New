-- Create necessary tables for Owner Admin Panel

-- Table: user_roles
CREATE TABLE IF NOT EXISTS user_roles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin', 'owner', 'customer')),
  created_at timestamptz DEFAULT NOW()
);

-- Table: accounts (for cafe owners)
CREATE TABLE IF NOT EXISTS accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name text,
  inn text,
  bank_details jsonb,
  created_at timestamptz DEFAULT NOW(),
  updated_at timestamptz DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_roles
CREATE POLICY "Users can view own role" ON user_roles
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policies for accounts
CREATE POLICY "Owners can view own account" ON accounts
  FOR ALL USING (auth.uid() = owner_user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_owner_user_id ON accounts(owner_user_id);

-- Now set up the test user
DO $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get the user ID
  SELECT id INTO v_user_id 
  FROM auth.users 
  WHERE email = 'levitm@algsoft.ru';

  IF v_user_id IS NOT NULL THEN
    -- Set role
    INSERT INTO user_roles (user_id, role)
    VALUES (v_user_id, 'owner')
    ON CONFLICT (user_id) DO UPDATE SET role = 'owner';

    -- Create account
    INSERT INTO accounts (owner_user_id, company_name, created_at)
    VALUES (v_user_id, 'Algsoft Coffee Company', NOW())
    ON CONFLICT (owner_user_id) DO NOTHING;

    RAISE NOTICE 'Successfully configured user: levitm@algsoft.ru';
    RAISE NOTICE 'User ID: %', v_user_id;
  ELSE
    RAISE WARNING 'User not found: levitm@algsoft.ru';
  END IF;
END $$;
