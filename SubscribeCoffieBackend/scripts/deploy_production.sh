#!/bin/bash

# Production Deployment Script for SubscribeCoffie Backend
# This script helps deploy the Supabase backend to production cloud

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   SubscribeCoffie Production Deployment   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"

if ! command_exists supabase; then
    echo -e "${RED}❌ Supabase CLI not found. Install it first:${NC}"
    echo -e "${YELLOW}npm install -g supabase${NC}"
    exit 1
fi

if ! command_exists jq; then
    echo -e "${YELLOW}⚠️  jq not found. Some features may not work. Install with: brew install jq${NC}"
fi

if ! command_exists docker; then
    echo -e "${YELLOW}⚠️  Docker not found. Required for local testing.${NC}"
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Check if logged in to Supabase
echo -e "${YELLOW}[2/8] Checking Supabase authentication...${NC}"

if ! supabase projects list >/dev/null 2>&1; then
    echo -e "${YELLOW}Not logged in to Supabase. Logging in...${NC}"
    supabase login
else
    echo -e "${GREEN}✅ Already logged in to Supabase${NC}"
fi
echo ""

# List available projects
echo -e "${YELLOW}[3/8] Available Supabase projects:${NC}"
supabase projects list
echo ""

# Prompt for project reference
read -p "$(echo -e ${BLUE}Enter your production project reference ID: ${NC})" PROJECT_REF

if [ -z "$PROJECT_REF" ]; then
    echo -e "${RED}❌ Project reference cannot be empty${NC}"
    exit 1
fi

# Link to project
echo -e "${YELLOW}[4/8] Linking to production project...${NC}"

if [ -f "$PROJECT_ROOT/.git/config" ]; then
    cd "$PROJECT_ROOT"
    supabase link --project-ref "$PROJECT_REF"
    echo -e "${GREEN}✅ Successfully linked to project: $PROJECT_REF${NC}"
else
    echo -e "${RED}❌ Not a git repository. Please run from project root.${NC}"
    exit 1
fi
echo ""

# Test local migrations first
echo -e "${YELLOW}[5/8] Testing migrations locally...${NC}"
read -p "$(echo -e ${BLUE}Do you want to test migrations locally first? (y/n): ${NC})" TEST_LOCAL

if [ "$TEST_LOCAL" = "y" ] || [ "$TEST_LOCAL" = "Y" ]; then
    echo -e "${YELLOW}Starting local Supabase...${NC}"
    supabase start
    
    echo -e "${YELLOW}Resetting local database with migrations...${NC}"
    supabase db reset
    
    echo -e "${GREEN}✅ Local test passed${NC}"
    
    read -p "$(echo -e ${BLUE}Review the results. Continue to production? (y/n): ${NC})" CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo -e "${YELLOW}Deployment cancelled${NC}"
        exit 0
    fi
fi
echo ""

# Show migration diff
echo -e "${YELLOW}[6/8] Showing migration diff...${NC}"
echo -e "${BLUE}This will show what changes will be applied to production:${NC}"
supabase db diff --linked

echo ""
read -p "$(echo -e ${YELLOW}Review the diff carefully. Continue with deployment? (y/n): ${NC})" DEPLOY_CONFIRM

if [ "$DEPLOY_CONFIRM" != "y" ] && [ "$DEPLOY_CONFIRM" != "Y" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi
echo ""

# Deploy migrations
echo -e "${YELLOW}[7/8] Deploying migrations to production...${NC}"
echo -e "${RED}⚠️  WARNING: This action cannot be undone!${NC}"
read -p "$(echo -e ${RED}Type 'DEPLOY' to confirm: ${NC})" FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "DEPLOY" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo -e "${YELLOW}Pushing migrations to production...${NC}"
supabase db push

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Migrations deployed successfully!${NC}"
else
    echo -e "${RED}❌ Migration deployment failed${NC}"
    exit 1
fi
echo ""

# Verify deployment
echo -e "${YELLOW}[8/8] Verifying deployment...${NC}"

echo -e "${BLUE}Listing remote tables:${NC}"
supabase db remote list

echo ""
echo -e "${GREEN}✅ Deployment verification complete${NC}"
echo ""

# Create production seed reminder
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""
echo -e "1. ${BLUE}Set up commission rates:${NC}"
echo -e "   Run the SQL in Supabase Dashboard SQL Editor:"
echo -e "   ${GREEN}INSERT INTO commission_config (operation_type, commission_percent, active)${NC}"
echo -e "   ${GREEN}VALUES ('citypass_topup', 7.5, true), ('cafe_wallet_topup', 4.0, true), ('direct_order', 17.5, true);${NC}"
echo ""
echo -e "2. ${BLUE}Create storage buckets:${NC}"
echo -e "   - Go to Storage in Dashboard"
echo -e "   - Create: cafe-images (public)"
echo -e "   - Create: menu-images (public)"
echo -e "   - Create: cafe-documents (private)"
echo -e "   - Create: user-avatars (public)"
echo ""
echo -e "3. ${BLUE}Configure authentication:${NC}"
echo -e "   - Set Site URL: https://app.subscribecoffie.com"
echo -e "   - Add redirect URLs"
echo -e "   - Configure SMTP settings"
echo -e "   - Enable OAuth providers (Apple, Google)"
echo ""
echo -e "4. ${BLUE}Update iOS app configuration:${NC}"
echo -e "   - Update Environment.swift with production URL and keys"
echo -e "   - Test with production backend"
echo ""
echo -e "5. ${BLUE}Configure monitoring:${NC}"
echo -e "   - Set up alerts in Dashboard"
echo -e "   - Configure Sentry (optional)"
echo -e "   - Enable PITR backups (Pro plan)"
echo ""
echo -e "6. ${BLUE}Create first admin user:${NC}"
echo -e "   - Register through the app"
echo -e "   - Promote to admin in SQL Editor:"
echo -e "   ${GREEN}UPDATE profiles SET role = 'admin' WHERE email = 'your@email.com';${NC}"
echo ""
echo -e "${GREEN}📖 For detailed instructions, see: CLOUD_DEPLOYMENT.md${NC}"
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Deployment completed successfully!    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
