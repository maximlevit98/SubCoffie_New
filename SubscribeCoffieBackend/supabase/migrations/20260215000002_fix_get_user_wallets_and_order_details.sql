-- ============================================================================
-- Fixes:
-- 1) get_user_wallets: resolve ambiguous `id` reference for admin callers
-- 2) get_order_details: restore compatible implementation for current schema
--    - use order_events_core instead of missing order_status_events
--    - keep enhanced user_profile payload
--    - keep authorization checks (admin / owner of cafe / order owner)
-- Date: 2026-02-15
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1) get_user_wallets
-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_user_wallets(p_user_id uuid)
RETURNS TABLE(
  id uuid,
  wallet_type wallet_type,
  balance_credits int,
  lifetime_top_up_credits int,
  cafe_id uuid,
  cafe_name text,
  network_id uuid,
  network_name text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_authenticated_user_id uuid;
  v_actor_role text;
  v_jwt_role text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  v_authenticated_user_id := auth.uid();
  v_jwt_role := auth.role();

  IF v_authenticated_user_id IS NOT NULL THEN
    IF v_authenticated_user_id <> p_user_id THEN
      -- NOTE: qualify columns to avoid collision with output column `id`
      SELECT pr.role INTO v_actor_role
      FROM public.profiles pr
      WHERE pr.id = v_authenticated_user_id;

      IF COALESCE(v_actor_role, '') <> 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Cannot view other users wallets';
      END IF;
    END IF;
  ELSIF COALESCE(v_jwt_role, '') IN ('service_role', 'supabase_admin') OR session_user = 'postgres' THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Not authenticated. Please sign in.';
  END IF;

  RETURN QUERY
  SELECT
    w.id,
    w.wallet_type,
    w.balance_credits,
    w.lifetime_top_up_credits,
    w.cafe_id,
    c.name AS cafe_name,
    w.network_id,
    wn.name AS network_name,
    w.created_at
  FROM public.wallets w
  LEFT JOIN public.cafes c ON w.cafe_id = c.id
  LEFT JOIN public.wallet_networks wn ON w.network_id = wn.id
  WHERE w.user_id = p_user_id
  ORDER BY w.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_user_wallets IS
  'Returns wallets for user (own wallets/admin/service only)';

-- --------------------------------------------------------------------------
-- 2) get_order_details
-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_order_details(order_id_param uuid)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql
AS $$
DECLARE
  result jsonb;
  v_caller_role text;
  v_order_user_id uuid;
  v_order_cafe_id uuid;
  v_is_authorized boolean := false;
BEGIN
  -- Resolve order ownership context
  SELECT COALESCE(o.customer_user_id, o.user_id), o.cafe_id
  INTO v_order_user_id, v_order_cafe_id
  FROM public.orders_core o
  WHERE o.id = order_id_param;

  IF v_order_cafe_id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', order_id_param;
  END IF;

  -- Caller role
  SELECT pr.role
  INTO v_caller_role
  FROM public.profiles pr
  WHERE pr.id = auth.uid();

  -- Authorization: admin / owner of cafe / order owner
  IF v_caller_role = 'admin' THEN
    v_is_authorized := true;
  ELSIF v_caller_role = 'owner' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cafes c
      JOIN public.accounts a ON a.id = c.account_id
      WHERE c.id = v_order_cafe_id
        AND a.owner_user_id = auth.uid()
    ) INTO v_is_authorized;
  ELSIF v_order_user_id = auth.uid() THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Unauthorized: Cannot view this order';
  END IF;

  -- Build payload (enhanced with user profile)
  SELECT jsonb_build_object(
    'order', jsonb_build_object(
      'id', o.id,
      'cafe_id', o.cafe_id,
      'user_id', o.user_id,
      'customer_user_id', o.customer_user_id,
      'customer_name', o.customer_name,
      'customer_phone', o.customer_phone,
      'customer_notes', o.customer_notes,
      'status', o.status,
      'payment_status', o.payment_status,
      'order_type', o.order_type,
      'slot_time', o.slot_time,
      'payment_method', o.payment_method,
      'subtotal_credits', o.subtotal_credits,
      'total_credits', o.total_credits,
      'paid_credits', o.paid_credits,
      'bonus_used', o.bonus_used,
      'scheduled_ready_at', o.scheduled_ready_at,
      'eta_sec', o.eta_sec,
      'order_number', o.order_number,
      'created_at', o.created_at,
      'updated_at', o.updated_at,
      'wallet_id', o.wallet_id,
      'payment_transaction_id', o.payment_transaction_id,
      'user_profile', CASE
        WHEN p.id IS NOT NULL THEN jsonb_build_object(
          'id', p.id,
          'full_name', p.full_name,
          'email', p.email,
          'phone', p.phone,
          'avatar_url', p.avatar_url,
          'auth_provider', p.auth_provider,
          'created_at', p.created_at
        )
        ELSE NULL
      END
    ),
    'items', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', oi.id,
          'menu_item_id', oi.menu_item_id,
          'product_id', oi.product_id,
          'title', oi.title,
          'category', oi.category,
          'quantity', oi.quantity,
          'unit_credits', oi.unit_credits,
          'line_total', COALESCE(oi.line_total, oi.total_price_credits)
        )
        ORDER BY oi.created_at
      ) FILTER (WHERE oi.id IS NOT NULL),
      '[]'::jsonb
    ),
    'events', COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', e.id,
            'status', e.status,
            'created_at', e.created_at,
            'actor_user_id', NULL
          )
          ORDER BY e.created_at DESC
        )
        FROM public.order_events_core e
        WHERE e.order_id = o.id
      ),
      '[]'::jsonb
    )
  )
  INTO result
  FROM public.orders_core o
  LEFT JOIN public.order_items oi ON oi.order_id = o.id
  LEFT JOIN public.profiles p ON p.id = COALESCE(o.customer_user_id, o.user_id)
  WHERE o.id = order_id_param
  GROUP BY
    o.id, o.cafe_id, o.user_id, o.customer_user_id, o.customer_name,
    o.customer_phone, o.customer_notes, o.status, o.payment_status,
    o.order_type, o.slot_time, o.payment_method, o.subtotal_credits,
    o.total_credits, o.paid_credits, o.bonus_used, o.scheduled_ready_at,
    o.eta_sec, o.order_number, o.created_at, o.updated_at,
    o.wallet_id, o.payment_transaction_id,
    p.id, p.full_name, p.email, p.phone, p.avatar_url, p.auth_provider, p.created_at;

  IF result IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', order_id_param;
  END IF;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_details(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_order_details IS
  'Get order details with items, events, user profile and role-based access checks';
