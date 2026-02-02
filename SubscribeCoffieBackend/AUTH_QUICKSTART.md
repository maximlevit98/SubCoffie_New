# Authentication Quick Start Guide

## What's Implemented

✅ **Backend (Supabase)**
- Enhanced `profiles` table with OAuth support
- 5 new RPC functions for profile management
- Automatic profile creation triggers
- Support for email, phone, Google, and Apple auth providers

✅ **iOS App**
- New `AuthService.swift` - Complete authentication service
- Enhanced `LoginView.swift` - Multi-method login UI
- Email/Password authentication
- Sign in with Apple integration
- Sign in with Google integration
- Password reset flow
- Error handling and loading states

## Quick Start (Development)

### 1. Run Migration

```bash
cd SubscribeCoffieBackend
supabase db reset  # Applies all migrations including auth enhancement
```

### 2. Enable Email Auth (Already Configured)

Email authentication is ready to use immediately. The config is set to:
- Allow signups: ✅
- Email confirmations: Disabled (for dev)
- Minimum password length: 6 characters

### 3. Test Email Authentication

In the iOS app:
1. Launch app
2. Select "Email" tab
3. Tap "Создать аккаунт"
4. Enter name, email, password
5. Tap "Зарегистрироваться"
6. Sign in with email/password

### 4. Enable OAuth (Optional)

OAuth providers are **disabled by default**. To enable:

**Apple Sign In:**
```toml
# supabase/config.toml
[auth.external.apple]
enabled = true
client_id = "your.bundle.identifier"
secret = "env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)"
```

**Google Sign In:**
```toml
# supabase/config.toml
[auth.external.google]
enabled = true
client_id = "your-client-id.apps.googleusercontent.com"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
```

Then obtain credentials from:
- Apple: https://developer.apple.com/
- Google: https://console.cloud.google.com/

## What's Next

### Integrate with ContentView

Update `ContentView.swift` to use `AuthService`:

```swift
@StateObject private var authService = AuthService.shared

var body: some View {
    Group {
        if authService.isAuthenticated {
            // Show main app
            MainAppView()
        } else {
            // Show login
            LoginView { phone in
                // Handle legacy phone auth
            }
        }
    }
}
```

### Test the Implementation

1. **Email Sign Up**: Create account with email/password
2. **Email Sign In**: Log in with created account
3. **Password Reset**: Test forgot password flow
4. **Profile Sync**: Check profile created in Supabase Dashboard
5. **Sign Out**: Test logout functionality

### Production Checklist

Before deploying to production:

- [ ] Enable email confirmations in config.toml
- [ ] Set up production SMTP provider
- [ ] Obtain real OAuth credentials (Apple, Google)
- [ ] Update OAuth redirect URLs
- [ ] Test on real iOS device (for Apple Sign In)
- [ ] Add proper error tracking (Sentry, etc.)
- [ ] Review and update RLS policies
- [ ] Set up backup/recovery procedures

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                   iOS App                       │
│  ┌───────────────────────────────────────────┐  │
│  │           LoginView.swift                 │  │
│  │  • Email/Password form                    │  │
│  │  • Sign in with Apple button              │  │
│  │  • Sign in with Google button             │  │
│  │  • Phone auth (legacy)                    │  │
│  └─────────────────┬─────────────────────────┘  │
│                    │                            │
│  ┌─────────────────▼─────────────────────────┐  │
│  │          AuthService.swift                │  │
│  │  • Manages auth state                     │  │
│  │  • Calls Supabase Auth API                │  │
│  │  • Syncs profile data                     │  │
│  └─────────────────┬─────────────────────────┘  │
└────────────────────┼──────────────────────────────┘
                     │
                     │ HTTP/WebSocket
                     │
┌────────────────────▼──────────────────────────────┐
│              Supabase Backend                     │
│  ┌───────────────────────────────────────────┐    │
│  │         auth.users (built-in)             │    │
│  │  • Email/password storage                 │    │
│  │  • OAuth token validation                 │    │
│  │  • Session management                     │    │
│  └─────────────────┬─────────────────────────┘    │
│                    │                              │
│  ┌─────────────────▼─────────────────────────┐    │
│  │     public.profiles (custom)              │    │
│  │  • Extended user data                     │    │
│  │  • auth_provider tracking                 │    │
│  │  • Custom fields (phone, city, etc.)      │    │
│  └───────────────────────────────────────────┘    │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │         RPC Functions                      │   │
│  │  • get_or_create_profile()                 │   │
│  │  • update_profile()                        │   │
│  │  • get_profile_by_email()                  │   │
│  │  • deactivate_account()                    │   │
│  │  • reactivate_account()                    │   │
│  └────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────┘
```

## Files Changed/Created

### Backend
- ✅ `supabase/migrations/20260203_auth_enhancement.sql` - New migration
- ✅ `supabase/config.toml` - OAuth configuration
- ✅ `AUTH_IMPLEMENTATION.md` - Detailed documentation
- ✅ `AUTH_QUICKSTART.md` - This file

### iOS
- ✅ `Helpers/AuthService.swift` - New authentication service
- ✅ `Views/LoginView.swift` - Enhanced login UI
- ⏳ `ContentView.swift` - Needs integration (see above)
- ⏳ `SubscribeCoffieCleanApp.swift` - May need auth state setup

## Support & Documentation

- Full docs: `AUTH_IMPLEMENTATION.md`
- Supabase docs: https://supabase.com/docs/guides/auth
- Apple Sign In: https://developer.apple.com/sign-in-with-apple/
- Google OAuth: https://developers.google.com/identity

## Troubleshooting

**Issue:** Migration fails with "column already exists"
- **Solution:** This is normal if re-running. The migration uses `IF NOT EXISTS` to be idempotent.

**Issue:** "Email confirmations required" error
- **Solution:** Set `enable_confirmations = false` in config.toml for dev

**Issue:** Apple Sign In doesn't work
- **Solution:** Must test on real device, not simulator

**Issue:** OAuth redirect fails
- **Solution:** Check redirect URLs match exactly in provider console

## Next Steps

1. ✅ Backend migration completed
2. ✅ iOS UI and service created
3. ⏳ Integrate AuthService with ContentView
4. ⏳ Test all auth flows
5. ⏳ Set up OAuth credentials for production
6. ⏳ Deploy to cloud

---

**Status:** ✅ Implementation Complete - Ready for Integration Testing
