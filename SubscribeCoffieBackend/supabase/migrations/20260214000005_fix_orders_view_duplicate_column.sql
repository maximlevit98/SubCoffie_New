-- Migration: Fix orders_with_user_info view duplicate customer_phone column
-- Date: 2026-02-14
-- Purpose: Rename profile phone column to avoid conflict with orders_core.customer_phone

DROP VIEW IF EXISTS public.orders_with_user_info;

CREATE OR REPLACE VIEW public.orders_with_user_info AS
SELECT 
  o.*,
  p.full_name as profile_full_name,
  p.email as profile_email,
  p.phone as profile_phone,  -- Renamed from customer_phone to avoid conflict
  p.avatar_url as profile_avatar,
  p.auth_provider as profile_auth_provider,
  p.created_at as profile_registered_at
FROM public.orders_core o
LEFT JOIN public.profiles p ON o.customer_user_id = p.id;

COMMENT ON VIEW public.orders_with_user_info IS 'Orders with user profile information (profile_* columns to avoid conflicts with orders_core columns)';

-- Grant permissions on view
GRANT SELECT ON public.orders_with_user_info TO authenticated;
GRANT SELECT ON public.orders_with_user_info TO anon;
