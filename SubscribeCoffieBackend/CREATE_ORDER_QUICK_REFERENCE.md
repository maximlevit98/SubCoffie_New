# Quick Reference: create_order RPC

## ✅ Status: Verified and Working

## Quick Test

```bash
cd SubscribeCoffieBackend
./test_create_order.sh
```

## Function Signature

```sql
create_order(
  p_cafe_id UUID,           -- Required: ID кофейни
  p_order_type TEXT,        -- Required: 'now' | 'preorder' | 'subscription'
  p_slot_time TIMESTAMPTZ,  -- Optional: время для preorder
  p_customer_name TEXT,     -- Required: имя клиента
  p_customer_phone TEXT,    -- Required: телефон клиента
  p_customer_notes TEXT,    -- Optional: заметки
  p_payment_method TEXT,    -- Required: 'wallet' | 'card'
  p_items JSONB            -- Required: массив позиций
) RETURNS JSONB
```

## Example Usage

### From psql

```sql
SELECT create_order(
  p_cafe_id := 'uuid'::uuid,
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'John Doe',
  p_customer_phone := '+79991234567',
  p_customer_notes := 'Extra hot',
  p_payment_method := 'wallet',
  p_items := '[{
    "menu_item_id": "uuid",
    "quantity": 2,
    "modifiers": []
  }]'::jsonb
);
```

### From iOS (Swift)

```swift
let result = try await supabase.rpc(
    "create_order",
    params: [
        "p_cafe_id": cafeId,
        "p_order_type": "now",
        "p_slot_time": nil,
        "p_customer_name": "John Doe",
        "p_customer_phone": "+79991234567",
        "p_customer_notes": "Extra hot",
        "p_payment_method": "wallet",
        "p_items": [
            [
                "menu_item_id": menuItemId,
                "quantity": 2,
                "modifiers": []
            ]
        ]
    ]
).execute()
```

## Response Format

```json
{
  "order_id": "uuid",
  "order_number": "260202-0006",
  "total_credits": 426,
  "status": "new"
}
```

## Test Files

- `test_create_order.sh` - Basic test
- `test_create_order_comprehensive.sh` - Full test suite (6 tests)

## Documentation

- `CREATE_ORDER_RPC_VERIFICATION.md` - Detailed verification report
- `BACKEND_RPC_VERIFICATION_SUMMARY.md` - Complete summary

## Database Tables

Orders are created in:
- `orders_core` - Main order record
- `order_items` - Order line items

## Validation

The function validates:
- ✅ Cafe exists and is published
- ✅ Menu items exist, belong to cafe, and are available
- ✅ Calculates totals correctly
- ✅ Sets payment_status based on payment_method
  - wallet → paid
  - card → pending

## Error Handling

Throws exceptions for:
- Invalid cafe_id
- Invalid menu_item_id
- Menu item not available
- Menu item from different cafe

## Next Steps (from Plan)

This completes **Phase 2: Backend - Проверка RPC функции** ✅

Next phases:
- Phase 1: iOS - Реальное создание заказа
- Phase 3: Admin - Расширение queries для заказов
- Phase 4: Admin - Обновление страницы заказов
- Phase 5: Admin - Dashboard с метриками
- Phase 6: E2E тест
