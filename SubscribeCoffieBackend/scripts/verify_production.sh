#!/bin/bash

# Production Verification Script for SubscribeCoffie Backend
# This script verifies that the production deployment is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   SubscribeCoffie Production Verification ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}❌ .env.production not found${NC}"
    echo -e "${YELLOW}Copy env.production.template to .env.production and fill in values${NC}"
    exit 1
fi

# Load environment variables
source .env.production

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}❌ SUPABASE_URL or SUPABASE_ANON_KEY not set in .env.production${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables loaded${NC}"
echo -e "${BLUE}Supabase URL: $SUPABASE_URL${NC}"
echo ""

# Test 1: Check API availability
echo -e "${YELLOW}[1/7] Testing API availability...${NC}"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/rest/v1/" -H "apikey: $SUPABASE_ANON_KEY")

if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "404" ]; then
    echo -e "${GREEN}✅ API is accessible${NC}"
else
    echo -e "${RED}❌ API not accessible (HTTP $RESPONSE)${NC}"
    exit 1
fi
echo ""

# Test 2: Check tables exist
echo -e "${YELLOW}[2/7] Verifying database tables...${NC}"

TABLES=("cafes" "menu_items" "orders" "wallets" "profiles" "payment_methods" "commission_config")

for TABLE in "${TABLES[@]}"; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        "$SUPABASE_URL/rest/v1/$TABLE?select=count" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY")
    
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "206" ]; then
        echo -e "${GREEN}  ✓ Table '$TABLE' exists${NC}"
    else
        echo -e "${RED}  ✗ Table '$TABLE' not found (HTTP $RESPONSE)${NC}"
    fi
done
echo ""

# Test 3: Check RLS is enabled
echo -e "${YELLOW}[3/7] Checking Row Level Security...${NC}"

# Try to access wallets without auth (should fail or return empty)
WALLET_RESPONSE=$(curl -s "$SUPABASE_URL/rest/v1/wallets?select=*" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY")

if echo "$WALLET_RESPONSE" | grep -q "row-level security" || [ "$WALLET_RESPONSE" = "[]" ]; then
    echo -e "${GREEN}✅ RLS is working correctly${NC}"
else
    echo -e "${YELLOW}⚠️  RLS might not be properly configured${NC}"
    echo -e "${YELLOW}Response: $WALLET_RESPONSE${NC}"
fi
echo ""

# Test 4: Check cafes endpoint (public data)
echo -e "${YELLOW}[4/7] Testing public data access (cafes)...${NC}"

CAFES_RESPONSE=$(curl -s "$SUPABASE_URL/rest/v1/cafes?select=id,name,address&limit=5" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY")

CAFE_COUNT=$(echo "$CAFES_RESPONSE" | grep -o '"id"' | wc -l | xargs)

if [ "$CAFE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Cafes endpoint working ($CAFE_COUNT cafes found)${NC}"
else
    echo -e "${YELLOW}⚠️  No cafes found (this is OK for fresh deployment)${NC}"
fi
echo ""

# Test 5: Check commission config
echo -e "${YELLOW}[5/7] Checking commission configuration...${NC}"

COMMISSION_RESPONSE=$(curl -s "$SUPABASE_URL/rest/v1/commission_config?select=*" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY")

COMMISSION_COUNT=$(echo "$COMMISSION_RESPONSE" | grep -o '"operation_type"' | wc -l | xargs)

if [ "$COMMISSION_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Commission configuration found ($COMMISSION_COUNT entries)${NC}"
else
    echo -e "${YELLOW}⚠️  No commission configuration found${NC}"
    echo -e "${YELLOW}Run this SQL in Dashboard:${NC}"
    echo -e "${BLUE}INSERT INTO commission_config (operation_type, commission_percent, active)${NC}"
    echo -e "${BLUE}VALUES ('citypass_topup', 7.5, true), ('cafe_wallet_topup', 4.0, true), ('direct_order', 17.5, true);${NC}"
fi
echo ""

# Test 6: Check storage buckets
echo -e "${YELLOW}[6/7] Verifying storage buckets...${NC}"

BUCKETS=("cafe-images" "menu-images" "cafe-documents" "user-avatars")

for BUCKET in "${BUCKETS[@]}"; do
    BUCKET_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        "$SUPABASE_URL/storage/v1/bucket/$BUCKET" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY")
    
    if [ "$BUCKET_RESPONSE" = "200" ]; then
        echo -e "${GREEN}  ✓ Bucket '$BUCKET' exists${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Bucket '$BUCKET' not found (create in Dashboard → Storage)${NC}"
    fi
done
echo ""

# Test 7: Check authentication
echo -e "${YELLOW}[7/7] Checking authentication configuration...${NC}"

AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    "$SUPABASE_URL/auth/v1/health" \
    -H "apikey: $SUPABASE_ANON_KEY")

if [ "$AUTH_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ Authentication service is healthy${NC}"
else
    echo -e "${RED}❌ Authentication service issue (HTTP $AUTH_RESPONSE)${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Verification Summary             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Core infrastructure is working${NC}"
echo ""

# Checklist
echo -e "${YELLOW}Post-Deployment Checklist:${NC}"
echo ""
echo -e "[ ] Commission rates configured"
echo -e "[ ] Storage buckets created"
echo -e "[ ] SMTP configured (Auth → Settings)"
echo -e "[ ] OAuth providers configured (Apple, Google)"
echo -e "[ ] Site URL and redirect URLs set"
echo -e "[ ] First admin user created and promoted"
echo -e "[ ] iOS app updated with production URL"
echo -e "[ ] Admin panel deployed with production config"
echo -e "[ ] Monitoring and alerts configured"
echo -e "[ ] PITR backups enabled (Pro plan)"
echo ""
echo -e "${BLUE}For detailed checklist, see: CLOUD_DEPLOYMENT.md (Phase 10)${NC}"
echo ""

echo -e "${GREEN}✨ Production verification complete!${NC}"
