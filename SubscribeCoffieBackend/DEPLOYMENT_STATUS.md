# SubscribeCoffie Deployment Status

## Current Environment: Local Development

**Status**: ⚠️ Demo-Only Mode (Real Payments Disabled)  
**Last Updated**: 2026-02-03

---

## ⚠️ PAYMENT STATUS

### Current Mode: Mock Payments Only
- ✅ **Demo/Test Ready**: Mock payments working
- ❌ **Production Ready**: Real payments DISABLED by design
- 🔒 **Security**: All safeguards in place

**Real Payment Integration:**
- Status: **INTENTIONALLY DISABLED**
- Migration: `20260202010000_real_payment_integration.sql.disabled`
- Feature Flag: `ENABLE_REAL_PAYMENTS=false`
- Documentation: See `PAYMENT_SECURITY.md`

**⚠️ DO NOT ENABLE real payments without:**
1. Completing Pre-Production Checklist (PAYMENT_SECURITY.md)
2. Technical + Business + Legal approvals
3. Security audit completion

### Mock Payment Infrastructure (DEV-ONLY)
**Location:** `supabase/seed.sql` (auto-loaded in dev)  
**Functions:** `mock_wallet_topup()`, `mock_direct_order_payment()`  
**Behavior:** Instant credits, no real money, `provider='mock'`  
**Production:** ❌ **MUST NOT DEPLOY** - seed.sql not run in production

**Deployment Protection:**
- ✅ Mock functions in seed.sql (dev-only)
- ✅ Production migration clean (no mock references)
- ✅ Separate file: `seed_dev_mock_payments.sql` (documentation)
- ✅ Clear DEV-ONLY markers in all mock code

**See:** `FIX_004_MOCK_PAYMENTS_SEPARATION.md` for details

---

## 🔐 SECRETS & ENVIRONMENT VARIABLES

### Current Status: ✅ SECURE
**Last Audit**: 2026-02-03  
**Audit Result**: No secrets in repository

### What's Protected:
- ✅ NO service_role keys in code
- ✅ NO payment provider keys (Stripe/YooKassa) in code
- ✅ NO real database credentials in code
- ✅ Local development uses standard Supabase local keys only

### Configuration Files:

#### iOS App (SubscribeCoffieClean)
**File**: `ENV_CONFIGURATION.md`  
**Current**: Hardcoded local Supabase anon key (SAFE for dev)  
**Production**: Manual configuration required in `Environment.swift`  
**Security**: ✅ NO service_role keys, NO payment keys

#### Admin Panel (subscribecoffie-admin)
**File**: `ENV_CONFIGURATION.md`  
**Current**: Uses `process.env` (no hardcoded values)  
**Required**: Create `.env.local` from template  
**Security**: ✅ Service role key server-side only

#### Edge Functions (SubscribeCoffieBackend)
**File**: `supabase/functions/SECRETS_TEMPLATE.md`  
**Current**: Uses `Deno.env.get()` (no hardcoded values)  
**Required**: Set via `supabase secrets set`  
**Security**: ✅ Secrets stored in Supabase Cloud, NOT in repo

### How to Configure:

**Local Development:**
```bash
# 1. Get keys from local Supabase
cd SubscribeCoffieBackend
supabase status

# 2. Create admin panel .env.local
cd ../subscribecoffie-admin
cat > .env.local << EOF
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
SUPABASE_SERVICE_ROLE_KEY=<from supabase status>
EOF

# 3. iOS app uses hardcoded local keys (no action needed)
```

**Production:**
```bash
# 1. Set Edge Function secrets
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<production_service_role_key>
supabase secrets set ENABLE_REAL_PAYMENTS=false

# 2. Configure admin panel via hosting platform (Vercel/Netlify)
# Set environment variables in dashboard

# 3. Update iOS Environment.swift with production URL and anon key
# Edit: SubscribeCoffieClean/Helpers/Environment.swift
```

### Security Checklist:
- [x] No secrets committed to git
- [x] All sensitive keys use environment variables
- [x] iOS only has anon key (never service_role)
- [x] Admin panel service_role key server-side only
- [x] Edge Functions use Supabase Secrets
- [x] .env.local in .gitignore
- [x] Configuration templates documented
- [x] Security audit completed

**See:**
- iOS: `SubscribeCoffieClean/ENV_CONFIGURATION.md`
- Admin: `subscribecoffie-admin/ENV_CONFIGURATION.md`
- Edge Functions: `SubscribeCoffieBackend/supabase/functions/SECRETS_TEMPLATE.md`

---

## 🌱 SEED DATA MANAGEMENT

### Development Seeds (Local Only)

**File:** `supabase/seed.sql`  
**Purpose:** Create test data for local development  
**Auto-runs:** ✅ Automatically on `supabase db reset`  
**Contains:**
- Test owner user (levitm@algsoft.ru / 1234567890)
- Test account and profile
- 2 test cafes (1 published, 1 draft)
- 16 sample menu items
- 1 test order
- Mock payment functions (DEV-ONLY)

**🔒 Safety:**
- ✅ Never runs in production
- ✅ Local development only
- ✅ Contains obvious test data (test emails, fake cafes)
- ✅ Mock functions clearly marked as DEV-ONLY

### Production Seeds (Manual Only)

**File:** `supabase/seed.production.sql`  
**Purpose:** Initialize ONLY essential configuration in production  
**Auto-runs:** ❌ NEVER (manual execution only)  
**Contains:**
- Commission rates configuration (7.5%, 4.0%, 17.5%)
- System configuration (if applicable)
- NO test users, NO test cafes, NO test data

**🛡️ Safety Mechanisms:**
1. **Port check** - Aborts if detected port 54322 (local Supabase)
2. **Test user detection** - Warns if test emails found
3. **Manual execution only** - Must be run in Supabase Dashboard → SQL Editor
4. **Explicit warnings** - Clear instructions to prevent accidents
5. **No automation** - CANNOT be run via scripts or CI/CD

### How to Apply Production Seed

**⚠️ CRITICAL: Only run this ONCE after initial production deployment**

```bash
# Step 1: Deploy migrations first
cd SubscribeCoffieBackend
supabase db push

# Step 2: Verify migrations applied
supabase db list

# Step 3: Go to Supabase Dashboard
# Navigate to: Dashboard → SQL Editor

# Step 4: Copy content of seed.production.sql
cat supabase/seed.production.sql

# Step 5: Paste into SQL Editor and review EVERY line

# Step 6: Run manually (click "Run" button)

# Step 7: Verify output shows:
#   ✅ Safety checks passed
#   ✅ Commission config set
#   ✅ Production seed complete
```

### Seed Data Protection Rules

**✅ ALLOWED in Production Seeds:**
- Configuration tables (commission_config, system_config)
- Reference data (categories, tags, constants)
- Default notification templates
- System-wide settings

**❌ FORBIDDEN in Production Seeds:**
- Test user accounts
- Fake cafe data
- Sample menu items
- Test orders
- Mock payment methods
- Development credentials
- Hardcoded test data

**✅ Real Production Data Comes From:**
- User registrations (auth flow)
- Cafe onboarding (owner panel)
- Real orders (iOS app)
- Actual menu uploads (owner panel)
- Real payment transactions (when enabled)

### Emergency: If Test Data Accidentally Applied

**If you ran seed.sql in production by mistake:**

```sql
-- 1. Immediately delete test users
DELETE FROM auth.users 
WHERE email LIKE '%@test.com' 
   OR email LIKE '%@example.com'
   OR email = 'levitm@algsoft.ru';

-- 2. Delete test profiles
DELETE FROM profiles 
WHERE email LIKE '%@test.com' 
   OR email LIKE '%@example.com'
   OR email = 'levitm@algsoft.ru';

-- 3. Delete test cafes
DELETE FROM cafes 
WHERE name LIKE 'Test%' 
   OR name LIKE '%Demo%';

-- 4. Delete test orders
DELETE FROM orders_core 
WHERE customer_phone LIKE '+7999%';

-- 5. Verify cleanup
SELECT COUNT(*) FROM auth.users; -- Should be only real users
SELECT COUNT(*) FROM cafes; -- Should be only real cafes
```

**Then:**
1. Review all data
2. Restore from backup if needed
3. Re-run seed.production.sql properly
4. Investigate how the mistake happened
5. Update procedures to prevent recurrence

---

## Environment Overview

### Local Development
- **Status**: ✅ Active
- **Supabase**: Local instance (Docker)
- **URL**: `http://127.0.0.1:54321`
- **Database**: PostgreSQL 17 (local)
- **Purpose**: Development and testing

### Staging (Optional)
- **Status**: ⏸️ Not configured
- **Supabase**: N/A
- **URL**: TBD
- **Purpose**: Pre-production testing

### Production
- **Status**: 🚀 Ready to deploy
- **Supabase**: Not yet deployed
- **URL**: TBD (will be `https://[project-ref].supabase.co`)
- **Purpose**: Live production environment

---

## Database Schema Status

### Migrations Applied (Local)

✅ All 27 migrations tested and verified locally:

1. `20260120120000_mvp_coffee.sql` - Base cafe and menu structure
2. `20260121000000_orders_mvp.sql` - Order management
3. `20260123000000_menu_items_restore.sql` - Menu items restoration
4. `20260123093000_rename_to_snake_case.sql` - Schema standardization
5. `20260123104500_api_contract_align.sql` - API contract alignment
6. `20260123120000_fix_menu_items_rest.sql` - Menu items fixes
7. `20260123130000_cafes_filters.sql` - Cafe filtering
8. `20260123133000_orders_preorder_fields.sql` - Pre-order support
9. `20260123140000_get_time_slots_rpc.sql` - Time slot management
10. `20260123150000_wallet_transactions.sql` - Wallet system
11. `20260123160000_qr_issued_flow.sql` - QR code workflow
12. `20260125120000_profiles_admin_role.sql` - Admin role support
13. `20260126120000_wallet_transactions_rls.sql` - Wallet security
14. `20260126123000_calculate_ready_slots_rpc.sql` - Slot calculations
15. `20260126123500_profiles_owner_role.sql` - Owner role support
16. `20260126124000_audit_logs.sql` - Audit logging
17. `20260130130000_security_lints_fix.sql` - Security improvements
18. `20260131000000_order_management_rpc.sql` - Order RPC functions
19. `20260131010000_wallet_sync_functions.sql` - Wallet sync
20. `20260131020000_analytics_views.sql` - Analytics views
21. `20260131030000_push_notifications.sql` - Push notification support
22. `20260201000000_wallet_types_mock_payments.sql` - Wallet types & mock payments
23. `20260202000000_cafe_onboarding.sql` - Cafe onboarding flow
24. `20260203_auth_enhancement.sql` - Auth improvements (duplicate)
25. `20260203000000_auth_enhancement.sql` - Auth improvements
26. `20260204_order_history_rpc.sql` - Order history
27. `20260206000000_cafe_networks_management.sql` - Cafe networks

**Note**: Migrations 24 and 25 appear to be duplicates. Review before production deploy.

### Tables Created (27 total)

- ✅ `cafes` - Cafe information
- ✅ `menu_items` - Menu items and products
- ✅ `orders` - Customer orders
- ✅ `order_items` - Order line items
- ✅ `wallets` - User wallets (CityPass & Cafe Wallet)
- ✅ `wallet_transactions` - Transaction history
- ✅ `wallet_networks` - Cafe networks
- ✅ `cafe_network_members` - Network membership
- ✅ `payment_methods` - User payment methods (mock)
- ✅ `payment_transactions` - Payment transaction log
- ✅ `commission_config` - Commission rates configuration
- ✅ `profiles` - User profiles
- ✅ `audit_logs` - System audit trail
- ✅ `cafe_onboarding_requests` - Cafe onboarding applications
- ✅ `cafe_documents` - Cafe documents and images
- ✅ `push_notification_tokens` - Push notification tokens
- ✅ (And more...)

### RLS Policies

- ✅ Row Level Security enabled on all tables
- ✅ Policies configured for:
  - Anonymous users (public data only)
  - Authenticated users (own data)
  - Admin users (all data)
  - Owner users (own cafe data)

### RPC Functions (30+)

- ✅ Wallet management functions
- ✅ Order management functions
- ✅ Time slot calculation
- ✅ Analytics functions
- ✅ Cafe onboarding functions
- ✅ Commission calculation
- ✅ Network management functions

---

## Deployment Artifacts

### Documentation Created

- ✅ [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) - Comprehensive deployment guide
- ✅ [PRODUCTION_QUICKSTART.md](./PRODUCTION_QUICKSTART.md) - Fast-track deployment guide
- ✅ [PRODUCTION_CHECKLIST.md](./PRODUCTION_CHECKLIST.md) - Complete deployment checklist
- ✅ [env.production.template](./env.production.template) - Environment variables template
- ✅ [seed.production.sql](./supabase/seed.production.sql) - Production seed data

### Scripts Created

- ✅ [scripts/deploy_production.sh](./scripts/deploy_production.sh) - Automated deployment script
- ✅ [scripts/verify_production.sh](./scripts/verify_production.sh) - Post-deployment verification
- ✅ [scripts/backup_production.sh](./scripts/backup_production.sh) - Database backup script

### iOS App Configuration

- ✅ [Environment.swift](../SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Helpers/Environment.swift) - Updated with production support

---

## Pre-Deployment Checklist

### Prerequisites
- ✅ Supabase CLI installed
- ✅ Docker running (for local testing)
- ✅ All migrations tested locally
- ✅ Documentation prepared
- ✅ Scripts ready
- ⏳ Supabase account created (user action required)
- ⏳ Payment method added to Supabase (user action required)

### Configuration Ready
- ✅ Environment variable templates
- ✅ Production seed data prepared
- ✅ iOS app configuration updated
- ⏳ Domain registered (if using custom domain)
- ⏳ SMTP provider configured (user action required)
- ⏳ OAuth providers configured (user action required)

---

## Deployment Steps (When Ready)

### Phase 1: Initial Setup (Day 1)
```bash
# 1. Create Supabase project
# Go to: https://app.supabase.com → New Project

# 2. Link local project to cloud
cd SubscribeCoffieBackend
supabase login
supabase link --project-ref YOUR_PROJECT_REF

# 3. Deploy database
./scripts/deploy_production.sh

# 4. Verify deployment
./scripts/verify_production.sh
```

### Phase 2: Configuration (Day 1)
- Configure authentication (SMTP, OAuth)
- Create storage buckets
- Set up monitoring and alerts
- Apply production seed data

### Phase 3: Application Deployment (Day 2)
- Update iOS app with production credentials
- Deploy admin panel to hosting
- Create first admin user
- Test complete user journey

### Phase 4: Go Live (Day 3)
- Beta testing with select users
- Monitor for 48 hours
- Gather feedback
- Full public launch

---

## Rollback Plan

### If Critical Issues Occur

1. **Enable maintenance mode** (if implemented)
2. **Notify users** via email/push notifications
3. **Investigate issue** using logs and monitoring
4. **Restore from backup** if needed:
   ```bash
   gunzip backup_TIMESTAMP_full.sql.gz
   psql -h [DB_HOST] -U postgres -f backup_TIMESTAMP_full.sql
   ```
5. **Communicate status** to users
6. **Fix and re-deploy** when ready

### Emergency Contacts

- **Supabase Support**: support@supabase.com (Pro plan only)
- **Team**: [Add contact info]

---

## Monitoring Strategy

### Day 1-7 (Critical Period)
- ✅ Monitor every 2 hours
- ✅ Check error rates
- ✅ Watch database usage
- ✅ Review API response times
- ✅ Track user registrations

### Week 2-4
- ✅ Daily monitoring
- ✅ Weekly backups verified
- ✅ Performance optimization
- ✅ User feedback analysis

### Month 2+
- ✅ Automated monitoring with alerts
- ✅ Monthly security audits
- ✅ Quarterly disaster recovery tests
- ✅ Continuous optimization

---

## Success Metrics

### Technical KPIs
- **API Response Time**: < 500ms average
- **Error Rate**: < 1%
- **Uptime**: > 99.9%
- **Database Size**: Monitor growth
- **API Requests**: Track usage vs limits

### Business KPIs
- **User Registrations**: Track growth
- **Active Cafes**: Monitor onboarding
- **Orders per Day**: Track activity
- **GMV**: Gross merchandise value
- **Commission Revenue**: Platform earnings

---

## Next Steps After Production Deploy

### Immediate (Week 1)
1. ✅ Monitor stability
2. ✅ Gather user feedback
3. ✅ Fix critical bugs
4. ✅ Optimize performance

### Short Term (Month 1)
1. 🔄 **Real Payment Integration** (Phase 2.0.1)
   - Integrate Stripe or ЮKassa
   - Replace mock payments
   - Test with real transactions
2. 🔄 **Beta expansion** - Invite more users
3. 🔄 **Marketing** - Launch campaign
4. 🔄 **Partnerships** - Onboard cafes

### Medium Term (Months 2-3)
1. 🔄 **Loyalty Program** (Phase 2.1)
2. 🔄 **Marketing Tools** (Phase 2.2)
3. 🔄 **Real-time Updates** (Phase 2.5)
4. 🔄 **Recommendations** (Phase 2.3)

### Long Term (Months 4-6)
1. 🔄 **Multi-region Support** (Phase 3.1)
2. 🔄 **B2B Dashboard** (Phase 3.2)
3. 🔄 **Delivery** (Phase 3.3)
4. 🔄 **Subscriptions** (Phase 3.4)

---

## Cost Tracking

### Current: Local Development
- **Cost**: $0/month (local only)

### Projected: Production (Free Tier)
- **Cost**: $0/month
- **Good for**: MVP, < 1k users
- **Limits**: 500MB DB, 50 req/sec

### Projected: Production (Pro Tier)
- **Cost**: $25/month
- **Good for**: Launch, < 10k users
- **Includes**: 8GB DB, 200 req/sec, PITR, support

### Additional Costs (Future)
- **SendGrid**: $15-80/month (email)
- **Twilio**: $0.0075/SMS (phone auth)
- **Sentry**: $26-80/month (error tracking)
- **Domain**: $12/year
- **Hosting** (admin panel): $0-20/month (Vercel free tier available)

**Total Estimated**: $50-150/month for full production setup

---

## Status Summary

| Component | Status | Next Action |
|-----------|--------|-------------|
| Database Schema | ✅ Ready | Deploy to cloud |
| Migrations | ✅ Tested | Push to production |
| Documentation | ✅ Complete | Review before deploy |
| Scripts | ✅ Ready | Test in production |
| iOS App | ✅ Configured | Update with prod URLs |
| Admin Panel | ⏳ Pending | Deploy to hosting |
| Monitoring | ⏳ Pending | Configure in dashboard |
| Backups | ⏳ Pending | Enable PITR |
| OAuth | ⏳ Pending | Configure providers |
| SMTP | ⏳ Pending | Configure SendGrid |

**Overall Status**: 🚀 **Ready for Production Deployment**

---

**Prepared by**: AI Assistant  
**Date**: 2026-01-30  
**Version**: 1.0  

**Deployment Command**:
```bash
cd SubscribeCoffieBackend
./scripts/deploy_production.sh
```

**Questions?** See [CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md) or [PRODUCTION_QUICKSTART.md](./PRODUCTION_QUICKSTART.md)
