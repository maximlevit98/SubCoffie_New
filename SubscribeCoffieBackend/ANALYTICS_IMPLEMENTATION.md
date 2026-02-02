# Analytics Implementation Guide

## Обзор

Система аналитики предоставляет владельцам кафе и администраторам платформы детальную статистику по заказам, выручке, популярным позициям меню и эффективности работы.

## Архитектура

### Backend (Supabase)

#### Views
- `cafe_analytics` - агрегированная аналитика по всем кафе
- `popular_menu_items` - популярные позиции меню с суммарной статистикой

#### RPC Functions

##### 1. `get_dashboard_metrics(cafe_id_param uuid)`
Возвращает основные метрики для dashboard:
- Статистика за сегодня, эту неделю, этот месяц, за всё время
- Количество заказов и выручка по периодам
- Уникальные клиенты

**Пример использования:**
```sql
select * from get_dashboard_metrics(null); -- для всех кафе
select * from get_dashboard_metrics('uuid-кафе'); -- для конкретного кафе
```

##### 2. `get_revenue_by_day(cafe_id_param uuid, days_param int)`
Возвращает статистику выручки по дням:
- Количество заказов
- Общая выручка
- Средний чек

**Пример использования:**
```sql
select * from get_revenue_by_day(null, 7); -- последние 7 дней для всех кафе
select * from get_revenue_by_day('uuid-кафе', 30); -- последние 30 дней для кафе
```

##### 3. `get_top_menu_items(cafe_id_param uuid, limit_param int, from_date timestamptz)`
Возвращает топ позиций меню:
- Название и категория
- Количество заказов
- Общее количество проданных единиц
- Общая выручка

**Пример использования:**
```sql
select * from get_top_menu_items(null, 10, now() - interval '30 days'); -- топ-10 за месяц
select * from get_top_menu_items('uuid-кафе', 5, now() - interval '7 days'); -- топ-5 за неделю
```

##### 4. `get_hourly_orders_stats(cafe_id_param uuid, date_from timestamptz, date_to timestamptz)`
⭐ **НОВАЯ ФУНКЦИЯ** - Возвращает статистику заказов по часам дня:
- Час дня (0-23)
- Количество заказов
- Общая выручка
- Средний чек
- Уникальные клиенты

**Пример использования:**
```sql
select * from get_hourly_orders_stats(
  'uuid-кафе',
  now() - interval '7 days',
  now()
); -- пиковые часы за последнюю неделю
```

**Применение:** Определение пиковых часов для оптимизации расписания персонала.

##### 5. `get_cafe_conversion_stats(cafe_id_param uuid, date_from timestamptz, date_to timestamptz)`
⭐ **НОВАЯ ФУНКЦИЯ** - Возвращает статистику конверсии:
- Общее количество заказов
- Завершённые заказы
- Отменённые заказы
- Процент завершения (completion_rate)
- Процент отмены (cancellation_rate)
- Среднее время подготовки (в минутах)

**Пример использования:**
```sql
select * from get_cafe_conversion_stats(
  'uuid-кафе',
  now() - interval '30 days',
  now()
);
```

**Результат:**
```json
{
  "period": {
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-01-30T00:00:00Z"
  },
  "orders": {
    "total": 150,
    "completed": 140,
    "cancelled": 10
  },
  "conversion": {
    "completion_rate": 93.33,
    "cancellation_rate": 6.67
  },
  "performance": {
    "avg_preparation_minutes": 8.5
  }
}
```

##### 6. `get_period_comparison(cafe_id_param uuid, current_from, current_to, previous_from, previous_to)`
⭐ **НОВАЯ ФУНКЦИЯ** - Сравнивает статистику между двумя периодами:
- Заказы, выручка, средний чек, клиенты для обоих периодов
- Процент роста/падения по каждой метрике

**Пример использования:**
```sql
select * from get_period_comparison(
  'uuid-кафе',
  '2026-01-01'::timestamptz,  -- текущий период начало
  '2026-01-31'::timestamptz,  -- текущий период конец
  '2025-12-01'::timestamptz,  -- предыдущий период начало
  '2025-12-31'::timestamptz   -- предыдущий период конец
);
```

**Результат:**
```json
{
  "current": {
    "orders": 150,
    "revenue": 450000,
    "avg_order": 3000,
    "customers": 85
  },
  "previous": {
    "orders": 120,
    "revenue": 360000,
    "avg_order": 3000,
    "customers": 70
  },
  "growth": {
    "orders": 25.00,      // +25% заказов
    "revenue": 25.00,     // +25% выручки
    "customers": 21.43    // +21.43% клиентов
  }
}
```

## Frontend (Admin Panel)

### Dashboard (`/admin/dashboard`)

#### Возможности:
1. **Фильтрация по кафе** - выпадающий список для выбора конкретного кафе или всех кафе
2. **Метрики по периодам** - сегодня, эта неделя, этот месяц
3. **Конверсия и эффективность** (только для выбранного кафе):
   - Количество успешных заказов
   - Процент завершения
   - Среднее время подготовки
   - Предупреждение об отменённых заказах
4. **Пиковые часы** (только для выбранного кафе):
   - Визуализация заказов по часам дня
   - Автоматическое определение топ-3 пиковых часов
5. **График выручки** - таблица с данными за последние 7 дней
6. **Топ-5 позиций меню** - самые популярные блюда

### API Клиент (`lib/supabase/queries/analytics.ts`)

Все RPC функции обёрнуты в TypeScript функции:

```typescript
// Основные метрики
await getDashboardMetrics(cafeId?: string);

// Выручка по дням
await getRevenueByDay(cafeId?: string, days: number);

// Топ позиций меню
await getTopMenuItems(cafeId?: string, limit: number);

// Статистика кафе за период
await getCafeStats(cafeId?: string, fromDate?: string, toDate?: string);

// Новые функции:
await getHourlyOrdersStats(cafeId: string, dateFrom?: string, dateTo?: string);
await getCafeConversionStats(cafeId: string, dateFrom?: string, dateTo?: string);
await getPeriodComparison(cafeId: string, currentFrom, currentTo, previousFrom, previousTo);
```

## Тестирование

### SQL тесты
Создан файл `tests/analytics_functions.test.sql` для проверки всех RPC функций.

**Запуск тестов:**
```bash
cd SubscribeCoffieBackend
psql $DATABASE_URL -f tests/analytics_functions.test.sql
```

### Ручное тестирование
1. Запустите Supabase локально:
   ```bash
   supabase start
   ```

2. Примените миграции:
   ```bash
   supabase db reset
   ```

3. Создайте тестовые данные (если нужно):
   ```bash
   psql $DATABASE_URL -f tests/seed_test_data.sql
   ```

4. Откройте admin panel:
   ```bash
   cd subscribecoffie-admin
   npm run dev
   ```

5. Перейдите на `/admin/dashboard` и проверьте:
   - Метрики отображаются корректно
   - Фильтр по кафе работает
   - Графики и статистика загружаются без ошибок

## Безопасность и права доступа

### RLS (Row Level Security)
Все RPC функции имеют `security definer`, что означает, что они выполняются с правами владельца функции (postgres).

### Права доступа
- `authenticated` - могут вызывать все RPC функции и читать views
- В будущем: владельцы кафе смогут видеть только данные своих кафе (требуется добавление `owner_id` в таблицу `cafes`)

## Расширение для владельцев кафе

### TODO: Ограничение доступа по cafe_id
Для реализации полноценного B2B dashboard для владельцев:

1. Добавить поле `owner_id` в таблицу `cafes`:
```sql
alter table public.cafes add column owner_id uuid references auth.users(id);
```

2. Создать middleware в admin panel для определения роли:
```typescript
// middleware.ts
const { role, userId } = await getUserRole();

if (role === 'owner') {
  // Получить cafe_id владельца
  const { data: cafes } = await supabase
    .from('cafes')
    .select('id')
    .eq('owner_id', userId);
  
  // Автоматически фильтровать dashboard по cafe_id
}
```

3. Обновить RPC функции для проверки прав:
```sql
create or replace function get_dashboard_metrics(cafe_id_param uuid)
returns jsonb
security definer
as $$
begin
  -- Если не админ, проверяем owner_id
  if not exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  ) then
    -- Владелец может видеть только свои кафе
    if not exists (
      select 1 from cafes 
      where id = cafe_id_param and owner_id = auth.uid()
    ) then
      raise exception 'Access denied';
    end if;
  end if;
  
  -- ... остальная логика
end;
$$;
```

## Метрики производительности

Все RPC функции оптимизированы для быстрой работы:
- Используют индексы на `created_at`, `cafe_id`, `status`
- Агрегации выполняются на уровне БД
- Результаты возвращаются в формате JSONB для минимизации парсинга

**Ожидаемое время выполнения:**
- `get_dashboard_metrics`: ~50-100ms
- `get_revenue_by_day`: ~30-50ms
- `get_hourly_orders_stats`: ~50-80ms
- `get_cafe_conversion_stats`: ~60-100ms

## Roadmap

### Ближайшие улучшения (P1):
- [ ] Добавить экспорт данных в CSV/Excel
- [ ] Интеграция реального графика (Chart.js / Recharts)
- [ ] Кэширование результатов (Redis / Supabase Edge Functions)
- [ ] Real-time обновления метрик (Supabase Realtime)

### Будущие улучшения (P2):
- [ ] Когортный анализ клиентов
- [ ] Предсказание спроса (ML модель)
- [ ] Автоматические отчёты по email
- [ ] Mobile app для владельцев кафе

## Поддержка

При возникновении вопросов или проблем:
1. Проверьте миграции: `supabase db reset`
2. Проверьте права доступа: `select * from pg_policies where tablename like '%cafe%'`
3. Посмотрите логи: `supabase functions logs`
4. Запустите тесты: `npm test`

## Примеры использования

### Получение пиковых часов для оптимизации персонала

```sql
-- Найти часы с максимальной загрузкой за последний месяц
select 
  hour_of_day,
  orders_count,
  total_revenue
from get_hourly_orders_stats(
  '550e8400-e29b-41d4-a716-446655440000',
  now() - interval '30 days',
  now()
)
where orders_count > 5
order by orders_count desc
limit 5;
```

### Анализ эффективности за последний квартал

```sql
-- Сравнить последние 3 месяца с предыдущими 3 месяцами
select * from get_period_comparison(
  '550e8400-e29b-41d4-a716-446655440000',
  now() - interval '3 months',
  now(),
  now() - interval '6 months',
  now() - interval '3 months'
);
```

### Выявление проблемных кафе с низкой конверсией

```sql
-- Найти кафе с конверсией ниже 80%
select 
  c.name,
  (stats->>'conversion'->>'completion_rate')::numeric as completion_rate
from cafes c
cross join lateral (
  select get_cafe_conversion_stats(
    c.id,
    now() - interval '30 days',
    now()
  ) as stats
) s
where (stats->'conversion'->>'completion_rate')::numeric < 80
order by completion_rate;
```
