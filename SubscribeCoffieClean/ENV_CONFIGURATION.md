# ⚠️ iOS App Configuration Guide
# This file documents how to configure Supabase keys for iOS app
# iOS configuration is done via EnvironmentConfig.swift, NOT via .env files

# ==============================================================================
# DEVELOPMENT (LOCAL SUPABASE)
# ==============================================================================

# Current configuration in Environment.swift:
# - URL: http://127.0.0.1:54321
# - Anon Key: eyJhbGciOiJFUzI1NiIs... (hardcoded local Supabase default)

# This is SAFE for local development:
# ✅ Local Supabase uses standard demo keys
# ✅ No real data or secrets
# ✅ Only works on 127.0.0.1 (localhost)

# ==============================================================================
# STAGING / PRODUCTION CONFIGURATION
# ==============================================================================

# To configure for staging or production:

# 1. Open: SubscribeCoffieClean/Helpers/Environment.swift
# 2. Update the appropriate case in supabaseAnonKeyString:

# case .staging:
#     return "your-staging-anon-key-here"

# case .production:
#     return "your-production-anon-key-here"

# 3. Update URLs in supabaseBaseURLString similarly

# ==============================================================================
# SECURITY RULES
# ==============================================================================

# iOS APP MUST ONLY USE:
# ✅ Supabase Anonymous (Anon) Key
# ✅ Public Supabase URL

# iOS APP MUST NEVER HAVE:
# ❌ Service Role Key (server-only!)
# ❌ Payment Provider Keys (Stripe/YooKassa)
# ❌ Any secrets that bypass RLS

# ==============================================================================
# HOW TO GET PRODUCTION KEYS
# ==============================================================================

# 1. Go to: https://app.supabase.com
# 2. Select your project
# 3. Settings → API
# 4. Copy:
#    - Project URL → use in supabaseBaseURLString
#    - anon/public key → use in supabaseAnonKeyString
# 5. NEVER copy service_role key to iOS!

# ==============================================================================
# RUNTIME OVERRIDE (FOR TESTING)
# ==============================================================================

# During development, you can override via UserDefaults:
# EnvironmentConfig.setSupabaseBaseURL("https://your-test-ref.supabase.co")
# EnvironmentConfig.setSupabaseAnonKey("your-test-anon-key")

# To reset:
# EnvironmentConfig.resetOverrides()

# ==============================================================================
# WHAT IF I NEED REAL DEVICE TESTING?
# ==============================================================================

# Local Supabase (127.0.0.1) doesn't work on real iOS devices.
# Two options:

# Option 1: Use Mac's IP address
# 1. Find your Mac's IP: System Settings → Network
# 2. Update Environment.swift development case:
#    return "http://192.168.X.X:54321"
# 3. Ensure Mac firewall allows connections on port 54321

# Option 2: Use ngrok or similar tunnel
# 1. Run: ngrok http 54321
# 2. Copy ngrok URL
# 3. Override at runtime:
#    EnvironmentConfig.setSupabaseBaseURL("https://abc123.ngrok.io")

# ==============================================================================
# DEPLOYMENT CHECKLIST
# ==============================================================================

# Before submitting to App Store:
# [ ] Update production URL and anon key in Environment.swift
# [ ] Remove any development-only override code
# [ ] Test that app works with production Supabase
# [ ] Verify RLS policies protect sensitive data
# [ ] Test offline behavior (no network)
# [ ] Test with production backend (not local)
# [ ] Ensure no service_role keys in code
# [ ] Ensure no payment provider keys in code
# [ ] Run security audit (check for hardcoded secrets)
