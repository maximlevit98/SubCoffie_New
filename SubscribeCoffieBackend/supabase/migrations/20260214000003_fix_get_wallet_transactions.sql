-- Migration: Fix get_wallet_transactions RPC column names
-- Date: 2026-02-14
-- Purpose: Update RPC to use correct column names (balance_before/after instead of credits_balance_before/after)

-- ============================================================================
-- Fix get_wallet_transactions RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION get_wallet_transactions(
  user_id_param uuid,
  limit_param int DEFAULT 50,
  offset_param int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  wallet_id uuid,
  amount int,
  type text,
  description text,
  order_id uuid,
  actor_user_id uuid,
  balance_before int,
  balance_after int,
  created_at timestamptz
)
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql
AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- 🛡️ SECURITY: Get caller's role
  SELECT role INTO v_caller_role 
  FROM public.profiles 
  WHERE profiles.id = auth.uid();
  
  -- 🛡️ SECURITY: Only allow user to view their own transactions, or admin
  IF v_caller_role != 'admin' AND auth.uid() != user_id_param THEN
    RAISE EXCEPTION 'Unauthorized: Cannot view other users transactions';
  END IF;
  
  -- 🛡️ SECURITY: Validate limit
  IF limit_param > 1000 THEN
    RAISE EXCEPTION 'Limit cannot exceed 1000';
  END IF;
  
  RETURN QUERY
  SELECT 
    wt.id,
    wt.wallet_id,
    wt.amount,
    wt.type,
    wt.description,
    wt.order_id,
    wt.actor_user_id,
    wt.balance_before,  -- ✅ Fixed: was credits_balance_before
    wt.balance_after,   -- ✅ Fixed: was credits_balance_after
    wt.created_at
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  WHERE w.user_id = user_id_param
  ORDER BY wt.created_at DESC
  LIMIT limit_param
  OFFSET offset_param;
END;
$$;

COMMENT ON FUNCTION get_wallet_transactions IS 'Получает историю транзакций кошелька (HARDENED: own transactions or admin only, canonical schema)';

-- ============================================================================
-- Complete
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ get_wallet_transactions RPC fixed for canonical schema';
  RAISE NOTICE '   - Fixed column names: balance_before/after';
  RAISE NOTICE '   - Added actor_user_id to return type';
  RAISE NOTICE '';
END $$;
