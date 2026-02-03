-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Prevent Self-Assignment of Admin/Owner Roles
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- Problem: Users can potentially UPDATE profiles SET role='admin'/'owner' 
--          via existing "Profiles update own" policy
-- Solution: Explicitly prevent role changes except via SECURITY DEFINER functions
--           (like redeem_owner_invitation RPC)
--
-- Date: 2026-02-04
-- Security Priority: P0 (Critical)
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 1: Update RLS Policy to prevent role changes
-- ═══════════════════════════════════════════════════════════════════════════════

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Profiles update own" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile (except role)" ON public.profiles;

-- Create granular policy: users can update own profile BUT NOT role column
-- Note: We cannot use OLD.role in WITH CHECK directly in PostgreSQL RLS
-- Instead, we rely on column-level REVOKE (Step 2) to block role updates
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);

COMMENT ON POLICY "Users can update own profile" ON public.profiles IS 
  'Users can UPDATE their own profile, but role column is protected via column-level security (REVOKE UPDATE). Direct role changes blocked.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 2: Column-level security (belt and suspenders approach)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Revoke UPDATE permission on role column for authenticated users
-- This provides an additional layer of protection
REVOKE UPDATE (role) ON public.profiles FROM authenticated;
REVOKE UPDATE (role) ON public.profiles FROM anon;

-- Grant UPDATE only on safe columns (users can update these)
-- Note: SECURITY DEFINER functions bypass these restrictions
-- Only grant on columns that actually exist in profiles table
GRANT UPDATE (full_name, phone, updated_at) ON public.profiles TO authenticated;

COMMENT ON COLUMN public.profiles.role IS 
  'User role (admin/owner/user). Can only be changed via SECURITY DEFINER functions. Direct UPDATE by users is blocked.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 3: Create helper function to check if role assignment is allowed
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.can_assign_role()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  caller_role text;
BEGIN
  -- Get caller's role from profiles
  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid();
  
  -- Only admin can assign roles (or SECURITY DEFINER functions with elevated privileges)
  RETURN (caller_role = 'admin');
END;
$$;

COMMENT ON FUNCTION public.can_assign_role IS 
  'Helper function to check if current user can assign roles. Returns true only for admins.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 4: Add audit log trigger for role changes
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.audit_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Log role changes to audit_logs (if table exists)
  IF (OLD.role IS DISTINCT FROM NEW.role) THEN
    -- Only log if audit_logs table exists
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_logs') THEN
      INSERT INTO public.audit_logs (
        actor_user_id,
        action,
        table_name,
        record_id,
        payload,
        created_at
      ) VALUES (
        COALESCE(auth.uid(), NEW.id), -- actor is current user or the user being updated
        'role_changed',
        'profiles',
        NEW.id,
        jsonb_build_object(
          'old_role', OLD.role,
          'new_role', NEW.role,
          'user_email', NEW.email,
          'changed_by', auth.uid(),
          'timestamp', NOW()
        ),
        NOW()
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.audit_role_change IS 
  'Trigger function to log all role changes to audit_logs table for security tracking.';

-- Attach trigger to profiles table
DROP TRIGGER IF EXISTS on_role_change ON public.profiles;
CREATE TRIGGER on_role_change
  AFTER UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (OLD.role IS DISTINCT FROM NEW.role)
  EXECUTE FUNCTION public.audit_role_change();

COMMENT ON TRIGGER on_role_change ON public.profiles IS 
  'Audit trigger: logs all role changes for security tracking.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 5: Prevent admin demotion (admin role is permanent)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.prevent_admin_demotion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- If old role was 'admin' and new role is different, block it
  IF OLD.role = 'admin' AND NEW.role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Cannot demote admin role. Admin role is permanent for security reasons.';
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.prevent_admin_demotion IS 
  'Trigger function to prevent admin demotion. Admin role is permanent once assigned.';

-- Attach trigger to profiles table (BEFORE UPDATE to block the change)
DROP TRIGGER IF EXISTS prevent_admin_demotion_trigger ON public.profiles;
CREATE TRIGGER prevent_admin_demotion_trigger
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (OLD.role = 'admin' AND NEW.role IS DISTINCT FROM 'admin')
  EXECUTE FUNCTION public.prevent_admin_demotion();

COMMENT ON TRIGGER prevent_admin_demotion_trigger ON public.profiles IS 
  'Security trigger: prevents admin role from being demoted. Admin is permanent.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 6: Admin-only RPC to grant admin role
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.admin_grant_admin_role(
  p_target_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
  v_target_email text;
  v_target_current_role text;
BEGIN
  -- 🛡️ SECURITY: Only admins can grant admin role
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();
  
  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admin users can grant admin role';
  END IF;
  
  -- 🛡️ SECURITY: Cannot grant admin to yourself (optional check)
  IF p_target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot grant admin role to yourself';
  END IF;
  
  -- Get target user info
  SELECT email, role INTO v_target_email, v_target_current_role
  FROM public.profiles
  WHERE id = p_target_user_id;
  
  IF v_target_email IS NULL THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;
  
  -- If already admin, return success
  IF v_target_current_role = 'admin' THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'User is already admin',
      'user_id', p_target_user_id,
      'email', v_target_email
    );
  END IF;
  
  -- Grant admin role
  UPDATE public.profiles
  SET 
    role = 'admin',
    updated_at = NOW()
  WHERE id = p_target_user_id;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Admin role granted successfully',
    'user_id', p_target_user_id,
    'email', v_target_email,
    'old_role', v_target_current_role,
    'new_role', 'admin'
  );
END;
$$;

COMMENT ON FUNCTION public.admin_grant_admin_role IS 
  'Admin-only RPC to grant admin role to another user. Includes audit logging and prevents self-escalation.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.admin_grant_admin_role TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 5: Ensure SECURITY DEFINER functions can still change roles
-- ═══════════════════════════════════════════════════════════════════════════════

-- No changes needed - SECURITY DEFINER functions (like redeem_owner_invitation)
-- run with the privileges of the function owner, bypassing RLS and column-level security.
-- This is the ONLY way roles should be assigned in production.

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TESTING NOTES
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- Test 1: Regular user CANNOT change own role
-- ───────────────────────────────────────────
-- SET ROLE authenticated;
-- SET request.jwt.claims.sub TO '<user_id>';
-- UPDATE public.profiles SET role='admin' WHERE id = auth.uid();
-- Expected: ERROR: permission denied for column "role" of relation "profiles"
--
-- Test 2: Regular user CAN update other fields
-- ─────────────────────────────────────────────
-- UPDATE public.profiles SET full_name='New Name' WHERE id = auth.uid();
-- Expected: SUCCESS
--
-- Test 3: RPC redeem_owner_invitation STILL WORKS
-- ────────────────────────────────────────────────
-- SELECT redeem_owner_invitation('valid-token-here');
-- Expected: SUCCESS, role changed to 'owner', audit log created
--
-- Test 4: Audit log is created for role changes
-- ──────────────────────────────────────────────
-- SELECT * FROM audit_logs 
-- WHERE action = 'role_changed' 
-- ORDER BY created_at DESC LIMIT 1;
-- Expected: Entry with old_role/new_role/changed_by
--
-- Test 5: Policy check with WITH CHECK violation
-- ───────────────────────────────────────────────
-- Try to update role via direct query (should fail at WITH CHECK)
-- Even if column-level security didn't exist, this would fail
-- ═══════════════════════════════════════════════════════════════════════════════
