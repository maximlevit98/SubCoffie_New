---
name: iOS to Admin Orders Integration
overview: Пошаговая интеграция заказов от iOS до админ-панели с тестированием после каждого шага для гарантии работоспособности сборки.
todos:
  - id: todo-1770028738435-sripyaanr
    content: "Backend: Создать таблицу order_items + тест"
    status: completed
---

# План: iOS Checkout → Admin Orders (с тестированием)

## Стратегия: Incremental Build + Test

После КАЖДОГО шага запускаем проверки:

- Backend: применяем миграцию + проверяем SQL
- iOS: xcodebuild (компиляция)
- Admin: TypeScript check + lint

Это гарантирует, что на каждом этапе проект компилируется без ошибок.

---

## Фаза 1: Backend - Таблица Orders

### Шаг 1.1: Создать миграцию для таблицы orders

**Файлы:**

- `SubscribeCoffieBackend/supabase/migrations/20260201000001_create_orders_table.sql`

**Содержимое:**

```sql
-- Таблица заказов
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cafe_id UUID NOT NULL REFERENCES public.cafes(id) ON DELETE CASCADE,
  customer_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Номер и тип заказа
  order_number TEXT NOT NULL UNIQUE,
  order_type TEXT NOT NULL CHECK (order_type IN ('now', 'preorder', 'subscription')),
  slot_time TIMESTAMPTZ,
  
  -- Статус
  status TEXT NOT NULL DEFAULT 'new' CHECK (
    status IN ('new', 'accepted', 'preparing', 'ready', 'issued', 'cancelled')
  ),
  cancel_reason TEXT,
  cancel_comment TEXT,
  
  -- Финансы
  subtotal_credits INT NOT NULL,
  delivery_fee_credits INT DEFAULT 0,
  discount_credits INT DEFAULT 0,
  total_credits INT NOT NULL,
  
  -- Оплата
  payment_method TEXT NOT NULL CHECK (
    payment_method IN ('wallet', 'card', 'cash', 'subscription')
  ),
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    payment_status IN ('pending', 'paid', 'failed', 'refunded')
  ),
  payment_transaction_id UUID,
  
  -- Клиент
  customer_name TEXT,
  customer_phone TEXT,
  customer_notes TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  preparing_at TIMESTAMPTZ,
  ready_at TIMESTAMPTZ,
  issued_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ
);

-- Индексы
CREATE INDEX idx_orders_cafe_id ON public.orders(cafe_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_customer ON public.orders(customer_user_id);
CREATE INDEX idx_orders_created_at ON public.orders(created_at DESC);

-- Комментарии
COMMENT ON TABLE public.orders IS 'Заказы от клиентов';
COMMENT ON COLUMN public.orders.status IS 'Статусы: new → accepted → preparing → ready → issued / cancelled';
```

**Тест после шага:**

```bash
cd SubscribeCoffieBackend
supabase db reset
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "\d orders"
# Должна показаться структура таблицы без ошибок
```

---

### Шаг 1.2: Создать миграцию для таблицы order_items

**Файлы:**

- `SubscribeCoffieBackend/supabase/migrations/20260201000002_create_order_items_table.sql`

**Содержимое:**

```sql
-- Таблица позиций заказа
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE RESTRICT,
  
  -- Снимок на момент заказа
  item_name TEXT NOT NULL,
  base_price_credits INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  
  -- Модификаторы (JSON)
  modifiers JSONB DEFAULT '[]'::jsonb,
  
  total_price_credits INT NOT NULL,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_order_items_menu_item ON public.order_items(menu_item_id);

-- Комментарии
COMMENT ON TABLE public.order_items IS 'Позиции заказов';
COMMENT ON COLUMN public.order_items.modifiers IS 'JSON массив модификаторов: [{"group": "Объём", "name": "Большой", "price": 30}]';
```

**Тест после шага:**

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "\d order_items"
# Должна показаться структура таблицы
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT * FROM orders LIMIT 1"
# Должен вернуть 0 rows (таблица пустая, но работает)
```

---

### Шаг 1.3: Добавить функцию генерации номера заказа

**Файлы:**

- `SubscribeCoffieBackend/supabase/migrations/20260201000003_add_order_number_generator.sql`

**Содержимое:**

```sql
-- Функция генерации номера заказа
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
  new_number TEXT;
  date_part TEXT;
  sequence_part INT;
BEGIN
  -- Формат: YYMMDD-XXXX (например: 260201-0001)
  date_part := TO_CHAR(NOW(), 'YYMMDD');
  
  -- Получить последний номер за сегодня
  SELECT COALESCE(
    MAX(CAST(SPLIT_PART(order_number, '-', 2) AS INT)), 
    0
  ) + 1 INTO sequence_part
  FROM public.orders
  WHERE order_number LIKE date_part || '-%';
  
  new_number := date_part || '-' || LPAD(sequence_part::TEXT, 4, '0');
  RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автогенерации номера
CREATE OR REPLACE FUNCTION set_order_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_number IS NULL THEN
    NEW.order_number := generate_order_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_order_number
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION set_order_number();

-- Триггер для updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
```

**Тест после шага:**

```bash
# Тест функции генерации номера
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT generate_order_number();"
# Должен вернуть: 260201-0001

# Тест триггера
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
INSERT INTO orders (cafe_id, order_type, subtotal_credits, total_credits, payment_method, order_number)
VALUES ('e2bcac65-e503-416e-a428-97b4712d270b', 'now', 100, 100, 'wallet', NULL)
RETURNING order_number;
"
# Должен автоматически сгенерировать номер
```

---

### Шаг 1.4: Добавить RLS политики для orders

**Файлы:**

- `SubscribeCoffieBackend/supabase/migrations/20260201000004_add_orders_rls.sql`

**Содержимое:**

```sql
-- RLS для orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Owner может видеть заказы своих кофеен
CREATE POLICY owner_view_orders ON public.orders
  FOR SELECT USING (
    cafe_id IN (
      SELECT c.id FROM public.cafes c
      JOIN public.accounts a ON c.account_id = a.id
      WHERE a.owner_user_id = auth.uid()
    )
  );

-- Owner может обновлять заказы своих кофеен
CREATE POLICY owner_update_orders ON public.orders
  FOR UPDATE USING (
    cafe_id IN (
      SELECT c.id FROM public.cafes c
      JOIN public.accounts a ON c.account_id = a.id
      WHERE a.owner_user_id = auth.uid()
    )
  );

-- Клиенты могут создавать заказы
CREATE POLICY customer_create_orders ON public.orders
  FOR INSERT WITH CHECK (
    customer_user_id = auth.uid() OR
    auth.jwt()->>'role' = 'service_role'
  );

-- Order items - view/insert для своих заказов
CREATE POLICY owner_view_order_items ON public.order_items
  FOR SELECT USING (
    order_id IN (
      SELECT o.id FROM public.orders o
      JOIN public.cafes c ON o.cafe_id = c.id
      JOIN public.accounts a ON c.account_id = a.id
      WHERE a.owner_user_id = auth.uid()
    )
  );

CREATE POLICY customer_create_order_items ON public.order_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE id = order_id
      AND (customer_user_id = auth.uid() OR auth.jwt()->>'role' = 'service_role')
    )
  );
```

**Тест после шага:**

```bash
# Проверить что RLS включен
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('orders', 'order_items');
"
# Должен показать rowsecurity = t (true)

# Проверить политики
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('orders', 'order_items');
"
# Должен показать список политик
```

---

### Шаг 1.5: Создать RPC функцию для создания заказа

**Файлы:**

- `SubscribeCoffieBackend/supabase/migrations/20260201000005_create_order_rpc.sql`

**Содержимое:**

```sql
-- RPC функция для создания заказа
CREATE OR REPLACE FUNCTION create_order(
  p_cafe_id UUID,
  p_order_type TEXT,
  p_slot_time TIMESTAMPTZ,
  p_customer_name TEXT,
  p_customer_phone TEXT,
  p_customer_notes TEXT,
  p_payment_method TEXT,
  p_items JSONB
)
RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_subtotal INT := 0;
  v_item JSONB;
  v_menu_item RECORD;
  v_item_price INT;
  v_modifier JSONB;
  v_order_number TEXT;
BEGIN
  -- Валидация кофейни
  IF NOT EXISTS (SELECT 1 FROM public.cafes WHERE id = p_cafe_id AND status = 'published') THEN
    RAISE EXCEPTION 'Кофейня не найдена или не опубликована';
  END IF;

  -- Создать заказ
  INSERT INTO public.orders (
    cafe_id,
    customer_user_id,
    order_type,
    slot_time,
    customer_name,
    customer_phone,
    customer_notes,
    payment_method,
    status,
    payment_status,
    subtotal_credits,
    total_credits
  ) VALUES (
    p_cafe_id,
    auth.uid(),
    p_order_type,
    p_slot_time,
    p_customer_name,
    p_customer_phone,
    p_customer_notes,
    p_payment_method,
    'new',
    CASE WHEN p_payment_method = 'wallet' THEN 'paid' ELSE 'pending' END,
    0,
    0
  )
  RETURNING id, order_number INTO v_order_id, v_order_number;

  -- Добавить позиции заказа
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Получить информацию о позиции меню
    SELECT * INTO v_menu_item
    FROM public.menu_items
    WHERE id = (v_item->>'menu_item_id')::UUID
      AND cafe_id = p_cafe_id
      AND is_available = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Позиция меню % не найдена или недоступна', v_item->>'menu_item_id';
    END IF;

    -- Рассчитать цену с модификаторами
    v_item_price := v_menu_item.price_credits;
    
    IF v_item->'modifiers' IS NOT NULL THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers')
      LOOP
        v_item_price := v_item_price + COALESCE((v_modifier->>'price')::INT, 0);
      END LOOP;
    END IF;

    v_item_price := v_item_price * (v_item->>'quantity')::INT;

    -- Добавить order_item
    INSERT INTO public.order_items (
      order_id,
      menu_item_id,
      item_name,
      base_price_credits,
      quantity,
      modifiers,
      total_price_credits
    ) VALUES (
      v_order_id,
      v_menu_item.id,
      v_menu_item.name,
      v_menu_item.price_credits,
      (v_item->>'quantity')::INT,
      COALESCE(v_item->'modifiers', '[]'::jsonb),
      v_item_price
    );

    v_subtotal := v_subtotal + v_item_price;
  END LOOP;

  -- Обновить сумму заказа
  UPDATE public.orders
  SET 
    subtotal_credits = v_subtotal,
    total_credits = v_subtotal
  WHERE id = v_order_id;

  -- Вернуть результат
  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'total_credits', v_subtotal,
    'status', 'new'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Права на выполнение
GRANT EXECUTE ON FUNCTION create_order TO authenticated;
GRANT EXECUTE ON FUNCTION create_order TO anon;
```

**Тест после шага:**

```bash
# Получить ID позиции меню
MENU_ITEM_ID=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT id FROM menu_items LIMIT 1;")

# Тест RPC функции
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT create_order(
  p_cafe_id := 'e2bcac65-e503-416e-a428-97b4712d270b',
  p_order_type := 'now',
  p_slot_time := NULL,
  p_customer_name := 'Test User',
  p_customer_phone := '+79991234567',
  p_customer_notes := 'Test order',
  p_payment_method := 'wallet',
  p_items := '[{\"menu_item_id\": \"$MENU_ITEM_ID\", \"quantity\": 1, \"modifiers\": []}]'::jsonb
);
"
# Должен вернуть JSON с order_id, order_number, total_credits
```

---

## Фаза 2: iOS - Интеграция создания заказа

### Шаг 2.1: Создать модели для заказа

**Файлы:**

- `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Models/Order.swift`

**Содержимое:**

```swift
import Foundation

struct CreateOrderRequest: Encodable {
    let cafe_id: UUID
    let order_type: String
    let slot_time: Date?
    let customer_name: String
    let customer_phone: String
    let customer_notes: String?
    let payment_method: String
    let items: [OrderItemRequest]
}

struct OrderItemRequest: Encodable {
    let menu_item_id: UUID
    let quantity: Int
    let modifiers: [OrderModifier]
}

struct OrderModifier: Encodable {
    let group: String
    let name: String
    let price: Int
}

struct CreateOrderResponse: Decodable {
    let order_id: UUID
    let order_number: String
    let total_credits: Int
    let status: String
}

struct Order: Identifiable, Codable {
    let id: UUID
    let order_number: String
    let status: String
    let total_credits: Int
    let created_at: Date
}
```

**Тест после шага:**

```bash
cd SubscribeCoffieClean
xcodebuild -scheme SubscribeCoffieClean -sdk iphonesimulator -configuration Debug build | grep -E "(error|warning:|BUILD)"
# Должно закончиться: BUILD SUCCEEDED
```

---

### Шаг 2.2: Создать OrderService для iOS

**Файлы:**

- `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Helpers/OrderServiceStub.swift`

**Содержимое:**

```swift
import Foundation
import Supabase

@MainActor
class OrderServiceStub: ObservableObject {
    static let shared = OrderServiceStub()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    func createOrder(
        cafeId: UUID,
        items: [(id: UUID, name: String, quantity: Int, price: Int)],
        paymentMethod: String,
        customerNotes: String?
    ) async throws -> CreateOrderResponse {
        isLoading = true
        defer { isLoading = false }
        
        // Подготовить items для API
        let orderItems = items.map { item in
            OrderItemRequest(
                menu_item_id: item.id,
                quantity: item.quantity,
                modifiers: []
            )
        }
        
        let request = CreateOrderRequest(
            cafe_id: cafeId,
            order_type: "now",
            slot_time: nil,
            customer_name: "Test User",
            customer_phone: "+79991234567",
            customer_notes: customerNotes,
            payment_method: paymentMethod,
            items: orderItems
        )
        
        do {
            // Кодируем в JSON
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let jsonData = try encoder.encode(request)
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            
            // Вызываем RPC
            let response = try await SupabaseClientProvider.client
                .rpc("create_order", params: jsonObject)
                .execute()
            
            // Декодируем ответ
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(CreateOrderResponse.self, from: response.data)
            
            AppLogger.debug("Order created: \(result.order_number)")
            
            return result
            
        } catch {
            AppLogger.error("Failed to create order: \(error)")
            lastError = error.localizedDescription
            throw error
        }
    }
}
```

**Тест после шага:**

```bash
xcodebuild -scheme SubscribeCoffieClean -sdk iphonesimulator -configuration Debug build | grep -E "(error|warning:|BUILD)"
# Должно закончиться: BUILD SUCCEEDED
```

---

### Шаг 2.3: Интегрировать в ContentView

**Файлы:**

- `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/ContentView.swift`

**Изменения:**

Добавить вызов OrderService в блоке checkout:

```swift
// Найти блок с orderService.createOrder
// Обновить его вызов:

Button("Оформить заказ") {
    Task {
        do {
            // Подготовить items из корзины
            let items = cartStore.lines.map { line in
                (
                    id: line.product.id,
                    name: line.product.name,
                    quantity: line.quantity,
                    price: line.product.priceCredits
                )
            }
            
            let order = try await OrderServiceStub.shared.createOrder(
                cafeId: cafeStore.currentCafe!.id,
                items: items,
                paymentMethod: "wallet",
                customerNotes: nil
            )
            
            AppLogger.debug("Order created: \(order.order_number)")
            
            // Очистить корзину
            cartStore.clear()
            
            // Показать успех
            showOrderSuccess = true
            
        } catch {
            AppLogger.error("Order failed: \(error)")
        }
    }
}
```

**Тест после шага:**

```bash
# Полная сборка
xcodebuild -scheme SubscribeCoffieClean -sdk iphonesimulator -configuration Debug build

# Запустить симулятор
./run-simulator.sh

# МАНУАЛЬНЫЙ ТЕСТ:
# 1. Открыть кофейню
# 2. Добавить позиции в корзину
# 3. Нажать "Оформить заказ"
# 4. Проверить в консоли: "Order created: 260201-XXXX"
```

---

## Фаза 3: Admin Panel - Queries для заказов

### Шаг 3.1: Создать queries/orders.ts

**Файлы:**

- `subscribecoffie-admin/lib/supabase/queries/orders.ts`

**Содержимое:**

```typescript
import { createAdminClient } from "../admin";

export type OrderRecord = {
  id: string;
  cafe_id: string;
  order_number: string;
  order_type: 'now' | 'preorder' | 'subscription';
  status: 'new' | 'accepted' | 'preparing' | 'ready' | 'issued' | 'cancelled';
  payment_status: 'pending' | 'paid' | 'failed' | 'refunded';
  payment_method: 'wallet' | 'card' | 'cash' | 'subscription';
  
  customer_name: string | null;
  customer_phone: string | null;
  customer_notes: string | null;
  
  subtotal_credits: number;
  total_credits: number;
  
  created_at: string;
  slot_time: string | null;
  
  order_items?: OrderItemRecord[];
};

export type OrderItemRecord = {
  id: string;
  item_name: string;
  quantity: number;
  base_price_credits: number;
  total_price_credits: number;
  modifiers: Array<{
    group: string;
    name: string;
    price: number;
  }>;
};

export async function listOrders(
  cafeId: string,
  status?: string
): Promise<{
  data: OrderRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  let query = supabase
    .from("orders")
    .select(`
      *,
      order_items (*)
    `)
    .eq("cafe_id", cafeId)
    .order("created_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as OrderRecord[] };
}

export async function getOrderById(
  orderId: string
): Promise<{
  data: OrderRecord | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase
    .from("orders")
    .select(`
      *,
      order_items (*)
    `)
    .eq("id", orderId)
    .single();

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as OrderRecord };
}
```

**Тест после шага:**

```bash
cd subscribecoffie-admin
npx tsc --noEmit
# Не должно быть ошибок TypeScript
```

---

### Шаг 3.2: Создать actions.ts для обновления статуса

**Файлы:**

- `subscribecoffie-admin/app/admin/cafes/[id]/orders/actions.ts`

**Содержимое:**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { createAdminClient } from "@/lib/supabase/admin";

export async function updateOrderStatus(formData: FormData) {
  const orderId = formData.get("order_id") as string;
  const newStatus = formData.get("status") as string;

  if (!orderId || !newStatus) {
    throw new Error("Missing order_id or status");
  }

  const supabase = createAdminClient();

  // Подготовить данные для обновления
  const updateData: any = { 
    status: newStatus,
    updated_at: new Date().toISOString()
  };

  // Добавить timestamp для нового статуса
  if (newStatus === 'accepted') {
    updateData.accepted_at = new Date().toISOString();
  } else if (newStatus === 'preparing') {
    updateData.preparing_at = new Date().toISOString();
  } else if (newStatus === 'ready') {
    updateData.ready_at = new Date().toISOString();
  } else if (newStatus === 'issued') {
    updateData.issued_at = new Date().toISOString();
  } else if (newStatus === 'cancelled') {
    updateData.cancelled_at = new Date().toISOString();
  }

  const { error } = await supabase
    .from("orders")
    .update(updateData)
    .eq("id", orderId);

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/admin/cafes");
}
```

**Тест после шага:**

```bash
npx tsc --noEmit
npx eslint app/admin/cafes/\[id\]/orders/actions.ts
# Не должно быть ошибок
```

---

### Шаг 3.3: Создать страницу списка заказов

**Файлы:**

- `subscribecoffie-admin/app/admin/cafes/[id]/orders/page.tsx`

**Содержимое:**

```typescript
import Link from "next/link";
import { listOrders } from "@/lib/supabase/queries/orders";

type OrdersPageProps = {
  params: Promise<{ id: string }>;
};

export default async function OrdersPage({ params }: OrdersPageProps) {
  const { id: cafeId } = await params;
  const { data: orders, error } = await listOrders(cafeId);

  if (error) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Заказы</h2>
        <div className="rounded border border-red-200 bg-red-50 p-4">
          <p className="text-sm text-red-700">
            Ошибка загрузки заказов: {error}
          </p>
        </div>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Заказы</h2>
          <p className="text-sm text-zinc-600">
            Всего заказов: {orders?.length || 0}
          </p>
        </div>
        <Link
          href={`/admin/cafes/${cafeId}`}
          className="rounded border border-zinc-300 px-4 py-2 text-sm hover:bg-zinc-50"
        >
          ← К кофейне
        </Link>
      </div>

      {/* Список заказов (простая таблица для начала) */}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50">
            <tr>
              <th className="px-4 py-3 font-medium">Номер</th>
              <th className="px-4 py-3 font-medium">Время</th>
              <th className="px-4 py-3 font-medium">Клиент</th>
              <th className="px-4 py-3 font-medium">Позиции</th>
              <th className="px-4 py-3 font-medium">Сумма</th>
              <th className="px-4 py-3 font-medium">Статус</th>
              <th className="px-4 py-3 font-medium">Оплата</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {orders && orders.length > 0 ? (
              orders.map((order) => (
                <tr key={order.id} className="text-zinc-700 hover:bg-zinc-50">
                  <td className="px-4 py-3 font-mono text-xs">
                    {order.order_number}
                  </td>
                  <td className="px-4 py-3 text-xs">
                    {new Date(order.created_at).toLocaleString('ru-RU')}
                  </td>
                  <td className="px-4 py-3">
                    <div>
                      <div className="font-medium">{order.customer_name || 'Гость'}</div>
                      {order.customer_phone && (
                        <div className="text-xs text-zinc-500">{order.customer_phone}</div>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-xs">
                    {order.order_items?.map(item => 
                      `${item.item_name} x${item.quantity}`
                    ).join(', ')}
                  </td>
                  <td className="px-4 py-3 font-semibold">
                    {order.total_credits} ₽
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded px-2 py-1 text-xs font-medium ${
                      order.status === 'new' ? 'bg-blue-100 text-blue-800' :
                      order.status === 'accepted' ? 'bg-yellow-100 text-yellow-800' :
                      order.status === 'preparing' ? 'bg-orange-100 text-orange-800' :
                      order.status === 'ready' ? 'bg-green-100 text-green-800' :
                      order.status === 'issued' ? 'bg-gray-100 text-gray-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded px-2 py-1 text-xs ${
                      order.payment_status === 'paid' ? 'bg-green-100 text-green-800' :
                      order.payment_status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {order.payment_method}
                    </span>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-sm text-zinc-500">
                  Заказов пока нет
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
```

**Тест после шага:**

```bash
npx tsc --noEmit
npx next build --no-lint
# Должно пройти без ошибок

# Запустить dev server
npm run dev

# Открыть страницу заказов
open http://localhost:3000/admin/cafes/e2bcac65-e503-416e-a428-97b4712d270b/orders
```

---

### Шаг 3.4: Добавить ссылку на заказы в кофейне

**Файлы:**

- `subscribecoffie-admin/app/admin/cafes/[id]/page.tsx`

**Изменения:**

Добавить кнопку "Заказы" в шапку страницы редактирования кофейни:

```typescript
<div className="flex items-center gap-3">
  <Link
    href={`/admin/menu-items?cafe_id=${data.id}`}
    className="rounded border border-blue-300 bg-blue-50 px-4 py-2 text-sm font-medium text-blue-700 hover:bg-blue-100"
  >
    🍽️ Управлять меню
  </Link>
  <Link
    href={`/admin/cafes/${data.id}/orders`}
    className="rounded border border-green-300 bg-green-50 px-4 py-2 text-sm font-medium text-green-700 hover:bg-green-100"
  >
    📦 Заказы
  </Link>
  <Link href="/admin/cafes" className="text-sm text-zinc-600 hover:underline">
    Back to cafes
  </Link>
</div>
```

**Тест после шага:**

```bash
npx tsc --noEmit
npm run dev

# Открыть страницу кофейни
open http://localhost:3000/admin/cafes/e2bcac65-e503-416e-a428-97b4712d270b

# МАНУАЛЬНАЯ ПРОВЕРКА:
# 1. Видна кнопка "📦 Заказы"
# 2. Клик переводит на /admin/cafes/{id}/orders
# 3. Страница загружается без ошибок
```

---

## Фаза 4: End-to-End тест

### Шаг 4.1: Полный E2E тест создания заказа

**Процедура тестирования:**

```bash
# 1. Backend: Проверить что БД готова
cd SubscribeCoffieBackend
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT COUNT(*) FROM orders;"

# 2. iOS: Запустить симулятор
cd ../SubscribeCoffieClean
./run-simulator.sh

# 3. iOS: Создать заказ вручную
# - Выбрать кофейню
# - Добавить позиции в корзину
# - Нажать "Оформить заказ"
# - В консоли должно быть: "Order created: 260201-XXXX"

# 4. Backend: Проверить что заказ в БД
cd ../SubscribeCoffieBackend
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT order_number, status, total_credits, customer_name 
FROM orders 
ORDER BY created_at DESC 
LIMIT 1;
"

# 5. Admin: Открыть админку
cd ../subscribecoffie-admin
open http://localhost:3000/admin/cafes/e2bcac65-e503-416e-a428-97b4712d270b/orders

# 6. Admin: Проверить что заказ отображается
# - Видна таблица с заказами
# - Последний заказ с правильным номером
# - Статус "new"
# - Сумма соответствует
```

**Критерии успеха:**

- ✅ iOS создаёт заказ через RPC
- ✅ Заказ сохраняется в БД с правильными данными
- ✅ Admin отображает заказ в таблице
- ✅ Все поля заполнены корректно
- ✅ Никаких ошибок в консоли

---

## Следующие шаги (опционально)

После успешного E2E теста можно добавить:

1. **Kanban Board** для заказов (вместо таблицы)
2. **Кнопки смены статуса** (Принять → Готовить → Выдать)
3. **Обновление метрик дашборда**
4. **Real-time обновления** (WebSocket)
5. **Детальная страница заказа**

Но эти фичи можно добавлять инкрементально ПОСЛЕ того, как базовый flow работает.

---

## Rollback Plan

Если что-то сломалось:

```bash
# Откатить миграции
cd SubscribeCoffieBackend
supabase db reset

# Пересобрать iOS
cd ../SubscribeCoffieClean
xcodebuild clean -scheme SubscribeCoffieClean
xcodebuild -scheme SubscribeCoffieClean -sdk iphonesimulator

# Пересобрать Admin
cd ../subscribecoffie-admin
rm -rf .next
npm run build
```