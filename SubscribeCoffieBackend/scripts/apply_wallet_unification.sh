#!/bin/bash
# Apply Wallet Schema Unification Migrations
# Date: 2026-02-05
# Priority: P0

set -e

echo "🚀 Wallet Schema Unification - Migration Script"
echo "================================================"
echo ""
echo "This script will apply 4 migrations:"
echo "  1. 20260205000001_fix_wallets_rls_security.sql"
echo "  2. 20260205000002_expand_wallet_transactions.sql"
echo "  3. 20260205000003_unify_wallets_schema.sql"
echo "  4. 20260205000004_deprecate_wallet_sync_functions.sql"
echo ""
echo "⚠️  WARNING: This will:"
echo "  - Remove direct UPDATE access to wallets for users"
echo "  - Expand wallet_transactions table schema"
echo "  - Migrate wallets to canonical schema (wallet_type, balance_credits, lifetime_top_up_credits)"
echo "  - Merge bonus_balance into balance_credits"
echo "  - Drop old RPC functions (get_user_wallet, add_wallet_transaction, etc.)"
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "❌ Aborted"
  exit 1
fi

echo ""
echo "📊 Checking current database state..."
echo ""

# Check if we're connected to the right database
psql -d postgres -c "SELECT current_database(), current_user;" 2>&1

echo ""
echo "🔍 Checking wallets table schema..."
psql -d postgres -c "\d public.wallets" 2>&1 || echo "⚠️  wallets table not found"

echo ""
echo "📋 Current wallets count:"
psql -d postgres -c "SELECT COUNT(*) as wallet_count FROM public.wallets;" 2>&1 || echo "⚠️  Cannot query wallets"

echo ""
read -p "Proceed with migration? (yes/no): " confirm2
if [ "$confirm2" != "yes" ]; then
  echo "❌ Aborted"
  exit 1
fi

echo ""
echo "⏳ Applying migrations..."
echo ""

# Apply migrations in order
for migration in \
  "20260205000001_fix_wallets_rls_security.sql" \
  "20260205000002_expand_wallet_transactions.sql" \
  "20260205000003_unify_wallets_schema.sql" \
  "20260205000004_deprecate_wallet_sync_functions.sql"
do
  echo "📄 Applying: $migration"
  if [ -f "supabase/migrations/$migration" ]; then
    psql -d postgres -f "supabase/migrations/$migration" --single-transaction --set ON_ERROR_STOP=on
    echo "✅ Applied: $migration"
  else
    echo "❌ File not found: supabase/migrations/$migration"
    exit 1
  fi
  echo ""
done

echo ""
echo "🎉 All migrations applied successfully!"
echo ""
echo "📊 Post-migration verification:"
echo ""

# Verify schema
echo "1. Checking wallets schema:"
psql -d postgres -c "\d public.wallets" 2>&1

echo ""
echo "2. Wallet type breakdown:"
psql -d postgres -c "SELECT wallet_type, COUNT(*) as count, SUM(balance_credits) as total_balance FROM public.wallets GROUP BY wallet_type;" 2>&1

echo ""
echo "3. Checking for negative balances (should be 0):"
psql -d postgres -c "SELECT COUNT(*) as negative_balance_count FROM public.wallets WHERE balance_credits < 0;" 2>&1

echo ""
echo "4. Wallet transactions schema:"
psql -d postgres -c "\d public.wallet_transactions" 2>&1

echo ""
echo "✅ Migration complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Test admin panel: http://localhost:3000/admin/wallets"
echo "  2. Test iOS app wallet display and top-up"
echo "  3. Check logs for any errors"
echo "  4. If all looks good, apply to staging/production"
echo ""
echo "📚 Documentation: WALLET_SCHEMA_UNIFICATION.md"
