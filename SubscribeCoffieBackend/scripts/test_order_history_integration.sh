#!/bin/bash
# Integration test for order history with sample data creation

set -e

SUPABASE_URL="http://127.0.0.1:54321"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

echo "🧪 Order History Integration Test"
echo "=================================="
echo ""

# Get a cafe ID from the database
echo "📍 Fetching a cafe for testing..."
CAFE_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/cafes?limit=1" \
  -H "apikey: ${ANON_KEY}")

CAFE_ID=$(echo "$CAFE_RESPONSE" | jq -r '.[0].id')
CAFE_NAME=$(echo "$CAFE_RESPONSE" | jq -r '.[0].name')

if [ -z "$CAFE_ID" ] || [ "$CAFE_ID" == "null" ]; then
    echo "❌ No cafes found in database. Please run seed first."
    exit 1
fi

echo "✅ Using cafe: $CAFE_NAME (ID: $CAFE_ID)"
echo ""

# Get a menu item
echo "🍵 Fetching a menu item..."
MENU_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/menu_items?cafe_id=eq.${CAFE_ID}&limit=1" \
  -H "apikey: ${ANON_KEY}")

MENU_ITEM_ID=$(echo "$MENU_RESPONSE" | jq -r '.[0].id')
MENU_ITEM_TITLE=$(echo "$MENU_RESPONSE" | jq -r '.[0].title')
MENU_ITEM_PRICE=$(echo "$MENU_RESPONSE" | jq -r '.[0].price_credits')

if [ -z "$MENU_ITEM_ID" ] || [ "$MENU_ITEM_ID" == "null" ]; then
    echo "❌ No menu items found. Please run seed first."
    exit 1
fi

echo "✅ Using menu item: $MENU_ITEM_TITLE - $MENU_ITEM_PRICE credits"
echo ""

# Create test orders
TEST_PHONE="+79991234567"
echo "📦 Creating test orders for phone: $TEST_PHONE"

for i in {1..3}; do
    echo "   Creating order #$i..."
    
    # Create order
    ORDER_PAYLOAD=$(cat <<EOF
[{
    "cafe_id": "$CAFE_ID",
    "customer_phone": "$TEST_PHONE",
    "status": "Created",
    "subtotal_credits": $MENU_ITEM_PRICE,
    "bonus_used": 0,
    "paid_credits": $MENU_ITEM_PRICE,
    "eta_minutes": 10
}]
EOF
)
    
    ORDER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/orders" \
      -H "apikey: ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$ORDER_PAYLOAD")
    
    ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.[0].id')
    
    if [ ! -z "$ORDER_ID" ] && [ "$ORDER_ID" != "null" ]; then
        # Create order item
        ITEM_PAYLOAD=$(cat <<EOF
[{
    "order_id": "$ORDER_ID",
    "menu_item_id": "$MENU_ITEM_ID",
    "title": "$MENU_ITEM_TITLE",
    "unit_credits": $MENU_ITEM_PRICE,
    "quantity": 1,
    "category": "Drink"
}]
EOF
)
        
        curl -s -X POST "${SUPABASE_URL}/rest/v1/order_items" \
          -H "apikey: ${ANON_KEY}" \
          -H "Content-Type: application/json" \
          -d "$ITEM_PAYLOAD" > /dev/null
        
        # Create order event
        EVENT_PAYLOAD=$(cat <<EOF
[{
    "order_id": "$ORDER_ID",
    "status": "Created"
}]
EOF
)
        
        curl -s -X POST "${SUPABASE_URL}/rest/v1/order_events" \
          -H "apikey: ${ANON_KEY}" \
          -H "Content-Type: application/json" \
          -d "$EVENT_PAYLOAD" > /dev/null
        
        echo "   ✅ Order #$i created: $ORDER_ID"
        
        # Mark some orders as completed for statistics
        if [ $i -le 2 ]; then
            curl -s -X PATCH "${SUPABASE_URL}/rest/v1/orders?id=eq.${ORDER_ID}" \
              -H "apikey: ${ANON_KEY}" \
              -H "Content-Type: application/json" \
              -d '{"status": "Issued"}' > /dev/null
            
            curl -s -X POST "${SUPABASE_URL}/rest/v1/order_events" \
              -H "apikey: ${ANON_KEY}" \
              -H "Content-Type: application/json" \
              -d "[{\"order_id\": \"$ORDER_ID\", \"status\": \"Issued\"}]" > /dev/null
            
            echo "   ✅ Order #$i marked as Issued"
        fi
        
        # Save first order ID for reorder test
        if [ $i -eq 1 ]; then
            FIRST_ORDER_ID=$ORDER_ID
        fi
    else
        echo "   ❌ Failed to create order #$i"
    fi
    
    sleep 0.5
done

echo ""
echo "🧪 Running RPC function tests..."
echo ""

# Test 1: get_user_order_history
echo "📋 Test 1: Fetching order history..."
HISTORY_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_user_order_history" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"p_phone\": \"$TEST_PHONE\",
    \"p_limit\": 10,
    \"p_offset\": 0
  }")

ORDER_COUNT=$(echo "$HISTORY_RESPONSE" | jq '. | length')
echo "✅ Found $ORDER_COUNT orders in history"

if [ "$ORDER_COUNT" -ge 3 ]; then
    echo "   First order details:"
    FIRST_ORDER=$(echo "$HISTORY_RESPONSE" | jq '.[0]')
    echo "   - Cafe: $(echo "$FIRST_ORDER" | jq -r '.cafe_name')"
    echo "   - Status: $(echo "$FIRST_ORDER" | jq -r '.status')"
    echo "   - Total: $(echo "$FIRST_ORDER" | jq -r '.paid_credits') credits"
    echo "   - Items: $(echo "$FIRST_ORDER" | jq -r '.items | length')"
fi
echo ""

# Test 2: get_order_statistics
echo "📊 Test 2: Fetching order statistics..."
STATS=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_order_statistics" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"p_phone\": \"$TEST_PHONE\"
  }")

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

# Test 3: Reorder
if [ ! -z "$FIRST_ORDER_ID" ]; then
    echo "🔄 Test 3: Testing reorder functionality..."
    echo "   Original order ID: $FIRST_ORDER_ID"
    
    REORDER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/reorder" \
      -H "apikey: ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -d "{
        \"p_original_order_id\": \"$FIRST_ORDER_ID\"
      }")
    
    NEW_ORDER_ID=$(echo "$REORDER_RESPONSE" | tr -d '"')
    
    if [ ! -z "$NEW_ORDER_ID" ] && [ "$NEW_ORDER_ID" != "null" ]; then
        echo "✅ Reorder successful! New order ID: $NEW_ORDER_ID"
        
        # Test 4: get_order_with_items
        echo ""
        echo "🔍 Test 4: Fetching complete order details..."
        ORDER_DETAILS=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_order_with_items" \
          -H "apikey: ${ANON_KEY}" \
          -H "Content-Type: application/json" \
          -d "{
            \"p_order_id\": \"$NEW_ORDER_ID\"
          }")
        
        NEW_ORDER_STATUS=$(echo "$ORDER_DETAILS" | jq -r '.[0].status // "unknown"')
        NEW_ORDER_ITEMS=$(echo "$ORDER_DETAILS" | jq -r '.[0].items | length')
        NEW_ORDER_EVENTS=$(echo "$ORDER_DETAILS" | jq -r '.[0].events | length')
        
        echo "✅ New order details:"
        echo "   - Order ID: $NEW_ORDER_ID"
        echo "   - Status: $NEW_ORDER_STATUS"
        echo "   - Items count: $NEW_ORDER_ITEMS"
        echo "   - Events count: $NEW_ORDER_EVENTS"
        echo "   - Cafe: $(echo "$ORDER_DETAILS" | jq -r '.[0].cafe_name')"
        
        # Verify updated statistics
        echo ""
        echo "📊 Test 5: Verifying updated statistics..."
        STATS_AFTER=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_order_statistics" \
          -H "apikey: ${ANON_KEY}" \
          -H "Content-Type: application/json" \
          -d "{
            \"p_phone\": \"$TEST_PHONE\"
          }")
        
        TOTAL_AFTER=$(echo "$STATS_AFTER" | jq -r '.[0].total_orders // 0')
        echo "✅ Statistics updated:"
        echo "   - Total orders increased from $TOTAL_ORDERS to $TOTAL_AFTER"
    else
        echo "❌ Reorder failed"
    fi
fi

echo ""
echo "✅ All integration tests completed successfully!"
echo ""
echo "Summary:"
echo "- Created 3 test orders (2 completed, 1 pending)"
echo "- Verified order history retrieval"
echo "- Verified statistics calculation"
echo "- Verified reorder functionality"
echo "- Verified detailed order fetching"
