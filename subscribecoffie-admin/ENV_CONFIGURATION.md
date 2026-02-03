# ⚠️ Admin Panel Environment Variables Template
# Copy this file to .env.local and fill in your actual values
# DO NOT commit .env.local to git!

# ==============================================================================
# SUPABASE CONFIGURATION
# ==============================================================================

# Supabase Project URL
# Development (local): http://127.0.0.1:54321
# Production: Get from https://app.supabase.com → Your Project → Settings → API
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321

# Supabase Anonymous (Public) Key
# Safe to use client-side - RLS policies protect your data
# Development (local): Get from `supabase status` output
# Production: Get from https://app.supabase.com → Your Project → Settings → API
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here

# Alternative name (both are supported)
# NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your_anon_key_here

# Supabase Service Role Key (SERVER-SIDE ONLY!)
# ⚠️ NEVER expose this key client-side
# ⚠️ This key bypasses RLS and has full database access
# Development (local): Get from `supabase status` output
# Production: Get from https://app.supabase.com → Your Project → Settings → API → service_role key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# ==============================================================================
# SECURITY NOTES
# ==============================================================================

# 1. ANON KEY (NEXT_PUBLIC_SUPABASE_ANON_KEY):
#    - Safe to expose client-side
#    - Protected by Row Level Security (RLS) policies
#    - Can only perform operations allowed by RLS
#    - Prefix: NEXT_PUBLIC_ means it's bundled in browser code

# 2. SERVICE ROLE KEY (SUPABASE_SERVICE_ROLE_KEY):
#    - NEVER expose client-side
#    - NO NEXT_PUBLIC_ prefix (server-only)
#    - Bypasses ALL RLS policies
#    - Full admin access to database
#    - Only use in server actions and API routes

# ==============================================================================
# PRODUCTION DEPLOYMENT CHECKLIST
# ==============================================================================

# Before deploying to production:
# [ ] Update NEXT_PUBLIC_SUPABASE_URL with production URL
# [ ] Update NEXT_PUBLIC_SUPABASE_ANON_KEY with production anon key
# [ ] Update SUPABASE_SERVICE_ROLE_KEY with production service role key
# [ ] Add .env.local to .gitignore (should already be there)
# [ ] Set environment variables in Vercel/Netlify/your hosting platform
# [ ] Verify RLS policies are enabled on all tables
# [ ] Test that anon key cannot access restricted data
# [ ] Monitor logs for unauthorized access attempts

# ==============================================================================
# LOCAL DEVELOPMENT
# ==============================================================================

# To get local Supabase keys:
# 1. Run: cd SubscribeCoffieBackend && supabase status
# 2. Copy API URL → NEXT_PUBLIC_SUPABASE_URL
# 3. Copy anon key → NEXT_PUBLIC_SUPABASE_ANON_KEY
# 4. Copy service_role key → SUPABASE_SERVICE_ROLE_KEY

# Default local Supabase values (from `supabase start`):
# URL: http://127.0.0.1:54321
# anon key: eyJhbGciOi... (varies by version)
# service_role key: eyJhbGciOi... (varies by version)
