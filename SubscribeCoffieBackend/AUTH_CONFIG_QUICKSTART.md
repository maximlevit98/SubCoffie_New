# Auth Configuration Quick Reference

## ✅ Configuration Complete

All Supabase Auth providers have been configured for the iOS User Registration System.

## What Was Configured

### 1. Email/Password Authentication
- **Status**: ✅ Enabled
- **Signup**: Enabled
- **Email Confirmations**: Disabled for local dev (enable in production)
- **Local Testing**: Emails captured at http://127.0.0.1:54324

### 2. Phone/SMS Authentication
- **Status**: ✅ Enabled with test OTP
- **Signup**: Enabled
- **Test Phone Numbers**:
  - `+79991234567` → OTP: `123456`
  - `+79991234568` → OTP: `654321`
- **Production**: Requires Twilio configuration

### 3. Apple Sign In
- **Status**: ✅ Enabled (requires credentials)
- **Client ID**: `env(SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID)`
- **Redirect URI**: `subscribecoffie://auth/callback`
- **Setup Required**: See AUTH_PROVIDERS_CONFIGURATION.md

### 4. Google Sign In
- **Status**: ✅ Enabled (requires credentials)
- **Client ID**: `env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)`
- **Redirect URI**: `subscribecoffie://auth/callback`
- **Setup Required**: See AUTH_PROVIDERS_CONFIGURATION.md

## Files Modified

1. **supabase/config.toml**
   - Added iOS deep link: `subscribecoffie://auth/callback`
   - Enabled Apple OAuth provider
   - Enabled Google OAuth provider
   - Configured test OTP codes for phone auth

2. **env.local.example** (NEW)
   - Template for OAuth credentials
   - Environment variable documentation

3. **AUTH_PROVIDERS_CONFIGURATION.md** (NEW)
   - Complete setup guide for all providers
   - Troubleshooting tips
   - Production deployment checklist

## Quick Start for Local Development

### 1. Start Supabase
```bash
cd SubscribeCoffieBackend
supabase start
```

### 2. Test Authentication Methods

**Email/Password** (works immediately):
- Sign up with any email
- Check verification email at: http://127.0.0.1:54324

**Phone/SMS** (works immediately):
- Use phone: `+79991234567`
- Use OTP: `123456`

**Apple/Google OAuth** (requires setup):
- Follow AUTH_PROVIDERS_CONFIGURATION.md
- Set environment variables in `.env.local`
- Restart Supabase

## Production Setup Required

For production deployment, you need to:

1. **Apple Sign In**:
   - Create Service ID in Apple Developer Console
   - Generate client secret (JWT)
   - Set environment variables

2. **Google Sign In**:
   - Create OAuth Client in Google Cloud Console
   - Configure redirect URIs
   - Set environment variables

3. **SMS (Optional)**:
   - Sign up for Twilio
   - Configure account credentials
   - Enable in config.toml

4. **Email (Optional)**:
   - Sign up for SendGrid or similar
   - Configure SMTP settings
   - Enable email confirmations

## Security Features Enabled

- ✅ JWT token expiry (1 hour)
- ✅ Refresh token rotation
- ✅ Rate limiting on all auth endpoints
- ✅ Password minimum length (6 characters)
- ✅ Secure password change (reauthentication required)

## Next Steps

1. ✅ **Phase 1**: Backend configuration (COMPLETED)
2. ⏭️ **Phase 2**: Database migration (create RPC functions)
3. ⏭️ **Phase 3**: iOS AuthService integration
4. ⏭️ **Phase 4**: iOS UI implementation
5. ⏭️ **Phase 5**: Testing & validation

## Documentation

- **Full Guide**: AUTH_PROVIDERS_CONFIGURATION.md
- **Environment Setup**: env.local.example
- **Main Config**: supabase/config.toml

## Testing Commands

```bash
# Verify configuration
supabase status

# Check auth settings
supabase settings get --format json

# View logs
supabase logs auth

# Reset if needed
supabase db reset
```

## Support

If you encounter issues:
1. Check AUTH_PROVIDERS_CONFIGURATION.md troubleshooting section
2. Verify environment variables are set correctly
3. Check Supabase logs: `supabase logs auth`
4. Verify redirect URLs match in all locations
