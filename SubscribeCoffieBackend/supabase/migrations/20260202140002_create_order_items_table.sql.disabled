-- Enhance order_items table for iOS checkout flow
-- Add modifiers support and additional fields

DO $$
BEGIN
  -- Check if order_items needs enhancement
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'order_items' AND column_name = 'modifiers'
  ) THEN
    ALTER TABLE public.order_items
      ADD COLUMN modifiers JSONB DEFAULT '[]'::jsonb,
      ADD COLUMN item_name TEXT,
      ADD COLUMN base_price_credits INT,
      ADD COLUMN total_price_credits INT;
      
    -- Migrate existing data
    UPDATE public.order_items
    SET 
      item_name = COALESCE(title, 'Unknown'),
      base_price_credits = COALESCE(unit_credits, 0),
      total_price_credits = COALESCE(line_total, unit_credits * quantity, 0)
    WHERE item_name IS NULL;
    
    -- Make fields NOT NULL after migration
    ALTER TABLE public.order_items
      ALTER COLUMN item_name SET NOT NULL,
      ALTER COLUMN base_price_credits SET NOT NULL,
      ALTER COLUMN total_price_credits SET NOT NULL;
  END IF;
END$$;

-- Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_menu_item ON public.order_items(menu_item_id);

-- Add comments
COMMENT ON TABLE public.order_items IS 'Позиции заказов с поддержкой модификаторов';
COMMENT ON COLUMN public.order_items.modifiers IS 'JSON массив модификаторов: [{"group": "Объём", "name": "Большой", "price": 30}]';
COMMENT ON COLUMN public.order_items.item_name IS 'Название позиции на момент заказа';
COMMENT ON COLUMN public.order_items.base_price_credits IS 'Базовая цена без модификаторов';
COMMENT ON COLUMN public.order_items.total_price_credits IS 'Итоговая цена с учетом модификаторов и количества';
