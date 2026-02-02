-- Create function to get owner's cafes
CREATE OR REPLACE FUNCTION get_owner_cafes()
RETURNS TABLE (
  id uuid,
  name text,
  address text,
  status text,
  phone text,
  email text,
  description text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Get cafes owned by the current user
  RETURN QUERY
  SELECT 
    c.id,
    c.name,
    c.address,
    c.status,
    c.phone,
    c.email,
    c.description,
    c.created_at,
    c.updated_at
  FROM cafes c
  JOIN accounts a ON c.account_id = a.id
  WHERE a.owner_user_id = auth.uid()
  ORDER BY c.created_at DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_owner_cafes() TO authenticated;

COMMENT ON FUNCTION get_owner_cafes() IS 'Returns all cafes owned by the current authenticated user';
