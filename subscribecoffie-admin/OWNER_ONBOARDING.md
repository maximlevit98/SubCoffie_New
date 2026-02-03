# 🎨 OWNER ONBOARDING - COMPLETE GUIDE

## 📖 OVERVIEW

Этот документ описывает **полный флоу** регистрации владельца кофейни (Owner) через систему invite-only с enterprise-уровнем безопасности.

---

## 🔄 OWNER REGISTRATION FLOW

### Step 1: Admin Creates Invitation

**Who:** Administrator  
**Where:** `/admin/owner-invitations`  
**Action:** Create new owner invitation

**Process:**
1. Admin logs in to admin panel
2. Navigates to "Owner Invitations" page
3. Fills form:
   - **Email** (required): Future owner's email
   - **Company Name** (optional): e.g. "Joe's Coffee"
   - **Cafe** (optional): Link to specific cafe
   - **Expiry** (default 7 days): 1-720 hours
4. Submits form
5. System generates **unique token** (256-bit secure random)
6. Token is **hashed (SHA256)** before storage
7. **Plaintext token shown ONCE** in UI
8. Admin copies invite URL and sends to future owner

**Security:**
- ✅ Only admin role can create invitations
- ✅ Server-side validation (email format, expiry range)
- ✅ Token never stored in plaintext
- ✅ Audit log: invitation creation

**API:**
```
POST /api/admin/owner-invites
{
  "email": "owner@example.com",
  "company_name": "Joe's Coffee",
  "cafe_id": "uuid or null",
  "expires_in_hours": 168
}
```

---

### Step 2: Owner Receives Invitation

**Who:** Future owner  
**How:** Email, messenger, or direct link  
**URL Format:**
```
https://your-domain.com/register/owner?token=abc123def456...
```

**Important:**
- ⚠️ Token is single-use
- ⏰ Token expires after N hours
- 🔒 Token must match email

---

### Step 3: Owner Opens Registration Page

**Who:** Future owner  
**Where:** `/register/owner?token=...`  
**Action:** Validate invitation token

**Process:**
1. Page loads with token from URL
2. System validates token (RPC: `validate_owner_invitation`)
3. Shows invitation status:
   - ✅ **Valid**: Show registration form
   - ❌ **Expired**: Show error + request new invite
   - ❌ **Used**: Show error + suggest login
   - ❌ **Invalid**: Show error + check URL

**Validation Checks:**
- Token exists in database (by hash)
- Status = 'pending'
- Not expired (`expires_at > now()`)
- Not reached max uses (`use_count < max_uses`)

**UI States:**
```
┌─────────────────────────────────────┐
│ ⏳ Validating invitation...         │
└─────────────────────────────────────┘

✅ Valid:
┌─────────────────────────────────────┐
│ ✅ Invitation Valid                 │
│ Email: owner@example.com            │
│ Company: Joe's Coffee               │
│ Expires: Feb 10, 2026               │
│                                     │
│ [Registration Form]                 │
└─────────────────────────────────────┘

❌ Expired:
┌─────────────────────────────────────┐
│ ⏰ Invitation Expired                │
│ This invitation expired on:         │
│ Feb 05, 2026                        │
│                                     │
│ Please request a new invitation     │
│ from the administrator.             │
│                                     │
│ [Back to Home]                      │
└─────────────────────────────────────┘
```

---

### Step 4: Owner Fills Registration Form

**Who:** Future owner  
**Where:** `/register/owner?token=...` (same page)  
**Action:** Complete registration

**Form Fields:**

| Field | Type | Validation | Required |
|-------|------|------------|----------|
| **Email** | text | Pre-filled, read-only | ✅ |
| **Full Name** | text | Min 2 chars | ✅ |
| **Phone** | text | Min 10 digits, format: +X (XXX) XXX-XXXX | ✅ |
| **Password** | password | Min 8 chars, 1 upper, 1 lower, 1 digit | ✅ |
| **Confirm Password** | password | Must match password | ✅ |

**Validation Rules:**

#### Email:
- ✅ Valid format: `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`
- ✅ Must match invitation email (case-insensitive)
- ✅ Pre-filled and read-only (cannot change)

#### Password (Strong):
- ✅ Min 8 characters
- ✅ At least 1 uppercase letter
- ✅ At least 1 lowercase letter
- ✅ At least 1 digit
- ✅ Confirm must match

**Example:**
```
✅ Valid:   MyPass123
❌ Invalid: mypass123 (no uppercase)
❌ Invalid: MYPASS123 (no lowercase)
❌ Invalid: MyPassword (no digit)
❌ Invalid: MyPass1 (too short)
```

#### Phone:
- ✅ Min 10 digits
- ✅ Allows: digits, spaces, dashes, +, (), -
- ✅ Format: `+7 (999) 123-45-67` or `+1-555-123-4567`

**Error Messages (User-Friendly):**
```
❌ "Email is required"
❌ "Please enter a valid email address"
❌ "Email must match invitation: owner@example.com"
❌ "Full name is required"
❌ "Phone number is required"
❌ "Please enter a valid phone number (at least 10 digits)"
❌ "Password is required"
❌ "Password must be at least 8 characters long"
❌ "Password must contain at least one uppercase letter"
❌ "Password must contain at least one lowercase letter"
❌ "Password must contain at least one number"
❌ "Passwords do not match"
```

---

### Step 5: System Creates User Account

**Action:** Automatic (backend)  
**Process:**

1. **Supabase Auth: Sign Up**
   ```typescript
   supabase.auth.signUp({
     email: email,
     password: password,
     options: {
       data: { full_name, phone }
     }
   })
   ```
   
2. **RPC: Redeem Invitation**
   ```typescript
   supabase.rpc('redeem_owner_invitation', {
     p_token: token
   })
   ```

**What Happens (Backend):**
1. ✅ Validate token (hash, expiry, status)
2. ✅ Verify email match (invitation vs auth user)
3. ✅ Check current role (prevent double-assignment)
4. ✅ Assign `profiles.role = 'owner'`
5. ✅ Create/get `accounts` entry
6. ✅ Link cafe (if `cafe_id` in invitation)
7. ✅ Create `cafe_owners` entry (many-to-many)
8. ✅ Mark invitation as `status = 'accepted'`
9. ✅ Increment `use_count`
10. ✅ Audit log: `owner_invitation.redeemed`

**Atomic Operation:**
- ✅ Uses `FOR UPDATE` lock (prevents race conditions)
- ✅ All-or-nothing (transaction)
- ✅ Idempotent (duplicate attempts return error)

**Error Handling:**

| Error | User Message | Action |
|-------|-------------|---------|
| Token expired | "⏰ This invitation has expired. Please request a new invitation from the administrator." | Delete auth user |
| Token used | "🔒 This invitation has already been used and cannot be redeemed again." | Delete auth user |
| Email mismatch | "📧 Email mismatch: This invitation was sent to X. Please use the correct email address." | Delete auth user |
| Already owner | "✅ You already have an owner account! Please sign in instead." | Keep user, redirect to login |
| Invalid token | "❌ Invalid invitation token. Please check your invitation link and try again." | Delete auth user |

**Cleanup on Error:**
If `redeem_owner_invitation` fails (except "already owner"), the system **automatically deletes** the newly created auth user to prevent orphan accounts.

---

### Step 6: Redirect to Dashboard

**Action:** Automatic  
**Destination:** Based on cafe linkage

**Logic:**
```typescript
if (invitation.cafe_id) {
  redirect → "/admin/owner/dashboard"  // Owner has cafe
} else {
  redirect → "/admin/owner/onboarding"  // Owner needs cafe
}
```

**Success Message:**
```
🎉 Registration successful! Welcome to the platform. 
Redirecting to your dashboard...
```

---

## 🛡️ SECURITY FEATURES

### 1. Invite-Only Access
- ❌ No public owner registration
- ✅ Only admin can create invitations
- ✅ Token-based redemption

### 2. Token Security
- ✅ **256-bit random token** (crypto-secure)
- ✅ **SHA256 hashing** (never stored plaintext)
- ✅ **URL-safe encoding** (Base64 URL-safe)
- ✅ **Single-use** (use_count tracking)
- ✅ **Expiry** (configurable 1-720 hours)
- ✅ **Shown once** (UI prevents re-display)

### 3. Email Verification
- ✅ Server-side email match validation
- ✅ Case-insensitive comparison
- ✅ Trimmed whitespace

### 4. Role Assignment
- ✅ **Server-side only** (RPC with SECURITY DEFINER)
- ✅ **Atomic operation** (FOR UPDATE lock)
- ✅ **Prevent duplicates** (check current role)
- ✅ **Prevent escalation** (cannot assign to admin)

### 5. Scope Isolation
- ✅ **RLS policies** (cafe_owners + accounts)
- ✅ **Granular permissions** (can_edit_menu, can_manage_orders)
- ✅ **Server-side guards** (`requireAdmin`, `verifyCafeOwnership`)

### 6. Audit Logging
All critical operations logged:
- ✅ Invitation creation
- ✅ Invitation redemption
- ✅ Invitation revocation
- ✅ Role assignment
- ✅ Cafe linkage

**Audit Log Structure:**
```sql
INSERT INTO audit_logs (
  actor_user_id,   -- Who performed action
  action,          -- What happened
  table_name,      -- Affected table
  record_id,       -- Affected record
  payload          -- Additional context (JSONB)
)
```

**Example:**
```json
{
  "actor_user_id": "admin-uuid",
  "action": "owner_invitation.created",
  "table_name": "owner_invitations",
  "record_id": "invitation-uuid",
  "payload": {
    "email": "owner@example.com",
    "company_name": "Joe's Coffee",
    "cafe_id": "cafe-uuid",
    "expires_at": "2026-02-10T12:00:00Z"
  }
}
```

---

## 🚫 SECURITY PROHIBITIONS (ENFORCED)

### ❌ Prohibited: Client-Side Role Assignment
```typescript
// ❌ NEVER DO THIS (blocked by RLS)
await supabase
  .from('profiles')
  .update({ role: 'owner' })
  .eq('id', userId);
```

### ❌ Prohibited: Plaintext Token Storage
```sql
-- ❌ NEVER DO THIS
CREATE TABLE owner_invitations (
  token TEXT -- Plaintext!
);

-- ✅ CORRECT (hash only)
CREATE TABLE owner_invitations (
  token_hash TEXT -- SHA256
);
```

### ❌ Prohibited: Service Role on Client
```typescript
// ❌ NEVER DO THIS
const supabase = createClient(url, SERVICE_ROLE_KEY);
```

### ❌ Prohibited: Trust Client Data
```typescript
// ❌ NEVER DO THIS
if (userClaims.role === 'admin') { /* ... */ }

// ✅ CORRECT (server-side check)
const { role } = await getUserRole(); // Queries DB
if (role === 'admin') { /* ... */ }
```

---

## 🧪 TESTING CHECKLIST

### Test 1: Happy Path (Valid Invitation)
1. Admin creates invitation for `owner@test.com`
2. Copy invite URL
3. Open URL in browser (new user)
4. Fill registration form with valid data
5. Submit
6. **Expected:** User created, role assigned, redirected to dashboard

### Test 2: Expired Invitation
1. Admin creates invitation with expiry = 1 hour
2. Wait 1 hour (or manually update `expires_at` in DB)
3. Open invite URL
4. **Expected:** "Invitation has expired" error

### Test 3: Used Invitation
1. Complete Test 1 (successful registration)
2. Try to use same invite URL again (new browser/incognito)
3. **Expected:** "Invitation already used" error

### Test 4: Email Mismatch
1. Admin creates invitation for `owner@test.com`
2. Open invite URL
3. Try to register with `different@test.com`
4. **Expected:** "Email must match invitation" error

### Test 5: Weak Password
1. Open valid invite URL
2. Try password: `weak` (no uppercase, no digit, too short)
3. **Expected:** Validation error before submission

### Test 6: Duplicate Redemption (Race Condition)
1. Admin creates invitation
2. Open invite URL in 2 tabs simultaneously
3. Submit both forms at same time
4. **Expected:** Only one succeeds, other gets "already used" error

### Test 7: Non-Admin Cannot Create Invitation
1. Login as regular user (role='user')
2. Try `POST /api/admin/owner-invites`
3. **Expected:** 403 Forbidden

### Test 8: Owner Scope Isolation
1. Create 2 owners: Owner A (Cafe 1), Owner B (Cafe 2)
2. Login as Owner A
3. Try to view/edit Cafe 2 menu items
4. **Expected:** Empty result / permission denied

---

## 📊 DATABASE SCHEMA

### Tables:

**`owner_invitations`:**
```sql
id               uuid PRIMARY KEY
email            text NOT NULL
token_hash       text NOT NULL UNIQUE  -- SHA256, never plaintext!
company_name     text
cafe_id          uuid (FK → cafes)
status           text ('pending', 'accepted', 'expired', 'revoked')
expires_at       timestamptz NOT NULL
max_uses         int DEFAULT 1
use_count        int DEFAULT 0
accepted_by_user_id  uuid (FK → auth.users)
accepted_at      timestamptz
created_by_admin_id  uuid (FK → auth.users)
created_at       timestamptz DEFAULT now()
updated_at       timestamptz DEFAULT now()
metadata         jsonb DEFAULT '{}'
```

**`cafe_owners` (Many-to-Many):**
```sql
cafe_id           uuid (FK → cafes) PRIMARY KEY
owner_id          uuid (FK → auth.users) PRIMARY KEY
role              text DEFAULT 'owner'
can_edit_menu     boolean DEFAULT true
can_manage_orders boolean DEFAULT true
can_view_finances boolean DEFAULT true
added_by          uuid (FK → auth.users)
added_at          timestamptz DEFAULT now()
metadata          jsonb DEFAULT '{}'
```

### RPC Functions:

| Function | Role | Description |
|----------|------|-------------|
| `admin_create_owner_invitation` | admin | Create invitation, return token (once) |
| `validate_owner_invitation` | public | Check token validity (no auth) |
| `redeem_owner_invitation` | authenticated | Assign role, link cafe, mark used |
| `accept_owner_invitation` | authenticated | (Legacy) Similar to redeem |
| `admin_revoke_owner_invitation` | admin | Revoke invitation |

---

## 🎯 ACCEPTANCE CRITERIA (ALL MET ✅)

### 1. Cannot Get Owner Role Without:
- [x] ✅ Admin invite (required)
- [x] ✅ Successful redeem via RPC (with all checks)

### 2. Owner After Registration:
- [x] ✅ Sees only own cafes (scope by `cafe_id`)
- [x] ✅ Cannot edit others' menu items
- [x] ✅ Cannot manage others' orders

### 3. Non-Owner/Non-Admin:
- [x] ✅ Cannot access `/admin` (layout guard)
- [x] ✅ Cannot call admin API routes (server guard)

### 4. Invitation Token:
- [x] ✅ Single-use (use_count tracking)
- [x] ✅ Expires (time-based)
- [x] ✅ Stored as hash only (SHA256)

### 5. Audit Logging:
- [x] ✅ Invitation creation
- [x] ✅ Invitation redemption
- [x] ✅ Invitation revocation
- [x] ✅ Role assignment
- [x] ✅ Cafe linkage

---

## 📁 FILE STRUCTURE

```
SubscribeCoffieBackend/
├── supabase/migrations/
│   ├── 20260203120000_owner_invitations_system.sql
│   │   - owner_invitations table
│   │   - admin_create_owner_invitation RPC
│   │   - validate_owner_invitation RPC
│   │   - accept_owner_invitation RPC
│   │   - admin_revoke_owner_invitation RPC
│   │
│   └── 20260203130000_owner_invites_many_to_many.sql
│       - cafe_owners table (many-to-many)
│       - redeem_owner_invitation RPC
│       - Enhanced RLS policies
│       - Auto-sync trigger
│
├── OWNER_REGISTRATION_SYSTEM.md
├── OWNER_REGISTRATION_QUICKSTART.md
├── OWNER_INVITATIONS_PART3.md
├── OWNER_REGISTRATION_PART4.md
└── OWNER_ONBOARDING.md (this file)

subscribecoffie-admin/
├── app/
│   ├── admin/
│   │   ├── layout.tsx (guards: auth + role)
│   │   ├── owner-invitations/page.tsx (create/list/revoke)
│   │   └── owner/
│   │       ├── onboarding/page.tsx
│   │       └── dashboard/page.tsx
│   │
│   ├── register/owner/page.tsx (public registration)
│   │
│   └── api/
│       └── admin/owner-invites/
│           ├── route.ts (POST: create, GET: list)
│           └── [invitationId]/route.ts (DELETE: revoke)
│
└── lib/supabase/
    ├── roles.ts (getUserRole, requireAdmin)
    └── server.ts (createServerClient)
```

---

## 🚀 PRODUCTION DEPLOYMENT

### Environment Variables:
```env
# .env.local (Next.js)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
NEXT_PUBLIC_BASE_URL=https://your-domain.com
```

### Pre-Launch Checklist:
- [ ] Migrations applied to production database
- [ ] `NEXT_PUBLIC_BASE_URL` set to production domain
- [ ] Admin account created and tested
- [ ] Invite creation tested (admin panel)
- [ ] Owner registration tested (full flow)
- [ ] Scope isolation tested (owner A cannot see owner B's data)
- [ ] Audit logs enabled and monitored
- [ ] Error messages reviewed (no SQL leaks)
- [ ] RLS policies enabled on all tables
- [ ] Service role key NOT exposed to client

---

## 🎉 SUCCESS!

**Система Owner Registration готова к production!**

- ✅ Enterprise-level security
- ✅ User-friendly UX
- ✅ Complete audit trail
- ✅ Granular permissions
- ✅ Scope isolation
- ✅ Token security
- ✅ Error handling
- ✅ Documentation complete

**Questions?** Refer to other docs:
- `OWNER_REGISTRATION_SYSTEM.md` - Technical details
- `OWNER_REGISTRATION_QUICKSTART.md` - Quick start guide
- `OWNER_INVITATIONS_PART3.md` - Many-to-many architecture
- `OWNER_REGISTRATION_PART4.md` - Admin panel implementation
