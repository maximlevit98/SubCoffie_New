#!/bin/bash

# Enhanced Backend Test Suite
# Полный набор тестов с отчетностью

set -e

echo "========================================="
echo "Enhanced Backend Test Suite"
echo "========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Определяем DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    export DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
    echo -e "${YELLOW}Using default DATABASE_URL: $DATABASE_URL${NC}"
fi

# Счетчики для статистики
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

# Функция для запуска теста
run_test() {
    local test_name=$1
    local test_file=$2
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo ""
    echo -e "${BLUE}Running: $test_name${NC}"
    echo "========================================="
    
    if psql "$DATABASE_URL" -f "$test_file" 2>&1 | tee /tmp/test_output.log; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Проверка подключения к БД
echo "Checking database connection..."
if ! psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to database${NC}"
    echo "Make sure Supabase is running: supabase start"
    exit 1
fi
echo -e "${GREEN}✅ Database connection OK${NC}"

# Seeding test data
echo ""
echo "Step 0: Seeding test data..."
echo "========================================="
if psql "$DATABASE_URL" -f tests/seed_test_data.sql > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Test data seeded successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Test data seeding had warnings (may be OK)${NC}"
fi

# Unit Tests
run_test "Orders RPC Tests" "tests/orders_rpc.test.sql"
run_test "Wallets RPC Tests" "tests/wallets_rpc.test.sql"
run_test "Analytics Tests" "tests/analytics.test.sql"
run_test "Payment Integration Tests" "tests/payment_integration.test.sql"

# Integration Tests
run_test "RPC Integration Tests" "tests/rpc_integration.test.sql"
run_test "Full Integration Tests" "tests/integration_full.test.sql"

# Security Tests
if [ -f "tests/security_tests.sql" ]; then
    run_test "Security Tests" "tests/security_tests.sql"
fi

# Advanced Analytics Tests (если есть)
if [ -f "tests/test_advanced_analytics.sql" ]; then
    run_test "Advanced Analytics Tests" "tests/test_advanced_analytics.sql"
fi

# Cafe Onboarding Tests (если есть)
if [ -f "tests/test_cafe_onboarding.sql" ]; then
    run_test "Cafe Onboarding Tests" "tests/test_cafe_onboarding.sql"
fi

# Social Features Tests (если есть)
if [ -f "tests/social_features.test.sql" ]; then
    run_test "Social Features Tests" "tests/social_features.test.sql"
fi

# Финальный отчет
echo ""
echo "========================================="
echo -e "${BLUE}Test Summary${NC}"
echo "========================================="
echo -e "Total Tests:  ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
    echo ""
    exit 1
fi
