-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Secure cafe onboarding RPC functions
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- Problem: approve_cafe and reject_cafe accept p_admin_user_id as parameter
--          Attacker could pass any admin's ID to bypass checks
-- Solution: Use auth.uid() to verify caller is admin
--
-- Date: 2026-02-04
-- Security Priority: P0 (Critical)
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 1: Secure approve_cafe
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.approve_cafe(
  p_request_id UUID,
  p_admin_user_id UUID,
  p_admin_comment TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_request RECORD;
  v_cafe_id UUID;
  v_caller_role TEXT;
BEGIN
  -- 🛡️ SECURITY: Verify caller is admin (not just parameter)
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();
  
  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admin users can approve cafes';
  END IF;
  
  -- 🛡️ SECURITY: Ensure p_admin_user_id matches auth.uid()
  IF p_admin_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Admin user ID must match authenticated user';
  END IF;

  -- Get request details
  SELECT * INTO v_request
  FROM public.cafe_onboarding_requests
  WHERE id = p_request_id;

  IF v_request IS NULL THEN
    RAISE EXCEPTION 'Onboarding request not found';
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Only pending requests can be approved';
  END IF;

  -- Create cafe
  INSERT INTO public.cafes (
    name,
    address,
    mode,
    eta_minutes,
    active_orders,
    max_active_orders,
    distance_km,
    supports_citypass,
    rating,
    avg_check_credits,
    status
  )
  VALUES (
    v_request.cafe_name,
    v_request.cafe_address,
    'closed', -- Default to closed, owner will set it to open
    15, -- Default ETA
    0, -- No active orders yet
    18, -- Default max
    0.0, -- Distance will be calculated based on user location
    TRUE, -- Default to supporting CityPass
    0.0, -- No rating yet
    250, -- Default average check
    'draft' -- Start as draft until owner completes setup
  )
  RETURNING id INTO v_cafe_id;

  -- Update request status
  UPDATE public.cafe_onboarding_requests
  SET
    status = 'approved',
    approved_by = auth.uid(), -- Use auth.uid() not parameter
    approved_at = NOW(),
    admin_comment = p_admin_comment,
    updated_at = NOW()
  WHERE id = p_request_id;

  -- Move documents to cafe
  UPDATE public.cafe_documents
  SET cafe_id = v_cafe_id
  WHERE onboarding_request_id = p_request_id;
  
  -- Audit log
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_logs') THEN
    INSERT INTO public.audit_logs (
      actor_user_id,
      action,
      table_name,
      record_id,
      payload
    ) VALUES (
      auth.uid(),
      'cafe_approved',
      'cafe_onboarding_requests',
      p_request_id,
      jsonb_build_object(
        'cafe_id', v_cafe_id,
        'cafe_name', v_request.cafe_name,
        'comment', p_admin_comment
      )
    );
  END IF;

  RETURN v_cafe_id;
END;
$$;

COMMENT ON FUNCTION public.approve_cafe IS 
  '🔒 SECURED: Approve cafe onboarding request. Admin verified via auth.uid().';

-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 2: Secure reject_cafe
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.reject_cafe(
  p_request_id UUID,
  p_admin_user_id UUID,
  p_admin_comment TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_request RECORD;
  v_caller_role TEXT;
BEGIN
  -- 🛡️ SECURITY: Verify caller is admin (not just parameter)
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();
  
  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admin users can reject cafes';
  END IF;
  
  -- 🛡️ SECURITY: Ensure p_admin_user_id matches auth.uid()
  IF p_admin_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Admin user ID must match authenticated user';
  END IF;

  -- Get request details
  SELECT * INTO v_request
  FROM public.cafe_onboarding_requests
  WHERE id = p_request_id;

  IF v_request IS NULL THEN
    RAISE EXCEPTION 'Onboarding request not found';
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Only pending requests can be rejected';
  END IF;

  -- Update request status
  UPDATE public.cafe_onboarding_requests
  SET
    status = 'rejected',
    approved_by = auth.uid(), -- Use auth.uid() not parameter
    approved_at = NOW(),
    admin_comment = p_admin_comment,
    updated_at = NOW()
  WHERE id = p_request_id;
  
  -- Audit log
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_logs') THEN
    INSERT INTO public.audit_logs (
      actor_user_id,
      action,
      table_name,
      record_id,
      payload
    ) VALUES (
      auth.uid(),
      'cafe_rejected',
      'cafe_onboarding_requests',
      p_request_id,
      jsonb_build_object(
        'cafe_name', v_request.cafe_name,
        'comment', p_admin_comment
      )
    );
  END IF;
END;
$$;

COMMENT ON FUNCTION public.reject_cafe IS 
  '🔒 SECURED: Reject cafe onboarding request. Admin verified via auth.uid().';

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TESTING NOTES
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- Test 1: Non-admin cannot approve/reject
-- ───────────────────────────────────────
-- SET ROLE owner_user;
-- SELECT approve_cafe('<request_id>', '<admin_id>', 'test');
-- Expected: ERROR: Only admin users can approve cafes
--
-- Test 2: Admin cannot spoof another admin's ID
-- ──────────────────────────────────────────────
-- SET ROLE admin_user_1;
-- SELECT approve_cafe('<request_id>', '<admin_user_2_id>', 'test');
-- Expected: ERROR: Admin user ID must match authenticated user
--
-- Test 3: Admin can approve with own ID
-- ──────────────────────────────────────
-- SET ROLE admin_user;
-- SELECT approve_cafe('<request_id>', auth.uid(), 'approved!');
-- Expected: SUCCESS, cafe created
-- ═══════════════════════════════════════════════════════════════════════════════
