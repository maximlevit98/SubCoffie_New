-- Функция генерации номера заказа
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
  new_number TEXT;
  date_part TEXT;
  sequence_part INT;
BEGIN
  -- Формат: YYMMDD-XXXX (например: 260202-0001)
  date_part := TO_CHAR(NOW(), 'YYMMDD');
  
  -- Получить последний номер за сегодня (работает с orders_core)
  SELECT COALESCE(
    MAX(CAST(SPLIT_PART(order_number, '-', 2) AS INT)), 
    0
  ) + 1 INTO sequence_part
  FROM public.orders_core
  WHERE order_number LIKE date_part || '-%';
  
  new_number := date_part || '-' || LPAD(sequence_part::TEXT, 4, '0');
  RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автогенерации номера (orders_core)
CREATE OR REPLACE FUNCTION set_order_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
    NEW.order_number := generate_order_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_order_number ON public.orders_core;
CREATE TRIGGER trigger_set_order_number
  BEFORE INSERT ON public.orders_core
  FOR EACH ROW
  EXECUTE FUNCTION set_order_number();

-- Ensure updated_at trigger exists (might already exist from other migrations)
DROP TRIGGER IF EXISTS trigger_orders_updated_at ON public.orders_core;
CREATE TRIGGER trigger_orders_updated_at
  BEFORE UPDATE ON public.orders_core
  FOR EACH ROW
  EXECUTE FUNCTION public.tg__update_timestamp();

COMMENT ON FUNCTION generate_order_number IS 'Генерирует уникальный номер заказа в формате YYMMDD-XXXX';
COMMENT ON FUNCTION set_order_number IS 'Триггер для автоматической генерации номера заказа';
