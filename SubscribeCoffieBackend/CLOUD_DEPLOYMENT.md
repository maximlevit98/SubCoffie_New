# Supabase Cloud Deployment Guide

## Overview

This guide covers the complete migration from local Supabase development to Supabase Cloud production environment.

## Prerequisites

Before starting the deployment:

- [ ] Supabase account created (https://supabase.com)
- [ ] Supabase CLI installed and updated (`npm install -g supabase`)
- [ ] Docker running (for local testing before deploy)
- [ ] Access to production domain/URLs
- [ ] Payment method configured in Supabase dashboard (for paid plan if needed)

## Phase 1: Create and Configure Cloud Project

### Step 1: Create New Project

1. Go to https://app.supabase.com
2. Click "New Project"
3. Configure:
   - **Project Name**: `subscribecoffie-production`
   - **Database Password**: Generate strong password (save to password manager)
   - **Region**: Choose closest to your users (e.g., `eu-central-1` for Europe, `us-east-1` for USA)
   - **Pricing Plan**: Start with Free tier, upgrade to Pro when needed

4. Wait for project to be provisioned (2-5 minutes)

### Step 2: Get Project Credentials

Once project is ready, note down these values (from Project Settings → API):

```bash
# Add these to your .env.production file
SUPABASE_URL=https://[your-project-ref].supabase.co
SUPABASE_ANON_KEY=[your-anon-key]
SUPABASE_SERVICE_ROLE_KEY=[your-service-role-key] # Keep secret!
```

### Step 3: Link Local Project to Cloud

```bash
cd /path/to/SubscribeCoffieBackend

# Login to Supabase (opens browser)
supabase login

# Link to your cloud project
supabase link --project-ref [your-project-ref]

# Verify link
supabase projects list
```

## Phase 2: Configure Production Settings

### Step 1: Update Authentication Settings

In Supabase Dashboard → Authentication → Settings:

1. **Site URL**: 
   - Set to your production domain: `https://app.subscribecoffie.com`
   
2. **Redirect URLs**: Add these patterns:
   - `https://app.subscribecoffie.com/**`
   - `com.subscribecoffie.app://**` (for iOS deep links)
   - `subscribecoffie://auth/callback`

3. **Email Auth**:
   - Enable email confirmations: `true`
   - Secure password change: `true`
   
4. **SMS Auth** (if using phone auth):
   - Provider: Configure Twilio or MessageBird
   - Add credentials in Auth → Providers → Phone

5. **OAuth Providers** (when ready):
   - Configure Apple Sign In (required for iOS)
   - Configure Google Sign In

### Step 2: Configure Email Service (SMTP)

For production emails, configure SMTP in Dashboard → Project Settings → Auth → SMTP Settings:

**Option A: SendGrid (Recommended)**
```
Host: smtp.sendgrid.net
Port: 587
Username: apikey
Password: [your-sendgrid-api-key]
Sender email: noreply@subscribecoffie.com
Sender name: SubscribeCoffie
```

**Option B: AWS SES**
```
Host: email-smtp.[region].amazonaws.com
Port: 587
Username: [SMTP-username]
Password: [SMTP-password]
```

### Step 3: Configure Storage

In Dashboard → Storage → Settings:

1. **File size limits**: 50 MiB (for cafe images/menus)
2. Create buckets:
   - `cafe-images` (public)
   - `menu-images` (public)
   - `cafe-documents` (private, for onboarding docs)
   - `user-avatars` (public)

### Step 4: Configure Database Settings

In Dashboard → Project Settings → Database:

1. **Connection Pooling**: Enable (recommended for production)
   - Mode: Transaction
   - Pool size: 15 (adjust based on load)

2. **Network Restrictions** (optional but recommended):
   - Add your office/server IPs if you have static IPs
   - Or leave open for mobile app access

3. **Backups**: Configure Point-in-Time Recovery (PITR)
   - Available on Pro plan
   - Enables restoration to any point in last 7 days

## Phase 3: Deploy Database Schema

### Step 1: Test Migrations Locally

Before deploying to production, verify all migrations work:

```bash
# Reset local database
supabase db reset

# Check for any errors
# If successful, you'll see all 27 migrations applied
```

### Step 2: Deploy Migrations to Production

```bash
# Push all migrations to production
supabase db push

# This will:
# - Apply all migrations in order
# - Show diff before applying
# - Ask for confirmation
```

**⚠️ Important**: 
- Migrations are irreversible in production
- Review the diff carefully before confirming
- Migrations will create all tables, RLS policies, functions, triggers

### Step 3: Verify Database Schema

```bash
# List all tables in production
supabase db remote list

# Or use SQL Editor in Dashboard to verify:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

Expected tables:
- `cafes`
- `menu_items`
- `orders`
- `order_items`
- `wallets`
- `wallet_transactions`
- `profiles`
- `audit_logs`
- `cafe_onboarding_requests`
- `cafe_documents`
- `wallet_networks`
- `cafe_network_members`
- `payment_methods`
- `payment_transactions`
- `commission_config`
- And more...

## Phase 4: Seed Production Data

### Step 1: Create Production Seed File

Create a minimal production seed (DO NOT use test data):

```bash
# Create production-specific seed
cat > supabase/seed.production.sql << 'EOF'
-- Production seed: Initial setup only

-- Insert default commission rates
INSERT INTO commission_config (operation_type, commission_percent, active)
VALUES
  ('citypass_topup', 7.5, true),
  ('cafe_wallet_topup', 4.0, true),
  ('direct_order', 17.5, true);

-- Set up system admin (update with your email after first login)
-- You'll need to register first, then run this update manually
```

### Step 2: Apply Seed Data (Manual)

**DO NOT** automatically seed production with test data.

Instead:
1. Use SQL Editor in Dashboard
2. Manually insert only necessary configuration data
3. Real cafe data will come from onboarding flow

## Phase 5: Configure Environment Variables

### Step 1: Create Environment Files

Create `.env.production` for your iOS app and admin panel:

```bash
# iOS App (.env.production)
SUPABASE_URL=https://[your-project-ref].supabase.co
SUPABASE_ANON_KEY=[your-anon-key]
ENVIRONMENT=production
API_TIMEOUT=30000
ENABLE_LOGGING=false
```

```bash
# Admin Panel (.env.production)
NEXT_PUBLIC_SUPABASE_URL=https://[your-project-ref].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[your-anon-key]
SUPABASE_SERVICE_ROLE_KEY=[your-service-role-key]
NODE_ENV=production
```

### Step 2: Update iOS App Configuration

Update `SubscribeCoffieClean/SubscribeCoffieClean/Helpers/Environment.swift`:

```swift
enum AppEnvironment {
    case development
    case staging
    case production
    
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    var supabaseURL: String {
        switch self {
        case .development:
            return "http://127.0.0.1:54321"
        case .staging:
            return "https://[staging-ref].supabase.co"
        case .production:
            return "https://[production-ref].supabase.co"
        }
    }
    
    var supabaseAnonKey: String {
        switch self {
        case .development:
            return "[local-anon-key]"
        case .staging:
            return "[staging-anon-key]"
        case .production:
            return "[production-anon-key]"
        }
    }
}
```

## Phase 6: Security Hardening

### Step 1: Review Row Level Security (RLS)

All tables should have RLS enabled. Verify in SQL Editor:

```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';
```

All should show `rowsecurity = true`.

### Step 2: Verify RLS Policies

Check that policies exist for all tables:

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

### Step 3: Test Anonymous Access

Test that anonymous users can only access public data:

```bash
# Use anon key to test
ANON_KEY="[your-anon-key]"
API_URL="https://[your-project-ref].supabase.co"

# Should work: public cafes
curl "$API_URL/rest/v1/cafes?select=*" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY"

# Should fail: user wallets (requires auth)
curl "$API_URL/rest/v1/wallets?select=*" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY"
# Expected: {"code":"42501","message":"new row violates row-level security policy"}
```

### Step 4: Rotate Service Role Key

**⚠️ CRITICAL**: The service role key bypasses RLS. 

- NEVER expose it in client apps
- NEVER commit it to git
- Only use it in backend/admin panel (server-side)
- Rotate periodically (in Dashboard → Settings → API)

## Phase 7: Monitoring and Observability

### Step 1: Enable Logging

In Dashboard → Logs:

1. **Query Performance**: Monitor slow queries
2. **API Logs**: Track API usage and errors
3. **Auth Logs**: Monitor authentication attempts

### Step 2: Set Up Alerts

In Dashboard → Settings → Alerts:

1. **Database Usage**: Alert at 80% capacity
2. **API Rate Limits**: Alert when approaching limits
3. **Error Rate**: Alert on unusual error spikes

### Step 3: Configure External Monitoring (Optional)

Integrate with:
- **Sentry**: For error tracking (iOS app, admin panel)
- **Datadog/New Relic**: For APM
- **PagerDuty**: For critical alerts

## Phase 8: Backup and Disaster Recovery

### Step 1: Enable Point-in-Time Recovery

Available on Pro plan ($25/month):
- 7 days retention
- Restore to any point
- Essential for production

### Step 2: Manual Backup Strategy

```bash
# Export schema
supabase db dump -f backup-schema.sql --schema-only

# Export data
supabase db dump -f backup-data.sql --data-only

# Store backups in secure location (S3, etc)
```

### Step 3: Test Restore Process

Periodically test that you can restore from backup:

```bash
# Create test project
# Restore backup
psql -h [test-db-host] -U postgres -f backup-schema.sql
psql -h [test-db-host] -U postgres -f backup-data.sql

# Verify data integrity
```

## Phase 9: Performance Optimization

### Step 1: Add Database Indexes

Monitor slow queries and add indexes:

```sql
-- Example: Index on frequently queried fields
CREATE INDEX IF NOT EXISTS idx_orders_user_created 
  ON orders(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_cafe_status 
  ON orders(cafe_id, status);

CREATE INDEX IF NOT EXISTS idx_menu_items_cafe 
  ON menu_items(cafe_id) WHERE available = true;
```

### Step 2: Enable Connection Pooling

In Dashboard → Settings → Database → Connection Pooling:
- Enable for production
- Use transaction mode for most cases
- Reduces connection overhead

### Step 3: Configure Caching (Optional)

For high-traffic endpoints:
- Use Supabase Realtime for live updates
- Cache static data (menu items) in app
- Use CDN for images

## Phase 10: Go Live Checklist

### Pre-Launch

- [ ] All migrations applied successfully
- [ ] RLS policies tested and verified
- [ ] Authentication flows working (email, phone, OAuth)
- [ ] Storage buckets created and configured
- [ ] SMTP configured and tested (send test email)
- [ ] Environment variables set in iOS app
- [ ] Environment variables set in admin panel
- [ ] Monitoring and alerts configured
- [ ] Backup strategy in place
- [ ] Documentation updated

### Launch

- [ ] iOS app pointing to production URL
- [ ] Admin panel deployed and pointing to production
- [ ] First admin user created and tested
- [ ] Test complete user journey:
  - User registration
  - Cafe browsing
  - Order creation
  - Payment (mock for now)
  - Order fulfillment
  - Wallet operations
- [ ] Load testing completed
- [ ] Security audit completed

### Post-Launch

- [ ] Monitor error rates (Sentry, Dashboard)
- [ ] Monitor API usage (stay within limits)
- [ ] Monitor database performance
- [ ] Monitor user feedback
- [ ] Plan for scaling (upgrade to Pro if needed)

## Troubleshooting

### Issue: Migrations Fail

```bash
# Check migration status
supabase migration list

# Check for errors in specific migration
supabase db diff --file migrations/[migration-file].sql

# If needed, repair migration
supabase migration repair [version]
```

### Issue: RLS Blocking Legitimate Access

```sql
-- Debug RLS policies
SET ROLE authenticated;
SELECT * FROM wallets; -- Test as authenticated user

-- Check auth context
SELECT auth.uid(); -- Should return user ID
SELECT auth.role(); -- Should return 'authenticated'
```

### Issue: Connection Limits Reached

- Upgrade to Pro plan (higher limits)
- Enable connection pooling
- Optimize query patterns in app
- Close connections properly

### Issue: API Rate Limits

Free tier limits:
- 50 requests/second
- 500MB database
- 1GB file storage

Upgrade to Pro for:
- 200 requests/second
- 8GB database
- 100GB file storage

## Scaling Considerations

### When to Upgrade to Pro

Upgrade when you hit any of these:
- 500MB database size
- 50 req/sec sustained
- Need PITR backups
- Need phone support
- Need custom domain

### Future Scaling Options

1. **Database Read Replicas** (Pro plan)
   - Offload read queries
   - Improve global latency

2. **Edge Functions** (already available)
   - For complex business logic
   - Background jobs
   - Webhooks

3. **CDN Integration**
   - Cloudflare for static assets
   - Reduce origin load

4. **Multi-Region** (Enterprise)
   - Deploy closer to users globally
   - Disaster recovery across regions

## Cost Estimation

### Free Tier
- $0/month
- Good for: Development, MVP testing
- Limits: 500MB DB, 1GB storage, 50 req/sec

### Pro Tier
- $25/month
- Good for: Production launch, <10k users
- Includes: 8GB DB, 100GB storage, 200 req/sec, PITR

### Expected Growth
- 1k users: Free tier OK
- 10k users: Pro tier recommended
- 50k+ users: Consider Team/Enterprise

### Cost Optimization Tips
1. Use CDN for images (reduce storage/bandwidth)
2. Implement pagination (reduce query costs)
3. Cache frequently accessed data
4. Archive old data periodically

## Support and Resources

- **Documentation**: https://supabase.com/docs
- **Discord Community**: https://discord.supabase.com
- **Status Page**: https://status.supabase.com
- **GitHub Issues**: https://github.com/supabase/supabase/issues
- **Email Support**: Pro plan includes email support

## Next Steps After Cloud Deployment

1. ✅ Cloud deployment complete
2. 🔄 **Real Payment Integration** (Phase 2.0.1)
   - Replace mock payments with Stripe/ЮKassa
   - See `PAYMENT_INTEGRATION.md` (to be created)
3. 🔄 **OAuth Configuration** (Phase 1.3)
   - Configure Apple Sign In
   - Configure Google Sign In
4. 🔄 **Production Testing** (Phase 2.1)
   - Beta test with real cafes
   - Load testing
   - Security audit

---

**Last Updated**: 2026-01-30
**Version**: 1.0
**Status**: Ready for Production Deployment
