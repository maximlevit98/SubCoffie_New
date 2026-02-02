# Authentication Implementation Guide

## Overview

SubscribeCoffie now supports multiple authentication methods:
- **Email + Password** - Traditional email/password authentication
- **Sign in with Apple** - OAuth via Apple ID
- **Sign in with Google** - OAuth via Google
- **Phone-based authentication** - Legacy SMS-based login (mock implementation for now)

## Architecture

### Backend (Supabase)

The authentication system is built on Supabase Auth with the following components:

#### Database Schema

**Migration: `20260203_auth_enhancement.sql`**

Enhanced `profiles` table with new columns:
- `avatar_url` - Profile picture URL (from OAuth or uploaded)
- `auth_provider` - Authentication method used ('email', 'phone', 'google', 'apple')
- `last_sign_in_at` - Last successful sign-in timestamp
- `updated_at` - Profile update timestamp
- `is_active` - Account status (active/deactivated)

#### RPC Functions

1. **`get_or_create_profile(user_id uuid)`**
   - Retrieves or creates user profile
   - Returns full profile JSON
   - Security: User can access own profile, admins can access any

2. **`update_profile(...)`**
   - Updates user profile fields
   - Parameters: user_id, full_name, phone, birth_date, city, avatar_url, etc.
   - Security: User can update own profile, admins can update any

3. **`get_profile_by_email(p_email text)`**
   - Admin-only function to find users by email
   - Useful for support and user management

4. **`deactivate_account(p_user_id uuid)`**
   - Soft-delete user account
   - User can deactivate own account, admins can deactivate any

5. **`reactivate_account(p_user_id uuid)`**
   - Reactivate previously deactivated account
   - Admin-only function

#### Triggers

- **`on_auth_user_created`** - Automatically creates profile when user signs up
- **`on_auth_user_updated`** - Syncs auth.users data to profiles table
- **`set_profiles_updated_at`** - Updates timestamp on profile changes

### iOS App

**New files:**
- `AuthService.swift` - Main authentication service
- `LoginView.swift` - Enhanced login UI with multiple auth methods

#### AuthService

The `AuthService` class is a singleton that manages all authentication operations:

```swift
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var currentProfile: UserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    
    // Email/Password
    func signUpWithEmail(email: String, password: String, fullName: String?) async throws
    func signInWithEmail(email: String, password: String) async throws
    
    // OAuth
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws
    func signInWithGoogle() async throws
    
    // Password Management
    func resetPassword(email: String) async throws
    func updatePassword(newPassword: String) async throws
    
    // Session
    func signOut() async throws
    
    // Profile
    func fetchUserProfile(userId: UUID) async
    func updateProfile(...) async throws
}
```

#### LoginView

Enhanced login screen with:
- Segmented control to switch between Email and Phone auth
- Email/Password form with sign up/sign in modes
- Sign in with Apple button (native)
- Sign in with Google button
- Password reset flow
- Error handling and loading states

## Setup Instructions

### 1. Backend Configuration

#### Enable OAuth Providers in Supabase

Edit `supabase/config.toml`:

**Apple Sign In:**
```toml
[auth.external.apple]
enabled = true
client_id = "your.bundle.identifier"
secret = "env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)"
```

**Google Sign In:**
```toml
[auth.external.google]
enabled = true
client_id = "your-google-client-id.apps.googleusercontent.com"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
skip_nonce_check = true  # Required for local development
```

#### Run Migration

```bash
cd SubscribeCoffieBackend
supabase db reset  # Applies all migrations including auth enhancement
```

### 2. iOS App Configuration

#### Add Sign in with Apple Capability

1. Open Xcode project
2. Select target → Signing & Capabilities
3. Click "+ Capability"
4. Add "Sign in with Apple"

#### Update Info.plist for Google OAuth

Add URL scheme for Google OAuth callback:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

#### Update ContentView Integration

The `ContentView` needs to be updated to use `AuthService` instead of mock phone authentication. Here's how to integrate:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Main app UI
                MainAppView()
            } else {
                // Login screen
                LoginView { phone in
                    // Legacy phone auth callback (can be removed later)
                }
            }
        }
        .onAppear {
            // Check for existing session
            Task {
                if let session = await authService.getCurrentSession() {
                    // User is already logged in
                }
            }
        }
    }
}
```

### 3. Environment Variables

Create a `.env` file (DO NOT commit to git):

```bash
# Apple OAuth
SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=your_apple_secret_key

# Google OAuth
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=your_google_oauth_secret
```

### 4. Production Setup

#### Obtain OAuth Credentials

**Apple Sign In:**
1. Go to [Apple Developer Portal](https://developer.apple.com/)
2. Navigate to Certificates, Identifiers & Profiles
3. Create a Service ID for your app
4. Configure Sign in with Apple
5. Generate a private key and note the Key ID
6. Use these credentials in Supabase Dashboard → Authentication → Providers

**Google OAuth:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials (Web application)
5. Add authorized redirect URIs:
   - `https://your-project.supabase.co/auth/v1/callback`
   - `http://127.0.0.1:54321/auth/v1/callback` (for local dev)
6. Copy Client ID and Client Secret to Supabase

#### Deploy to Cloud

1. Deploy backend to Supabase Cloud:
   ```bash
   supabase link --project-ref your-project-ref
   supabase db push
   ```

2. Update iOS app with production Supabase URL:
   ```swift
   // SupabaseConfig.swift
   static let url = URL(string: "https://your-project.supabase.co")!
   static let anonKey = "your-production-anon-key"
   ```

3. Update OAuth redirect URLs in provider dashboards

## User Flows

### Email Sign Up Flow

1. User taps "Email" mode
2. Taps "Создать аккаунт"
3. Enters name, email, password, confirm password
4. Taps "Зарегистрироваться"
5. Backend creates user in `auth.users` and profile in `profiles` table
6. User receives confirmation email (if enabled)
7. User signs in with email/password

### Apple Sign In Flow

1. User taps "Войти через Apple"
2. iOS shows Apple Sign In sheet
3. User authenticates with Face ID/Touch ID
4. Apple returns identity token and user data
5. `AuthService.signInWithApple()` sends token to Supabase
6. Supabase validates token and creates/updates user
7. Profile is created/updated with Apple data (name, email)
8. User is signed in

### Google Sign In Flow

1. User taps "Войти через Google"
2. iOS opens Google OAuth web flow
3. User selects Google account and grants permissions
4. Google redirects back with authorization code
5. Supabase exchanges code for user data
6. Profile is created/updated with Google data
7. User is signed in

### Password Reset Flow

1. User taps "Забыли пароль?"
2. Enters email address
3. Taps "Отправить"
4. Backend sends password reset email
5. User clicks link in email
6. User enters new password
7. Password is updated

## Security Considerations

### Backend Security

- ✅ Row Level Security (RLS) enabled on `profiles` table
- ✅ Users can only read/update their own profile
- ✅ Admins can access all profiles
- ✅ OAuth secrets stored in environment variables (not in code)
- ✅ JWT tokens expire after 1 hour
- ✅ Refresh token rotation enabled
- ✅ Minimum password length: 6 characters

### iOS Security

- ✅ AuthService uses `@MainActor` for thread-safe state updates
- ✅ Passwords are never stored locally
- ✅ Auth tokens stored securely by Supabase SDK (uses Keychain)
- ✅ OAuth tokens are validated server-side
- ✅ Error messages don't expose sensitive information

## Testing

### Test Email Auth

```swift
// Sign up
try await authService.signUpWithEmail(
    email: "test@example.com",
    password: "testpass123",
    fullName: "Test User"
)

// Sign in
try await authService.signInWithEmail(
    email: "test@example.com",
    password: "testpass123"
)
```

### Test Apple Sign In

1. Run app on real device (Simulator doesn't support Apple Sign In fully)
2. Tap "Sign in with Apple"
3. Authenticate with test Apple ID
4. Check profile is created in Supabase Dashboard

### Test Google Sign In

1. Configure Google OAuth credentials
2. Run app
3. Tap "Sign in with Google"
4. Authenticate with test Google account
5. Check profile is created

## Migration from Legacy Phone Auth

The app still supports legacy phone-based authentication. To fully migrate:

1. Update `ContentView` to remove phone auth AppStorage keys
2. Add migration logic to convert existing phone-based users to email auth
3. Prompt users to set up email/password on next login
4. Remove phone auth code after migration period

## Troubleshooting

### Apple Sign In Issues

**Problem:** "Invalid client_id or redirect_uri"
- **Solution:** Ensure Apple Service ID matches exactly with what's configured in Supabase

**Problem:** Apple Sign In button doesn't work
- **Solution:** Test on real device, ensure capability is enabled in Xcode

### Google Sign In Issues

**Problem:** "Redirect URI mismatch"
- **Solution:** Add all possible redirect URIs to Google Console (localhost, Supabase URL)

**Problem:** "The nonce is invalid"
- **Solution:** Set `skip_nonce_check = true` in config.toml for local development

### Email Auth Issues

**Problem:** "Email confirmations required"
- **Solution:** Set `enable_confirmations = false` in config.toml for development

**Problem:** "Weak password"
- **Solution:** Ensure password is at least 6 characters

## Future Enhancements

- [ ] Add 2FA (TOTP) support
- [ ] Add biometric authentication (Face ID/Touch ID) for quick re-auth
- [ ] Add "Continue with Email Link" (passwordless)
- [ ] Add social login (Facebook, Twitter)
- [ ] Add user avatar upload
- [ ] Add email verification step
- [ ] Add phone number verification
- [ ] Implement proper SMS-based phone auth (replace mock)

## Support

For questions or issues:
1. Check Supabase logs: `supabase logs`
2. Check iOS console for error messages
3. Review RLS policies in Supabase Dashboard
4. Verify OAuth credentials are correct

## References

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Apple Sign In Documentation](https://developer.apple.com/documentation/sign_in_with_apple)
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)
