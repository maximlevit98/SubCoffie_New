-- Enhance existing orders table for iOS checkout flow
-- Add missing fields needed for the new order creation flow

-- Check if we're working with orders_core or orders table
DO $$
BEGIN
  -- If orders is a view, work with orders_core
  IF EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'public' AND table_name = 'orders'
  ) THEN
    -- Add fields to orders_core
    ALTER TABLE public.orders_core
      ADD COLUMN IF NOT EXISTS order_number TEXT UNIQUE,
      ADD COLUMN IF NOT EXISTS customer_name TEXT,
      ADD COLUMN IF NOT EXISTS customer_notes TEXT,
      ADD COLUMN IF NOT EXISTS cancel_reason TEXT,
      ADD COLUMN IF NOT EXISTS cancel_comment TEXT,
      ADD COLUMN IF NOT EXISTS delivery_fee_credits INT DEFAULT 0,
      ADD COLUMN IF NOT EXISTS discount_credits INT DEFAULT 0,
      ADD COLUMN IF NOT EXISTS total_credits INT,
      ADD COLUMN IF NOT EXISTS payment_method TEXT,
      ADD COLUMN IF NOT EXISTS payment_transaction_id UUID,
      ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS preparing_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS ready_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
    
    -- Update total_credits for existing rows
    UPDATE public.orders_core 
    SET total_credits = subtotal_credits + COALESCE(delivery_fee_credits, 0) - COALESCE(discount_credits, 0)
    WHERE total_credits IS NULL;
    
  -- If orders is a table, work with it directly
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'orders'
  ) THEN
    -- Add fields to orders table
    ALTER TABLE public.orders
      ADD COLUMN IF NOT EXISTS order_number TEXT UNIQUE,
      ADD COLUMN IF NOT EXISTS customer_name TEXT,
      ADD COLUMN IF NOT EXISTS customer_notes TEXT,
      ADD COLUMN IF NOT EXISTS cancel_reason TEXT,
      ADD COLUMN IF NOT EXISTS cancel_comment TEXT,
      ADD COLUMN IF NOT EXISTS delivery_fee_credits INT DEFAULT 0,
      ADD COLUMN IF NOT EXISTS discount_credits INT DEFAULT 0,
      ADD COLUMN IF NOT EXISTS total_credits INT,
      ADD COLUMN IF NOT EXISTS payment_method TEXT,
      ADD COLUMN IF NOT EXISTS payment_transaction_id UUID,
      ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS preparing_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS ready_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
      
    -- Update total_credits for existing rows  
    UPDATE public.orders 
    SET total_credits = subtotal_credits + COALESCE(delivery_fee_credits, 0) - COALESCE(discount_credits, 0)
    WHERE total_credits IS NULL;
  END IF;
END$$;

-- Create index on order_number
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON public.orders_core(order_number) WHERE order_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON public.orders_core(payment_method) WHERE payment_method IS NOT NULL;

-- Add comments
COMMENT ON COLUMN public.orders_core.order_number IS 'Уникальный номер заказа в формате YYMMDD-XXXX';
COMMENT ON COLUMN public.orders_core.payment_method IS 'Метод оплаты: wallet, card, cash, subscription';
COMMENT ON COLUMN public.orders_core.customer_name IS 'Имя клиента для отображения в заказе';
COMMENT ON COLUMN public.orders_core.customer_notes IS 'Комментарий клиента к заказу';
COMMENT ON COLUMN public.orders_core.total_credits IS 'Итоговая сумма с учетом доставки и скидок';
