-- Update get_order_details RPC to include user profile information

CREATE OR REPLACE FUNCTION get_order_details(order_id_param UUID)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  result JSONB;
BEGIN
  -- Получаем заказ с items, events, и профилем пользователя
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
      -- Add user profile information
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
          'line_total', oi.line_total
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
            'actor_user_id', e.actor_user_id
          )
          ORDER BY e.created_at DESC
        )
        FROM order_status_events e
        WHERE e.order_id = o.id
      ),
      '[]'::jsonb
    )
  ) INTO result
  FROM orders_core o
  LEFT JOIN order_items oi ON oi.order_id = o.id
  LEFT JOIN profiles p ON p.id = o.customer_user_id
  WHERE o.id = order_id_param
  GROUP BY o.id, o.cafe_id, o.user_id, o.customer_user_id, o.customer_name, 
           o.customer_phone, o.customer_notes, o.status, o.payment_status, 
           o.order_type, o.slot_time, o.payment_method, o.subtotal_credits, 
           o.total_credits, o.paid_credits, o.bonus_used, o.scheduled_ready_at, 
           o.eta_sec, o.order_number, o.created_at, o.updated_at,
           p.id, p.full_name, p.email, p.phone, p.avatar_url, p.auth_provider, p.created_at;

  IF result IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', order_id_param;
  END IF;

  RETURN result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_order_details TO authenticated;

COMMENT ON FUNCTION get_order_details IS 'Get order details with items, events, and user profile information';
