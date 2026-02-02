# Production Deployment Quick Start

> **⚡ Fast track guide for deploying SubscribeCoffie to Supabase Cloud**  
> For detailed instructions, see [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md)

## Prerequisites

```bash
# Install Supabase CLI
npm install -g supabase

# Verify installation
supabase --version

# Ensure Docker is running (for pre-deployment testing)
docker ps
```

## Step 1: Create Supabase Project (5 minutes)

1. Go to https://app.supabase.com
2. Click **"New Project"**
3. Configure:
   - **Name**: `subscribecoffie-production`
   - **Database Password**: Generate strong password (save it!)
   - **Region**: Choose closest to your users
   - **Plan**: Free (upgrade to Pro later)
4. Wait for provisioning (2-5 minutes)
5. Note your **Project Reference ID** from the URL

## Step 2: Get Project Credentials (2 minutes)

From Supabase Dashboard → Settings → API, copy:

```bash
# Save these to .env.production
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Step 3: Deploy Database (10 minutes)

```bash
cd SubscribeCoffieBackend

# Login to Supabase
supabase login

# Link to your cloud project
supabase link --project-ref YOUR_PROJECT_REF

# Test migrations locally first (recommended)
supabase db reset

# Review what will be deployed
supabase db diff --linked

# Deploy to production
supabase db push
```

## Step 4: Seed Production Data (2 minutes)

In Supabase Dashboard → SQL Editor, run:

```sql
-- Insert default commission rates
INSERT INTO commission_config (operation_type, commission_percent, active)
VALUES
  ('citypass_topup', 7.5, true),
  ('cafe_wallet_topup', 4.0, true),
  ('direct_order', 17.5, true);

-- Verify
SELECT * FROM commission_config;
```

## Step 5: Configure Authentication (5 minutes)

In Dashboard → Authentication → Settings:

1. **Site URL**: `https://app.subscribecoffie.com` (or your domain)
2. **Redirect URLs**: Add these:
   - `https://app.subscribecoffie.com/**`
   - `com.subscribecoffie.app://**`
   - `subscribecoffie://auth/callback`

### SMTP (Email) Setup

In Dashboard → Project Settings → Auth → SMTP:

```
Host: smtp.sendgrid.net
Port: 587
Username: apikey
Password: [Your SendGrid API Key]
Sender: noreply@subscribecoffie.com
```

**Test**: Send a test email from Dashboard

## Step 6: Create Storage Buckets (3 minutes)

In Dashboard → Storage → New Bucket:

1. **cafe-images**
   - Public: ✅ Yes
   - File size limit: 5MB
   - Allowed types: `image/jpeg`, `image/png`, `image/webp`

2. **menu-images**
   - Public: ✅ Yes
   - File size limit: 5MB
   - Allowed types: `image/jpeg`, `image/png`, `image/webp`

3. **cafe-documents**
   - Public: ❌ No
   - File size limit: 10MB
   - Allowed types: `application/pdf`, `image/*`

4. **user-avatars**
   - Public: ✅ Yes
   - File size limit: 2MB
   - Allowed types: `image/jpeg`, `image/png`, `image/webp`

## Step 7: Update iOS App (5 minutes)

Edit `SubscribeCoffieClean/.../Helpers/Environment.swift`:

```swift
case .production:
    return "https://your-actual-project-ref.supabase.co"

// And for anon key:
case .production:
    return "your-actual-anon-key"
```

**Build and test** with production backend.

## Step 8: Create First Admin User (2 minutes)

1. Register a user through the iOS app or directly via auth endpoint
2. Get the user email
3. In Dashboard → SQL Editor, run:

```sql
-- Replace with your actual email
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'your-admin@email.com';

-- Verify
SELECT id, email, role FROM profiles WHERE role = 'admin';
```

## Step 9: Verify Deployment (5 minutes)

Run the verification script:

```bash
cd SubscribeCoffieBackend

# Create .env.production from template
cp env.production.template .env.production

# Edit .env.production with your actual values
nano .env.production

# Run verification
./scripts/verify_production.sh
```

Expected output: All checks should pass ✅

## Step 10: Configure OAuth (Optional, 15 minutes)

### Apple Sign In (Required for App Store)

1. Go to https://developer.apple.com
2. Certificates, IDs & Profiles → Identifiers
3. Create new **Service ID**
4. Enable "Sign in with Apple"
5. Configure return URLs:
   - `https://your-project-ref.supabase.co/auth/v1/callback`
6. In Supabase Dashboard → Authentication → Providers:
   - Enable Apple
   - Add Service ID and Team ID

### Google Sign In

1. Go to https://console.cloud.google.com
2. Create OAuth 2.0 Client ID
3. Add authorized redirect URI:
   - `https://your-project-ref.supabase.co/auth/v1/callback`
4. In Supabase Dashboard → Authentication → Providers:
   - Enable Google
   - Add Client ID and Secret

## Automated Deployment Script

Alternatively, use the automated script:

```bash
cd SubscribeCoffieBackend
./scripts/deploy_production.sh
```

This script will guide you through all steps interactively.

## Post-Deployment Checklist

- [ ] All migrations applied successfully
- [ ] Commission rates configured
- [ ] Storage buckets created
- [ ] SMTP configured and tested
- [ ] Site URL and redirect URLs set
- [ ] First admin user created
- [ ] iOS app pointing to production
- [ ] Verification script passed
- [ ] OAuth configured (Apple required for iOS)
- [ ] Monitoring configured

## Monitoring and Alerts

### Essential Monitoring

1. **Supabase Dashboard → Logs**
   - Monitor for errors
   - Watch API usage
   - Check query performance

2. **Set up Alerts** (Dashboard → Settings → Alerts):
   - Database usage > 80%
   - API rate limit approaching
   - Unusual error rate

### External Monitoring (Recommended)

```bash
# Add to your iOS app and admin panel
SENTRY_DSN=https://your-sentry-dsn
```

## Backup Strategy

Set up automated daily backups:

```bash
# Manual backup
./scripts/backup_production.sh

# Automate with cron (recommended)
# Add to crontab:
0 2 * * * cd /path/to/SubscribeCoffieBackend && ./scripts/backup_production.sh
```

**Store backups in**:
- AWS S3
- Google Cloud Storage
- Dropbox (encrypted)

## Scaling Guidelines

### When to Upgrade to Pro ($25/month)

Upgrade when you hit any of:
- ✅ 500MB database size
- ✅ 50 requests/second sustained
- ✅ Need Point-in-Time Recovery (PITR)
- ✅ Need priority support
- ✅ >1k active users

### Pro Plan Benefits

- 8GB database (vs 500MB)
- 100GB file storage (vs 1GB)
- 200 requests/second (vs 50)
- 7-day PITR backups
- Email support
- No "Powered by Supabase" branding

## Troubleshooting

### Issue: Migrations fail

```bash
# Check migration status
supabase migration list

# Repair if needed
supabase migration repair [version]

# Re-run
supabase db push
```

### Issue: RLS blocking legitimate access

```sql
-- Debug RLS policies
SET ROLE authenticated;
SELECT * FROM your_table;

-- Check auth context
SELECT auth.uid();
SELECT auth.role();
```

### Issue: Can't connect from iOS app

1. Verify URL and anon key in Environment.swift
2. Check Site URL in Dashboard → Auth
3. Verify RLS policies allow access
4. Check network (use real device, not simulator)

### Issue: SMTP emails not sending

1. Verify SMTP credentials
2. Check sender email is verified
3. Test email in Dashboard
4. Check spam folder
5. Review auth logs for errors

## Cost Estimation

### Free Tier (Good for MVP)
- $0/month
- 500MB database
- 1GB file storage
- 50 requests/second
- 2GB bandwidth
- ~1,000 active users

### Pro Tier (Recommended for Launch)
- $25/month
- 8GB database
- 100GB file storage
- 200 requests/second
- 250GB bandwidth
- ~10,000 active users

## Next Steps After Deployment

1. ✅ **Monitor for 48 hours** - Watch for any issues
2. 🧪 **Beta testing** - Invite test users
3. 🧪 **Load testing** - Simulate traffic
4. 📱 **TestFlight** - Deploy iOS app for testing
5. 🎯 **Marketing** - Prepare launch campaign
6. 💳 **Payment Integration** - Replace mock payments with real (Phase 2.0.1)
7. 📊 **Analytics** - Track key metrics

## Support Resources

- **Documentation**: [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) (detailed guide)
- **Checklist**: [PRODUCTION_CHECKLIST.md](./PRODUCTION_CHECKLIST.md) (comprehensive)
- **Supabase Docs**: https://supabase.com/docs
- **Discord**: https://discord.supabase.com
- **Status**: https://status.supabase.com

## Emergency Contacts

- **Supabase Support**: support@supabase.com (Pro plan)
- **Team Lead**: [Your contact]
- **On-call**: [Your number]

---

**Time to Deploy**: ~45 minutes (excluding OAuth setup)  
**Difficulty**: Intermediate  
**Prerequisites**: Basic CLI knowledge, Supabase account

🎉 **You're ready to go live!**
