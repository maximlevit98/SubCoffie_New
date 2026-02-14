-- iOS User Authentication Enhancement
-- Adds support for full user registration with Email, Phone, Apple, and Google OAuth

-- Ensure profiles table has all required fields
DO $$
BEGIN
  -- Add avatar_url if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'avatar_url'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN avatar_url TEXT;
  END IF;

  -- Add auth_provider if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'auth_provider'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN auth_provider TEXT DEFAULT 'email';
  END IF;

  -- Add updated_at if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END$$;

-- Ensure auth_provider has valid values
DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;

CREATE OR REPLACE FUNCTION public.tg__set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.tg__set_updated_at();

-- Add constraint for auth_provider
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_auth_provider_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_auth_provider_check
      CHECK (auth_provider IN ('email', 'phone', 'google', 'apple'));
  END IF;
END$$;

-- Update handle_new_user to set auth_provider based on email/phone
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, auth_provider)
  VALUES (
    NEW.id,
    NEW.email,
    CASE
      WHEN NEW.phone IS NOT NULL AND NEW.email IS NULL THEN 'phone'
      WHEN NEW.email LIKE '%@privaterelay.appleid.com' THEN 'apple'
      ELSE 'email'
    END
  )
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        auth_provider = EXCLUDED.auth_provider;
  RETURN NEW;
END;
$$;

-- RPC: Initialize user profile with full data (called after signup/signin)
CREATE OR REPLACE FUNCTION public.init_user_profile(
  p_full_name TEXT,
  p_phone TEXT DEFAULT NULL,
  p_birth_date DATE DEFAULT NULL,
  p_city TEXT DEFAULT 'Москва'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_profile RECORD;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Update profile with full information
  UPDATE public.profiles
  SET
    full_name = p_full_name,
    phone = COALESCE(p_phone, phone),
    birth_date = COALESCE(p_birth_date, birth_date),
    city = COALESCE(p_city, city, 'Москва'),
    updated_at = NOW()
  WHERE id = v_user_id;

  -- Return updated profile
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_profile.id,
    'email', v_profile.email,
    'phone', v_profile.phone,
    'full_name', v_profile.full_name,
    'birth_date', v_profile.birth_date,
    'city', v_profile.city,
    'avatar_url', v_profile.avatar_url,
    'auth_provider', v_profile.auth_provider,
    'role', v_profile.role,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
END;
$$;

-- RPC: Get current user's profile
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_profile RECORD;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get profile
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  RETURN jsonb_build_object(
    'id', v_profile.id,
    'email', v_profile.email,
    'phone', v_profile.phone,
    'full_name', v_profile.full_name,
    'birth_date', v_profile.birth_date,
    'city', v_profile.city,
    'avatar_url', v_profile.avatar_url,
    'auth_provider', v_profile.auth_provider,
    'role', v_profile.role,
    'default_wallet_type', v_profile.default_wallet_type,
    'default_cafe_id', v_profile.default_cafe_id,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
END;
$$;

-- RPC: Update current user's profile
CREATE OR REPLACE FUNCTION public.update_my_profile(
  p_full_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_birth_date DATE DEFAULT NULL,
  p_city TEXT DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_profile RECORD;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Update only provided fields
  UPDATE public.profiles
  SET
    full_name = COALESCE(p_full_name, full_name),
    phone = COALESCE(p_phone, phone),
    birth_date = COALESCE(p_birth_date, birth_date),
    city = COALESCE(p_city, city),
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    updated_at = NOW()
  WHERE id = v_user_id;

  -- Return updated profile
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_profile.id,
    'email', v_profile.email,
    'phone', v_profile.phone,
    'full_name', v_profile.full_name,
    'birth_date', v_profile.birth_date,
    'city', v_profile.city,
    'avatar_url', v_profile.avatar_url,
    'auth_provider', v_profile.auth_provider,
    'role', v_profile.role,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.init_user_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_profile TO authenticated;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS profiles_phone_idx ON public.profiles(phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS profiles_auth_provider_idx ON public.profiles(auth_provider);

-- Create view for orders with user information (for admin panel)
CREATE OR REPLACE VIEW public.orders_with_user_info AS
SELECT 
  o.*,
  p.full_name as profile_full_name,
  p.email as profile_email,
  p.phone as profile_phone,  -- Renamed to avoid conflict with orders_core.customer_phone
  p.avatar_url as profile_avatar,
  p.auth_provider as profile_auth_provider,
  p.created_at as profile_registered_at
FROM public.orders_core o
LEFT JOIN public.profiles p ON o.customer_user_id = p.id;

-- Grant permissions on view
GRANT SELECT ON public.orders_with_user_info TO authenticated;
GRANT SELECT ON public.orders_with_user_info TO anon;

COMMENT ON FUNCTION public.init_user_profile IS 'Initialize user profile with full registration data (iOS)';
COMMENT ON FUNCTION public.get_my_profile IS 'Get current user profile (iOS)';
COMMENT ON FUNCTION public.update_my_profile IS 'Update current user profile (iOS)';
COMMENT ON VIEW public.orders_with_user_info IS 'Orders joined with user profile information for admin panel';
