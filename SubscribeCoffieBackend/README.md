# SubscribeCoffie Backend

Backend infrastructure for SubscribeCoffie - coffee subscription platform with multi-wallet support.

## 📚 Quick Links

- **[Local Development Setup](./SUPABASE_SETUP.md)** - Get started with local development
- **[Production Deployment](./PRODUCTION_QUICKSTART.md)** - Deploy to Supabase Cloud (Quick Start)
- **[Detailed Deployment Guide](./CLOUD_DEPLOYMENT.md)** - Comprehensive production deployment
- **[Deployment Checklist](./PRODUCTION_CHECKLIST.md)** - Complete pre-launch checklist
- **[Deployment Status](./DEPLOYMENT_STATUS.md)** - Current deployment status

## 🚀 Getting Started

### Local Development

```bash
# Start local Supabase instance (requires Docker)
supabase start

# View connection details
supabase status

# Reset database with all migrations + seed data
supabase db reset

# Run smoke test
API_URL=http://127.0.0.1:54321
ANON_KEY="<anon key from supabase status>"
curl "$API_URL/rest/v1/cafes?select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY"
# Expect: 5 cafes returned
```

For detailed setup instructions, see [SUPABASE_SETUP.md](./SUPABASE_SETUP.md)

### Production Deployment

```bash
# Quick deployment to Supabase Cloud
./scripts/deploy_production.sh

# Verify deployment
./scripts/verify_production.sh

# Create backup
./scripts/backup_production.sh
```

For detailed deployment instructions, see [PRODUCTION_QUICKSTART.md](./PRODUCTION_QUICKSTART.md)

## 📁 Project Structure

```
SubscribeCoffieBackend/
├── supabase/
│   ├── config.toml           # Supabase configuration
│   ├── migrations/           # Database migrations (27 files)
│   ├── seed.sql              # Local development seed data
│   └── seed.production.sql   # Production seed data (minimal)
├── scripts/
│   ├── deploy_production.sh  # Automated deployment script
│   ├── verify_production.sh  # Post-deployment verification
│   ├── backup_production.sh  # Database backup script
│   └── smoke_backend.sh      # Smoke tests
├── tests/                    # Test files
├── docs/                     # Documentation
├── CLOUD_DEPLOYMENT.md       # Detailed deployment guide
├── PRODUCTION_QUICKSTART.md  # Quick start guide
├── PRODUCTION_CHECKLIST.md   # Deployment checklist
├── DEPLOYMENT_STATUS.md      # Current status
└── env.production.template   # Production environment variables
```

## 🗄️ Database Schema

### Core Tables
- **cafes** - Cafe information and metadata
- **menu_items** - Menu items and products
- **orders** - Customer orders
- **order_items** - Order line items

### Wallet System
- **wallets** - User wallets (CityPass & Cafe Wallet)
- **wallet_transactions** - Transaction history
- **wallet_networks** - Cafe networks
- **cafe_network_members** - Network membership
- **payment_methods** - User payment methods
- **payment_transactions** - Payment transaction log
- **commission_config** - Commission rates configuration

### User Management
- **profiles** - User profiles (linked to auth.users)
- **audit_logs** - System audit trail
- **push_notification_tokens** - Push notification registration

### Cafe Onboarding
- **cafe_onboarding_requests** - Cafe applications
- **cafe_documents** - Cafe documents and images

### Analytics
- **cafe_analytics** - View for cafe analytics
- **popular_menu_items** - View for popular items
- And more...

## 🔐 Security

- ✅ Row Level Security (RLS) enabled on all tables
- ✅ Role-based access control (admin, owner, user)
- ✅ Secure authentication with Supabase Auth
- ✅ API key protection
- ✅ SQL injection prevention
- ✅ XSS protection

## 🧪 Testing

```bash
# Run all tests
./tests/run_all_tests.sh

# Run specific test suites
./tests/security_tests.sql
./tests/orders_rpc.test.sql
./tests/wallets_rpc.test.sql
./tests/analytics.test.sql
```

## 📊 Monitoring

### Local Development
- Supabase Studio: http://127.0.0.1:54323
- Database logs: `supabase logs`
- API logs: Check Studio interface

### Production
- Supabase Dashboard: https://app.supabase.com
- Logs: Dashboard → Logs
- Metrics: Dashboard → Reports
- Alerts: Dashboard → Settings → Alerts

## 🔄 Migrations

### Create New Migration
```bash
# Create a new migration file
supabase migration new your_migration_name

# Edit the file in supabase/migrations/
# Then test locally:
supabase db reset
```

### Apply Migrations
```bash
# Local
supabase db reset

# Production
supabase db push
```

## 💾 Backups

### Manual Backup
```bash
./scripts/backup_production.sh
```

### Automated Backup (Pro Plan)
- Point-in-Time Recovery (PITR) - 7 days retention
- Automatic daily backups
- Configure in Supabase Dashboard

## 🌍 Environments

### Development (Local)
- URL: `http://127.0.0.1:54321`
- Database: PostgreSQL 17 (Docker)
- Purpose: Development and testing
- Seed data: Full test dataset

### Production (Supabase Cloud)
- URL: `https://[project-ref].supabase.co`
- Database: Managed PostgreSQL
- Purpose: Live production
- Seed data: Minimal configuration only

## 📖 Documentation

- [Local Setup Guide](./SUPABASE_SETUP.md)
- [API Contract](./SUPABASE_API_CONTRACT.md)
- [Production Deployment](./CLOUD_DEPLOYMENT.md)
- [Quick Start](./PRODUCTION_QUICKSTART.md)
- [Deployment Checklist](./PRODUCTION_CHECKLIST.md)
- [Auth Implementation](./AUTH_IMPLEMENTATION.md)
- [Cafe Onboarding](./CAFE_ONBOARDING_IMPLEMENTATION.md)
- [Cafe Networks](./CAFE_NETWORKS_IMPLEMENTATION.md)
- [Order UX](./ORDER_UX_IMPLEMENTATION.md)

## 🛠️ Tech Stack

- **Database**: PostgreSQL 17
- **Backend**: Supabase (Auth, Storage, Edge Functions, Realtime)
- **Migrations**: Supabase CLI
- **Testing**: SQL test files
- **Monitoring**: Supabase Dashboard + Sentry (optional)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test locally with `supabase db reset`
4. Create migration if needed
5. Update documentation
6. Submit for review

## 📝 License

Proprietary - SubscribeCoffie

## 🆘 Support

- **Documentation Issues**: Open GitHub issue
- **Production Issues**: Check [DEPLOYMENT_STATUS.md](./DEPLOYMENT_STATUS.md)
- **Supabase Support**: https://supabase.com/docs
- **Discord**: https://discord.supabase.com

---

**Current Status**: ✅ Ready for Production Deployment  
**Last Updated**: 2026-01-30  
**Version**: 1.0.0
