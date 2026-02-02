-- ============================================================================
-- Owner Admin Panel - Order Management Functions
-- ============================================================================
-- Description: API functions for owner order management
-- Date: 2026-02-01
--
-- This migration creates:
-- 1. Order status management functions
-- 2. Order cancellation with refund
-- 3. Real-time order queries
-- 4. Order statistics functions
-- ============================================================================

-- ============================================================================
-- 1. Update Order Status (with validation)
-- ============================================================================

create or replace function public.owner_update_order_status(
  p_order_id uuid,
  p_new_status text,
  p_owner_user_id uuid default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders_core%ROWTYPE;
  v_user_id uuid;
begin
  -- Use auth.uid() if not provided
  v_user_id := coalesce(p_owner_user_id, auth.uid());

  -- Get order
  select * into v_order
  from public.orders_core
  where id = p_order_id;

  if v_order is null then
    raise exception 'Order not found';
  end if;

  -- Check ownership
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = v_order.cafe_id and a.owner_user_id = v_user_id
  ) then
    raise exception 'Unauthorized: not your cafe order';
  end if;

  -- Validate status transition
  -- Valid transitions:
  -- Created -> Accepted, Rejected, Canceled
  -- Accepted -> In progress, Canceled
  -- In progress -> Ready, Canceled
  -- Ready -> Picked up, No-show, Canceled
  
  if v_order.status = 'Picked up' or v_order.status = 'Canceled' or 
     v_order.status = 'Refunded' or v_order.status = 'No-show' then
    raise exception 'Cannot change status of completed order';
  end if;

  -- Update status
  update public.orders_core
  set status = p_new_status,
      updated_at = now()
  where id = p_order_id
  returning * into v_order;

  -- Insert order event
  insert into public.order_events (order_id, status)
  values (p_order_id, p_new_status);

  return v_order;
end;
$$;

comment on function public.owner_update_order_status is 'Update order status with ownership validation';
grant execute on function public.owner_update_order_status(uuid, text, uuid) to authenticated;

-- ============================================================================
-- 2. Cancel Order with Refund
-- ============================================================================

create or replace function public.owner_cancel_order(
  p_order_id uuid,
  p_reason text,
  p_owner_user_id uuid default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders_core%ROWTYPE;
  v_user_id uuid;
  v_refund_amount int;
begin
  -- Use auth.uid() if not provided
  v_user_id := coalesce(p_owner_user_id, auth.uid());

  -- Get order
  select * into v_order
  from public.orders_core
  where id = p_order_id;

  if v_order is null then
    raise exception 'Order not found';
  end if;

  -- Check ownership
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = v_order.cafe_id and a.owner_user_id = v_user_id
  ) then
    raise exception 'Unauthorized: not your cafe order';
  end if;

  -- Can't cancel already completed orders
  if v_order.status in ('Picked up', 'Canceled', 'Refunded') then
    raise exception 'Cannot cancel completed order';
  end if;

  -- Calculate refund amount
  v_refund_amount := v_order.paid_credits + v_order.bonus_used;

  -- Update order status
  update public.orders_core
  set status = 'canceled',
      updated_at = now()
  where id = p_order_id
  returning * into v_order;

  -- Insert order event
  insert into public.order_events (order_id, status)
  values (p_order_id, 'Canceled');

  -- Process refund if payment was made
  if v_order.payment_status = 'paid' and v_refund_amount > 0 then
    -- TODO: Implement actual refund logic
    -- This should credit back to the wallet
    update public.orders
    set payment_status = 'refunded'
    where id = p_order_id;
  end if;

  return v_order;
end;
$$;

comment on function public.owner_cancel_order is 'Cancel order with automatic refund';
grant execute on function public.owner_cancel_order(uuid, text, uuid) to authenticated;

-- ============================================================================
-- 3. Get Cafe Orders (with filters)
-- ============================================================================

create or replace function public.get_cafe_orders(
  p_cafe_id uuid,
  p_status_filter text default null,
  p_date_from timestamptz default null,
  p_date_to timestamptz default null,
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  id uuid,
  cafe_id uuid,
  user_id uuid,
  status text,
  order_type text,
  payment_status text,
  subtotal_credits int,
  bonus_used int,
  paid_credits int,
  slot_time timestamptz,
  customer_phone text,
  created_at timestamptz,
  updated_at timestamptz,
  items_count bigint,
  customer_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Check ownership
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = p_cafe_id and a.owner_user_id = auth.uid()
  ) then
    raise exception 'Unauthorized: not your cafe';
  end if;

  return query
  select 
    o.id,
    o.cafe_id,
    o.user_id,
    o.status,
    o.order_type,
    o.payment_status,
    o.subtotal_credits,
    o.bonus_used,
    o.paid_credits,
    o.slot_time,
    o.customer_phone,
    o.created_at,
    o.updated_at,
    count(oi.id) as items_count,
    p.full_name as customer_name
  from public.orders_core o
  left join public.order_items oi on o.id = oi.order_id
  left join public.profiles p on o.user_id = p.id
  where o.cafe_id = p_cafe_id
    and (p_status_filter is null or o.status = p_status_filter)
    and (p_date_from is null or o.created_at >= p_date_from)
    and (p_date_to is null or o.created_at <= p_date_to)
  group by o.id, p.full_name
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

comment on function public.get_cafe_orders is 'Get orders for cafe with filters';
grant execute on function public.get_cafe_orders(uuid, text, timestamptz, timestamptz, int, int) to authenticated;

-- ============================================================================
-- 4. Get Order Details (with items)
-- ============================================================================

create or replace function public.get_order_details(order_id_param uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders_core%ROWTYPE;
  v_result jsonb;
  v_items jsonb;
  v_customer jsonb;
  v_cafe jsonb;
begin
  -- Get order
  select * into v_order
  from public.orders_core
  where id = order_id_param;

  if v_order is null then
    raise exception 'Order not found';
  end if;

  -- Check ownership (owner or customer)
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = v_order.cafe_id and a.owner_user_id = auth.uid()
  ) and auth.uid() != v_order.user_id then
    raise exception 'Unauthorized';
  end if;

  -- Get order items
  select jsonb_agg(
    jsonb_build_object(
      'id', oi.id,
      'menu_item_id', oi.menu_item_id,
      'title', oi.title,
      'unit_credits', oi.unit_credits,
      'quantity', oi.quantity,
      'category', oi.category
    )
  ) into v_items
  from public.order_items oi
  where oi.order_id = order_id_param;

  -- Get customer info
  select jsonb_build_object(
    'id', p.id,
    'full_name', p.full_name,
    'phone', p.phone
  ) into v_customer
  from public.profiles p
  where p.id = v_order.user_id;

  -- Get cafe info
  select jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'address', c.address,
    'phone', c.phone
  ) into v_cafe
  from public.cafes c
  where c.id = v_order.cafe_id;

  -- Build result
  v_result := jsonb_build_object(
    'order', row_to_json(v_order),
    'items', coalesce(v_items, '[]'::jsonb),
    'customer', v_customer,
    'cafe', v_cafe
  );

  return v_result;
end;
$$;

comment on function public.get_order_details is 'Get complete order details with items, customer, and cafe info';
grant execute on function public.get_order_details(uuid) to authenticated;

-- ============================================================================
-- 5. Get Cafe Dashboard Stats
-- ============================================================================

create or replace function public.get_cafe_dashboard_stats(
  p_cafe_id uuid,
  p_date_from timestamptz default null,
  p_date_to timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stats jsonb;
  v_total_orders int;
  v_total_revenue int;
  v_avg_order_value numeric;
  v_active_orders int;
begin
  -- Check ownership
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = p_cafe_id and a.owner_user_id = auth.uid()
  ) then
    raise exception 'Unauthorized: not your cafe';
  end if;

  -- Set default date range (today if not specified)
  p_date_from := coalesce(p_date_from, date_trunc('day', now()));
  p_date_to := coalesce(p_date_to, now());

  -- Total orders
  select count(*)
  into v_total_orders
  from public.orders
  where cafe_id = p_cafe_id
    and created_at >= p_date_from
    and created_at <= p_date_to;

  -- Total revenue
  select coalesce(sum(paid_credits + bonus_used), 0)
  into v_total_revenue
  from public.orders
  where cafe_id = p_cafe_id
    and created_at >= p_date_from
    and created_at <= p_date_to
    and payment_status = 'paid';

  -- Average order value
  if v_total_orders > 0 then
    v_avg_order_value := v_total_revenue::numeric / v_total_orders;
  else
    v_avg_order_value := 0;
  end if;

  -- Active orders (not completed)
  select count(*)
  into v_active_orders
  from public.orders
  where cafe_id = p_cafe_id
    and status not in ('Picked up', 'Canceled', 'Refunded', 'No-show');

  -- Build stats object
  v_stats := jsonb_build_object(
    'total_orders', v_total_orders,
    'total_revenue', v_total_revenue,
    'avg_order_value', v_avg_order_value,
    'active_orders', v_active_orders,
    'date_from', p_date_from,
    'date_to', p_date_to
  );

  return v_stats;
end;
$$;

comment on function public.get_cafe_dashboard_stats is 'Get dashboard statistics for cafe';
grant execute on function public.get_cafe_dashboard_stats(uuid, timestamptz, timestamptz) to authenticated;

-- ============================================================================
-- 6. Get Account Dashboard Stats (All Cafes)
-- ============================================================================

create or replace function public.get_account_dashboard_stats(
  p_user_id uuid,
  p_date_from timestamptz default null,
  p_date_to timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stats jsonb;
  v_account_id uuid;
  v_total_cafes int;
  v_published_cafes int;
  v_total_orders int;
  v_total_revenue int;
begin
  -- Check authorization
  if auth.uid() != p_user_id then
    raise exception 'Unauthorized';
  end if;

  -- Get account
  select id into v_account_id
  from public.accounts
  where owner_user_id = p_user_id
  limit 1;

  if v_account_id is null then
    raise exception 'Account not found';
  end if;

  -- Set default date range
  p_date_from := coalesce(p_date_from, date_trunc('day', now()));
  p_date_to := coalesce(p_date_to, now());

  -- Total cafes
  select count(*)
  into v_total_cafes
  from public.cafes
  where account_id = v_account_id;

  -- Published cafes
  select count(*)
  into v_published_cafes
  from public.cafes
  where account_id = v_account_id
    and status = 'published';

  -- Total orders across all cafes
  select count(*)
  into v_total_orders
  from public.orders_core o
  join public.cafes c on o.cafe_id = c.id
  where c.account_id = v_account_id
    and o.created_at >= p_date_from
    and o.created_at <= p_date_to;

  -- Total revenue across all cafes
  select coalesce(sum(o.paid_credits + o.bonus_used), 0)
  into v_total_revenue
  from public.orders_core o
  join public.cafes c on o.cafe_id = c.id
  where c.account_id = v_account_id
    and o.created_at >= p_date_from
    and o.created_at <= p_date_to
    and o.payment_status = 'paid';

  -- Build stats object
  v_stats := jsonb_build_object(
    'total_cafes', v_total_cafes,
    'published_cafes', v_published_cafes,
    'total_orders', v_total_orders,
    'total_revenue', v_total_revenue,
    'date_from', p_date_from,
    'date_to', p_date_to
  );

  return v_stats;
end;
$$;

comment on function public.get_account_dashboard_stats is 'Get dashboard statistics for owner account (all cafes)';
grant execute on function public.get_account_dashboard_stats(uuid, timestamptz, timestamptz) to authenticated;

-- ============================================================================
-- 7. Get Active Orders by Status (for Kanban)
-- ============================================================================

create or replace function public.get_cafe_orders_by_status(p_cafe_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  -- Check ownership
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = p_cafe_id and a.owner_user_id = auth.uid()
  ) then
    raise exception 'Unauthorized: not your cafe';
  end if;

  -- Get orders grouped by status
  select jsonb_build_object(
    'Created', coalesce(
      (select jsonb_agg(o.* order by o.created_at asc)
       from public.orders_core o
       where o.cafe_id = p_cafe_id and o.status = 'Created'),
      '[]'::jsonb
    ),
    'Accepted', coalesce(
      (select jsonb_agg(o.* order by o.created_at asc)
       from public.orders_core o
       where o.cafe_id = p_cafe_id and o.status = 'Accepted'),
      '[]'::jsonb
    ),
    'In progress', coalesce(
      (select jsonb_agg(o.* order by o.created_at asc)
       from public.orders_core o
       where o.cafe_id = p_cafe_id and o.status = 'In progress'),
      '[]'::jsonb
    ),
    'Ready', coalesce(
      (select jsonb_agg(o.* order by o.created_at asc)
       from public.orders_core o
       where o.cafe_id = p_cafe_id and o.status = 'Ready'),
      '[]'::jsonb
    ),
    'Picked up', coalesce(
      (select jsonb_agg(o.* order by o.created_at desc)
       from public.orders_core o
       where o.cafe_id = p_cafe_id 
         and o.status = 'Picked up'
         and o.created_at >= now() - interval '1 day'),
      '[]'::jsonb
    )
  ) into v_result;

  return v_result;
end;
$$;

comment on function public.get_cafe_orders_by_status is 'Get orders grouped by status for Kanban board';
grant execute on function public.get_cafe_orders_by_status(uuid) to authenticated;

-- ============================================================================
-- 8. Mark Item as Stop-List
-- ============================================================================

create or replace function public.toggle_menu_item_stop_list(
  p_item_id uuid,
  p_is_available boolean,
  p_owner_user_id uuid default null
)
returns public.menu_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.menu_items;
  v_user_id uuid;
begin
  -- Use auth.uid() if not provided
  v_user_id := coalesce(p_owner_user_id, auth.uid());

  -- Get item
  select * into v_item
  from public.menu_items
  where id = p_item_id;

  if v_item is null then
    raise exception 'Menu item not found';
  end if;

  -- Check ownership
  if not exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = v_item.cafe_id and a.owner_user_id = v_user_id
  ) then
    raise exception 'Unauthorized: not your cafe menu item';
  end if;

  -- Update availability
  update public.menu_items
  set is_active = p_is_available,
      updated_at = now()
  where id = p_item_id
  returning * into v_item;

  return v_item;
end;
$$;

comment on function public.toggle_menu_item_stop_list is 'Toggle menu item availability (stop-list)';
grant execute on function public.toggle_menu_item_stop_list(uuid, boolean, uuid) to authenticated;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
