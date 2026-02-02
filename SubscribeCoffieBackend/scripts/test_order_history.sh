#!/bin/bash
# Test script for order history RPC functions

set -e

SUPABASE_URL="http://127.0.0.1:54321"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

echo "🧪 Testing Order History RPC Functions"
echo "========================================"
echo ""

# Test 1: get_user_order_history
echo "📋 Test 1: Fetching order history for demo phone..."
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_user_order_history" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_phone": "+79991234567",
    "p_limit": 10,
    "p_offset": 0
  }')

echo "Response: $RESPONSE"
ORDER_COUNT=$(echo "$RESPONSE" | jq '. | length')
echo "✅ Found $ORDER_COUNT orders"
echo ""

# Test 2: get_order_statistics
echo "📊 Test 2: Fetching order statistics..."
STATS=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_order_statistics" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_phone": "+79991234567"
  }')

echo "Response: $STATS"
TOTAL_ORDERS=$(echo "$STATS" | jq -r '.[0].total_orders // 0')
COMPLETED_ORDERS=$(echo "$STATS" | jq -r '.[0].completed_orders // 0')
TOTAL_SPENT=$(echo "$STATS" | jq -r '.[0].total_spent_credits // 0')
FAVORITE_CAFE=$(echo "$STATS" | jq -r '.[0].favorite_cafe_name // "None"')

echo "✅ Statistics:"
echo "   - Total orders: $TOTAL_ORDERS"
echo "   - Completed orders: $COMPLETED_ORDERS"
echo "   - Total spent: $TOTAL_SPENT credits"
echo "   - Favorite cafe: $FAVORITE_CAFE"
echo ""

# Test 3: Get first order ID for reorder test
if [ "$ORDER_COUNT" -gt "0" ]; then
    FIRST_ORDER_ID=$(echo "$RESPONSE" | jq -r '.[0].order_id')
    
    echo "🔄 Test 3: Testing reorder with order ID: $FIRST_ORDER_ID"
    REORDER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/reorder" \
      -H "apikey: ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -d "{
        \"p_original_order_id\": \"$FIRST_ORDER_ID\"
      }")
    
    echo "Response: $REORDER_RESPONSE"
    NEW_ORDER_ID=$(echo "$REORDER_RESPONSE" | tr -d '"')
    
    if [ ! -z "$NEW_ORDER_ID" ] && [ "$NEW_ORDER_ID" != "null" ]; then
        echo "✅ Reorder successful! New order ID: $NEW_ORDER_ID"
        
        # Test 4: Verify the new order was created
        echo ""
        echo "🔍 Test 4: Fetching details of new order..."
        ORDER_DETAILS=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_order_with_items" \
          -H "apikey: ${ANON_KEY}" \
          -H "Content-Type: application/json" \
          -d "{
            \"p_order_id\": \"$NEW_ORDER_ID\"
          }")
        
        echo "Response: $ORDER_DETAILS"
        NEW_ORDER_STATUS=$(echo "$ORDER_DETAILS" | jq -r '.[0].status // "unknown"')
        NEW_ORDER_ITEMS=$(echo "$ORDER_DETAILS" | jq -r '.[0].items | length')
        
        echo "✅ New order details:"
        echo "   - Status: $NEW_ORDER_STATUS"
        echo "   - Items count: $NEW_ORDER_ITEMS"
    else
        echo "❌ Reorder failed"
    fi
else
    echo "⚠️  Skipping reorder test - no orders found"
fi

echo ""
echo "✅ All tests completed!"
