-- ============================================================================
-- Fix admin_get_wallet_orders: use canonical orders_core bonus column
-- Date: 2026-02-15
-- ============================================================================

CREATE OR REPLACE FUNCTION admin_get_wallet_orders(
  p_wallet_id uuid,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  order_id uuid,
  order_number text,
  created_at timestamptz,
  status text,
  cafe_id uuid,
  cafe_name text,
  subtotal_credits int,
  paid_credits int,
  bonus_used int,
  payment_method text,
  payment_status text,
  customer_name text,
  customer_phone text,
  items jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int;
  v_offset int;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Invalid wallet_id: NULL';
  END IF;

  SELECT validated_limit, validated_offset
  INTO v_limit, v_offset
  FROM validate_pagination(p_limit, p_offset, 200);

  RETURN QUERY
  SELECT
    o.id AS order_id,
    o.order_number,
    o.created_at,
    o.status,
    o.cafe_id,
    c.name AS cafe_name,
    o.subtotal_credits,
    o.paid_credits,
    COALESCE(o.bonus_used, 0) AS bonus_used,
    o.payment_method,
    o.payment_status,
    o.customer_name,
    o.customer_phone,
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'item_id', oi.id,
            'item_name', oi.item_name,
            'qty', oi.quantity,
            'unit_price_credits', oi.unit_credits,
            'line_total_credits', oi.total_price_credits,
            'modifiers', oi.modifiers
          )
          ORDER BY oi.created_at
        )
        FROM order_items oi
        WHERE oi.order_id = o.id
      ),
      '[]'::jsonb
    ) AS items
  FROM orders_core o
  LEFT JOIN cafes c ON o.cafe_id = c.id
  WHERE o.wallet_id = p_wallet_id
  ORDER BY o.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION admin_get_wallet_orders IS
  'Admin: Get wallet orders with itemized breakdown (uses orders_core.bonus_used)';

GRANT EXECUTE ON FUNCTION admin_get_wallet_orders(uuid, int, int) TO authenticated;
