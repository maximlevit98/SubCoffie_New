# 🔐 OWNER INVITATIONS - PART 3: MANY-TO-MANY + ENHANCED SECURITY

## ✅ РЕАЛИЗОВАНО В ЧАСТИ 3

Дата: 2026-02-03  
Миграция: `20260203130000_owner_invites_many_to_many.sql`  
Приоритет: P0 (Security Critical)

---

## 📊 ЧТО ДОБАВЛЕНО

### 1. 🔗 Таблица `cafe_owners` (Many-to-Many)

**Преимущества:**
- ✅ Один owner → несколько cafes
- ✅ Одна cafe → несколько owners (будущее: manager, staff roles)
- ✅ Granular permissions (can_edit_menu, can_manage_orders, can_view_finances)
- ✅ Audit trail (added_by, added_at)

**Структура:**
```sql
CREATE TABLE public.cafe_owners (
  cafe_id uuid NOT NULL REFERENCES cafes(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Permissions
  role text NOT NULL DEFAULT 'owner', -- owner/manager/staff
  can_edit_menu boolean NOT NULL DEFAULT true,
  can_manage_orders boolean NOT NULL DEFAULT true,
  can_view_finances boolean NOT NULL DEFAULT true,
  
  -- Audit
  added_by uuid REFERENCES auth.users(id),
  added_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}',
  
  PRIMARY KEY (cafe_id, owner_id)
);
```

**Индексы:**
```sql
✅ cafe_owners_pkey: (cafe_id, owner_id) PRIMARY KEY
✅ cafe_owners_owner_id_idx: (owner_id)
✅ cafe_owners_cafe_id_idx: (cafe_id)
✅ cafe_owners_role_idx: (role)
```

---

### 2. 🔒 Enhanced RLS Policies

#### **cafe_owners:**
```sql
✅ "Owners can view own cafe relationships" (SELECT)
   → WHERE auth.uid() = owner_id

✅ "Admins can view all cafe relationships" (SELECT)
   → WHERE role = 'admin'

✅ "Admins can manage cafe relationships" (ALL)
   → WHERE role = 'admin'
```

#### **cafes (обновлено):**
```sql
✅ "Owners can view accessible cafes" (SELECT)
   → Via cafe_owners OR accounts (backward compatible)

✅ "Owners can update accessible cafes" (UPDATE)
   → Via cafe_owners OR accounts
```

#### **menu_items (обновлено):**
```sql
✅ "Owners can manage accessible cafe menu items" (ALL)
   → Via cafe_owners (with can_edit_menu = true) OR accounts
```

#### **orders_core (обновлено):**
```sql
✅ "Owners can view accessible cafe orders" (SELECT)
   → Via cafe_owners (with can_manage_orders = true) OR accounts

✅ "Owners can update accessible cafe orders" (UPDATE)
   → Via cafe_owners (with can_manage_orders = true) OR accounts
```

**Важно:** Все политики имеют **backward compatibility** с accounts!

---

### 3. ⚙️ RPC Functions

#### **A. `redeem_owner_invitation(p_token text)`**

**Назначение:** Безопасное погашение приглашения (альтернатива `accept_owner_invitation`)

**Безопасность:**
```sql
SECURITY DEFINER
SET search_path = public, extensions
```

**Проверки:**
1. ✅ Аутентификация (`auth.uid()`)
2. ✅ Токен валиден (hash + not expired + not used)
3. ✅ Email match (invitation.email = user.email)
4. ✅ Role check (не owner, не admin)
5. ✅ Atomic operation (`FOR UPDATE` lock)

**Действия:**
1. ✅ Назначает `profiles.role = 'owner'`
2. ✅ Создаёт/получает `accounts`
3. ✅ Обновляет `cafes.account_id` (если cafe_id в приглашении)
4. ✅ **Создаёт запись в `cafe_owners`** ← NEW!
5. ✅ Помечает invitation `accepted`
6. ✅ Audit log: `owner_invitation.redeemed`

**Возврат:**
```json
{
  "success": true,
  "message": "Invitation redeemed successfully",
  "account_id": "uuid",
  "cafe_id": "uuid or null",
  "redirect_url": "/admin/owner/dashboard or /admin/owner/onboarding"
}
```

**Отличие от `accept_owner_invitation`:**
- ✅ Создаёт запись в `cafe_owners` (many-to-many)
- ✅ Более строгий `search_path`
- ✅ Audit log action: `redeemed` вместо `accepted`

---

#### **B. `has_owner_access_to_cafe(p_user_id, p_cafe_id)`**

**Назначение:** Проверка доступа owner к cafe

```sql
SELECT has_owner_access_to_cafe(
  '00000000-0000-0000-0000-000000000001'::uuid, -- user_id
  '00000000-0000-0000-0000-000000000002'::uuid  -- cafe_id
);
-- Returns: true/false
```

**Проверяет:**
1. ✅ Via `cafe_owners` (many-to-many)
2. ✅ Via `accounts` (backward compatible)

**Use case:** Middleware/guards в API routes

---

#### **C. `get_owner_accessible_cafes(p_user_id?)`**

**Назначение:** Получить все cafes доступные owner

```sql
-- Get own cafes
SELECT * FROM get_owner_accessible_cafes();

-- Admin: get specific user's cafes
SELECT * FROM get_owner_accessible_cafes('user_id_here');
```

**Возвращает:**
- Cafes via `cafe_owners` (many-to-many)
- Cafes via `accounts` (backward compatible)
- **DISTINCT** (deduplicated)

**Security:**
- ✅ Non-admin users can only get own cafes
- ✅ Admin can get any user's cafes

---

### 4. 🔄 Auto-sync Trigger

**Триггер:** `tg_auto_create_cafe_owner`

**Назначение:** При создании cafe автоматически создаёт запись в `cafe_owners`

**Логика:**
```sql
-- When INSERT on cafes:
1. Get owner_user_id from accounts (via cafe.account_id)
2. Insert into cafe_owners (cafe_id, owner_id)
3. ON CONFLICT DO NOTHING (idempotent)
```

**Эффект:**
- ✅ Новые cafes автоматически доступны owner
- ✅ Sync между `accounts` и `cafe_owners`
- ✅ Backward compatibility сохраняется

---

### 5. 📊 View: `owner_dashboard_stats`

**Назначение:** Статистика для dashboard владельца

```sql
SELECT * FROM owner_dashboard_stats 
WHERE owner_id = auth.uid();
```

**Возвращает:**
```
owner_id         | uuid
total_cafes      | integer (count of accessible cafes)
total_menu_items | integer (across all cafes)
total_orders     | integer (excluding cancelled/refunded)
pending_orders   | integer (created/paid status)
total_revenue    | integer (sum of paid_credits)
```

**Use case:** Dashboard overview widget

---

## 🔐 SECURITY MODEL (СТРОГИЙ)

### Принципы:

1. **owner_invitations:**
   - ❌ SELECT/INSERT/UPDATE/DELETE для owner/user/anon
   - ✅ Только admin
   - ✅ RPC (`redeem_owner_invitation`) работает с токеном

2. **cafe_owners:**
   - ✅ SELECT: owner видит свои связи
   - ✅ SELECT: admin видит все
   - ✅ INSERT/UPDATE/DELETE: только admin или через RPC

3. **cafes/menu_items/orders:**
   - ✅ CRUD только в рамках `cafe_id` где есть связь в `cafe_owners`
   - ✅ OR через `accounts` (backward compatible)
   - ❌ Операции вне scope запрещены

---

## 🧪 ТЕСТИРОВАНИЕ

### Test 1: Owner cannot access other cafe

```sql
-- Setup
INSERT INTO cafe_owners (cafe_id, owner_id) 
VALUES 
  ('cafe1', 'owner1'),
  ('cafe2', 'owner2');

-- Test (as owner1)
SET request.jwt.claims = '{"sub": "owner1"}';

-- Should succeed
SELECT * FROM cafes WHERE id = 'cafe1';

-- Should return empty (no access)
SELECT * FROM cafes WHERE id = 'cafe2';
```

### Test 2: Permissions enforcement

```sql
-- Setup: owner with can_edit_menu = false
INSERT INTO cafe_owners (cafe_id, owner_id, can_edit_menu)
VALUES ('cafe1', 'owner1', false);

-- Test (as owner1)
SET request.jwt.claims = '{"sub": "owner1"}';

-- Should FAIL (no menu permission)
INSERT INTO menu_items (cafe_id, name, ...) 
VALUES ('cafe1', 'Espresso', ...);
```

### Test 3: redeem_owner_invitation

```sql
-- Create invitation
SELECT admin_create_owner_invitation(
  'test@test.com', 
  'Test Co', 
  'cafe123', -- pre-link cafe
  24
);

-- Signup user (via Supabase Auth)
-- email: test@test.com

-- Redeem invitation
SELECT redeem_owner_invitation('token_here');

-- Verify cafe_owners entry created
SELECT * FROM cafe_owners 
WHERE owner_id = (SELECT id FROM auth.users WHERE email = 'test@test.com');

-- Expected:
-- cafe_id | owner_id | role | can_edit_menu | can_manage_orders | can_view_finances
-- cafe123 | user_id  | owner| true          | true              | true
```

---

## 🔄 MIGRATION COMPATIBILITY

### Existing Data:

✅ **Migration auto-syncs existing data:**
```sql
-- For each account:
--   For each cafe (where cafes.account_id = account.id):
--     INSERT INTO cafe_owners (cafe_id, owner_id)
--     ON CONFLICT DO NOTHING
```

### Backward Compatibility:

✅ **All RLS policies check BOTH:**
- `cafe_owners` (new, many-to-many)
- `accounts` (old, one-to-many)

**Пример:**
```sql
-- Policy: Owners can view accessible cafes
USING (
  -- NEW: via cafe_owners
  EXISTS (SELECT 1 FROM cafe_owners WHERE cafe_id = cafes.id AND owner_id = auth.uid())
  OR
  -- OLD: via accounts (backward compatible)
  account_id IN (SELECT id FROM accounts WHERE owner_user_id = auth.uid())
)
```

### Future-proof:

✅ **Ready for multi-owner cafes:**
```sql
-- Cafe can have multiple owners
INSERT INTO cafe_owners (cafe_id, owner_id) VALUES
  ('cafe1', 'owner1'),  -- Main owner
  ('cafe1', 'owner2');  -- Co-owner or manager
```

---

## 📚 USE CASES

### Use Case 1: Multi-cafe Owner

**Scenario:** Owner управляет 3 кофейнями

```sql
-- cafe_owners:
-- cafe1 | owner1 | owner | true | true | true
-- cafe2 | owner1 | owner | true | true | true
-- cafe3 | owner1 | owner | true | true | true

-- Owner видит все 3 кафе в dashboard
SELECT * FROM get_owner_accessible_cafes('owner1');
-- Returns: cafe1, cafe2, cafe3
```

### Use Case 2: Cafe with Multiple Owners (Future)

**Scenario:** Cafe имеет 2 владельцев + 1 менеджер

```sql
-- cafe_owners:
-- cafe1 | owner1  | owner   | true | true | true
-- cafe1 | owner2  | owner   | true | true | true
-- cafe1 | manager1| manager | true | true | false (no finances)

-- All 3 users can manage cafe (with different permissions)
```

### Use Case 3: Granular Permissions

**Scenario:** Staff может видеть заказы, но не редактировать меню

```sql
INSERT INTO cafe_owners (cafe_id, owner_id, role, can_edit_menu, can_manage_orders)
VALUES ('cafe1', 'staff1', 'staff', false, true);

-- staff1 can:
-- ✅ View/update orders (can_manage_orders = true)
-- ❌ Edit menu items (can_edit_menu = false)
```

---

## 🚀 DEPLOYMENT

### Checklist:

- [x] Миграция применена: `20260203130000_owner_invites_many_to_many.sql`
- [x] Existing data синхронизирован (auto-sync в миграции)
- [x] RLS policies обновлены
- [x] Trigger создан
- [x] Frontend обновлён (`redeem_owner_invitation`)
- [x] Backward compatibility сохранена

### Rollback Plan:

**Если нужен rollback:**
1. Frontend: вернуть `accept_owner_invitation` вместо `redeem_owner_invitation`
2. Database: обе функции работают параллельно
3. RLS policies: проверяют `accounts` OR `cafe_owners`

---

## 📝 SUMMARY

### ✅ Добавлено:
- Таблица `cafe_owners` (many-to-many)
- RPC `redeem_owner_invitation` (secure)
- RPC `has_owner_access_to_cafe` (helper)
- RPC `get_owner_accessible_cafes` (enhanced)
- Trigger `tg_auto_create_cafe_owner` (auto-sync)
- View `owner_dashboard_stats` (dashboard)
- Enhanced RLS policies (granular permissions)

### ✅ Security:
- ❌ Self-assignment blocked
- ✅ Strict scope isolation
- ✅ Audit logging
- ✅ Token-based redemption
- ✅ Email validation
- ✅ Atomic operations

### ✅ Compatibility:
- ✅ Backward compatible с `accounts`
- ✅ Existing data auto-synced
- ✅ Old RLS policies updated (check both sources)

---

**Готово!** Система полностью реализована с enterprise-уровнем безопасности! 🎉
