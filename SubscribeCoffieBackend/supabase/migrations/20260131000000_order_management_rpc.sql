-- Migration: Order Management RPC Functions
-- Description: Добавляет RPC функции для управления заказами из админ-панели

-- ============================================================================
-- 1. Функция обновления статуса заказа
-- ============================================================================

create or replace function update_order_status(
  order_id uuid,
  new_status text,
  actor_user_id uuid default null
)
returns jsonb
security definer
language plpgsql
as $$
declare
  old_status text;
  result jsonb;
begin
  -- Получаем текущий статус
  select status into old_status from public.orders where id = order_id;
  
  if old_status is null then
    raise exception 'Order not found: %', order_id;
  end if;
  
  -- Проверка валидности нового статуса
  if new_status not in ('created', 'paid', 'preparing', 'ready', 'issued', 'cancelled', 'refunded') then
    raise exception 'Invalid status: %', new_status;
  end if;
  
  -- Обновляем статус
  update public.orders 
  set 
    status = new_status, 
    updated_at = now()
  where id = order_id;
  
  -- Логируем в order_events
  insert into public.order_events (order_id, status, actor_user_id, created_at)
  values (order_id, new_status, actor_user_id, now());
  
  -- Возвращаем обновленный заказ
  select jsonb_build_object(
    'id', o.id,
    'status', o.status,
    'old_status', old_status,
    'updated_at', o.updated_at,
    'cafe_id', o.cafe_id,
    'customer_phone', o.customer_phone
  ) into result
  from public.orders o
  where o.id = order_id;
  
  return result;
end;
$$;

comment on function update_order_status is 'Обновляет статус заказа с логированием в order_events';

-- ============================================================================
-- 2. Функция получения заказов по кафе с фильтрацией
-- ============================================================================

create or replace function get_orders_by_cafe(
  cafe_id_param uuid default null,
  status_filter text default null,
  limit_param int default 50,
  offset_param int default 0
)
returns table (
  id uuid,
  cafe_id uuid,
  customer_phone text,
  status text,
  subtotal_credits int,
  bonus_used int,
  paid_credits int,
  scheduled_ready_at timestamptz,
  eta_sec int,
  eta_minutes int,
  created_at timestamptz,
  updated_at timestamptz,
  items_count bigint
)
security definer
language plpgsql
as $$
begin
  return query
  select 
    o.id,
    o.cafe_id,
    o.customer_phone,
    o.status,
    o.subtotal_credits,
    o.bonus_used,
    o.paid_credits,
    o.scheduled_ready_at,
    o.eta_sec,
    o.eta_minutes,
    o.created_at,
    o.updated_at,
    count(oi.id) as items_count
  from public.orders o
  left join public.order_items oi on oi.order_id = o.id
  where 
    (cafe_id_param is null or o.cafe_id = cafe_id_param)
    and (status_filter is null or o.status = status_filter)
  group by o.id
  order by o.created_at desc
  limit limit_param
  offset offset_param;
end;
$$;

comment on function get_orders_by_cafe is 'Получает заказы с фильтрацией по кафе и статусу';

-- ============================================================================
-- 3. Функция получения деталей заказа
-- ============================================================================

create or replace function get_order_details(order_id_param uuid)
returns jsonb
security definer
language plpgsql
as $$
declare
  result jsonb;
begin
  -- Получаем заказ с items
  select jsonb_build_object(
    'order', to_jsonb(o.*),
    'items', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', oi.id,
          'menu_item_id', oi.menu_item_id,
          'product_id', oi.product_id,
          'title', oi.title,
          'category', oi.category,
          'quantity', oi.quantity,
          'unit_credits', oi.unit_credits,
          'line_total', oi.line_total
        )
        order by oi.created_at
      ) filter (where oi.id is not null),
      '[]'::jsonb
    ),
    'events', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', oe.id,
            'status', oe.status,
            'actor_user_id', oe.actor_user_id,
            'created_at', oe.created_at
          )
          order by oe.created_at desc
        )
        from public.order_events oe
        where oe.order_id = order_id_param
      ),
      '[]'::jsonb
    )
  ) into result
  from public.orders o
  left join public.order_items oi on oi.order_id = o.id
  where o.id = order_id_param
  group by o.id;
  
  if result is null then
    raise exception 'Order not found: %', order_id_param;
  end if;
  
  return result;
end;
$$;

comment on function get_order_details is 'Получает детали заказа с items и историей статусов';

-- ============================================================================
-- 4. Функция получения статистики заказов
-- ============================================================================

create or replace function get_orders_stats(
  cafe_id_param uuid default null,
  from_date timestamptz default now() - interval '30 days',
  to_date timestamptz default now()
)
returns jsonb
security definer
language plpgsql
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'total_orders', count(*),
    'total_revenue', coalesce(sum(o.paid_credits), 0),
    'avg_order_value', coalesce(avg(o.paid_credits), 0),
    'by_status', (
      select jsonb_object_agg(status, cnt)
      from (
        select status, count(*) as cnt
        from public.orders
        where 
          (cafe_id_param is null or cafe_id = cafe_id_param)
          and created_at between from_date and to_date
        group by status
      ) sub
    )
  ) into result
  from public.orders o
  where 
    (cafe_id_param is null or o.cafe_id = cafe_id_param)
    and o.created_at between from_date and to_date;
  
  return result;
end;
$$;

comment on function get_orders_stats is 'Получает статистику заказов за период';

-- ============================================================================
-- Grant permissions
-- ============================================================================

-- Доступ для authenticated users (для чтения своих заказов)
grant execute on function get_order_details to authenticated;

-- Доступ для admin (полный доступ)
grant execute on function update_order_status to authenticated;
grant execute on function get_orders_by_cafe to authenticated;
grant execute on function get_orders_stats to authenticated;
