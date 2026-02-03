-- ⚠️ CRITICAL SECURITY FIX: RLS Policy Hardening
-- Issue: Several overly permissive policies allow unauthorized data access
-- Date: 2026-02-03
-- Priority: P0

-- ============================================================================
-- PROBLEM SUMMARY
-- ============================================================================
-- 1. menu_items: anon can read ALL menu items (including unpublished)
-- 2. orders_core: anon can read ALL orders (including sensitive data)
-- 3. order_items: overly permissive INSERT policies
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔐 CRITICAL SECURITY FIX: RLS Policy Hardening';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- ============================================================================
-- FIX #1: menu_items - Remove overly permissive policies
-- ============================================================================

DROP POLICY IF EXISTS "anon_select_menu_items_v2" ON public.menu_items;
DROP POLICY IF EXISTS "public_select_menu_items" ON public.menu_items;

-- ============================================================================
-- FIX #2: orders_core - Remove overly permissive anon read policy
-- ============================================================================

DROP POLICY IF EXISTS "anon_select_orders" ON public.orders_core;

-- ============================================================================
-- FIX #3: order_items - Clean up duplicate/loose policies
-- ============================================================================

DROP POLICY IF EXISTS "order_items_insert_own" ON public.order_items;

-- ============================================================================
-- FIX #4: orders_core - Clean up duplicate/loose SELECT policies
-- ============================================================================

DROP POLICY IF EXISTS "orders_core_select_own" ON public.orders_core;

-- ============================================================================
-- FIX #5: Verify RLS is enabled on all sensitive tables
-- ============================================================================

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders_core ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ SECURITY FIX COMPLETE';
  RAISE NOTICE 'See: FIX_007_RLS_POLICY_HARDENING.md for details';
END $$;
