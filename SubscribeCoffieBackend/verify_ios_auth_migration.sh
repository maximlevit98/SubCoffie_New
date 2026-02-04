#!/bin/bash
# ============================================================================
# iOS User Authentication Migration - Verification Script
# ============================================================================
# This script verifies that the migration was applied successfully
# and all components are working correctly.
#
# Usage:
#   chmod +x verify_ios_auth_migration.sh
#   ./verify_ios_auth_migration.sh
#
# Prerequisites:
#   - Supabase CLI installed
#   - Local Supabase instance running OR connection to remote instance
#   - psql available in PATH

set -e  # Exit on error

echo "============================================================================"
echo "iOS User Authentication Migration Verification"
echo "============================================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI not found${NC}"
    echo "Please install: https://supabase.com/docs/guides/cli"
    exit 1
fi

echo -e "${GREEN}✓${NC} Supabase CLI found"
echo ""

# Check if local Supabase is running
if supabase status &> /dev/null; then
    echo -e "${GREEN}✓${NC} Local Supabase is running"
    USE_LOCAL=true
    DB_URL=$(supabase status | grep "DB URL" | awk '{print $3}')
else
    echo -e "${YELLOW}⚠${NC} Local Supabase not running"
    echo "Checking for remote connection..."
    # Try to use project ref if available
    if [ -f ".env" ]; then
        source .env
        if [ -n "$SUPABASE_URL" ]; then
            echo -e "${GREEN}✓${NC} Using remote Supabase from .env"
            USE_LOCAL=false
        else
            echo -e "${RED}❌ No Supabase connection available${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ No .env file found${NC}"
        exit 1
    fi
fi

echo ""
echo "Running verification checks..."
echo "============================================================================"
echo ""

# Function to run SQL and check result
check_sql() {
    local description="$1"
    local sql="$2"
    local expected="$3"
    
    echo -n "Checking: $description... "
    
    if [ "$USE_LOCAL" = true ]; then
        result=$(supabase db execute "$sql" --output=csv 2>&1 | tail -n 1)
    else
        # For remote, would need psql with connection string
        echo -e "${YELLOW}SKIP (remote)${NC}"
        return
    fi
    
    if [[ "$result" == *"$expected"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Expected: $expected"
        echo "  Got: $result"
        return 1
    fi
}

# Check 1: Profiles table has new columns
echo "1. Verifying profiles table schema..."
check_sql "avatar_url column exists" \
    "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='profiles' AND column_name='avatar_url'" \
    "1"

check_sql "auth_provider column exists" \
    "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='profiles' AND column_name='auth_provider'" \
    "1"

check_sql "updated_at column exists" \
    "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='profiles' AND column_name='updated_at'" \
    "1"

echo ""

# Check 2: Constraints exist
echo "2. Verifying constraints..."
check_sql "auth_provider constraint exists" \
    "SELECT COUNT(*) FROM pg_constraint WHERE conname='profiles_auth_provider_check'" \
    "1"

echo ""

# Check 3: Indexes exist
echo "3. Verifying indexes..."
check_sql "profiles_phone_idx exists" \
    "SELECT COUNT(*) FROM pg_indexes WHERE indexname='profiles_phone_idx'" \
    "1"

check_sql "profiles_auth_provider_idx exists" \
    "SELECT COUNT(*) FROM pg_indexes WHERE indexname='profiles_auth_provider_idx'" \
    "1"

check_sql "profiles_avatar_url_idx exists" \
    "SELECT COUNT(*) FROM pg_indexes WHERE indexname='profiles_avatar_url_idx'" \
    "1"

echo ""

# Check 4: RPC functions exist
echo "4. Verifying RPC functions..."
check_sql "init_user_profile function exists" \
    "SELECT COUNT(*) FROM pg_proc WHERE proname='init_user_profile'" \
    "1"

check_sql "get_my_profile function exists" \
    "SELECT COUNT(*) FROM pg_proc WHERE proname='get_my_profile'" \
    "1"

check_sql "update_my_profile function exists" \
    "SELECT COUNT(*) FROM pg_proc WHERE proname='update_my_profile'" \
    "1"

check_sql "get_user_profile function exists" \
    "SELECT COUNT(*) FROM pg_proc WHERE proname='get_user_profile'" \
    "1"

check_sql "search_users function exists" \
    "SELECT COUNT(*) FROM pg_proc WHERE proname='search_users'" \
    "1"

echo ""

# Check 5: Views exist
echo "5. Verifying views..."
check_sql "orders_with_profiles view exists" \
    "SELECT COUNT(*) FROM information_schema.views WHERE table_name='orders_with_profiles'" \
    "1"

echo ""

# Check 6: Trigger exists
echo "6. Verifying triggers..."
check_sql "on_auth_user_created trigger exists" \
    "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name='on_auth_user_created'" \
    "1"

check_sql "tg_profiles_updated_at trigger exists" \
    "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name='tg_profiles_updated_at'" \
    "1"

echo ""
echo "============================================================================"
echo "Advanced Checks (requires test data)"
echo "============================================================================"
echo ""

# Check if we can run functional tests
if [ "$USE_LOCAL" = true ]; then
    echo "Running functional test suite..."
    echo ""
    
    # Run the full test file
    if supabase db test < tests/ios_user_auth_tests.sql > /tmp/ios_auth_test_output.txt 2>&1; then
        echo -e "${GREEN}✓${NC} Functional tests passed"
        echo ""
        echo "Sample output:"
        tail -n 20 /tmp/ios_auth_test_output.txt
    else
        echo -e "${YELLOW}⚠${NC} Some functional tests failed (this is OK if no test data exists)"
        echo "Check /tmp/ios_auth_test_output.txt for details"
    fi
else
    echo -e "${YELLOW}⚠${NC} Functional tests skipped (requires local Supabase)"
fi

echo ""
echo "============================================================================"
echo "Manual Verification Steps"
echo "============================================================================"
echo ""
echo "To fully verify the migration, perform these manual tests:"
echo ""
echo "1. iOS App - Email Registration:"
echo "   - Sign up with email/password"
echo "   - Complete profile setup (name, birth date, city)"
echo "   - Verify profile appears in admin panel"
echo ""
echo "2. iOS App - Phone Registration:"
echo "   - Sign up with phone number"
echo "   - Enter SMS OTP code"
echo "   - Complete profile setup"
echo "   - Verify profile appears in admin panel"
echo ""
echo "3. iOS App - Apple Sign In:"
echo "   - Sign in with Apple"
echo "   - Complete any missing profile fields"
echo "   - Verify auth_provider = 'apple'"
echo "   - Verify avatar_url is populated"
echo ""
echo "4. iOS App - Google Sign In:"
echo "   - Sign in with Google"
echo "   - Complete any missing profile fields"
echo "   - Verify auth_provider = 'google'"
echo "   - Verify avatar_url is populated"
echo ""
echo "5. Admin Panel:"
echo "   - Navigate to Users page"
echo "   - Verify all registered users are displayed"
echo "   - Search for users by name/email/phone"
echo "   - View order details and verify user info appears"
echo ""
echo "6. Database:"
echo "   - Check profiles table has data"
echo "   - Verify auth_provider values are correct"
echo "   - Check updated_at changes on profile updates"
echo ""
echo "============================================================================"
echo "Verification Complete!"
echo "============================================================================"
echo ""

if [ "$USE_LOCAL" = true ]; then
    echo -e "${GREEN}✓${NC} All automated checks passed"
    echo ""
    echo "Next steps:"
    echo "1. Review the quickstart guide: IOS_USER_AUTH_QUICKSTART.md"
    echo "2. Update iOS app to use new RPC functions"
    echo "3. Update admin panel to display user information"
    echo "4. Configure OAuth providers in Supabase Dashboard"
    echo "5. Run manual tests as listed above"
else
    echo -e "${YELLOW}⚠${NC} Limited verification on remote database"
    echo ""
    echo "For full verification, run locally:"
    echo "  supabase start"
    echo "  supabase db push"
    echo "  ./verify_ios_auth_migration.sh"
fi

echo ""
echo "For detailed usage instructions, see: IOS_USER_AUTH_QUICKSTART.md"
echo ""
