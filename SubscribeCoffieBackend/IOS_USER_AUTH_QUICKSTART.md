# iOS User Authentication Migration - Quick Start Guide

## Overview

This migration (`20260204000001_ios_user_auth.sql`) enables full production-ready user authentication for the iOS app with support for multiple authentication methods:

- ✅ Email/Password registration
- ✅ Phone/SMS OTP authentication
- ✅ Apple Sign In (OAuth)
- ✅ Google Sign In (OAuth)

## What Changed

### Database Schema Enhancements

#### Profiles Table - New Columns

| Column | Type | Description |
|--------|------|-------------|
| `avatar_url` | text | Profile picture URL (from OAuth or uploads) |
| `auth_provider` | text | Authentication method: 'email', 'phone', 'google', 'apple' |
| `updated_at` | timestamptz | Auto-updated timestamp for profile changes |

#### New Indexes

- `profiles_phone_idx` - Fast phone number lookups
- `profiles_auth_provider_idx` - Filter users by auth method
- `profiles_avatar_url_idx` - Quick avatar checks

### New RPC Functions

#### For iOS App (Authenticated Users)

1. **`init_user_profile(full_name, birth_date, city, phone?)`**
   - Called after user signs up to complete profile
   - Required fields: full_name, birth_date, city
   - Optional: phone (if not already set via phone auth)
   - Returns: JSON profile object

2. **`get_my_profile()`**
   - Fetches current user's complete profile
   - No parameters needed (uses auth token)
   - Returns: JSON profile object

3. **`update_my_profile(full_name?, phone?, birth_date?, city?, avatar_url?, default_wallet_type?, default_cafe_id?)`**
   - Updates current user's profile
   - All parameters optional - only updates provided fields
   - Returns: JSON profile object

#### For Admin Panel

4. **`get_user_profile(user_id)`**
   - Admin-only: Fetch any user's profile by ID
   - Returns: JSON profile object

5. **`search_users(search_term, limit?, offset?)`**
   - Admin-only: Search users by name, email, or phone
   - Returns: JSON array of matching profiles

### Enhanced Trigger

The `handle_new_user()` trigger now automatically:
- Detects OAuth provider from auth metadata
- Extracts avatar URL from OAuth response
- Extracts full name from OAuth response
- Sets appropriate `auth_provider` value

### New View

**`orders_with_profiles`**
- Joins orders with user profile data
- Useful for admin panel to show user info on orders
- Contains: user_full_name, user_email, user_phone, user_avatar_url, user_auth_provider, user_registered_at

## How to Use

### Step 1: Apply Migration

```bash
cd SubscribeCoffieBackend
supabase db push
```

Or manually:
```bash
psql -U postgres -d postgres -f supabase/migrations/20260204000001_ios_user_auth.sql
```

### Step 2: Run Tests (Optional but Recommended)

```bash
psql -U postgres -d postgres -f tests/ios_user_auth_tests.sql
```

Expected output: All 23 tests should pass.

### Step 3: iOS Integration

#### A. Email/Password Registration Flow

```swift
// 1. User signs up with email
let authResponse = try await supabase.auth.signUp(
    email: email,
    password: password
)

// 2. Complete profile setup
let profileData = try await supabase.rpc(
    "init_user_profile",
    params: [
        "p_full_name": fullName,
        "p_birth_date": birthDate,
        "p_city": city
    ]
).execute()
```

#### B. Phone/SMS Registration Flow

```swift
// 1. Send OTP
try await supabase.auth.signInWithOTP(
    phone: phoneNumber
)

// 2. Verify OTP
let authResponse = try await supabase.auth.verifyOTP(
    phone: phoneNumber,
    token: otpCode,
    type: .sms
)

// 3. Complete profile setup
let profileData = try await supabase.rpc(
    "init_user_profile",
    params: [
        "p_full_name": fullName,
        "p_birth_date": birthDate,
        "p_city": city,
        "p_phone": phoneNumber
    ]
).execute()
```

#### C. Apple Sign In Flow

```swift
// 1. Sign in with Apple
let authResponse = try await supabase.auth.signInWithIdToken(
    credentials: .init(
        provider: .apple,
        idToken: appleIDToken
    )
)

// 2. Profile auto-created! Just fetch it
let profile = try await supabase.rpc("get_my_profile").execute()

// 3. If needed, complete missing fields
if profile.birthDate == nil || profile.city == nil {
    try await supabase.rpc(
        "init_user_profile",
        params: [
            "p_full_name": profile.fullName ?? "User",
            "p_birth_date": birthDate,
            "p_city": city
        ]
    ).execute()
}
```

#### D. Get Current User Profile

```swift
let profile = try await supabase.rpc("get_my_profile").execute()
```

#### E. Update Profile

```swift
let updatedProfile = try await supabase.rpc(
    "update_my_profile",
    params: [
        "p_city": "Санкт-Петербург",
        "p_avatar_url": "https://example.com/avatar.jpg"
    ]
).execute()
```

### Step 4: Admin Panel Integration

#### List Users Page

```typescript
// app/admin/users/page.tsx
const { data: users } = await supabase
  .from('profiles')
  .select('*')
  .order('created_at', { ascending: false })
  .range(offset, offset + limit - 1)
```

#### Search Users

```typescript
const { data: results } = await supabase
  .rpc('search_users', {
    p_search_term: searchQuery,
    p_limit: 20,
    p_offset: 0
  })
```

#### Order Details with User Info

```typescript
const { data: order } = await supabase
  .from('orders_with_profiles')
  .select('*')
  .eq('id', orderId)
  .single()

// Now you have:
// order.user_full_name
// order.user_email
// order.user_phone
// order.user_avatar_url
// order.user_auth_provider
```

## Data Examples

### Email Registration Profile

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "full_name": "John Doe",
  "phone": "+79991234567",
  "birth_date": "1990-01-15",
  "city": "Москва",
  "auth_provider": "email",
  "avatar_url": null,
  "role": "user",
  "created_at": "2026-02-04T10:00:00Z",
  "updated_at": "2026-02-04T10:05:00Z"
}
```

### Apple OAuth Profile

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "email": "apple@privaterelay.appleid.com",
  "full_name": "Apple User",
  "phone": null,
  "birth_date": "1995-06-20",
  "city": "Москва",
  "auth_provider": "apple",
  "avatar_url": "https://example.com/apple_avatar.jpg",
  "role": "user",
  "created_at": "2026-02-04T11:00:00Z",
  "updated_at": "2026-02-04T11:00:30Z"
}
```

## Security Notes

### RLS Policies

All existing RLS policies remain in place:
- Users can read/update their own profile
- Admins can read/update all profiles
- New RPC functions respect these policies

### Function Security

- `init_user_profile()` - User can only initialize their own profile
- `get_my_profile()` - User can only get their own profile
- `update_my_profile()` - User can only update their own profile
- `get_user_profile()` - Admin only
- `search_users()` - Admin only

### Data Validation

- `full_name` - Required, cannot be empty
- `birth_date` - Required
- `city` - Required, cannot be empty
- `phone` - Optional, but validated format recommended
- `auth_provider` - Constrained to: 'email', 'phone', 'google', 'apple'

## Troubleshooting

### Issue: Profile not created after signup

**Solution:** Check if `handle_new_user()` trigger is active:
```sql
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

### Issue: OAuth avatar not appearing

**Solution:** Check raw_user_meta_data in auth.users:
```sql
SELECT raw_user_meta_data FROM auth.users WHERE id = 'user_id';
```

### Issue: RPC function permission denied

**Solution:** Grant execute permissions:
```sql
GRANT EXECUTE ON FUNCTION public.init_user_profile TO authenticated;
```

### Issue: Phone index not being used

**Solution:** Ensure phone has value:
```sql
EXPLAIN ANALYZE 
SELECT * FROM profiles WHERE phone = '+79991234567';
```

## Performance

### Benchmark Results (Expected)

- Profile lookup by ID: < 1ms
- Phone number search: < 5ms (with index)
- Email search: < 5ms (with unique index)
- Profile update: < 2ms
- OAuth profile creation: < 10ms

### Optimization Tips

1. Use `get_my_profile()` sparingly - cache in iOS app
2. Batch profile updates when possible
3. Use `orders_with_profiles` view only when you need user data
4. Implement pagination for user lists (use offset/limit)

## Next Steps

1. ✅ Migration applied
2. ⬜ Update iOS `AuthService.swift` to use new RPCs
3. ⬜ Create iOS registration UI views
4. ⬜ Update admin panel users page
5. ⬜ Configure OAuth providers in Supabase Dashboard
6. ⬜ Test all authentication flows
7. ⬜ Deploy to production

## Support

- Migration file: `supabase/migrations/20260204000001_ios_user_auth.sql`
- Test file: `tests/ios_user_auth_tests.sql`
- Implementation plan: See root plan document

## Version History

- **v1.0** (2026-02-04): Initial release with full authentication support
