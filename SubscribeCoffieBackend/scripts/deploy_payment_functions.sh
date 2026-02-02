#!/bin/bash

# Deploy Payment Edge Functions to Supabase
# Usage: ./scripts/deploy_payment_functions.sh

set -e

echo "🚀 Deploying Payment Edge Functions..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -d "supabase/functions" ]; then
    echo "❌ Error: supabase/functions directory not found"
    echo "   Please run this script from the SubscribeCoffieBackend directory"
    exit 1
fi

echo ""
echo "📦 Deploying create-payment function..."
supabase functions deploy create-payment --no-verify-jwt

echo ""
echo "📦 Deploying yookassa-webhook function..."
supabase functions deploy yookassa-webhook --no-verify-jwt

echo ""
echo "📦 Deploying stripe-webhook function..."
supabase functions deploy stripe-webhook --no-verify-jwt

echo ""
echo "✅ All payment functions deployed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Set environment variables in Supabase Dashboard:"
echo "   - YOOKASSA_SHOP_ID"
echo "   - YOOKASSA_SECRET_KEY"
echo "   - STRIPE_SECRET_KEY"
echo "   - STRIPE_WEBHOOK_SECRET"
echo ""
echo "2. Configure webhook URLs in payment provider dashboards:"
echo "   YooKassa: https://your-project.supabase.co/functions/v1/yookassa-webhook"
echo "   Stripe:   https://your-project.supabase.co/functions/v1/stripe-webhook"
echo ""
echo "3. Activate payment provider in database:"
echo "   UPDATE payment_provider_config SET is_active = true WHERE provider_name = 'yookassa';"
echo ""
