-- ⚠️⚠️⚠️ CRITICAL: PRODUCTION SEED DATA ONLY ⚠️⚠️⚠️
-- 
-- This file contains ONLY essential configuration data for production.
-- DO NOT include test data, demo users, or fake cafe data.
--
-- ============================================================================
-- SAFETY CHECKS
-- ============================================================================
--
-- This file should ONLY be run:
-- 1. In Supabase Cloud Dashboard → SQL Editor (manual execution)
-- 2. After reviewing EVERY line
-- 3. With explicit approval from Technical Lead + Product Owner
--
-- DO NOT run this via automated scripts or CI/CD!
-- DO NOT run this in local development (use seed.sql instead)!
--
-- ============================================================================

-- 🛡️ SAFETY CHECK #1: Prevent accidental local execution
DO $$
DECLARE
  v_port text;
  v_test_users int;
BEGIN
  -- Check if we're running on local Supabase (port 54321 or 5432 with postgres user)
  SELECT setting INTO v_port FROM pg_settings WHERE name = 'port';
  
  -- Local Supabase uses port 54321 for database
  IF v_port = '54321' THEN
    RAISE EXCEPTION '🚨 SAFETY ABORT: This appears to be a LOCAL Supabase instance (port 54321). Use seed.sql for local development instead. Production seed should ONLY be run in Supabase Cloud Dashboard → SQL Editor.';
  END IF;
  
  -- Also check for standard local postgres on 5432 with common local patterns
  IF v_port = '5432' AND current_database() = 'postgres' THEN
    RAISE WARNING '⚠️  WARNING: Running on default PostgreSQL port 5432. Please confirm this is production Supabase Cloud.';
  END IF;
  
  -- Check if this is a development environment (looking for obvious dev indicators)
  SELECT COUNT(*) INTO v_test_users
  FROM auth.users 
  WHERE email LIKE '%@test.com' 
     OR email LIKE '%@example.com'
     OR email = 'levitm@algsoft.ru';
  
  IF v_test_users > 0 THEN
    RAISE WARNING '⚠️  WARNING: Detected % test users in database. Are you sure this is production?', v_test_users;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Safety checks passed. Continuing with production seed...';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- Commission Configuration
-- ============================================================================
-- Default commission rates for different wallet types and operations

DO $$ BEGIN
  RAISE NOTICE '1️⃣  Setting up commission configuration...';
END $$;

INSERT INTO commission_config (operation_type, commission_percent, active, created_at)
VALUES
  -- CityPass wallet top-up commission (universal wallet)
  ('citypass_topup', 7.5, true, now()),
  
  -- Cafe Wallet top-up commission (cafe-specific wallet)
  ('cafe_wallet_topup', 4.0, true, now()),
  
  -- Direct order payment commission (no wallet)
  ('direct_order', 17.5, true, now())

ON CONFLICT (operation_type) 
DO UPDATE SET 
  commission_percent = EXCLUDED.commission_percent,
  active = EXCLUDED.active,
  updated_at = now();

DO $$ BEGIN
  RAISE NOTICE '   ✅ Commission config set:';
  RAISE NOTICE '      - CityPass top-up: 7.5%%';
  RAISE NOTICE '      - Cafe Wallet top-up: 4.0%%';
  RAISE NOTICE '      - Direct order: 17.5%%';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- System Configuration (if you have a config table)
-- ============================================================================
-- Add any system-wide configuration here

-- Example (uncomment if you have a system_config table):
-- DO $$ BEGIN
--   RAISE NOTICE '2️⃣  Setting up system configuration...';
-- END $$;
-- 
-- INSERT INTO system_config (key, value, description)
-- VALUES
--   ('min_order_amount', '100', 'Minimum order amount in credits'),
--   ('max_order_amount', '10000', 'Maximum order amount in credits'),
--   ('wallet_topup_min', '100', 'Minimum wallet top-up amount'),
--   ('wallet_topup_max', '50000', 'Maximum wallet top-up amount'),
--   ('order_timeout_minutes', '30', 'Order timeout in minutes'),
--   ('qr_code_expiry_minutes', '15', 'QR code expiry in minutes')
-- ON CONFLICT (key) DO UPDATE SET 
--   value = EXCLUDED.value,
--   description = EXCLUDED.description;
--
-- DO $$ BEGIN
--   RAISE NOTICE '   ✅ System config set';
--   RAISE NOTICE '';
-- END $$;

-- ============================================================================
-- Default Notification Templates (if applicable)
-- ============================================================================
-- If you have notification templates table, seed default templates here

-- ============================================================================
-- Verification Queries
-- ============================================================================
-- Run these to verify the seed was successful

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '✅ PRODUCTION SEED COMPLETE';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
  RAISE NOTICE 'Verification:';
END $$;

-- Check commission config
SELECT 
  operation_type, 
  commission_percent, 
  active,
  CASE WHEN active THEN '✅ Active' ELSE '❌ Inactive' END as status
FROM commission_config 
ORDER BY operation_type;

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT MANUAL STEPS (see below):';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- Post-Deployment Manual Steps
-- ============================================================================
-- These steps MUST be done manually after deployment:

DO $$ BEGIN
  RAISE NOTICE '1️⃣  CREATE FIRST ADMIN USER:';
  RAISE NOTICE '   a. Register a user through the iOS app or auth endpoint';
  RAISE NOTICE '   b. Get the user_id from auth.users table';
  RAISE NOTICE '   c. Run this query (replace with actual email):';
  RAISE NOTICE '';
  RAISE NOTICE '   UPDATE profiles ';
  RAISE NOTICE '   SET role = ''admin'' ';
  RAISE NOTICE '   WHERE email = ''your-admin@email.com'';';
  RAISE NOTICE '';
  
  RAISE NOTICE '2️⃣  CREATE STORAGE BUCKETS:';
  RAISE NOTICE '   Go to Dashboard → Storage → Create Bucket:';
  RAISE NOTICE '   - Name: cafe-images, Public: Yes, File size limit: 5MB';
  RAISE NOTICE '   - Name: menu-images, Public: Yes, File size limit: 5MB';
  RAISE NOTICE '   - Name: cafe-documents, Public: No, File size limit: 10MB';
  RAISE NOTICE '   - Name: user-avatars, Public: Yes, File size limit: 2MB';
  RAISE NOTICE '';
  
  RAISE NOTICE '3️⃣  CONFIGURE RLS POLICIES FOR STORAGE:';
  RAISE NOTICE '   Buckets should have appropriate RLS policies';
  RAISE NOTICE '   (These should already be in migrations, but verify)';
  RAISE NOTICE '';
  
  RAISE NOTICE '4️⃣  SET UP EMAIL TEMPLATES:';
  RAISE NOTICE '   Go to Dashboard → Authentication → Email Templates';
  RAISE NOTICE '   Customize:';
  RAISE NOTICE '   - Confirmation email';
  RAISE NOTICE '   - Magic link email';
  RAISE NOTICE '   - Password reset email';
  RAISE NOTICE '   - Invitation email';
  RAISE NOTICE '';
  
  RAISE NOTICE '5️⃣  CONFIGURE SMTP:';
  RAISE NOTICE '   Go to Dashboard → Project Settings → Auth';
  RAISE NOTICE '   Set up SMTP with SendGrid or AWS SES';
  RAISE NOTICE '';
  
  RAISE NOTICE '6️⃣  CONFIGURE OAUTH:';
  RAISE NOTICE '   Go to Dashboard → Authentication → Providers';
  RAISE NOTICE '   Enable and configure:';
  RAISE NOTICE '   - Apple (required for iOS App Store)';
  RAISE NOTICE '   - Google';
  RAISE NOTICE '';
  
  RAISE NOTICE '7️⃣  SET SITE URL AND REDIRECT URLS:';
  RAISE NOTICE '   Go to Dashboard → Authentication → URL Configuration';
  RAISE NOTICE '   - Site URL: https://app.subscribecoffie.com';
  RAISE NOTICE '   - Redirect URLs:';
  RAISE NOTICE '     https://app.subscribecoffie.com/**';
  RAISE NOTICE '     com.subscribecoffie.app://**';
  RAISE NOTICE '     subscribecoffie://auth/callback';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- Notes
-- ============================================================================
-- 
-- This seed file is MINIMAL by design for production safety.
-- 
-- ⚠️ DO NOT seed production with:
-- - Test user accounts
-- - Fake cafe data
-- - Test orders
-- - Sample menu items
-- - Mock payment methods
-- 
-- ✅ Real data should come from:
-- - User registrations
-- - Cafe onboarding flow
-- - Real orders
-- - Actual menu uploads
-- 
-- 🔒 For development/staging, use the regular seed.sql file.
-- 
-- ============================================================================

DO $$ BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '🎉 Production seed complete!';
  RAISE NOTICE '📋 Complete the manual steps above';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
END $$;
