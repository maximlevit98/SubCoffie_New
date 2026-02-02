# Production Deployment Checklist

## Pre-Deployment Preparation

### 1. Supabase Account Setup
- [ ] Supabase account created at https://supabase.com
- [ ] Payment method added (for Pro plan if needed)
- [ ] Team members invited (if applicable)
- [ ] Organization created (optional, for multiple projects)

### 2. Domain and Infrastructure
- [ ] Production domain registered (app.subscribecoffie.com)
- [ ] SSL certificate configured (handled by Supabase/Vercel)
- [ ] DNS records configured if using custom domain
- [ ] CDN configured for static assets (optional)

### 3. Environment Preparation
- [ ] Supabase CLI installed and updated (`npm install -g supabase`)
- [ ] Docker installed and running (for pre-deployment testing)
- [ ] Local migrations tested (`supabase db reset`)
- [ ] All team members have necessary access

### 4. Code Review
- [ ] All migrations reviewed and tested locally
- [ ] RLS policies verified for all tables
- [ ] No test data in production seed file
- [ ] Sensitive data removed from code
- [ ] `.env.production` created (not committed to git)
- [ ] Documentation updated

---

## Supabase Cloud Setup

### 5. Project Creation
- [ ] New project created in Supabase dashboard
- [ ] Project name: `subscribecoffie-production`
- [ ] Region selected (closest to users)
- [ ] Strong database password generated and saved
- [ ] Project provisioned successfully

### 6. Project Configuration
- [ ] Project linked locally (`supabase link --project-ref YOUR_REF`)
- [ ] Project credentials saved to `.env.production`
  - [ ] SUPABASE_URL
  - [ ] SUPABASE_ANON_KEY
  - [ ] SUPABASE_SERVICE_ROLE_KEY
- [ ] Connection pooling enabled (Dashboard → Settings → Database)
- [ ] Database backups configured (PITR for Pro plan)

### 7. Database Deployment
- [ ] Migrations tested locally one final time
- [ ] Migration diff reviewed (`supabase db diff --linked`)
- [ ] Migrations pushed to production (`supabase db push`)
- [ ] All tables created successfully
- [ ] Verification query run: `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`

### 8. Database Seeding
- [ ] Production seed file reviewed (`supabase/seed.production.sql`)
- [ ] Commission rates configured
- [ ] System configuration inserted
- [ ] No test data included
- [ ] Seed applied via SQL Editor in Dashboard

---

## Authentication Configuration

### 9. Authentication Settings
- [ ] Site URL set to production domain
  - Go to: Authentication → URL Configuration
  - Site URL: `https://app.subscribecoffie.com`
- [ ] Redirect URLs configured:
  - `https://app.subscribecoffie.com/**`
  - `com.subscribecoffie.app://**`
  - `subscribecoffie://auth/callback`
- [ ] Email confirmations enabled
- [ ] Secure password change enabled
- [ ] JWT expiry configured (default: 3600s)

### 10. SMTP Configuration
- [ ] SMTP provider chosen (SendGrid, AWS SES, etc.)
- [ ] SMTP credentials obtained
- [ ] SMTP settings configured in Dashboard
  - Go to: Project Settings → Auth → SMTP Settings
  - Host: smtp.sendgrid.net
  - Port: 587
  - Username: apikey
  - Password: [API key]
  - Sender email: noreply@subscribecoffie.com
  - Sender name: SubscribeCoffie
- [ ] Test email sent successfully
- [ ] Email templates customized (optional)

### 11. SMS Configuration (Optional)
- [ ] SMS provider configured (Twilio, MessageBird)
- [ ] SMS credentials added
- [ ] Test SMS sent successfully
- [ ] Rate limits configured

### 12. OAuth Providers
- [ ] Apple Sign In configured (required for iOS)
  - [ ] Apple Developer account configured
  - [ ] Service ID created
  - [ ] Keys generated
  - [ ] Redirect URLs registered
  - [ ] Configuration added to Supabase Dashboard
- [ ] Google Sign In configured
  - [ ] Google Cloud Console project created
  - [ ] OAuth client ID created
  - [ ] Authorized redirect URIs added
  - [ ] Configuration added to Supabase Dashboard
- [ ] OAuth providers tested

---

## Storage Configuration

### 13. Storage Buckets
- [ ] `cafe-images` bucket created
  - [ ] Public access enabled
  - [ ] File size limit: 5MB
  - [ ] Allowed MIME types: image/jpeg, image/png, image/webp
- [ ] `menu-images` bucket created
  - [ ] Public access enabled
  - [ ] File size limit: 5MB
  - [ ] Allowed MIME types: image/jpeg, image/png, image/webp
- [ ] `cafe-documents` bucket created
  - [ ] Private access
  - [ ] File size limit: 10MB
  - [ ] Allowed MIME types: application/pdf, image/*
- [ ] `user-avatars` bucket created
  - [ ] Public access enabled
  - [ ] File size limit: 2MB
  - [ ] Allowed MIME types: image/jpeg, image/png, image/webp

### 14. Storage Policies
- [ ] RLS policies reviewed for all buckets
- [ ] Upload policies tested
- [ ] Download policies tested
- [ ] Delete policies tested

---

## Security Configuration

### 15. Row Level Security (RLS)
- [ ] RLS enabled on all tables: 
  ```sql
  SELECT tablename, rowsecurity 
  FROM pg_tables 
  WHERE schemaname = 'public';
  ```
- [ ] All tables show `rowsecurity = true`
- [ ] RLS policies reviewed for correctness
- [ ] Anonymous access tested (should be restricted)
- [ ] Authenticated access tested (should work)

### 16. API Security
- [ ] Service role key stored securely (not in client apps)
- [ ] Anon key usage verified (only for client apps)
- [ ] API rate limits reviewed
- [ ] CORS settings configured if needed

### 17. Database Security
- [ ] Network restrictions configured (if using static IPs)
- [ ] Connection pooling enabled
- [ ] SSL connections enforced
- [ ] Database password is strong and secure

---

## Monitoring and Observability

### 18. Supabase Dashboard
- [ ] Logs configured (Dashboard → Logs)
  - [ ] Query performance monitoring enabled
  - [ ] API logs enabled
  - [ ] Auth logs enabled
- [ ] Alerts configured (Dashboard → Settings → Alerts)
  - [ ] Database usage alert (80% threshold)
  - [ ] API rate limit alerts
  - [ ] Error rate alerts
- [ ] Metrics dashboard reviewed

### 19. External Monitoring (Optional)
- [ ] Sentry configured for error tracking
  - [ ] iOS app integration
  - [ ] Admin panel integration
  - [ ] DSN added to environment variables
- [ ] Analytics configured (Mixpanel, Amplitude)
- [ ] Uptime monitoring (UptimeRobot, Pingdom)
- [ ] APM configured (Datadog, New Relic)

---

## Client Applications

### 20. iOS App Configuration
- [ ] Environment.swift updated with production URL
- [ ] Production Supabase keys added
- [ ] Build configuration set to "Release"
- [ ] Debug logging disabled
- [ ] Deep link configuration verified
- [ ] Push notification certificates configured
- [ ] App Store Connect configured
- [ ] TestFlight build created
- [ ] Beta testers invited

### 21. Admin Panel Configuration
- [ ] Environment variables set for production
  - [ ] NEXT_PUBLIC_SUPABASE_URL
  - [ ] NEXT_PUBLIC_SUPABASE_ANON_KEY
  - [ ] SUPABASE_SERVICE_ROLE_KEY
- [ ] Deployed to hosting (Vercel, Netlify, etc.)
- [ ] Custom domain configured
- [ ] SSL certificate verified
- [ ] Admin login tested

---

## Testing

### 22. Functionality Testing
- [ ] User registration tested
  - [ ] Email confirmation received
  - [ ] Account activated successfully
- [ ] User login tested
  - [ ] Email/password login works
  - [ ] OAuth login works (Apple, Google)
  - [ ] Session persistence works
- [ ] Password reset tested
- [ ] Profile management tested

### 23. Core Features Testing
- [ ] Cafe browsing works
- [ ] Cafe filtering works (distance, rating, etc.)
- [ ] Menu items display correctly
- [ ] Order creation works
- [ ] Wallet operations work
  - [ ] CityPass wallet creation
  - [ ] Cafe Wallet creation
  - [ ] Mock payment flow
- [ ] QR code generation works
- [ ] Order status updates work
- [ ] Order history works

### 24. Admin Panel Testing
- [ ] Admin login works
- [ ] Cafe management works
  - [ ] Create cafe
  - [ ] Edit cafe
  - [ ] Delete cafe
- [ ] Menu management works
- [ ] Order management works
- [ ] Wallet management works
- [ ] Analytics dashboard loads
- [ ] Cafe onboarding approval flow works

### 25. Security Testing
- [ ] Unauthenticated users cannot access protected data
- [ ] Users can only access their own data
- [ ] Admin role restrictions work
- [ ] Owner role restrictions work
- [ ] SQL injection attempts blocked
- [ ] XSS attempts blocked
- [ ] CSRF protection working

### 26. Performance Testing
- [ ] API response times acceptable (<500ms average)
- [ ] Database queries optimized
- [ ] Indexes created for frequently queried fields
- [ ] Image loading optimized
- [ ] App load time acceptable (<3s)
- [ ] Load testing completed (if high traffic expected)

---

## Data Management

### 27. Backup Strategy
- [ ] Manual backup script tested (`scripts/backup_production.sh`)
- [ ] Backup schedule defined (daily recommended)
- [ ] Backups stored in secure location (S3, cloud storage)
- [ ] Backup encryption configured
- [ ] PITR enabled (Pro plan)
- [ ] Retention policy defined (30 days recommended)

### 28. Disaster Recovery
- [ ] Recovery plan documented
- [ ] Restore process tested in staging environment
- [ ] RTO (Recovery Time Objective) defined
- [ ] RPO (Recovery Point Objective) defined
- [ ] Emergency contacts list maintained
- [ ] Escalation procedures documented

---

## User Management

### 29. Initial Admin Setup
- [ ] First admin user registered
- [ ] Admin role assigned:
  ```sql
  UPDATE profiles 
  SET role = 'admin' 
  WHERE email = 'admin@subscribecoffie.com';
  ```
- [ ] Admin login verified
- [ ] Admin dashboard access verified

### 30. User Onboarding
- [ ] Welcome email template configured
- [ ] Onboarding flow tested
- [ ] User documentation prepared
- [ ] Support email configured (support@subscribecoffie.com)
- [ ] FAQ prepared

---

## Business Operations

### 31. Cafe Onboarding
- [ ] Onboarding form accessible
- [ ] Document upload works
- [ ] Approval workflow tested
- [ ] Notification emails work
- [ ] Owner account creation works
- [ ] Owner dashboard access works

### 32. Payment Configuration (Mock Mode)
- [ ] Mock payment flow tested
- [ ] Commission calculation verified
- [ ] Transaction logging works
- [ ] Wallet balance updates correctly
- [ ] Payment methods table populated

### 33. Support and Documentation
- [ ] User documentation published
- [ ] Cafe owner documentation published
- [ ] Admin documentation published
- [ ] API documentation published (if applicable)
- [ ] Support channels established
- [ ] Knowledge base created

---

## Compliance and Legal

### 34. Privacy and Data Protection
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Cookie policy published (if applicable)
- [ ] GDPR compliance reviewed (for EU users)
- [ ] Data retention policy defined
- [ ] User data export functionality (GDPR requirement)
- [ ] User data deletion functionality (GDPR requirement)

### 35. Business and Financial
- [ ] Business entity registered
- [ ] Payment processing agreement signed (for future)
- [ ] Commission rates finalized
- [ ] Pricing strategy confirmed
- [ ] Tax compliance reviewed

---

## Go-Live

### 36. Pre-Launch
- [ ] All above checklist items completed
- [ ] Soft launch date scheduled
- [ ] Beta testers recruited
- [ ] Marketing materials prepared
- [ ] Press kit prepared (optional)
- [ ] Social media accounts created
- [ ] Support team briefed

### 37. Launch Day
- [ ] DNS changes propagated (if using custom domain)
- [ ] Monitoring dashboards open
- [ ] Team available for support
- [ ] iOS app submitted to App Store (or TestFlight for beta)
- [ ] Admin panel accessible
- [ ] Launch announcement sent
- [ ] Social media posts published

### 38. Post-Launch Monitoring (First 48 hours)
- [ ] Error rates monitored
- [ ] API usage monitored
- [ ] Database performance monitored
- [ ] User registrations tracked
- [ ] Orders tracked
- [ ] User feedback collected
- [ ] Issues triaged and prioritized
- [ ] Critical bugs fixed immediately

---

## Post-Deployment

### 39. Week 1 Tasks
- [ ] Daily metrics reviewed
- [ ] User feedback analyzed
- [ ] Bug fixes prioritized and deployed
- [ ] Performance optimization if needed
- [ ] Backup verification
- [ ] Scaling assessment (upgrade to Pro if needed)

### 40. Month 1 Tasks
- [ ] Monthly metrics reviewed
- [ ] Cost analysis performed
- [ ] User retention tracked
- [ ] Feature requests prioritized
- [ ] Marketing effectiveness evaluated
- [ ] Partnership discussions with cafes

### 41. Ongoing Maintenance
- [ ] Weekly backups verified
- [ ] Monthly security audits
- [ ] Quarterly disaster recovery tests
- [ ] Continuous monitoring
- [ ] Regular updates and feature releases
- [ ] User satisfaction surveys

---

## Rollback Plan

### 42. Emergency Rollback (If Critical Issues Arise)
- [ ] Rollback procedure documented
- [ ] Emergency contacts list ready
- [ ] Maintenance mode banner prepared
- [ ] Communication templates ready (email, social media)
- [ ] Backup restoration tested
- [ ] Rollback decision criteria defined

---

## Scaling Preparation

### 43. Growth Thresholds
- [ ] Upgrade to Pro plan when:
  - Database size > 400MB
  - API requests > 40 req/sec sustained
  - Need for PITR backups
  - Need for priority support
- [ ] Consider read replicas when:
  - Query performance degrades
  - High read load (>1000 req/min)
- [ ] Consider multi-region when:
  - Expanding to new countries
  - Latency issues for remote users

---

## Success Metrics

### 44. KPIs to Track
- [ ] Daily Active Users (DAU)
- [ ] Monthly Active Users (MAU)
- [ ] User retention (Day 1, Day 7, Day 30)
- [ ] Order completion rate
- [ ] Average order value
- [ ] Number of active cafes
- [ ] GMV (Gross Merchandise Value)
- [ ] Commission revenue
- [ ] API response times
- [ ] Error rates
- [ ] Crash rates (iOS app)

---

## Sign-Off

**Deployment Completed By:** ___________________________

**Date:** ___________________________

**Sign-off:** ___________________________

**Notes:**
_______________________________________________
_______________________________________________
_______________________________________________

---

## Next Steps After Successful Deployment

1. ✅ **Cloud deployment complete**
2. 🔄 **Monitor for 48 hours** - Watch for any issues
3. 🔄 **Gather beta feedback** - Iterate on UX
4. 🔄 **Real payment integration** (Phase 2.0.1)
   - Integrate Stripe or ЮKassa
   - Replace mock payment flows
5. 🔄 **Scale infrastructure** as user base grows
6. 🔄 **Add features** per roadmap (loyalty, marketing, etc.)

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-30  
**Maintained By:** SubscribeCoffie Team
