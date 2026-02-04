# Supabase Auth Provider Configuration Guide

## Overview

This document explains the Supabase authentication configuration for the SubscribeCoffie iOS app. The system supports multiple authentication methods:

- **Email/Password** - Traditional email-based authentication
- **Phone/SMS** - Phone number with OTP verification
- **Apple Sign In** - Native iOS authentication
- **Google Sign In** - OAuth authentication via Google

## Configuration Files

### 1. `supabase/config.toml`

Main Supabase configuration file with auth provider settings.

**Key Changes Made:**

- Added iOS deep link redirect URL: `subscribecoffie://auth/callback`
- Enabled Apple OAuth provider
- Enabled Google OAuth provider  
- Configured test OTP codes for local phone authentication
- Email confirmations disabled for development (enable in production)

### 2. `env.local.example`

Template for environment variables containing OAuth secrets.

**Required for OAuth (Production):**

```bash
# Copy the example file
cp env.local.example .env.local

# Edit .env.local with your actual credentials
```

## Authentication Methods Configuration

### Email/Password Authentication

**Status:** ✅ Enabled by default

**Configuration:**
```toml
[auth.email]
enable_signup = true
enable_confirmations = false  # Set to true in production
otp_length = 6
otp_expiry = 3600  # 1 hour
```

**Local Development:**
- Emails are captured by Inbucket at `http://127.0.0.1:54324`
- No real emails are sent
- Email confirmation disabled for easier testing

**Production Setup:**
1. Enable email confirmations: `enable_confirmations = true`
2. Configure SMTP provider (SendGrid recommended)
3. Set `SENDGRID_API_KEY` environment variable

### Phone/SMS Authentication

**Status:** ✅ Enabled with test OTP codes

**Configuration:**
```toml
[auth.sms]
enable_signup = true
enable_confirmations = true
template = "Your code is {{ .Code }}"
max_frequency = "5s"

[auth.sms.test_otp]
"+79991234567" = "123456"
"+79991234568" = "654321"
```

**Local Development:**
- Use test phone numbers with predefined OTP codes
- No real SMS messages are sent
- Test numbers:
  - `+79991234567` → OTP: `123456`
  - `+79991234568` → OTP: `654321`

**Production Setup:**
1. Sign up for Twilio: https://console.twilio.com/
2. Get Account SID, Message Service SID, and Auth Token
3. Configure in `config.toml`:
   ```toml
   [auth.sms.twilio]
   enabled = true
   account_sid = "your_account_sid"
   message_service_sid = "your_message_service_sid"
   auth_token = "env(SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN)"
   ```
4. Set `SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN` environment variable
5. Remove or comment out `[auth.sms.test_otp]` section

### Apple Sign In

**Status:** ✅ Enabled (requires credentials)

**Configuration:**
```toml
[auth.external.apple]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)"
redirect_uri = "subscribecoffie://auth/callback"
```

**Setup Steps:**

1. **Apple Developer Console** (https://developer.apple.com/account/)
   - Create an App ID with "Sign in with Apple" capability
   - Create a Services ID (this becomes your `client_id`)
   - Configure redirect URLs: 
     - Development: `http://127.0.0.1:54321/auth/v1/callback`
     - Production: `https://your-project.supabase.co/auth/v1/callback`
     - iOS Deep Link: `subscribecoffie://auth/callback`
   - Create a Key for Sign in with Apple
   - Download the `.p8` key file

2. **Generate Client Secret** (required for Apple)
   - Use Apple's JWT generation tool or Supabase CLI
   - The secret expires every 6 months
   - Store in environment: `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET`

3. **Environment Variables**
   ```bash
   SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID=com.yourcompany.subscribecoffie.services
   SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

4. **iOS App Configuration**
   - Add "Sign in with Apple" capability in Xcode
   - Add URL scheme to `Info.plist` (see below)
   - Handle OAuth callback in app delegate

**Testing:**
- Apple Sign In works only on physical devices (not simulator)
- Use TestFlight for beta testing

### Google Sign In

**Status:** ✅ Enabled (requires credentials)

**Configuration:**
```toml
[auth.external.google]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
redirect_uri = "subscribecoffie://auth/callback"
skip_nonce_check = true  # Required for local development
```

**Setup Steps:**

1. **Google Cloud Console** (https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google+ API
   - Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
   - Choose "iOS" application type
   - Add Bundle ID: `com.yourcompany.subscribecoffie`
   - Add URL scheme: `subscribecoffie`

2. **Configure Redirect URIs**
   - Development: `http://127.0.0.1:54321/auth/v1/callback`
   - Production: `https://your-project.supabase.co/auth/v1/callback`
   - iOS Deep Link: `subscribecoffie://auth/callback`

3. **Environment Variables**
   ```bash
   SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=123456789-abc123.apps.googleusercontent.com
   SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=GOCSPX-abc123xyz789
   ```

4. **iOS App Configuration**
   - Add URL scheme to `Info.plist`
   - Install Google Sign-In SDK (if using native button)
   - Or use Supabase's OAuth flow (recommended)

**Testing:**
- Google Sign In works on both simulator and physical devices
- Use test Google accounts during development

## iOS Deep Linking Configuration

The app uses custom URL scheme for OAuth callbacks: `subscribecoffie://auth/callback`

### Info.plist Configuration

Add this to your iOS app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>subscribecoffie</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.subscribecoffie</string>
    </dict>
</array>
```

### App Delegate Handler

Add to `SubscribeCoffieCleanApp.swift`:

```swift
.onOpenURL { url in
    Task {
        try? await AuthService.shared.handleOAuthCallback(url: url)
    }
}
```

## Security Configuration

### Password Requirements

```toml
[auth]
minimum_password_length = 6
password_requirements = ""  # Can be: letters_digits, lower_upper_letters_digits, lower_upper_letters_digits_symbols
```

### Rate Limiting

Configured to prevent abuse:

```toml
[auth.rate_limit]
email_sent = 2              # Emails per hour
sms_sent = 30               # SMS per hour
sign_in_sign_ups = 30       # Logins per 5 minutes per IP
token_verifications = 30    # OTP verifications per 5 minutes per IP
```

### JWT Configuration

```toml
[auth]
jwt_expiry = 3600                      # 1 hour
enable_refresh_token_rotation = true
refresh_token_reuse_interval = 10      # 10 seconds grace period
```

## Environment Variables Reference

### Local Development (.env.local)

```bash
# Apple OAuth (optional for local dev)
SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID=com.yourcompany.subscribecoffie.services
SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=eyJhbGc...

# Google OAuth (optional for local dev)
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=GOCSPX-abc123

# SMS (not needed for local dev - using test OTP)
# SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN=your_token

# Email SMTP (not needed for local dev - using Inbucket)
# SENDGRID_API_KEY=SG.abc123
```

### Production Environment

For production deployment on Supabase Cloud:

1. Go to Supabase Dashboard → Project Settings → Configuration
2. Add environment variables in "Environment Variables" section
3. Or use Supabase CLI:
   ```bash
   supabase secrets set SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID=...
   supabase secrets set SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=...
   supabase secrets set SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=...
   supabase secrets set SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...
   ```

## Testing Checklist

### Local Development

- [ ] Email signup works (check Inbucket for confirmation email)
- [ ] Email login works
- [ ] Password reset works (check Inbucket)
- [ ] Phone signup works with test numbers (+79991234567 → 123456)
- [ ] Phone login works with test OTP
- [ ] Configuration file is valid (run `supabase start`)

### Production Setup

- [ ] Apple Sign In credentials configured
- [ ] Google Sign In credentials configured
- [ ] Twilio SMS provider configured (if using real SMS)
- [ ] SMTP email provider configured (if using real emails)
- [ ] Email confirmations enabled
- [ ] Redirect URLs configured in provider consoles
- [ ] iOS deep linking tested on physical device
- [ ] Rate limiting tested
- [ ] Password requirements enforced

## Troubleshooting

### Issue: OAuth callback not working

**Solution:**
1. Verify URL scheme in `Info.plist` matches `subscribecoffie`
2. Check redirect URI in provider console matches `subscribecoffie://auth/callback`
3. Ensure `additional_redirect_urls` in config.toml includes the deep link
4. Check app delegate has `.onOpenURL` handler

### Issue: Phone OTP not working locally

**Solution:**
1. Use exact test phone numbers: `+79991234567` or `+79991234568`
2. Use exact OTP codes: `123456` or `654321`
3. Check `[auth.sms.test_otp]` section is uncommented in config.toml

### Issue: Apple Sign In shows "Invalid Client"

**Solution:**
1. Regenerate Apple client secret (they expire every 6 months)
2. Verify Services ID matches `client_id`
3. Check redirect URLs in Apple Developer Console
4. Ensure "Sign in with Apple" capability is enabled in Xcode

### Issue: Google Sign In shows "redirect_uri_mismatch"

**Solution:**
1. Add all redirect URIs to Google Cloud Console:
   - `http://127.0.0.1:54321/auth/v1/callback`
   - `https://your-project.supabase.co/auth/v1/callback`
   - `subscribecoffie://auth/callback`
2. Wait a few minutes for Google to propagate changes

## Next Steps

After configuration is complete:

1. **Backend Phase**: Run database migration to create RPC functions
2. **iOS Phase**: Enable AuthService and create login views
3. **Testing Phase**: Verify all auth methods work end-to-end
4. **Production Phase**: Deploy with production OAuth credentials

## Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Apple Sign In Setup](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Google Sign In Setup](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Phone Auth Setup](https://supabase.com/docs/guides/auth/phone-login)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli)
