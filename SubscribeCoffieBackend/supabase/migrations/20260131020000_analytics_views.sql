-- Migration: Analytics Views
-- Description: Создает view и RPC функции для аналитики

-- ============================================================================
-- 1. View: Аналитика по кафе
-- ============================================================================

create or replace view public.cafe_analytics as
select 
  c.id as cafe_id,
  c.name as cafe_name,
  count(distinct o.id) filter (where o.status not in ('cancelled', 'refunded')) as total_orders,
  sum(o.paid_credits) filter (where o.status not in ('cancelled', 'refunded')) as total_revenue,
  avg(o.paid_credits) filter (where o.status not in ('cancelled', 'refunded')) as avg_order_value,
  count(distinct o.customer_phone) filter (where o.status not in ('cancelled', 'refunded')) as unique_customers,
  count(*) filter (where o.status = 'created') as orders_created,
  count(*) filter (where o.status = 'paid') as orders_paid,
  count(*) filter (where o.status = 'preparing') as orders_preparing,
  count(*) filter (where o.status = 'ready') as orders_ready,
  count(*) filter (where o.status = 'issued') as orders_issued,
  count(*) filter (where o.status = 'cancelled') as orders_cancelled
from public.cafes c
left join public.orders o on o.cafe_id = c.id
group by c.id, c.name;

comment on view public.cafe_analytics is 'Агрегированная аналитика по кафе';

-- ============================================================================
-- 2. View: Популярные позиции меню
-- ============================================================================

create or replace view public.popular_menu_items as
select 
  mi.cafe_id,
  mi.id as item_id,
  mi.name as item_name,
  mi.category,
  mi.price_credits,
  count(oi.id) as order_count,
  sum(oi.quantity) as total_quantity,
  sum(oi.line_total) as total_revenue,
  avg(oi.unit_credits) as avg_price
from public.menu_items mi
left join public.order_items oi on oi.menu_item_id = mi.id
left join public.orders o on o.id = oi.order_id
where o.status not in ('cancelled', 'refunded') or o.id is null
group by mi.cafe_id, mi.id, mi.name, mi.category, mi.price_credits
order by total_quantity desc nulls last;

comment on view public.popular_menu_items is 'Популярные позиции меню по количеству заказов';

-- ============================================================================
-- 3. RPC: Статистика кафе за период
-- ============================================================================

create or replace function get_cafe_stats(
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
    'period', jsonb_build_object(
      'from', from_date,
      'to', to_date
    ),
    'orders', jsonb_build_object(
      'total', count(*),
      'completed', count(*) filter (where status = 'issued'),
      'in_progress', count(*) filter (where status in ('created', 'paid', 'preparing', 'ready')),
      'cancelled', count(*) filter (where status in ('cancelled', 'refunded'))
    ),
    'revenue', jsonb_build_object(
      'total', coalesce(sum(paid_credits) filter (where status not in ('cancelled', 'refunded')), 0),
      'avg_order', coalesce(avg(paid_credits) filter (where status not in ('cancelled', 'refunded')), 0),
      'with_bonus', coalesce(sum(bonus_used), 0)
    ),
    'customers', jsonb_build_object(
      'unique', count(distinct customer_phone),
      'returning', count(distinct customer_phone) filter (
        where customer_phone in (
          select customer_phone 
          from public.orders 
          where created_at < from_date 
          and (cafe_id_param is null or cafe_id = cafe_id_param)
        )
      )
    )
  ) into result
  from public.orders
  where 
    created_at between from_date and to_date
    and (cafe_id_param is null or cafe_id = cafe_id_param);
    
  return result;
end;
$$;

comment on function get_cafe_stats is 'Получает детальную статистику кафе за период';

-- ============================================================================
-- 4. RPC: Топ позиций меню
-- ============================================================================

create or replace function get_top_menu_items(
  cafe_id_param uuid default null,
  limit_param int default 10,
  from_date timestamptz default now() - interval '30 days'
)
returns table (
  item_id uuid,
  item_name text,
  category text,
  price_credits int,
  order_count bigint,
  total_quantity bigint,
  total_revenue bigint
)
security definer
language plpgsql
as $$
begin
  return query
  select 
    mi.id,
    mi.name,
    mi.category,
    mi.price_credits,
    count(distinct oi.order_id) as order_count,
    sum(oi.quantity) as total_quantity,
    sum(oi.line_total) as total_revenue
  from public.menu_items mi
  join public.order_items oi on oi.menu_item_id = mi.id
  join public.orders o on o.id = oi.order_id
  where 
    o.status not in ('cancelled', 'refunded')
    and o.created_at >= from_date
    and (cafe_id_param is null or mi.cafe_id = cafe_id_param)
  group by mi.id, mi.name, mi.category, mi.price_credits
  order by total_quantity desc
  limit limit_param;
end;
$$;

comment on function get_top_menu_items is 'Получает топ позиций меню за период';

-- ============================================================================
-- 5. RPC: Выручка по дням
-- ============================================================================

create or replace function get_revenue_by_day(
  cafe_id_param uuid default null,
  days_param int default 30
)
returns table (
  date date,
  orders_count bigint,
  revenue bigint,
  avg_order_value numeric
)
security definer
language plpgsql
as $$
begin
  return query
  select 
    date_trunc('day', o.created_at)::date as date,
    count(*) as orders_count,
    coalesce(sum(o.paid_credits), 0) as revenue,
    coalesce(avg(o.paid_credits), 0) as avg_order_value
  from public.orders o
  where 
    o.created_at >= now() - (days_param || ' days')::interval
    and o.status not in ('cancelled', 'refunded')
    and (cafe_id_param is null or o.cafe_id = cafe_id_param)
  group by date_trunc('day', o.created_at)
  order by date desc;
end;
$$;

comment on function get_revenue_by_day is 'Получает выручку по дням за период';

-- ============================================================================
-- 6. RPC: Dashboard metrics
-- ============================================================================

create or replace function get_dashboard_metrics(
  cafe_id_param uuid default null
)
returns jsonb
security definer
language plpgsql
as $$
declare
  result jsonb;
  today_start timestamptz := date_trunc('day', now());
  week_start timestamptz := date_trunc('week', now());
  month_start timestamptz := date_trunc('month', now());
begin
  select jsonb_build_object(
    'today', jsonb_build_object(
      'orders', count(*) filter (where created_at >= today_start),
      'revenue', coalesce(sum(paid_credits) filter (where created_at >= today_start and status not in ('cancelled', 'refunded')), 0)
    ),
    'this_week', jsonb_build_object(
      'orders', count(*) filter (where created_at >= week_start),
      'revenue', coalesce(sum(paid_credits) filter (where created_at >= week_start and status not in ('cancelled', 'refunded')), 0)
    ),
    'this_month', jsonb_build_object(
      'orders', count(*) filter (where created_at >= month_start),
      'revenue', coalesce(sum(paid_credits) filter (where created_at >= month_start and status not in ('cancelled', 'refunded')), 0)
    ),
    'all_time', jsonb_build_object(
      'orders', count(*),
      'revenue', coalesce(sum(paid_credits) filter (where status not in ('cancelled', 'refunded')), 0),
      'customers', count(distinct customer_phone)
    )
  ) into result
  from public.orders
  where (cafe_id_param is null or cafe_id = cafe_id_param);
  
  return result;
end;
$$;

comment on function get_dashboard_metrics is 'Получает метрики для dashboard';

-- ============================================================================
-- Grant permissions
-- ============================================================================

grant select on public.cafe_analytics to authenticated;
grant select on public.popular_menu_items to authenticated;
grant execute on function get_cafe_stats to authenticated;
grant execute on function get_top_menu_items to authenticated;
grant execute on function get_revenue_by_day to authenticated;
grant execute on function get_dashboard_metrics to authenticated;
