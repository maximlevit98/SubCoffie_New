# Cafe Onboarding Quick Start Guide

## Применение миграции

1. Убедитесь, что Supabase запущен локально:
```bash
cd SubscribeCoffieBackend
supabase start
```

2. Миграция должна примениться автоматически при запуске. Если нужно применить вручную:
```bash
supabase db reset
```

3. Проверьте статус миграций:
```bash
supabase migration list
```

## Тестирование Backend

Запустите тестовый SQL скрипт:

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres -f tests/test_cafe_onboarding.sql
```

Или через Supabase Studio:
1. Откройте http://localhost:54323
2. Перейдите в SQL Editor
3. Вставьте содержимое `tests/test_cafe_onboarding.sql`
4. Нажмите "Run"

Все 8 тестов должны пройти успешно.

## Тестирование iOS App

### 1. Сборка проекта

```bash
cd SubscribeCoffieClean
open SubscribeCoffieClean.xcodeproj
```

В Xcode:
1. Убедитесь, что новые файлы добавлены в проект:
   - Models/CafeOnboardingModels.swift
   - Helpers/CafeOnboardingService.swift
   - Views/CafeOnboardingFormView.swift
   - Views/CafeOnboardingListView.swift
   - Views/CafeOnboardingDetailView.swift

2. Если файлы не видны в проекте, добавьте их:
   - File → Add Files to "SubscribeCoffieClean"
   - Выберите все 5 файлов
   - Убедитесь, что Target "SubscribeCoffieClean" выбран

3. Build проект (Cmd+B)

### 2. Запуск в симуляторе

1. Выберите симулятор (iPhone 14 или новее)
2. Нажмите Run (Cmd+R)
3. Войдите в приложение (или пройдите onboarding)

### 3. Тестирование функционала

#### Создание заявки:

1. Откройте профиль (иконка пользователя)
2. Прокрутите вниз до секции "Для владельцев кафе"
3. Нажмите "Подать заявку на подключение"
4. Вы увидите список заявок (пока пустой)
5. Нажмите "+" в правом верхнем углу
6. Заполните форму:
   ```
   Название: Тестовая кофейня
   Адрес: ул. Тестовая, 123
   Телефон: +79991234567
   Email: test@cafe.ru
   Тип бизнеса: Независимое
   Часы работы: 8:00-22:00
   Заказов в день: 50
   Описание: Уютная кофейня в центре города
   ```
7. Нажмите "Отправить"
8. Должен появиться alert "Заявка отправлена!"

#### Просмотр заявок:

1. После создания вы вернетесь к списку заявок
2. Должна отображаться ваша заявка со статусом "Ожидает" (оранжевый badge)
3. Нажмите на заявку для просмотра деталей
4. Вы должны увидеть:
   - Статус с иконкой часов
   - Все данные кафе
   - Кнопку "Отменить заявку"

#### Отмена заявки:

1. В детальном view нажмите "Отменить заявку"
2. Подтвердите отмену
3. Заявка исчезнет из списка или статус изменится на "Отменено"

## Тестирование с базой данных

### Одобрение заявки (через SQL):

```sql
-- Найти ID заявки
SELECT id, cafe_name, status FROM cafe_onboarding_requests;

-- Одобрить заявку (замените YOUR_REQUEST_ID на реальный UUID)
SELECT approve_cafe(
  p_request_id := 'YOUR_REQUEST_ID',
  p_review_comment := 'Отличная кофейня, одобрено!'
);

-- Проверить что кафе создано
SELECT * FROM cafes WHERE name = 'Тестовая кофейня';
```

После одобрения в iOS app:
1. Обновите список заявок (pull to refresh)
2. Статус должен измениться на "Одобрено" (зеленый)
3. Должна отображаться информация о созданном кафе

### Отклонение заявки (через SQL):

```sql
-- Отклонить заявку
SELECT reject_cafe(
  p_request_id := 'YOUR_REQUEST_ID',
  p_rejection_reason := 'Неполная информация, пожалуйста, предоставьте больше деталей'
);
```

В iOS app статус изменится на "Отклонено" (красный) с причиной отклонения.

## Проверка логов

### Backend logs:
```bash
supabase logs --type functions
```

### iOS logs в Xcode:
В Console должны появляться сообщения:
- `POST http://127.0.0.1:54321/rest/v1/rpc/submit_cafe_application`
- `Cafe onboarding application submitted: [UUID]`
- `Fetched X onboarding requests`

## Типичные проблемы

### 1. "Not authenticated" ошибка

**Проблема:** Пользователь не авторизован в приложении.

**Решение:** 
- Убедитесь, что вы вошли в приложение
- Проверьте, что Supabase Auth работает корректно

### 2. Файлы не компилируются в iOS

**Проблема:** Swift не видит новые файлы.

**Решение:**
- Убедитесь, что файлы добавлены в Target
- Clean Build Folder (Cmd+Shift+K)
- Rebuild (Cmd+B)

### 3. RPC функция не найдена

**Проблема:** `"function public.submit_cafe_application does not exist"`

**Решение:**
- Убедитесь, что миграция применена: `supabase migration list`
- Если нет, примените: `supabase db reset`
- Проверьте в Supabase Studio (SQL Editor): `SELECT * FROM pg_proc WHERE proname LIKE '%submit_cafe%';`

### 4. RLS ошибка доступа

**Проблема:** `"new row violates row-level security policy"`

**Решение:**
- Убедитесь, что пользователь авторизован
- Проверьте, что в профиле есть роль: `SELECT * FROM profiles WHERE id = auth.uid();`

## Следующие шаги

После успешного тестирования:

1. **Admin Panel** - создать страницы для администраторов:
   - `/admin/onboarding` - список заявок
   - `/admin/onboarding/[id]` - детали заявки с кнопками approve/reject

2. **Email уведомления** - настроить отправку email:
   - При одобрении заявки
   - При отклонении заявки
   - Напоминания о незавершенных заявках

3. **Загрузка документов**:
   - Интеграция с Supabase Storage
   - Добавить поля для загрузки фото в форму
   - Отображение документов в детальном view

4. **Продакшн деплой**:
   - Настроить Supabase Cloud проект
   - Обновить конфигурацию в iOS app
   - Настроить CI/CD

## Полезные ссылки

- Supabase Studio: http://localhost:54323
- API Documentation: http://localhost:54321/rest/v1/
- Supabase Docs: https://supabase.com/docs

## Контакты

При возникновении проблем или вопросов:
1. Проверьте логи Supabase: `supabase logs`
2. Проверьте Console в Xcode
3. Изучите `CAFE_ONBOARDING_IMPLEMENTATION.md` для деталей
