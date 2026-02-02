# Authentication Setup Guide

## Overview

SubscribeCoffie now supports multiple authentication methods:

1. **Email + Password** - Traditional email/password authentication
2. **Magic Link** - Passwordless email authentication with OTP
3. **Phone (SMS)** - Phone number authentication with SMS OTP
4. **Sign in with Apple** - OAuth authentication via Apple ID
5. **Sign in with Google** - OAuth authentication via Google

## Database Schema

The authentication system uses the following tables:

### `user_profiles`
Extended user profiles with OAuth support and preferences.

**Key Fields:**
- `id` - UUID, references auth.users
- `email`, `phone`, `full_name`, `avatar_url` - User identity
- `auth_provider` - Primary auth method (email, google, apple, phone)
- `notification_enabled`, `email_marketing_enabled`, `push_marketing_enabled` - Preferences
- `preferred_language`, `theme` - App preferences
- `is_verified`, `is_active` - Account status
- `last_login_at` - Last successful login timestamp

### `oauth_connections`
Tracks OAuth provider connections for each user. Users can link multiple providers.

**Key Fields:**
- `user_id` - References auth.users
- `provider` - OAuth provider (google, apple, facebook, github)
- `provider_user_id` - User ID from the provider
- `provider_email` - Email from the provider
- `is_primary` - Whether this is the primary auth method

### `login_history`
Security audit log for all login attempts.

**Key Fields:**
- `user_id` - References auth.users
- `login_method` - Method used (email, google, apple, phone, magic_link)
- `ip_address`, `user_agent`, `device_info` - Request metadata
- `success` - Whether login was successful
- `failure_reason` - Error message if failed

### `account_deletion_requests`
GDPR-compliant account deletion requests.

**Key Fields:**
- `user_id` - References auth.users
- `reason` - User-provided reason for deletion
- `status` - pending, approved, rejected, completed

## RPC Functions

### User Profile Management

#### `get_user_profile(p_user_id uuid)`
Returns complete user profile with OAuth connections.

**Returns:** JSONB with user profile data

**Example:**
```sql
SELECT public.get_user_profile('user-uuid-here');
```

#### `update_user_profile(...)`
Updates user profile information.

**Parameters:**
- `p_full_name` - Full name
- `p_birth_date` - Birth date
- `p_city` - City
- `p_bio` - Biography
- `p_avatar_url` - Avatar URL
- `p_notification_enabled` - Enable notifications
- `p_email_marketing_enabled` - Enable email marketing
- `p_push_marketing_enabled` - Enable push marketing
- `p_preferred_language` - Preferred language (ru, en)
- `p_theme` - Theme preference (light, dark, system)

**Returns:** JSONB with updated profile

### Authentication Logging

#### `record_login_attempt(...)`
Records a login attempt for security audit.

**Parameters:**
- `p_user_id` - User UUID
- `p_login_method` - Method used (email, google, apple, phone, magic_link)
- `p_ip_address` - Client IP address
- `p_user_agent` - Client user agent
- `p_device_info` - Device information (JSONB)
- `p_success` - Whether login was successful
- `p_failure_reason` - Error message if failed

**Returns:** UUID of login history record

#### `get_login_history(p_limit int, p_offset int)`
Gets user's login history.

**Returns:** JSONB array of login history items

### OAuth Management

#### `link_oauth_provider(...)`
Links an OAuth provider to the user's account.

**Parameters:**
- `p_provider` - Provider name (google, apple, facebook, github)
- `p_provider_user_id` - User ID from provider
- `p_provider_email` - Email from provider
- `p_provider_data` - Additional provider data (JSONB)
- `p_is_primary` - Set as primary auth method

**Returns:** JSONB with connection details

#### `unlink_oauth_provider(p_provider text)`
Unlinks an OAuth provider from the user's account.

**Note:** Cannot unlink if it's the only authentication method.

**Returns:** JSONB with success status

### Account Management

#### `request_account_deletion(p_reason text)`
Submits a GDPR-compliant account deletion request.

**Returns:** JSONB with request details

## iOS Integration

### AuthService

The `AuthService` class provides a unified interface for all authentication methods.

#### Setup

```swift
@StateObject private var authService = AuthService()
```

#### Email Authentication

**Sign Up:**
```swift
try await authService.signUpWithEmail(
    email: "user@example.com",
    password: "securePassword123",
    fullName: "John Doe"
)
```

**Sign In:**
```swift
try await authService.signInWithEmail(
    email: "user@example.com",
    password: "securePassword123"
)
```

**Password Reset:**
```swift
try await authService.sendPasswordResetEmail(email: "user@example.com")
```

#### Magic Link Authentication

**Send Magic Link:**
```swift
try await authService.sendMagicLink(email: "user@example.com")
```

**Verify OTP:**
```swift
try await authService.verifyOTP(
    email: "user@example.com",
    token: "123456"
)
```

#### Phone Authentication

**Send SMS OTP:**
```swift
try await authService.signInWithPhone(phone: "+79001234567")
```

**Verify SMS OTP:**
```swift
try await authService.verifyPhoneOTP(
    phone: "+79001234567",
    token: "123456"
)
```

#### OAuth Authentication

**Sign in with Apple:**
```swift
// In your view
SignInWithAppleButton(
    onRequest: { request in
        request.requestedScopes = [.fullName, .email]
    },
    onCompletion: { result in
        switch result {
        case .success(let authorization):
            Task {
                try await authService.signInWithApple(authorization: authorization)
            }
        case .failure(let error):
            print("Error: \(error)")
        }
    }
)
```

**Sign in with Google:**
```swift
try await authService.signInWithGoogle()
```

**Handle OAuth Callback:**
```swift
// In your app's deep link handler
try await authService.handleOAuthCallback(url: url)
```

#### Profile Management

**Update Profile:**
```swift
let updatedProfile = try await authService.updateProfile(
    fullName: "John Doe",
    birthDate: Date(),
    city: "Moscow",
    bio: "Coffee enthusiast"
)
```

**Update Preferences:**
```swift
try await authService.updatePreferences(
    notificationsEnabled: true,
    emailMarketingEnabled: false,
    language: "ru",
    theme: "dark"
)
```

#### Session Management

**Check Session:**
```swift
await authService.checkSession()
```

**Sign Out:**
```swift
try await authService.signOut()
```

**Get Login History:**
```swift
let history = try await authService.getLoginHistory(limit: 10, offset: 0)
```

#### Account Deletion

**Request Deletion:**
```swift
try await authService.requestAccountDeletion(
    reason: "No longer need the service"
)
```

### Published Properties

The `AuthService` publishes the following properties for SwiftUI binding:

- `@Published var currentUser: User?` - Current authenticated user
- `@Published var userProfile: UserProfile?` - Extended user profile
- `@Published var isAuthenticated: Bool` - Authentication status
- `@Published var isLoading: Bool` - Loading state
- `@Published var errorMessage: String?` - Last error message

### Models

#### UserProfile
```swift
struct UserProfile: Codable {
    let id: UUID
    var email: String?
    var phone: String?
    var fullName: String?
    var avatarUrl: String?
    var birthDate: String?
    var city: String?
    var bio: String?
    var authProvider: String
    var notificationEnabled: Bool
    var emailMarketingEnabled: Bool
    var pushMarketingEnabled: Bool
    var preferredLanguage: String
    var theme: String
    var isVerified: Bool
    var isActive: Bool
    var lastLoginAt: String?
    var oauthConnections: [OAuthConnection]?
}
```

#### OAuthConnection
```swift
struct OAuthConnection: Codable {
    let provider: String
    let providerEmail: String?
    let isPrimary: Bool
    let createdAt: String
}
```

#### LoginHistoryItem
```swift
struct LoginHistoryItem: Codable {
    let id: UUID
    let loginMethod: String
    let ipAddress: String?
    let userAgent: String?
    let deviceInfo: [String: String]?
    let success: Bool
    let failureReason: String?
    let createdAt: String
}
```

## Configuration

### Supabase Config (config.toml)

#### Email Authentication
Already enabled by default:
```toml
[auth.email]
enable_signup = true
enable_confirmations = false
```

#### SMS Authentication
```toml
[auth.sms]
enable_signup = true
enable_confirmations = true
template = "Your code is {{ .Code }}"
```

#### OAuth Providers

**Apple:**
```toml
[auth.external.apple]
enabled = true
client_id = ""
secret = "env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)"
```

**Google:**
```toml
[auth.external.google]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
skip_nonce_check = true
```

### Environment Variables

Create a `.env.local` file in the `supabase` directory:

```bash
# Apple OAuth (for production)
SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=your_apple_secret

# Google OAuth
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=your_google_client_id
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=your_google_client_secret
```

### iOS Configuration

#### Info.plist

Add URL scheme for OAuth callbacks:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>subscribecoffie</string>
        </array>
    </dict>
</array>
```

#### Sign in with Apple Capability

1. Enable "Sign in with Apple" capability in Xcode
2. Add to your App ID in Apple Developer Portal

## Testing

### Local Development

For local development, you can use test OTP codes:

```toml
[auth.sms.test_otp]
79001234567 = "123456"
```

### Email Testing

Supabase local development captures all emails. Check the Inbucket UI at:
```
http://localhost:54324
```

### OAuth Testing

For local OAuth testing:
1. Use ngrok or similar to expose your local server
2. Configure OAuth redirect URLs to point to your ngrok URL
3. Set `skip_nonce_check = true` for Google (already done)

## Security Considerations

1. **Password Requirements**: Minimum 6 characters (configurable in config.toml)
2. **Rate Limiting**: Configured in `[auth.rate_limit]` section
3. **RLS Policies**: All tables have Row Level Security enabled
4. **OAuth Secrets**: Never commit secrets to git, use environment variables
5. **Login History**: All login attempts are logged for security audit
6. **Account Deletion**: GDPR-compliant deletion process

## Migration

To apply the authentication enhancement migration:

```bash
cd SubscribeCoffieBackend
supabase db reset  # For local development
# OR
supabase db push   # For production
```

## Troubleshooting

### "Not authenticated" error
- Check if session is valid: `await authService.checkSession()`
- Verify JWT token is not expired
- Ensure RLS policies allow the operation

### OAuth callback not working
- Verify URL scheme is configured in Info.plist
- Check redirect URI matches in OAuth provider settings
- Ensure `handleOAuthCallback` is called in app delegate

### SMS not sending
- For local dev, check test OTP configuration
- For production, configure Twilio in config.toml
- Verify phone number format (+7XXXXXXXXXX)

### Email not sending
- For local dev, check Inbucket UI
- For production, configure SMTP in config.toml

## Next Steps

1. **Production OAuth Setup**:
   - Register app with Google Cloud Console
   - Register app with Apple Developer Portal
   - Configure production redirect URIs

2. **SMS Provider Setup**:
   - Sign up for Twilio account
   - Configure Twilio credentials in config.toml

3. **Email Provider Setup**:
   - Configure SendGrid or other SMTP provider
   - Update email templates

4. **UI Enhancements**:
   - Add profile editing screen
   - Add security settings screen
   - Add login history viewer
   - Add OAuth connection management

5. **Testing**:
   - Write unit tests for AuthService
   - Write integration tests for auth flows
   - Test all OAuth providers in production

## References

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)
