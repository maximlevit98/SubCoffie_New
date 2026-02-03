# ⚠️ Edge Functions Secrets Configuration
# Edge Functions use Supabase Secrets (stored securely, NOT in .env files)
# This template documents what secrets are required

# ==============================================================================
# HOW EDGE FUNCTION SECRETS WORK
# ==============================================================================

# Supabase Edge Functions access secrets via Deno.env.get()
# Secrets are stored securely in Supabase Cloud, NOT in your repository

# To set secrets:
# supabase secrets set SECRET_NAME=value

# To list secrets:
# supabase secrets list

# To delete a secret:
# supabase secrets unset SECRET_NAME

# ==============================================================================
# REQUIRED SECRETS (FOR MVP - DEMO MODE)
# ==============================================================================

# SUPABASE_SERVICE_ROLE_KEY
# - Purpose: Server-side database access (bypasses RLS)
# - Used by: create-payment Edge Function
# - How to get: `supabase status` → service_role key
# - Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
#
# Set with:
# supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# ==============================================================================
# REQUIRED SECRETS (WHEN REAL PAYMENTS ENABLED)
# ==============================================================================

# ENABLE_REAL_PAYMENTS
# - Purpose: Feature flag to enable/disable real payment processing
# - Values: 'true' or 'false'
# - Default: false (use mock payments)
#
# Set with:
# supabase secrets set ENABLE_REAL_PAYMENTS=false

# STRIPE_SECRET_KEY
# - Purpose: Process payments via Stripe
# - How to get: https://dashboard.stripe.com/apikeys
# - Test key: sk_test_... (for development)
# - Live key: sk_live_... (for production)
# - ⚠️ NEVER commit to git!
#
# Set with:
# supabase secrets set STRIPE_SECRET_KEY=sk_test_your_key_here

# STRIPE_WEBHOOK_SECRET
# - Purpose: Verify Stripe webhook signatures
# - How to get: Stripe Dashboard → Webhooks → Add endpoint → Reveal secret
# - Format: whsec_...
#
# Set with:
# supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_secret_here

# YOOKASSA_SECRET_KEY
# - Purpose: Process payments via YooKassa (Russian market)
# - How to get: https://yookassa.ru/my/merchant/integration/api-keys
# - Format: live_... or test_...
# - ⚠️ NEVER commit to git!
#
# Set with:
# supabase secrets set YOOKASSA_SECRET_KEY=your_yookassa_key_here

# YOOKASSA_SHOP_ID
# - Purpose: YooKassa shop identifier
# - How to get: YooKassa Dashboard
#
# Set with:
# supabase secrets set YOOKASSA_SHOP_ID=your_shop_id_here

# ==============================================================================
# LOCAL DEVELOPMENT
# ==============================================================================

# For local development, Edge Functions use .env file:
# Location: SubscribeCoffieBackend/supabase/functions/.env

# Create this file:
# cd SubscribeCoffieBackend/supabase/functions
# touch .env
# echo "SUPABASE_SERVICE_ROLE_KEY=your_local_key" >> .env

# ⚠️ Add to .gitignore:
# echo "supabase/functions/.env" >> .gitignore

# ==============================================================================
# PRODUCTION DEPLOYMENT
# ==============================================================================

# 1. Set all required secrets BEFORE deploying:
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_production_service_role_key
supabase secrets set ENABLE_REAL_PAYMENTS=false

# 2. When ready for real payments (after security checklist):
supabase secrets set ENABLE_REAL_PAYMENTS=true
supabase secrets set STRIPE_SECRET_KEY=sk_live_your_live_key
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
supabase secrets set YOOKASSA_SECRET_KEY=your_yookassa_live_key
supabase secrets set YOOKASSA_SHOP_ID=your_shop_id

# 3. Deploy functions:
supabase functions deploy create-payment

# 4. Verify secrets are set:
supabase secrets list

# ==============================================================================
# SECURITY CHECKLIST
# ==============================================================================

# Before enabling real payments:
# [ ] All secrets set via `supabase secrets set` (not in code)
# [ ] ENABLE_REAL_PAYMENTS set to false initially
# [ ] Test with Stripe/YooKassa test keys first
# [ ] Complete PAYMENT_SECURITY.md checklist (44 items)
# [ ] Webhook signature verification enabled
# [ ] Service role key never exposed client-side
# [ ] Secrets never committed to git
# [ ] Production secrets different from test secrets
# [ ] Regular secret rotation schedule in place

# ==============================================================================
# CURRENT STATUS (MVP)
# ==============================================================================

# Status: DEMO MODE ONLY
# Real payments: DISABLED
# Required secrets:
#   ✅ SUPABASE_SERVICE_ROLE_KEY (for admin operations)
#   ❌ STRIPE_SECRET_KEY (not needed yet)
#   ❌ YOOKASSA_SECRET_KEY (not needed yet)
#   ❌ ENABLE_REAL_PAYMENTS (defaults to false)

# See: PAYMENT_SECURITY.md for enabling real payments
