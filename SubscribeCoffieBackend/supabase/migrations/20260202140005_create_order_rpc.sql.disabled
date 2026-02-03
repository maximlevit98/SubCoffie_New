-- RPC функция для создания заказа (iOS checkout)
CREATE OR REPLACE FUNCTION create_order(
  p_cafe_id UUID,
  p_order_type TEXT,
  p_slot_time TIMESTAMPTZ,
  p_customer_name TEXT,
  p_customer_phone TEXT,
  p_customer_notes TEXT,
  p_payment_method TEXT,
  p_items JSONB
)
RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_subtotal INT := 0;
  v_item JSONB;
  v_menu_item RECORD;
  v_item_price INT;
  v_modifier JSONB;
  v_order_number TEXT;
  v_user_id UUID;
BEGIN
  -- Get current user ID (null for anonymous)
  v_user_id := auth.uid();
  
  -- Валидация кофейни
  IF NOT EXISTS (SELECT 1 FROM public.cafes WHERE id = p_cafe_id AND status = 'published') THEN
    RAISE EXCEPTION 'Кофейня не найдена или не опубликована';
  END IF;

  -- Создать заказ в orders_core
  INSERT INTO public.orders_core (
    cafe_id,
    user_id,
    customer_user_id,
    order_type,
    slot_time,
    customer_name,
    customer_phone,
    customer_notes,
    payment_method,
    status,
    payment_status,
    subtotal_credits,
    total_credits,
    created_at,
    updated_at
  ) VALUES (
    p_cafe_id,
    v_user_id, -- for legacy compatibility
    v_user_id, -- new field
    p_order_type,
    p_slot_time,
    p_customer_name,
    p_customer_phone,
    p_customer_notes,
    p_payment_method,
    'created', -- using snake_case status
    CASE WHEN p_payment_method = 'wallet' THEN 'paid' ELSE 'pending' END,
    0,
    0,
    NOW(),
    NOW()
  )
  RETURNING id, order_number INTO v_order_id, v_order_number;

  -- Добавить позиции заказа
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Получить информацию о позиции меню
    SELECT * INTO v_menu_item
    FROM public.menu_items
    WHERE id = (v_item->>'menu_item_id')::UUID
      AND cafe_id = p_cafe_id
      AND is_available = true;

    IF NOT FOUND THEN
      -- Rollback будет автоматическим при EXCEPTION
      RAISE EXCEPTION 'Позиция меню % не найдена или недоступна', v_item->>'menu_item_id';
    END IF;

    -- Рассчитать цену с модификаторами
    v_item_price := v_menu_item.price_credits;
    
    IF v_item->'modifiers' IS NOT NULL THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers')
      LOOP
        v_item_price := v_item_price + COALESCE((v_modifier->>'price')::INT, 0);
      END LOOP;
    END IF;

    v_item_price := v_item_price * COALESCE((v_item->>'quantity')::INT, 1);

    -- Добавить order_item
    INSERT INTO public.order_items (
      order_id,
      menu_item_id,
      item_name,
      base_price_credits,
      quantity,
      modifiers,
      total_price_credits,
      title, -- для совместимости со старой схемой
      unit_credits, -- для совместимости
      category, -- для совместимости
      created_at
    ) VALUES (
      v_order_id,
      v_menu_item.id,
      v_menu_item.name,
      v_menu_item.price_credits,
      COALESCE((v_item->>'quantity')::INT, 1),
      COALESCE(v_item->'modifiers', '[]'::jsonb),
      v_item_price,
      v_menu_item.name, -- title = name
      v_menu_item.price_credits, -- unit_credits = base_price
      COALESCE(v_menu_item.category, 'drinks'), -- default category
      NOW()
    );

    v_subtotal := v_subtotal + v_item_price;
  END LOOP;

  -- Обновить сумму заказа
  UPDATE public.orders_core
  SET 
    subtotal_credits = v_subtotal,
    total_credits = v_subtotal,
    paid_credits = CASE WHEN p_payment_method = 'wallet' THEN v_subtotal ELSE 0 END
  WHERE id = v_order_id;

  -- Вернуть результат
  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', COALESCE(v_order_number, v_order_id::text),
    'total_credits', v_subtotal,
    'status', 'new'
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Log error and re-raise
    RAISE EXCEPTION 'Ошибка создания заказа: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Права на выполнение
GRANT EXECUTE ON FUNCTION create_order TO authenticated;
GRANT EXECUTE ON FUNCTION create_order TO anon;

COMMENT ON FUNCTION create_order IS 'Создает заказ с проверкой доступности позиций и расчетом стоимости (iOS checkout)';
