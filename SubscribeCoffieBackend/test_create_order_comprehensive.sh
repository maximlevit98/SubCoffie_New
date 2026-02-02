#!/bin/bash
# Note: not using set -e to see all test results even if some fail

echo "🧪 Comprehensive create_order RPC Tests"
echo "=========================================="

DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

# Get test data
CAFE_ID=$(psql "$DB_URL" -t -c "SELECT id FROM cafes WHERE status = 'published' LIMIT 1;" | xargs)
MENU_ITEM_ID=$(psql "$DB_URL" -t -c "SELECT id FROM menu_items WHERE cafe_id = '$CAFE_ID' AND is_available = true LIMIT 1;" | xargs)

echo "Test Data:"
echo "  Cafe ID: $CAFE_ID"
echo "  Menu Item ID: $MENU_ITEM_ID"
echo ""

# Test 1: Standard order with "now" type
echo "Test 1: Standard order (type: now, payment: wallet)"
echo "---------------------------------------------------"
RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$CAFE_ID'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'John Doe',
  p_customer_phone := '+79991111111',
  p_customer_notes := 'No sugar, please',
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 1, \"modifiers\": []}]'::jsonb
);
" 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Test 1 PASSED"
  ORDER_ID=$(echo "$RESULT" | grep -o '"order_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  echo "   Order ID: $ORDER_ID"
else
  echo "❌ Test 1 FAILED: $RESULT"
fi
echo ""

# Test 2: Order with multiple items
echo "Test 2: Order with multiple quantities"
echo "--------------------------------------"
RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$CAFE_ID'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'Jane Smith',
  p_customer_phone := '+79992222222',
  p_customer_notes := NULL,
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 5, \"modifiers\": []}]'::jsonb
);
" 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Test 2 PASSED"
  ORDER_ID=$(echo "$RESULT" | grep -o '"order_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  TOTAL=$(echo "$RESULT" | grep -o '"total_credits"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
  echo "   Order ID: $ORDER_ID"
  echo "   Total: $TOTAL credits"
else
  echo "❌ Test 2 FAILED: $RESULT"
fi
echo ""

# Test 3: Order with card payment
echo "Test 3: Order with card payment method"
echo "--------------------------------------"
RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$CAFE_ID'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'Alice Brown',
  p_customer_phone := '+79993333333',
  p_customer_notes := 'Pay at pickup',
  p_payment_method := 'card',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 1, \"modifiers\": []}]'::jsonb
);
" 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Test 3 PASSED"
  ORDER_ID=$(echo "$RESULT" | grep -o '"order_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  echo "   Order ID: $ORDER_ID"
  
  # Verify payment_status is 'pending' for card
  PAYMENT_STATUS=$(psql "$DB_URL" -t -c "SELECT payment_status FROM orders_core WHERE id = '$ORDER_ID';" | xargs)
  if [ "$PAYMENT_STATUS" = "pending" ]; then
    echo "   ✅ Payment status correctly set to 'pending' for card payment"
  else
    echo "   ⚠️ Payment status: $PAYMENT_STATUS (expected: pending)"
  fi
else
  echo "❌ Test 3 FAILED: $RESULT"
fi
echo ""

# Test 4: Pre-order with slot_time
echo "Test 4: Pre-order with slot_time"
echo "--------------------------------"
SLOT_TIME=$(psql "$DB_URL" -t -c "SELECT (NOW() + INTERVAL '2 hours')::timestamptz;" | xargs)
RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$CAFE_ID'::uuid,
  p_order_type := 'preorder',
  p_slot_time := '$SLOT_TIME'::timestamptz,
  p_customer_name := 'Bob Wilson',
  p_customer_phone := '+79994444444',
  p_customer_notes := 'Pick up at 2pm',
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 2, \"modifiers\": []}]'::jsonb
);
" 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Test 4 PASSED"
  ORDER_ID=$(echo "$RESULT" | grep -o '"order_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  echo "   Order ID: $ORDER_ID"
  echo "   Slot time: $SLOT_TIME"
else
  echo "❌ Test 4 FAILED: $RESULT"
fi
echo ""

# Test 5: Error case - invalid cafe ID
echo "Test 5: Error handling - invalid cafe ID"
echo "----------------------------------------"
INVALID_CAFE="00000000-0000-0000-0000-000000000000"
RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$INVALID_CAFE'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'Test',
  p_customer_phone := '+79995555555',
  p_customer_notes := NULL,
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 1, \"modifiers\": []}]'::jsonb
);
" 2>&1)

if echo "$RESULT" | grep -q "не найдена"; then
  echo "✅ Test 5 PASSED - Error correctly thrown for invalid cafe"
else
  echo "❌ Test 5 FAILED - Should have thrown error for invalid cafe"
fi
echo ""

# Test 6: Error case - invalid menu item
echo "Test 6: Error handling - invalid menu item"
echo "------------------------------------------"
INVALID_ITEM="00000000-0000-0000-0000-000000000000"
RESULT=$(psql "$DB_URL" -t -c "
SELECT create_order(
  p_cafe_id := '$CAFE_ID'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'Test',
  p_customer_phone := '+79996666666',
  p_customer_notes := NULL,
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$INVALID_ITEM\", \"quantity\": 1, \"modifiers\": []}]'::jsonb
);
" 2>&1)

if echo "$RESULT" | grep -q "не найдена"; then
  echo "✅ Test 6 PASSED - Error correctly thrown for invalid menu item"
else
  echo "❌ Test 6 FAILED - Should have thrown error for invalid menu item"
fi
echo ""

# Summary
echo "=========================================="
echo "📊 Test Summary"
echo "=========================================="

# Count orders created in this test run
RECENT_ORDERS=$(psql "$DB_URL" -t -c "
SELECT COUNT(*) FROM orders_core 
WHERE created_at > NOW() - INTERVAL '1 minute';
" | xargs)

echo "Orders created: $RECENT_ORDERS"
echo ""

# Show recent orders
echo "Recent orders:"
psql "$DB_URL" -c "
SELECT 
  order_number,
  order_type,
  customer_name,
  payment_method,
  payment_status,
  total_credits,
  status
FROM orders_core 
WHERE created_at > NOW() - INTERVAL '1 minute'
ORDER BY created_at DESC;
"

echo ""
echo "✅ Comprehensive testing complete!"
