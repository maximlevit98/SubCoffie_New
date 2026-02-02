-- Production Seed Data for SubscribeCoffie
-- This file contains ONLY essential configuration data for production
-- DO NOT include test data in production

-- WARNING: Review this file carefully before applying to production
-- Run this SQL in Supabase Dashboard → SQL Editor after deployment

-- ============================================================================
-- Commission Configuration
-- ============================================================================
-- Default commission rates for different wallet types and operations

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

-- ============================================================================
-- System Configuration (if you have a config table)
-- ============================================================================
-- Add any system-wide configuration here

-- Example (if you have a system_config table):
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

-- ============================================================================
-- Default Notification Templates (if applicable)
-- ============================================================================
-- If you have notification templates table, seed default templates here

-- ============================================================================
-- Verification Queries
-- ============================================================================
-- Run these to verify the seed was successful

-- Check commission config
SELECT * FROM commission_config ORDER BY operation_type;

-- ============================================================================
-- Post-Deployment Manual Steps
-- ============================================================================
-- These steps must be done manually after deployment:

-- 1. CREATE FIRST ADMIN USER:
--    a. Register a user through the iOS app or auth endpoint
--    b. Get the user_id from auth.users table
--    c. Run this query (replace with actual email):
--
--    UPDATE profiles 
--    SET role = 'admin' 
--    WHERE email = 'your-admin@email.com';

-- 2. CREATE STORAGE BUCKETS:
--    Go to Dashboard → Storage → Create Bucket:
--    - Name: cafe-images, Public: Yes, File size limit: 5MB
--    - Name: menu-images, Public: Yes, File size limit: 5MB
--    - Name: cafe-documents, Public: No, File size limit: 10MB
--    - Name: user-avatars, Public: Yes, File size limit: 2MB

-- 3. CONFIGURE RLS POLICIES FOR STORAGE:
--    Buckets should have appropriate RLS policies
--    (These should already be in migrations, but verify)

-- 4. SET UP EMAIL TEMPLATES:
--    Go to Dashboard → Authentication → Email Templates
--    Customize:
--    - Confirmation email
--    - Magic link email
--    - Password reset email
--    - Invitation email

-- 5. CONFIGURE SMTP:
--    Go to Dashboard → Project Settings → Auth
--    Set up SMTP with SendGrid or AWS SES

-- 6. CONFIGURE OAUTH:
--    Go to Dashboard → Authentication → Providers
--    Enable and configure:
--    - Apple (required for iOS App Store)
--    - Google

-- 7. SET SITE URL AND REDIRECT URLS:
--    Go to Dashboard → Authentication → URL Configuration
--    - Site URL: https://app.subscribecoffie.com
--    - Redirect URLs:
--      https://app.subscribecoffie.com/**
--      com.subscribecoffie.app://**
--      subscribecoffie://auth/callback

-- ============================================================================
-- Notes
-- ============================================================================
-- 
-- This seed file is MINIMAL by design for production safety.
-- 
-- DO NOT seed production with:
-- - Test user accounts
-- - Fake cafe data
-- - Test orders
-- - Sample menu items
-- 
-- Real data should come from:
-- - User registrations
-- - Cafe onboarding flow
-- - Real orders
-- - Actual menu uploads
-- 
-- For development/staging, use the regular seed.sql file.
-- 
-- ============================================================================
