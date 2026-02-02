# 🔐 ПОСТОЯННЫЕ ДАННЫЕ ДЛЯ ВХОДА

## ❗ НИКОГДА НЕ МЕНЯЙТЕ ЭТИ ДАННЫЕ

```
Email:    levitm@algsoft.ru
Password: 1234567890
Role:     owner
```

---

## 📋 ИНСТРУКЦИЯ ПО СОЗДАНИЮ ПОЛЬЗОВАТЕЛЯ

### Способ 1: Через Supabase Studio (РЕКОМЕНДУЕТСЯ)

1. **Откройте Supabase Studio:**
   ```
   http://localhost:54323
   ```

2. **Перейдите в Authentication → Users**

3. **Нажмите "Add User" (или "Invite User")**

4. **Заполните форму:**
   - **Email**: `levitm@algsoft.ru`
   - **Password**: `1234567890`
   - **✅ ОБЯЗАТЕЛЬНО отметьте**: "Auto Confirm User"

5. **Нажмите "Create User"**

6. **Запустите SQL для установки роли:**
   
   Перейдите в **SQL Editor** и выполните:
   
   ```sql
   -- Установить роль owner
   INSERT INTO user_roles (user_id, role)
   SELECT id, 'owner'
   FROM auth.users
   WHERE email = 'levitm@algsoft.ru'
   ON CONFLICT (user_id) DO UPDATE SET role = 'owner';
   
   -- Создать аккаунт
   INSERT INTO accounts (owner_user_id, company_name)
   SELECT id, 'Algsoft Coffee Company'
   FROM auth.users
   WHERE email = 'levitm@algsoft.ru'
   ON CONFLICT (owner_user_id) DO NOTHING;
   ```

### Способ 2: Через SQL скрипт

```bash
cd SubscribeCoffieBackend
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f create_owner_test_user_complete.sql
```

Затем ОБЯЗАТЕЛЬНО обновите пароль через Supabase Studio:
- Authentication → Users → найдите пользователя → Actions → Reset Password
- Установите: `1234567890`

---

## ✅ ПРОВЕРКА ПОСЛЕ СОЗДАНИЯ

### 1. Проверить создание пользователя:
```sql
SELECT id, email, email_confirmed_at, created_at 
FROM auth.users 
WHERE email = 'levitm@algsoft.ru';
```

Должен вернуть 1 строку с подтвержденным email.

### 2. Проверить роль:
```sql
SELECT u.email, ur.role 
FROM auth.users u
JOIN user_roles ur ON u.id = ur.user_id
WHERE u.email = 'levitm@algsoft.ru';
```

Должно показать: `levitm@algsoft.ru | owner`

### 3. Проверить аккаунт:
```sql
SELECT a.company_name, u.email
FROM accounts a
JOIN auth.users u ON u.id = a.owner_user_id
WHERE u.email = 'levitm@algsoft.ru';
```

Должно показать: `Algsoft Coffee Company | levitm@algsoft.ru`

---

## 🚀 ВХОД В СИСТЕМУ

1. **Откройте страницу логина:**
   ```
   http://localhost:3000/login
   ```

2. **Введите данные:**
   - Email: `levitm@algsoft.ru`
   - Password: `1234567890`

3. **После входа вы попадете на:**
   ```
   http://localhost:3000/admin/owner/dashboard
   ```

---

## 🎯 ДОСТУПНЫЕ СТРАНИЦЫ

### Account Level:
- Dashboard: `/admin/owner/dashboard` → `http://localhost:3000/admin/owner/dashboard`
- Мои кофейни: `/admin/owner/cafes` → `http://localhost:3000/admin/owner/cafes`
- Создать кофейню: `/admin/owner/cafes/new` → `http://localhost:3000/admin/owner/cafes/new`
- Финансы: `/admin/owner/finances` → `http://localhost:3000/admin/owner/finances`
- Уведомления: `/admin/owner/notifications` → `http://localhost:3000/admin/owner/notifications`
- Настройки: `/admin/owner/settings` → `http://localhost:3000/admin/owner/settings`

### Cafe Level (замените {cafeId}):
- Дашборд кофейни: `/admin/owner/cafe/{cafeId}/dashboard`
- Заказы: `/admin/owner/cafe/{cafeId}/orders`
- Меню: `/admin/owner/cafe/{cafeId}/menu`
- Витрина: `/admin/owner/cafe/{cafeId}/storefront`
- Финансы: `/admin/owner/cafe/{cafeId}/finances`
- Настройки: `/admin/owner/cafe/{cafeId}/settings`
- Публикация: `/admin/owner/cafe/{cafeId}/publication`

---

## 🔧 TROUBLESHOOTING

### Проблема: "Invalid login credentials"
**Решение:** 
1. Убедитесь, что email подтвержден (`email_confirmed_at` не NULL)
2. Пересоздайте пользователя через Supabase Studio
3. Убедитесь, что пароль точно: `1234567890` (10 цифр)

### Проблема: "User not found"
**Решение:**
```sql
-- Проверить наличие пользователя
SELECT * FROM auth.users WHERE email = 'levitm@algsoft.ru';
```

Если пусто — создайте через Supabase Studio.

### Проблема: Редирект на /login после входа
**Решение:**
```sql
-- Проверить роль
SELECT * FROM user_roles WHERE user_id = (
  SELECT id FROM auth.users WHERE email = 'levitm@algsoft.ru'
);
```

Если пусто — выполните SQL из "Способ 1, шаг 6".

### Проблема: "Access denied"
**Решение:**
Убедитесь, что роль = `owner`, а не `customer` или `admin`.

---

## ⚠️ ВАЖНО

- **НЕ УДАЛЯЙТЕ** этого пользователя
- **НЕ МЕНЯЙТЕ** email или пароль
- **НЕ МЕНЯЙТЕ** роль с `owner` на другую
- Это **ТОЛЬКО ДЛЯ РАЗРАБОТКИ**, не для продакшн

---

## 📝 ФАЙЛЫ СОЗДАНЫ

1. `create_owner_test_user_complete.sql` - полный SQL скрипт
2. `setup_tables_and_user.sql` - создание таблиц
3. `OWNER_TEST_USER.md` - эта инструкция
4. `OWNER_TEST_USER_CREDENTIALS.md` - краткая справка

---

**Создано**: 1 февраля 2026  
**Статус**: Permanent  
**Не изменять**: НИКОГДА
