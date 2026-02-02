#!/bin/bash

# Run All Backend RPC Tests
# Скрипт для запуска всех SQL тестов

set -e

echo "========================================="
echo "Backend RPC Tests Suite"
echo "========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Определяем DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    export DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
    echo -e "${YELLOW}Using default DATABASE_URL: $DATABASE_URL${NC}"
fi

echo ""
echo "Step 1: Seeding test data..."
echo "========================================="
psql "$DATABASE_URL" -f tests/seed_test_data.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Test data seeded successfully${NC}"
else
    echo -e "${RED}❌ Failed to seed test data${NC}"
    exit 1
fi

echo ""
echo "Step 2: Running Orders RPC tests..."
echo "========================================="
psql "$DATABASE_URL" -f tests/orders_rpc.test.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Orders RPC tests passed${NC}"
else
    echo -e "${RED}❌ Orders RPC tests failed${NC}"
    exit 1
fi

echo ""
echo "Step 3: Running Wallets RPC tests..."
echo "========================================="
psql "$DATABASE_URL" -f tests/wallets_rpc.test.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Wallets RPC tests passed${NC}"
else
    echo -e "${RED}❌ Wallets RPC tests failed${NC}"
    exit 1
fi

echo ""
echo "Step 4: Running Analytics tests..."
echo "========================================="
psql "$DATABASE_URL" -f tests/analytics.test.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Analytics tests passed${NC}"
else
    echo -e "${RED}❌ Analytics tests failed${NC}"
    exit 1
fi

echo ""
echo "Step 5: Running Payment Integration tests..."
echo "========================================="
psql "$DATABASE_URL" -f tests/payment_integration.test.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Payment Integration tests passed${NC}"
else
    echo -e "${RED}❌ Payment Integration tests failed${NC}"
    exit 1
fi

echo ""
echo "Step 6: Running RPC Integration tests..."
echo "========================================="
psql "$DATABASE_URL" -f tests/rpc_integration.test.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ RPC Integration tests passed${NC}"
else
    echo -e "${RED}❌ RPC Integration tests failed${NC}"
    exit 1
fi

echo ""
echo "========================================="
echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
echo "========================================="
echo ""
echo "Test Summary:"
echo "  - Test data: ✅"
echo "  - Orders RPC: ✅"
echo "  - Wallets RPC: ✅"
echo "  - Analytics: ✅"
echo "  - Payment Integration: ✅"
echo "  - RPC Integration: ✅"
echo ""
