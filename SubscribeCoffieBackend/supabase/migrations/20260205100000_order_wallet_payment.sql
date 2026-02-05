-- Migration: Add Wallet Payment Support to create_order RPC
-- Description: Updates create_order to accept wallet_id, validate wallet, and deduct balance
-- Date: 2026-02-05
-- Priority: P0 (Payment flow)

-- ============================================================================
-- Update create_order RPC to support wallet payments
-- ============================================================================
-- Changes:
-- 1. Add p_wallet_id parameter (optional for backward compat with card/cash)
-- 2. Validate wallet using validate_wallet_for_order before creating order
-- 3. Check wallet balance before creating order
-- 4. Deduct balance and create order_payment transaction
-- 5. Return clear error messages for insufficient funds / invalid wallet
-- ============================================================================

-- Drop existing function to allow signature change
DROP FUNCTION IF EXISTS create_order(UUID, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, JSONB);

CREATE OR REPLACE FUNCTION create_order(
  p_cafe_id UUID,
  p_order_type TEXT,
  p_slot_time TIMESTAMPTZ,
  p_customer_name TEXT,
  p_customer_phone TEXT,
  p_customer_notes TEXT,
  p_payment_method TEXT,
  p_items JSONB,
  p_wallet_id UUID DEFAULT NULL  -- ✅ NEW: Wallet ID for wallet payments
)
RETURNS JSONB 
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id UUID;
  v_subtotal INT := 0;
  v_item JSONB;
  v_menu_item RECORD;
  v_item_price INT;
  v_modifier JSONB;
  v_order_number TEXT;
  v_user_id UUID;
  v_wallet_balance INT;
  v_wallet_user_id UUID;
  v_is_wallet_valid BOOLEAN;
  v_transaction_id UUID;
  v_balance_after INT;
BEGIN
  -- 🛡️ SECURITY: Get current user ID (cannot be spoofed)
  v_user_id := auth.uid();
  
  -- 🛡️ SECURITY: Validate cafe exists and is published
  IF NOT EXISTS (SELECT 1 FROM public.cafes WHERE id = p_cafe_id AND status = 'published') THEN
    RAISE EXCEPTION 'Кофейня не найдена или не опубликована';
  END IF;
  
  -- 🛡️ SECURITY: Validate order_type
  IF p_order_type NOT IN ('now', 'preorder', 'subscription') THEN
    RAISE EXCEPTION 'Invalid order type: %', p_order_type;
  END IF;
  
  -- 🛡️ SECURITY: Validate payment_method
  IF p_payment_method NOT IN ('wallet', 'card', 'cash') THEN
    RAISE EXCEPTION 'Invalid payment method: %', p_payment_method;
  END IF;
  
  -- 🛡️ WALLET: If payment method is wallet, wallet_id is required
  IF p_payment_method = 'wallet' AND p_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet ID required for wallet payments';
  END IF;
  
  -- 🛡️ SECURITY: Validate items array
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must have at least one item';
  END IF;
  
  IF jsonb_array_length(p_items) > 50 THEN
    RAISE EXCEPTION 'Order cannot have more than 50 items';
  END IF;
  
  -- Calculate subtotal (validate all items first)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- 🛡️ SECURITY: Get menu item and verify it belongs to THIS cafe
    SELECT * INTO v_menu_item
    FROM public.menu_items
    WHERE id = (v_item->>'menu_item_id')::UUID
      AND cafe_id = p_cafe_id  -- CRITICAL: Prevent cross-cafe item injection
      AND is_available = true;
    
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Позиция меню % не найдена или недоступна', v_item->>'menu_item_id';
    END IF;
    
    -- 🛡️ SECURITY: Validate quantity
    IF COALESCE((v_item->>'quantity')::INT, 0) <= 0 OR COALESCE((v_item->>'quantity')::INT, 0) > 99 THEN
      RAISE EXCEPTION 'Invalid quantity for item %', v_item->>'menu_item_id';
    END IF;
    
    -- Calculate price with modifiers
    v_item_price := v_menu_item.price_credits;
    
    IF v_item->'modifiers' IS NOT NULL THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers')
      LOOP
        -- 🛡️ SECURITY: Validate modifier price is reasonable
        IF COALESCE((v_modifier->>'price')::INT, 0) < 0 OR COALESCE((v_modifier->>'price')::INT, 0) > 10000 THEN
          RAISE EXCEPTION 'Invalid modifier price';
        END IF;
        v_item_price := v_item_price + COALESCE((v_modifier->>'price')::INT, 0);
      END LOOP;
    END IF;
    
    v_item_price := v_item_price * COALESCE((v_item->>'quantity')::INT, 1);
    v_subtotal := v_subtotal + v_item_price;
  END LOOP;
  
  -- 🛡️ SECURITY: Validate total is reasonable
  IF v_subtotal <= 0 OR v_subtotal > 1000000 THEN
    RAISE EXCEPTION 'Invalid order total: %', v_subtotal;
  END IF;
  
  -- ✅ WALLET PAYMENT: Validate and deduct balance
  IF p_payment_method = 'wallet' THEN
    -- 1. Validate wallet belongs to user
    SELECT user_id, balance_credits INTO v_wallet_user_id, v_wallet_balance
    FROM public.wallets
    WHERE id = p_wallet_id;
    
    IF v_wallet_user_id IS NULL THEN
      RAISE EXCEPTION 'Wallet not found';
    END IF;
    
    IF v_wallet_user_id != v_user_id THEN
      RAISE EXCEPTION 'Wallet does not belong to you';
    END IF;
    
    -- 2. Validate wallet can be used for this cafe
    SELECT public.validate_wallet_for_order(p_wallet_id, p_cafe_id) INTO v_is_wallet_valid;
    
    IF NOT v_is_wallet_valid THEN
      RAISE EXCEPTION 'Wallet cannot be used at this cafe. Please use CityPass or create a Cafe Wallet for this cafe.';
    END IF;
    
    -- 3. Check balance
    IF v_wallet_balance < v_subtotal THEN
      RAISE EXCEPTION 'Insufficient funds. Balance: % credits, Required: % credits', v_wallet_balance, v_subtotal;
    END IF;
    
    -- 4. Deduct balance (atomic update)
    UPDATE public.wallets
    SET 
      balance_credits = balance_credits - v_subtotal,
      updated_at = NOW()
    WHERE id = p_wallet_id
    RETURNING balance_credits INTO v_balance_after;
    
    -- 5. Create order_payment transaction
    INSERT INTO public.payment_transactions (
      user_id,
      wallet_id,
      amount_credits,
      commission_credits,
      transaction_type,
      status,
      completed_at
    ) VALUES (
      v_user_id,
      p_wallet_id,
      v_subtotal,
      0, -- No commission on order payments
      'order_payment',
      'completed',
      NOW()
    ) RETURNING id INTO v_transaction_id;
    
    -- 6. Create wallet_transactions record for audit trail
    INSERT INTO public.wallet_transactions (
      wallet_id,
      amount,
      type,
      balance_before,
      balance_after,
      description,
      reference_id,
      created_at
    ) VALUES (
      p_wallet_id,
      -v_subtotal, -- Negative for deduction
      'order_payment',
      v_wallet_balance,
      v_balance_after,
      'Order payment for cafe: ' || p_cafe_id::text,
      v_transaction_id,
      NOW()
    );
  END IF;
  
  -- Create order
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
    paid_credits,
    wallet_id,  -- ✅ NEW: Store wallet_id reference
    created_at,
    updated_at
  ) VALUES (
    p_cafe_id,
    v_user_id,
    v_user_id,
    p_order_type,
    p_slot_time,
    p_customer_name,
    p_customer_phone,
    p_customer_notes,
    p_payment_method,
    'created',
    CASE WHEN p_payment_method = 'wallet' THEN 'paid' ELSE 'pending' END,
    v_subtotal,
    v_subtotal,
    CASE WHEN p_payment_method = 'wallet' THEN v_subtotal ELSE 0 END,
    p_wallet_id,
    NOW(),
    NOW()
  )
  RETURNING id, order_number INTO v_order_id, v_order_number;
  
  -- Link transaction to order (if wallet payment)
  IF p_payment_method = 'wallet' THEN
    UPDATE public.payment_transactions
    SET order_id = v_order_id
    WHERE id = v_transaction_id;
  END IF;
  
  -- Add order items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_menu_item
    FROM public.menu_items
    WHERE id = (v_item->>'menu_item_id')::UUID;
    
    -- Calculate price with modifiers
    v_item_price := v_menu_item.price_credits;
    
    IF v_item->'modifiers' IS NOT NULL THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers')
      LOOP
        v_item_price := v_item_price + COALESCE((v_modifier->>'price')::INT, 0);
      END LOOP;
    END IF;
    
    v_item_price := v_item_price * COALESCE((v_item->>'quantity')::INT, 1);
    
    -- Add order_item
    INSERT INTO public.order_items (
      order_id,
      menu_item_id,
      item_name,
      base_price_credits,
      quantity,
      modifiers,
      total_price_credits,
      title,
      unit_credits,
      category,
      created_at
    ) VALUES (
      v_order_id,
      v_menu_item.id,
      v_menu_item.name,
      v_menu_item.price_credits,
      COALESCE((v_item->>'quantity')::INT, 1),
      COALESCE(v_item->'modifiers', '[]'::jsonb),
      v_item_price,
      v_menu_item.name,
      v_menu_item.price_credits,
      COALESCE(v_menu_item.category, 'drinks'),
      NOW()
    );
  END LOOP;
  
  -- 🔒 AUDIT: Log order creation
  INSERT INTO public.audit_logs (
    actor_user_id, 
    action, 
    table_name, 
    record_id, 
    payload, 
    created_at
  ) VALUES (
    v_user_id,
    'order.create',
    'orders_core',
    v_order_id,
    jsonb_build_object(
      'cafe_id', p_cafe_id,
      'total_credits', v_subtotal,
      'payment_method', p_payment_method,
      'wallet_id', p_wallet_id,
      'items_count', jsonb_array_length(p_items)
    ),
    NOW()
  );
  
  -- Return result
  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', COALESCE(v_order_number, v_order_id::text),
    'total_credits', v_subtotal,
    'status', 'new',
    'wallet_balance_after', v_balance_after,  -- ✅ NEW: Return new balance
    'transaction_id', v_transaction_id  -- ✅ NEW: Return transaction ID
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Return error with clear message
    RAISE EXCEPTION '%', SQLERRM;
END;
$$;

COMMENT ON FUNCTION create_order IS 'Создает заказ с поддержкой оплаты кошельком (validates wallet, checks balance, deducts payment)';

-- ============================================================================
-- Add wallet_id column to orders_core if not exists
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'orders_core' 
    AND column_name = 'wallet_id'
  ) THEN
    ALTER TABLE public.orders_core ADD COLUMN wallet_id UUID REFERENCES public.wallets(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS orders_core_wallet_id_idx ON public.orders_core(wallet_id);
    COMMENT ON COLUMN public.orders_core.wallet_id IS 'Wallet used for payment (for wallet payments)';
  END IF;
END $$;

-- ============================================================================
-- Complete
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ create_order updated with wallet payment support';
  RAISE NOTICE '';
  RAISE NOTICE 'Changes:';
  RAISE NOTICE '  - Added p_wallet_id parameter (optional)';
  RAISE NOTICE '  - Validates wallet using validate_wallet_for_order';
  RAISE NOTICE '  - Checks balance before order creation';
  RAISE NOTICE '  - Deducts balance atomically';
  RAISE NOTICE '  - Creates order_payment transaction';
  RAISE NOTICE '  - Creates wallet_transactions audit record';
  RAISE NOTICE '  - Returns wallet_balance_after and transaction_id';
  RAISE NOTICE '';
  RAISE NOTICE 'Error messages:';
  RAISE NOTICE '  - "Wallet not found" - Invalid wallet_id';
  RAISE NOTICE '  - "Wallet does not belong to you" - Wrong owner';
  RAISE NOTICE '  - "Wallet cannot be used at this cafe" - Wrong wallet type';
  RAISE NOTICE '  - "Insufficient funds" - Balance < total';
  RAISE NOTICE '';
END $$;
