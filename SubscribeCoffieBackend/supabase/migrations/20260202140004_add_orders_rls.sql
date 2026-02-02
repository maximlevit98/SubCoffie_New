-- Additional RLS policies for orders (complement existing ones)
-- Note: Basic owner/customer policies already exist from 20260201120000_owner_admin_panel_foundation.sql

-- Ensure RLS is enabled
ALTER TABLE public.orders_core ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Allow service role to bypass RLS (for server-side operations)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'orders_core' AND policyname = 'service_role_all_orders'
  ) THEN
    CREATE POLICY service_role_all_orders ON public.orders_core
      FOR ALL
      USING (auth.jwt()->>'role' = 'service_role');
  END IF;
END$$;

DO $$
BEGIN  
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'order_items' AND policyname = 'service_role_all_order_items'
  ) THEN
    CREATE POLICY service_role_all_order_items ON public.order_items
      FOR ALL
      USING (auth.jwt()->>'role' = 'service_role');
  END IF;
END$$;

-- Allow anonymous users to create orders (for guest checkout)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'orders_core' AND policyname = 'anon_create_orders'
  ) THEN
    CREATE POLICY anon_create_orders ON public.orders_core
      FOR INSERT
      WITH CHECK (true); -- Anonymous can create, we'll rely on app logic for validation
  END IF;
END$$;

-- Allow anonymous to insert order items (for their own orders during checkout)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'order_items' AND policyname = 'anon_create_order_items'
  ) THEN
    CREATE POLICY anon_create_order_items ON public.order_items
      FOR INSERT
      WITH CHECK (true); -- Will be validated by create_order RPC
  END IF;
END$$;

COMMENT ON POLICY service_role_all_orders ON public.orders_core IS 'Service role can perform all operations';
COMMENT ON POLICY anon_create_orders ON public.orders_core IS 'Anonymous users can create orders for guest checkout';
