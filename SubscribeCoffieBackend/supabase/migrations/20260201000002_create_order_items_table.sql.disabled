-- Таблица позиций заказа уже существует, добавляем недостающие поля
-- Добавить колонку modifiers если её нет
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'order_items' 
    AND column_name = 'modifiers'
  ) THEN
    ALTER TABLE public.order_items ADD COLUMN modifiers JSONB DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- Добавить колонки для совместимости с новой структурой заказов
DO $$ 
BEGIN
  -- item_name (алиас для title)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'order_items' 
    AND column_name = 'item_name'
  ) THEN
    ALTER TABLE public.order_items ADD COLUMN item_name TEXT;
    -- Синхронизировать с title
    UPDATE public.order_items SET item_name = title WHERE item_name IS NULL;
    ALTER TABLE public.order_items ALTER COLUMN item_name SET NOT NULL;
  END IF;

  -- base_price_credits (алиас для unit_credits)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'order_items' 
    AND column_name = 'base_price_credits'
  ) THEN
    ALTER TABLE public.order_items ADD COLUMN base_price_credits INT;
    -- Синхронизировать с unit_credits
    UPDATE public.order_items SET base_price_credits = unit_credits WHERE base_price_credits IS NULL;
    ALTER TABLE public.order_items ALTER COLUMN base_price_credits SET NOT NULL;
  END IF;

  -- total_price_credits (алиас для line_total)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'order_items' 
    AND column_name = 'total_price_credits'
  ) THEN
    ALTER TABLE public.order_items ADD COLUMN total_price_credits INT;
    -- Синхронизировать с line_total
    UPDATE public.order_items SET total_price_credits = unit_credits * quantity WHERE total_price_credits IS NULL;
    ALTER TABLE public.order_items ALTER COLUMN total_price_credits SET NOT NULL;
  END IF;
END $$;

-- Индексы (создаются только если не существуют)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'order_items' 
    AND indexname = 'idx_order_items_menu_item'
  ) THEN
    CREATE INDEX idx_order_items_menu_item ON public.order_items(menu_item_id);
  END IF;
END $$;

-- Комментарии
COMMENT ON TABLE public.order_items IS 'Позиции заказов';
COMMENT ON COLUMN public.order_items.modifiers IS 'JSON массив модификаторов: [{"group": "Объём", "name": "Большой", "price": 30}]';
COMMENT ON COLUMN public.order_items.item_name IS 'Название позиции (снимок на момент заказа)';
COMMENT ON COLUMN public.order_items.base_price_credits IS 'Базовая цена без модификаторов';
COMMENT ON COLUMN public.order_items.total_price_credits IS 'Итоговая цена с модификаторами и количеством';
