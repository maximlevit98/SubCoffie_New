# 🚀 OWNER REGISTRATION QUICK START

## 1️⃣ Создание приглашения (Admin)

### Через UI (рекомендовано):
1. Зайдите в админку: `http://localhost:3000/login`
2. Войдите как admin (`admin@coffie.local` / `admin123`)
3. Перейдите в `/admin/owner-invitations`
4. Нажмите "+ Create Invitation"
5. Заполните форму:
   - Email: `test_owner@example.com`
   - Company: `Test Coffee Shop` (optional)
   - Cafe: выберите или оставьте "Create later"
   - Expiry: `168` (7 дней)
6. Нажмите "Create Invitation"
7. **ВАЖНО**: Скопируйте ссылку и токен (показываются **один раз**!)

### Через SQL (для тестирования):
```sql
SELECT admin_create_owner_invitation(
  'test_owner@example.com',  -- email
  'Test Coffee Shop',        -- company_name
  NULL,                      -- cafe_id (NULL = create later)
  168                        -- expires_in_hours (7 days)
);
```

**Результат:**
```json
{
  "token": "abc123def456...",
  "invite_url": "https://domain.com/register/owner?token=abc123def456..."
}
```

---

## 2️⃣ Регистрация владельца (Owner)

### Шаги:
1. Перейдите по ссылке: `http://localhost:3000/register/owner?token=YOUR_TOKEN`
2. Проверьте email (pre-filled, readonly)
3. Заполните форму:
   - Full Name: `Ivan Petrov`
   - Phone: `+7 999 123 45 67` (optional)
   - Password: `securepass123` (min 8 chars)
   - Confirm Password: `securepass123`
4. Нажмите "Complete Registration"
5. Ждите redirect на `/admin/owner/onboarding` или `/admin/owner/dashboard`

---

## 3️⃣ Проверка (для тестирования)

### Проверить роль:
```sql
SELECT 
  u.email,
  p.role,
  a.company_name,
  a.id as account_id
FROM auth.users u
JOIN profiles p ON p.id = u.id
LEFT JOIN accounts a ON a.owner_user_id = u.id
WHERE u.email = 'test_owner@example.com';
```

**Ожидаемый результат:**
```
email                   | role  | company_name      | account_id
------------------------+-------+-------------------+-----------
test_owner@example.com  | owner | Test Coffee Shop  | uuid...
```

### Проверить приглашение:
```sql
SELECT 
  email,
  status,
  accepted_at,
  expires_at,
  use_count
FROM owner_invitations
WHERE email = 'test_owner@example.com';
```

**Ожидаемый результат:**
```
email                   | status   | accepted_at         | expires_at | use_count
------------------------+----------+---------------------+------------+-----------
test_owner@example.com  | accepted | 2026-02-03 12:00:00 | ...        | 1
```

### Проверить audit logs:
```sql
SELECT 
  action,
  actor_user_id,
  payload->'email' as email,
  created_at
FROM audit_logs
WHERE action LIKE 'owner_invitation%'
ORDER BY created_at DESC
LIMIT 5;
```

---

## 4️⃣ Типичные сценарии

### Сценарий 1: Новый owner без кафе
1. Admin создаёт invitation (без cafe_id)
2. Owner регистрируется
3. Redirect на `/admin/owner/onboarding`
4. Owner видит пошаговый план
5. Нажимает "Create Cafe" → `/admin/owner/cafes/new`

### Сценарий 2: Привязка к существующей кофейне
1. Admin создаёт invitation (с указанным cafe_id)
2. Owner регистрируется
3. Автоматически привязывается к кафе
4. Redirect на `/admin/owner/dashboard`
5. Owner сразу видит кафе и может управлять меню/заказами

### Сценарий 3: Revoke invitation
```sql
-- Find invitation ID
SELECT id, email, status FROM owner_invitations WHERE status = 'pending';

-- Revoke it
SELECT admin_revoke_owner_invitation('invitation_id_here');
```

---

## 5️⃣ Troubleshooting

### Ошибка: "Invalid invitation token"
**Причины:**
- Токен использован (status = 'accepted')
- Токен истёк (expires_at < now())
- Токен revoked (status = 'revoked')
- Неправильный токен

**Решение:** Создайте новое приглашение

### Ошибка: "Email mismatch"
**Причина:** Owner зарегистрировался с другим email

**Решение:** Используйте email, указанный в приглашении

### Ошибка: "User already has owner role"
**Причина:** Email уже зарегистрирован как owner

**Решение:** Используйте другой email

### Owner не видит кафе после регистрации
**Проверка:**
```sql
SELECT 
  a.id as account_id,
  a.owner_user_id,
  c.id as cafe_id,
  c.name as cafe_name
FROM accounts a
LEFT JOIN cafes c ON c.account_id = a.id
WHERE a.owner_user_id = (
  SELECT id FROM auth.users WHERE email = 'test_owner@example.com'
);
```

**Если cafe_id = NULL:** Owner должен создать кафе через onboarding

---

## 6️⃣ Безопасность

### ✅ Что реализовано:
- Токены хэшируются (SHA256)
- Expiry автоматический
- One-time use (max_uses = 1)
- Email validation строгая
- Роль назначается только через RPC
- Audit logging всех операций

### ⚠️ Best Practices:
- Отправляйте ссылки через защищённые каналы
- Используйте короткий expiry для production (24-72 часа)
- Регулярно чистите expired приглашения
- Мониторьте audit logs

---

## 7️⃣ Частые вопросы

**Q: Можно ли использовать токен повторно?**  
A: Нет, по умолчанию max_uses = 1

**Q: Что делать если owner потерял ссылку?**  
A: Admin должен revoke старое приглашение и создать новое

**Q: Можно ли изменить email в приглашении?**  
A: Нет, нужно создать новое приглашение

**Q: Как добавить email отправку?**  
A: Создайте Supabase Edge Function или используйте внешний сервис (SendGrid, Mailgun)

---

## 8️⃣ Следующие шаги

После успешной регистрации owner:

1. **Создать кафе** (`/admin/owner/cafes/new`)
2. **Добавить меню** (`/admin/owner/cafe/[id]/menu`)
3. **Настроить storefront** (`/admin/owner/cafe/[id]/storefront`)
4. **Отправить на модерацию** (`/admin/owner/cafe/[id]/publication`)
5. **Получить одобрение** (admin approves)
6. **Кафе публикуется** (status = 'published')

---

**Готово!** 🎉 Система работает и готова к использованию.
