# Owner Admin Panel - Test User Credentials

## 🔐 Permanent Test User

**NEVER CHANGE THESE CREDENTIALS**

### Login Details:
```
Email: levitm@algsoft.ru
Password: 1234567890
Role: owner
```

## 📋 Setup Instructions

### Option 1: Manual Setup via Supabase Studio (Recommended for Local)

1. Open Supabase Studio: `http://localhost:54323`
2. Navigate to **Authentication > Users**
3. Click **"Add User"** or **"Invite User"**
4. Enter:
   - **Email**: `levitm@algsoft.ru`
   - **Password**: `1234567890`
   - Check **"Auto Confirm User"** (important!)
5. Click **Create User**

6. Then run the SQL to set role:
   - Go to **SQL Editor**
   - Run the script: `supabase/migrations/20260201_create_owner_test_user.sql`

### Option 2: Using Supabase CLI

```bash
cd SubscribeCoffieBackend

# Start Supabase if not running
supabase start

# Run the migration
supabase db push

# Or apply specific migration
supabase migration up
```

### Option 3: Direct SQL (if user already exists)

```sql
-- Set role to owner
INSERT INTO user_roles (user_id, role)
SELECT id, 'owner'
FROM auth.users
WHERE email = 'levitm@algsoft.ru'
ON CONFLICT (user_id) DO UPDATE SET role = 'owner';
```

## 🧪 Testing Access

After setup, test the login:

1. Open: `http://localhost:3001/login`
2. Enter credentials:
   - Email: `levitm@algsoft.ru`
   - Password: `1234567890`
3. You should be redirected to: `http://localhost:3001/admin/owner/dashboard`

## 📊 Test Data

The migration also creates:
- A test account: **"Test Owner Company"**
- A test cafe: **"Test Coffee Point"** (in draft status)

## 🔧 Troubleshooting

### User not found
```bash
# Check if user exists
supabase db query "SELECT id, email, email_confirmed_at FROM auth.users WHERE email = 'levitm@algsoft.ru'"
```

### Role not set
```bash
# Check user role
supabase db query "SELECT u.email, ur.role FROM auth.users u LEFT JOIN user_roles ur ON u.id = ur.user_id WHERE u.email = 'levitm@algsoft.ru'"
```

### Password doesn't work
- Recreate the user in Supabase Studio
- Make sure to check "Auto Confirm User"
- Use exactly: `1234567890` (no spaces)

## 🚨 Security Note

**FOR DEVELOPMENT ONLY**

This is a test account with a simple password. Never use these credentials in production.

## 📝 Additional Notes

- This user has **owner** role
- Can access: `/admin/owner/*` routes
- Can manage multiple cafes
- Can switch between cafes using the CafeSwitcher component

---

**Last Updated**: February 1, 2026
**Status**: Active
**Environment**: Development Only
