# 🎯 OWNER/ADMIN ROLE MODEL: ПРОФЕССИОНАЛЬНАЯ РЕАЛИЗАЦИЯ

## ✅ ЧТО СДЕЛАНО

### A. БЕЗОПАСНОСТЬ РОЛЕЙ (P0 - CRITICAL)

#### 1. Запрет demote admin + RPC для выдачи admin роли
**Файл:** `SubscribeCoffieBackend/supabase/migrations/20260204000000_prevent_role_self_assignment.sql`

**Изменения:**
- ✅ Добавлен триггер `prevent_admin_demotion_trigger` - админа нельзя разжаловать
- ✅ Добавлен RPC `admin_grant_admin_role(p_target_user_id)`:
  - Проверяет что вызывающий - admin (через `auth.uid()`)
  - Запрещает выдавать admin самому себе
  - Логирует в audit_logs
- ✅ Триггер `audit_role_change` логирует все изменения роли

**Как использовать:**
```sql
-- Только admin может выдать admin роль другому пользователю
SELECT admin_grant_admin_role('user-uuid-here');
```

---

#### 2. Защита approve/reject cafe RPC
**Файл:** `SubscribeCoffieBackend/supabase/migrations/20260204010000_secure_cafe_onboarding_rpc.sql`

**Проблема:** Функции `approve_cafe` и `reject_cafe` принимали `p_admin_user_id` как параметр - злоумышленник мог подставить любой admin ID.

**Решение:**
- ✅ Теперь функции проверяют `auth.uid()` (реальный ID вызывающего)
- ✅ Параметр `p_admin_user_id` должен совпадать с `auth.uid()`
- ✅ Добавлен audit logging для всех операций
- ✅ `search_path` заблокирован для SECURITY DEFINER функций

**Тесты:**
```sql
-- ❌ Не должно работать: попытка подставить чужой admin ID
SELECT approve_cafe('<request_id>', '<another_admin_id>', 'test');
-- Expected: ERROR: Admin user ID must match authenticated user

-- ✅ Должно работать: только с собственным ID
SELECT approve_cafe('<request_id>', auth.uid(), 'approved!');
```

---

### B. МЕНЮ АДМИНКИ (P0)

#### 3. Owner Invitations в левом меню
**Файл:** `subscribecoffie-admin/components/LegacyAdminLayout.tsx`

**Изменения:**
- ✅ Добавлен пункт "📨 Owner Invitations" → `/admin/owner-invitations`
- ✅ Виден только для `role === 'admin'`
- ✅ Удалены ссылки на owner panel для admin'а

**Результат:** Admin больше не может "прыгать" в owner контекст через UI.

---

### C. ИНТЕГРАЦИЯ INVITES В CAFE ONBOARDING (P0→P1)

#### 4. Статусы invites в заявках на кафе
**Файлы:**
- `subscribecoffie-admin/app/admin/cafe-onboarding/page.tsx`
- `subscribecoffie-admin/app/admin/cafe-onboarding/InviteOwnerButton.tsx`

**Что добавлено:**
- ✅ В каждой заявке показывается статус приглашения владельца:
  - `✅ Принято` (accepted)
  - `⏳ Ожидает` (pending, до истечения срока)
  - `⏰ Истекло` (pending, но expires_at прошёл)
  - `🚫 Отозвано` (revoked)
- ✅ Если инвайта нет → кнопка "➕ Создать приглашение"
- ✅ При создании:
  - Автозаполняется email и company_name из заявки
  - Показывается invite URL (только один раз!)
  - Кнопка "📋 Копировать ссылку"

**UX Flow:**
1. Admin видит заявку на кафе
2. Нажимает "Создать приглашение"
3. Получает URL и отправляет владельцу
4. Владелец регистрируется по ссылке
5. Статус меняется на "✅ Принято"

---

### D. OWNER PANEL UX (P0)

#### 5. Имя владельца в header
**Файл:** `subscribecoffie-admin/app/admin/owner/layout.tsx`

**Изменения:**
- ✅ Загружает `profiles.full_name` и `email`
- ✅ Показывает в header: "Привет, **{full_name или email}**"
- ✅ Добавлена ссылка "⚙️ Настройки" → `/admin/owner/settings`
- ✅ Admin больше не может открыть `/admin/owner/*` (редирект на `/admin/dashboard`)

---

#### 6. Страница настроек владельца
**Файлы:**
- `subscribecoffie-admin/app/admin/owner/settings/page.tsx`
- `subscribecoffie-admin/app/admin/owner/settings/SignOutButton.tsx`

**Что показывается:**
- ✅ **Личная информация:**
  - Email
  - Полное имя
  - Телефон
- ✅ **Ваши кофейни:**
  - Список кафе из `cafe_owners`
- ✅ **Роль и доступ:**
  - Badge "Владелец (Owner)"
  - Описание прав
- ✅ **Действия:**
  - Кнопка "🚪 Выйти из системы"

---

## 🎯 ACCEPTANCE CRITERIA (ВЫПОЛНЕНО)

| Критерий | Статус | Реализация |
|----------|--------|------------|
| Админ не может быть разжалован | ✅ | `prevent_admin_demotion_trigger` |
| Нельзя самому назначить admin/owner | ✅ | Column-level `REVOKE UPDATE(role)` |
| Admin не видит owner panel в меню | ✅ | Убраны ссылки из `LegacyAdminLayout` |
| Admin не может открыть `/admin/owner/*` | ✅ | Guard в `OwnerLayout` |
| В меню есть "Owner Invitations" | ✅ | Добавлено в sidebar |
| Статусы invites видны в cafe onboarding | ✅ | Интеграция в `cafe-onboarding/page.tsx` |
| Owner видит своё имя в header | ✅ | Загружается из `profiles` |
| Owner имеет страницу настроек | ✅ | `/admin/owner/settings` |
| approve/reject cafe проверяют auth.uid() | ✅ | Migration `20260204010000_secure_cafe_onboarding_rpc.sql` |

---

## 📋 КАК ТЕСТИРОВАТЬ

### 1. Тест: Admin role permanent
```sql
-- Войти как admin
UPDATE profiles SET role = 'owner' WHERE id = auth.uid();
-- Expected: ERROR: Cannot demote admin role. Admin role is permanent for security reasons.
```

### 2. Тест: Admin не может выдать себе admin
```sql
-- Войти как не-admin
SELECT admin_grant_admin_role(auth.uid());
-- Expected: ERROR: Only admin users can grant admin role
```

### 3. Тест: Owner invites в cafe onboarding
1. Войти как admin: `admin@coffie.local` / `Admin123!`
2. Открыть `/admin/cafe-onboarding`
3. Создать тестовую заявку (или использовать существующую)
4. Нажать "➕ Создать приглашение"
5. Скопировать URL и открыть в incognito
6. Зарегистрироваться как owner
7. Проверить статус в заявке → должно быть "✅ Принято"

### 4. Тест: Owner settings page
1. Войти как owner: `levitm@algsoft.ru` / `1234567890`
2. Кликнуть "⚙️ Настройки" в header
3. Проверить:
   - Показывается email, имя, телефон
   - Список кафе
   - Роль "Владелец (Owner)"
   - Кнопка выхода работает

### 5. Тест: Admin не может открыть owner panel
1. Войти как admin
2. Попытаться открыть `/admin/owner/dashboard`
3. Должен быть редирект на `/admin/dashboard`

### 6. Тест: approve_cafe security
```sql
-- Войти как admin
SET ROLE authenticated;
SELECT approve_cafe('<request_id>', '<another_admin_id>', 'test');
-- Expected: ERROR: Admin user ID must match authenticated user
```

---

## 🔑 УЧЁТНЫЕ ДАННЫЕ (ПОСЛЕ DB RESET)

```bash
# Admin
Email: admin@coffie.local
Password: Admin123!
Access: /admin/dashboard, /admin/owner-invitations

# Owner
Email: levitm@algsoft.ru
Password: 1234567890
Access: /admin/owner/dashboard, /admin/owner/settings
```

---

## 📂 ИЗМЕНЁННЫЕ ФАЙЛЫ

### Backend (2 файла)
1. `SubscribeCoffieBackend/supabase/migrations/20260204000000_prevent_role_self_assignment.sql` (updated)
2. `SubscribeCoffieBackend/supabase/migrations/20260204010000_secure_cafe_onboarding_rpc.sql` (new)

### Frontend (6 файлов)
1. `subscribecoffie-admin/components/LegacyAdminLayout.tsx` (updated)
2. `subscribecoffie-admin/app/admin/cafe-onboarding/page.tsx` (updated)
3. `subscribecoffie-admin/app/admin/cafe-onboarding/InviteOwnerButton.tsx` (new)
4. `subscribecoffie-admin/app/admin/owner/layout.tsx` (updated)
5. `subscribecoffie-admin/app/admin/owner/settings/page.tsx` (updated)
6. `subscribecoffie-admin/app/admin/owner/settings/SignOutButton.tsx` (new)

---

## 🚀 СЛЕДУЮЩИЕ ШАГИ (ОПЦИОНАЛЬНО)

### P1 - Улучшения UX
- [ ] Добавить owner_invitation_id в cafe_onboarding_requests (FK для жёсткой связи)
- [ ] Email notification при создании invite
- [ ] Страница редактирования профиля owner (full_name, phone)

### P1 - Дополнительная безопасность
- [ ] Rate limiting для owner invite creation
- [ ] IP logging для admin operations
- [ ] 2FA для admin accounts

---

## 📚 ДОКУМЕНТАЦИЯ

Все изменения соответствуют "профессиональной" архитектуре:
- ✅ Строгое разделение контекстов (admin ≠ owner)
- ✅ Защита на уровне DB (triggers, RLS, column-level grants)
- ✅ Audit logging для критичных операций
- ✅ Server-side guards для всех admin API
- ✅ Понятные UX паттерны (статусы, кнопки, настройки)

**Готово к production! 🎉**
