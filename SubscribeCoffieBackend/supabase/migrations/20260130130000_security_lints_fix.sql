-- Security lint fixes: tighten RLS, set view security invoker, lock search_path

-- Views should run with invoker rights to avoid SECURITY DEFINER warnings.
alter view public.orders set (security_invoker = true);
alter view public.order_events set (security_invoker = true);

-- Ensure order_qr_tokens is protected by RLS (access via SECURITY DEFINER RPC).
alter table public.order_qr_tokens enable row level security;

-- Drop overly permissive policies.
drop policy if exists anon_all_order_items on public.order_items;
drop policy if exists anon_all_order_events on public.order_events_core;
drop policy if exists anon_insert_orders on public.orders_core;
drop policy if exists anon_update_orders_no_status_change on public.orders_core;

-- Orders: allow anon/auth access only to their own orders (or anon with null user_id).
drop policy if exists orders_core_select_own on public.orders_core;
create policy orders_core_select_own
  on public.orders_core
  for select to anon, authenticated
  using (
    (auth.uid() is not null and user_id = auth.uid())
    or (auth.uid() is null and user_id is null)
  );

drop policy if exists orders_core_insert_own on public.orders_core;
create policy orders_core_insert_own
  on public.orders_core
  for insert to anon, authenticated
  with check (
    (auth.uid() is not null and user_id = auth.uid())
    or (auth.uid() is null and user_id is null)
  );

drop policy if exists orders_core_update_own_no_status_change on public.orders_core;
create policy orders_core_update_own_no_status_change
  on public.orders_core
  for update to anon, authenticated
  using (
    (auth.uid() is not null and user_id = auth.uid())
    or (auth.uid() is null and user_id is null)
  )
  with check (
    status = (select o.status from public.orders_core o where o.id = orders_core.id)
    and (
      (auth.uid() is not null and user_id = auth.uid())
      or (auth.uid() is null and user_id is null)
    )
  );

-- Order items: restrict to orders owned by the same user (or anon with null user_id).
drop policy if exists order_items_select_own on public.order_items;
create policy order_items_select_own
  on public.order_items
  for select to anon, authenticated
  using (
    exists (
      select 1
      from public.orders_core o
      where o.id = order_items.order_id
        and (
          (auth.uid() is not null and o.user_id = auth.uid())
          or (auth.uid() is null and o.user_id is null)
        )
    )
  );

drop policy if exists order_items_insert_own on public.order_items;
create policy order_items_insert_own
  on public.order_items
  for insert to anon, authenticated
  with check (
    exists (
      select 1
      from public.orders_core o
      where o.id = order_items.order_id
        and (
          (auth.uid() is not null and o.user_id = auth.uid())
          or (auth.uid() is null and o.user_id is null)
        )
    )
  );

-- Order events core: restrict to orders owned by the same user (or anon with null user_id).
drop policy if exists order_events_core_select_own on public.order_events_core;
create policy order_events_core_select_own
  on public.order_events_core
  for select to anon, authenticated
  using (
    exists (
      select 1
      from public.orders_core o
      where o.id = order_events_core.order_id
        and (
          (auth.uid() is not null and o.user_id = auth.uid())
          or (auth.uid() is null and o.user_id is null)
        )
    )
  );

drop policy if exists order_events_core_insert_own on public.order_events_core;
create policy order_events_core_insert_own
  on public.order_events_core
  for insert to anon, authenticated
  with check (
    exists (
      select 1
      from public.orders_core o
      where o.id = order_events_core.order_id
        and (
          (auth.uid() is not null and o.user_id = auth.uid())
          or (auth.uid() is null and o.user_id is null)
        )
    )
  );

-- Lock down function search_path to avoid role-mutable search_path warnings.
alter function public.tg__set_updated_at() set search_path = public, extensions;
alter function public.tg__update_timestamp() set search_path = public, extensions;
alter function public.sc_status_from_legacy(text) set search_path = public, extensions;
alter function public.sc_status_to_legacy(text) set search_path = public, extensions;
alter function public.orders_view_insert() set search_path = public, extensions;
alter function public.orders_view_update() set search_path = public, extensions;
alter function public.orders_view_delete() set search_path = public, extensions;
alter function public.order_events_view_insert() set search_path = public, extensions;
alter function public.order_events_view_update() set search_path = public, extensions;
alter function public.order_events_view_delete() set search_path = public, extensions;
alter function public.tg__menu_items_sync_name_title() set search_path = public, extensions;
alter function public.get_time_slots(uuid, jsonb, timestamptz) set search_path = public, extensions;
alter function public.calculate_ready_slots(uuid, jsonb) set search_path = public, extensions;
