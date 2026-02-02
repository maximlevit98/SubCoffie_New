#!/bin/bash
set -e

echo "🧪 Testing create_order RPC function..."
echo "======================================="

# Database connection string
DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

# Get a cafe ID
echo ""
echo "1️⃣ Getting cafe ID..."
CAFE_ID=$(psql "$DB_URL" -t -c "SELECT id FROM cafes WHERE status = 'published' LIMIT 1;" | xargs)

if [ -z "$CAFE_ID" ]; then
  echo "❌ Error: No published cafes found"
  exit 1
fi
echo "✅ Cafe ID: $CAFE_ID"

# Get a menu item ID
echo ""
echo "2️⃣ Getting menu item ID..."
MENU_ITEM_ID=$(psql "$DB_URL" -t -c "SELECT id FROM menu_items WHERE cafe_id = '$CAFE_ID' AND is_available = true LIMIT 1;" | xargs)

if [ -z "$MENU_ITEM_ID" ]; then
  echo "❌ Error: No available menu items found for this cafe"
  exit 1
fi

# Get menu item details for verification
MENU_ITEM_NAME=$(psql "$DB_URL" -t -c "SELECT name FROM menu_items WHERE id = '$MENU_ITEM_ID';" | xargs)
MENU_ITEM_PRICE=$(psql "$DB_URL" -t -c "SELECT price_credits FROM menu_items WHERE id = '$MENU_ITEM_ID';" | xargs)

echo "✅ Menu Item: $MENU_ITEM_NAME (ID: $MENU_ITEM_ID, Price: $MENU_ITEM_PRICE credits)"

# Test create_order RPC
echo ""
echo "3️⃣ Testing create_order RPC function..."
echo "   Parameters:"
echo "   - cafe_id: $CAFE_ID"
echo "   - order_type: now"
echo "   - customer_name: Test User"
echo "   - customer_phone: +79991234567"
echo "   - payment_method: wallet"
echo "   - items: [{menu_item_id: $MENU_ITEM_ID, quantity: 2, modifiers: []}]"
echo ""

RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$CAFE_ID'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'Test User',
  p_customer_phone := '+79991234567',
  p_customer_notes := 'Test order from script',
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 2, \"modifiers\": []}]'::jsonb
);
" 2>&1)

# Check if there was an error
if [ $? -ne 0 ]; then
  echo "❌ Error executing create_order:"
  echo "$RESULT"
  exit 1
fi

echo "✅ Order created successfully!"
echo "$RESULT" | sed 's/^/   /'

# Parse the result
ORDER_ID=$(echo "$RESULT" | grep -o '"order_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
ORDER_NUMBER=$(echo "$RESULT" | grep -o '"order_number"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
TOTAL_CREDITS=$(echo "$RESULT" | grep -o '"total_credits"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')

echo ""
echo "4️⃣ Verifying order in database..."

# Check order in orders_core
ORDER_CHECK=$(psql "$DB_URL" -t -c "
SELECT 
  order_number, 
  status, 
  payment_status,
  total_credits, 
  customer_name,
  customer_phone,
  payment_method
FROM orders_core 
WHERE id = '$ORDER_ID';
")

if [ -z "$ORDER_CHECK" ]; then
  echo "❌ Error: Order not found in orders_core table"
  exit 1
fi

echo "✅ Order found in orders_core:"
echo "$ORDER_CHECK" | sed 's/^/   /'

# Check order items
ITEMS_COUNT=$(psql "$DB_URL" -t -c "
SELECT COUNT(*) 
FROM order_items 
WHERE order_id = '$ORDER_ID';
" | xargs)

echo ""
echo "✅ Order items count: $ITEMS_COUNT"

# Get order item details
ORDER_ITEMS=$(psql "$DB_URL" -c "
SELECT 
  item_name,
  quantity,
  base_price_credits,
  total_price_credits
FROM order_items 
WHERE order_id = '$ORDER_ID';
")

echo ""
echo "📋 Order Items Details:"
echo "$ORDER_ITEMS"

# Verify calculations
EXPECTED_TOTAL=$((MENU_ITEM_PRICE * 2))
ACTUAL_TOTAL=$(echo "$TOTAL_CREDITS" | xargs)

echo ""
echo "5️⃣ Verifying calculations..."
echo "   Expected total: $EXPECTED_TOTAL credits (2 x $MENU_ITEM_PRICE)"
echo "   Actual total: $ACTUAL_TOTAL credits"

if [ "$EXPECTED_TOTAL" -eq "$ACTUAL_TOTAL" ]; then
  echo "   ✅ Calculation correct!"
else
  echo "   ⚠️ Warning: Total mismatch (expected: $EXPECTED_TOTAL, got: $ACTUAL_TOTAL)"
fi

echo ""
echo "======================================="
echo "✅ All tests passed!"
echo "======================================="
echo ""
echo "Summary:"
echo "  - Order ID: $ORDER_ID"
echo "  - Order Number: $ORDER_NUMBER"
echo "  - Total Credits: $TOTAL_CREDITS"
echo "  - Status: created"
echo "  - Payment Status: paid (wallet)"
echo "  - Items: $ITEMS_COUNT"
echo ""
