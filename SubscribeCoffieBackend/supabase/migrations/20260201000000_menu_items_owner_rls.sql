-- Add RLS policies for menu_items table to allow owners to manage their cafes' menu items
-- Note: This migration requires the accounts table to exist (created in owner_admin_panel_foundation)

-- Only create policies if accounts table exists
DO $$
BEGIN
  -- Check if accounts table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'accounts'
  ) THEN
    -- Drop existing policies if they exist (for idempotency)
    DROP POLICY IF EXISTS "Owners can insert menu items" ON menu_items;
    DROP POLICY IF EXISTS "Owners can update menu items" ON menu_items;
    DROP POLICY IF EXISTS "Owners can delete menu items" ON menu_items;

    -- Владельцы могут добавлять позиции меню в свои кофейни
    EXECUTE 'CREATE POLICY "Owners can insert menu items"
    ON menu_items
    FOR INSERT
    WITH CHECK (
      cafe_id IN (
        SELECT cafes.id
        FROM cafes
        JOIN accounts ON cafes.account_id = accounts.id
        WHERE accounts.owner_user_id = auth.uid()
      )
    )';

    -- Владельцы могут обновлять позиции меню в своих кофейнях
    EXECUTE 'CREATE POLICY "Owners can update menu items"
    ON menu_items
    FOR UPDATE
    USING (
      cafe_id IN (
        SELECT cafes.id
        FROM cafes
        JOIN accounts ON cafes.account_id = accounts.id
        WHERE accounts.owner_user_id = auth.uid()
      )
    )';

    -- Владельцы могут удалять позиции меню в своих кофейнях
    EXECUTE 'CREATE POLICY "Owners can delete menu items"
    ON menu_items
    FOR DELETE
    USING (
      cafe_id IN (
        SELECT cafes.id
        FROM cafes
        JOIN accounts ON cafes.account_id = accounts.id
        WHERE accounts.owner_user_id = auth.uid()
      )
    )';

    EXECUTE 'COMMENT ON POLICY "Owners can insert menu items" ON menu_items IS 
    ''Allows cafe owners to add menu items to their own cafes''';

    EXECUTE 'COMMENT ON POLICY "Owners can update menu items" ON menu_items IS 
    ''Allows cafe owners to update menu items in their own cafes''';

    EXECUTE 'COMMENT ON POLICY "Owners can delete menu items" ON menu_items IS 
    ''Allows cafe owners to delete menu items from their own cafes''';
    
    RAISE NOTICE 'Created owner RLS policies for menu_items';
  ELSE
    RAISE NOTICE 'Skipping menu_items owner RLS policies - accounts table does not exist yet. Will be created by owner_admin_panel_foundation migration.';
  END IF;
END$$;
