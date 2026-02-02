-- Add missing fields to cafes table for Owner Admin Panel
ALTER TABLE cafes 
  ADD COLUMN IF NOT EXISTS account_id uuid REFERENCES accounts(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'draft' CHECK (status IN ('draft', 'moderation', 'published', 'paused', 'rejected'));

-- Create index for account_id
CREATE INDEX IF NOT EXISTS idx_cafes_account_id ON cafes(account_id);

-- Update RLS policy to allow owners to see their cafes
DROP POLICY IF EXISTS "Owners can view own cafes" ON cafes;
CREATE POLICY "Owners can view own cafes" ON cafes
  FOR SELECT
  USING (
    account_id IN (
      SELECT id FROM accounts WHERE owner_user_id = auth.uid()
    )
  );

-- Allow owners to update their cafes
DROP POLICY IF EXISTS "Owners can update own cafes" ON cafes;
CREATE POLICY "Owners can update own cafes" ON cafes
  FOR UPDATE
  USING (
    account_id IN (
      SELECT id FROM accounts WHERE owner_user_id = auth.uid()
    )
  );

-- Allow owners to insert cafes
DROP POLICY IF EXISTS "Owners can insert cafes" ON cafes;  
CREATE POLICY "Owners can insert cafes" ON cafes
  FOR INSERT
  WITH CHECK (
    account_id IN (
      SELECT id FROM accounts WHERE owner_user_id = auth.uid()
    )
  );

COMMENT ON COLUMN cafes.account_id IS 'Link to owner account';
COMMENT ON COLUMN cafes.status IS 'Publication status: draft, moderation, published, paused, rejected';
