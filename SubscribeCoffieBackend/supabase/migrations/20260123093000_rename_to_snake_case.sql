-- Normalize schema: snake_case identifiers + lower_snake statuses
-- Keep frontend compatibility via legacy views for orders + order_events.

create extension if not exists "pgcrypto";

-- Unified updated_at trigger
create or replace function public.tg__update_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Status mapping helpers (legacy <-> normalized)
create or replace function public.sc_status_from_legacy(p_status text)
returns text
language sql
as $$
  select case
    when p_status is null then null
    when p_status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show') then p_status
    when p_status = 'Created' then 'created'
    when p_status = 'Accepted' then 'accepted'
    when p_status = 'Rejected' then 'rejected'
    when p_status = 'In progress' then 'in_progress'
    when p_status = 'Ready' then 'ready'
    when p_status = 'Picked up' then 'picked_up'
    when p_status = 'Canceled' then 'canceled'
    when p_status = 'Refunded' then 'refunded'
    when p_status = 'No-show' then 'no_show'
    else lower(replace(p_status, ' ', '_'))
  end;
$$;

create or replace function public.sc_status_to_legacy(p_status text)
returns text
language sql
as $$
  select case
    when p_status is null then null
    when p_status = 'created' then 'Created'
    when p_status = 'accepted' then 'Accepted'
    when p_status = 'rejected' then 'Rejected'
    when p_status = 'in_progress' then 'In progress'
    when p_status = 'ready' then 'Ready'
    when p_status = 'picked_up' then 'Picked up'
    when p_status = 'canceled' then 'Canceled'
    when p_status = 'refunded' then 'Refunded'
    when p_status = 'no_show' then 'No-show'
    else p_status
  end;
$$;

-- Rename orders + order_events to core tables (keep legacy view names)
do $$
begin
  if to_regclass('public.orders_core') is null and to_regclass('public.orders') is not null then
    alter table public.orders rename to orders_core;
  end if;
  if to_regclass('public.order_events_core') is null and to_regclass('public.order_events') is not null then
    alter table public.order_events rename to order_events_core;
  end if;
end$$;

-- Ensure expected columns and naming (orders_core)
alter table public.orders_core
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists cafe_id uuid,
  add column if not exists customer_phone text,
  add column if not exists status text,
  add column if not exists eta_minutes int not null default 0,
  add column if not exists subtotal_credits int not null default 0,
  add column if not exists bonus_used int not null default 0,
  add column if not exists paid_credits int not null default 0,
  add column if not exists pickup_deadline timestamptz,
  add column if not exists no_show_at timestamptz,
  add column if not exists user_id uuid,
  add column if not exists wallet_id uuid;

-- Allow demo data without auth user/wallet.
do $$
begin
  alter table public.orders_core alter column user_id drop not null;
exception
  when others then
    null;
end$$;

do $$
begin
  alter table public.orders_core alter column wallet_id drop not null;
exception
  when others then
    null;
end$$;

update public.orders_core
set status = public.sc_status_from_legacy(status)
where status is not null;

alter table public.orders_core drop constraint if exists orders_status_check;
alter table public.orders_core
  add constraint orders_status_check
  check (status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show'));

drop trigger if exists tg_orders_core_updated_at on public.orders_core;
create trigger tg_orders_core_updated_at before update on public.orders_core
for each row execute function public.tg__update_timestamp();

-- order_items naming normalization
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'qty'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'quantity'
  ) then
    alter table public.order_items rename column qty to quantity;
  end if;
end$$;

-- Ensure menu_item_id exists for contract compatibility (seed uses this column).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'menu_item_id'
  ) then
    alter table public.order_items add column menu_item_id uuid;
  end if;
end$$;

-- Allow legacy product_id to be nullable when using menu_item_id.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'product_id'
  ) then
    alter table public.order_items alter column product_id drop not null;
  end if;
exception
  when others then
    null;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.order_items'::regclass
      and contype = 'f'
      and pg_get_constraintdef(oid) like '%(menu_item_id)%'
  ) then
    alter table public.order_items
      add constraint order_items_menu_item_id_fkey foreign key (menu_item_id)
      references public.menu_items(id);
  end if;
end$$;

-- Ensure category column exists and is compatible with contract.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'category'
  ) then
    alter table public.order_items add column category text;
  end if;
end$$;

update public.order_items
set category = 'drinks'
where category is null;

do $$
begin
  alter table public.order_items alter column category set not null;
exception
  when others then
    null;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.order_items'::regclass
      and contype = 'c'
      and conname = 'order_items_category_check'
  ) then
    alter table public.order_items
      add constraint order_items_category_check
      check (category in ('drinks','food','syrups','merch'));
  end if;
end$$;

alter table public.order_items
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'line_total'
  ) then
    alter table public.order_items
      add column line_total int generated always as (unit_credits * quantity) stored;
  end if;
end$$;

drop trigger if exists tg_order_items_updated_at on public.order_items;
create trigger tg_order_items_updated_at before update on public.order_items
for each row execute function public.tg__update_timestamp();

-- order_events_core naming + status normalization
alter table public.order_events_core
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists status text;

update public.order_events_core
set status = public.sc_status_from_legacy(status)
where status is not null;

alter table public.order_events_core drop constraint if exists order_events_status_check;
alter table public.order_events_core
  add constraint order_events_status_check
  check (status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show'));

drop trigger if exists tg_order_events_updated_at on public.order_events_core;
create trigger tg_order_events_updated_at before update on public.order_events_core
for each row execute function public.tg__update_timestamp();

-- Fix FKs to orders_core
do $$
declare
  fk_name text;
begin
  select conname into fk_name
  from pg_constraint
  where conrelid = 'public.order_items'::regclass
    and contype = 'f'
    and pg_get_constraintdef(oid) like '%(order_id)%';
  if fk_name is not null then
    execute format('alter table public.order_items drop constraint if exists %I', fk_name);
  end if;
  alter table public.order_items
    add constraint order_items_order_id_fkey foreign key (order_id)
    references public.orders_core(id) on delete cascade;
end$$;

do $$
declare
  fk_name text;
begin
  select conname into fk_name
  from pg_constraint
  where conrelid = 'public.order_events_core'::regclass
    and contype = 'f'
    and pg_get_constraintdef(oid) like '%(order_id)%';
  if fk_name is not null then
    execute format('alter table public.order_events_core drop constraint if exists %I', fk_name);
  end if;
  alter table public.order_events_core
    add constraint order_events_order_id_fkey foreign key (order_id)
    references public.orders_core(id) on delete cascade;
end$$;

-- cafes/products/menu_items normalization
alter table public.cafes
  add column if not exists updated_at timestamptz not null default now();
drop trigger if exists tg_cafes_updated_at on public.cafes;
create trigger tg_cafes_updated_at before update on public.cafes
for each row execute function public.tg__update_timestamp();

alter table public.products
  add column if not exists updated_at timestamptz not null default now();
drop trigger if exists tg_products_updated_at on public.products;
create trigger tg_products_updated_at before update on public.products
for each row execute function public.tg__update_timestamp();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'is_active'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'is_available'
  ) then
    alter table public.menu_items rename column is_active to is_available;
  end if;
end$$;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'name'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'title'
  ) then
    alter table public.menu_items rename column name to title;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'name'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'title'
  ) then
    alter table public.menu_items drop column name;
  end if;
end$$;

alter table public.menu_items
  add column if not exists description text,
  add column if not exists sort_order int not null default 0,
  add column if not exists is_available boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists tg_menu_items_updated_at on public.menu_items;
create trigger tg_menu_items_updated_at before update on public.menu_items
for each row execute function public.tg__update_timestamp();

-- profiles + wallets updated_at for consistency
alter table public.profiles
  add column if not exists updated_at timestamptz not null default now();
drop trigger if exists tg_profiles_updated_at on public.profiles;
create trigger tg_profiles_updated_at before update on public.profiles
for each row execute function public.tg__update_timestamp();

alter table public.wallets
  add column if not exists updated_at timestamptz not null default now();
drop trigger if exists tg_wallets_updated_at on public.wallets;
create trigger tg_wallets_updated_at before update on public.wallets
for each row execute function public.tg__update_timestamp();

-- Legacy compatibility views for REST
drop view if exists public.orders;
create view public.orders as
select
  id,
  created_at,
  updated_at,
  cafe_id,
  customer_phone,
  public.sc_status_to_legacy(status) as status,
  eta_minutes,
  subtotal_credits,
  bonus_used,
  paid_credits,
  pickup_deadline,
  no_show_at,
  user_id,
  wallet_id
from public.orders_core;

drop view if exists public.order_events;
create view public.order_events as
select
  id,
  order_id,
  public.sc_status_to_legacy(status) as status,
  created_at,
  updated_at
from public.order_events_core;

-- Updatable view triggers for legacy REST writes
create or replace function public.orders_view_insert()
returns trigger
language plpgsql
as $$
declare
  r public.orders_core%rowtype;
begin
  insert into public.orders_core (
    id, created_at, updated_at, cafe_id, customer_phone, status,
    eta_minutes, subtotal_credits, bonus_used, paid_credits,
    pickup_deadline, no_show_at, user_id, wallet_id
  ) values (
    coalesce(new.id, gen_random_uuid()),
    coalesce(new.created_at, now()),
    coalesce(new.updated_at, now()),
    new.cafe_id,
    new.customer_phone,
    public.sc_status_from_legacy(new.status),
    coalesce(new.eta_minutes, 0),
    coalesce(new.subtotal_credits, 0),
    coalesce(new.bonus_used, 0),
    coalesce(new.paid_credits, 0),
    new.pickup_deadline,
    new.no_show_at,
    new.user_id,
    new.wallet_id
  )
  returning * into r;

  new.id = r.id;
  new.created_at = r.created_at;
  new.updated_at = r.updated_at;
  new.status = public.sc_status_to_legacy(r.status);
  return new;
end;
$$;

create or replace function public.orders_view_update()
returns trigger
language plpgsql
as $$
declare
  r public.orders_core%rowtype;
begin
  update public.orders_core
  set
    cafe_id = coalesce(new.cafe_id, orders_core.cafe_id),
    customer_phone = coalesce(new.customer_phone, orders_core.customer_phone),
    status = public.sc_status_from_legacy(coalesce(new.status, orders_core.status)),
    eta_minutes = coalesce(new.eta_minutes, orders_core.eta_minutes),
    subtotal_credits = coalesce(new.subtotal_credits, orders_core.subtotal_credits),
    bonus_used = coalesce(new.bonus_used, orders_core.bonus_used),
    paid_credits = coalesce(new.paid_credits, orders_core.paid_credits),
    pickup_deadline = coalesce(new.pickup_deadline, orders_core.pickup_deadline),
    no_show_at = coalesce(new.no_show_at, orders_core.no_show_at),
    user_id = coalesce(new.user_id, orders_core.user_id),
    wallet_id = coalesce(new.wallet_id, orders_core.wallet_id),
    updated_at = now()
  where id = old.id
  returning * into r;

  new.id = r.id;
  new.created_at = r.created_at;
  new.updated_at = r.updated_at;
  new.status = public.sc_status_to_legacy(r.status);
  return new;
end;
$$;

create or replace function public.orders_view_delete()
returns trigger
language plpgsql
as $$
begin
  delete from public.orders_core where id = old.id;
  return old;
end;
$$;

drop trigger if exists orders_view_insert on public.orders;
drop trigger if exists orders_view_update on public.orders;
drop trigger if exists orders_view_delete on public.orders;

create trigger orders_view_insert instead of insert on public.orders
for each row execute function public.orders_view_insert();

create trigger orders_view_update instead of update on public.orders
for each row execute function public.orders_view_update();

create trigger orders_view_delete instead of delete on public.orders
for each row execute function public.orders_view_delete();

create or replace function public.order_events_view_insert()
returns trigger
language plpgsql
as $$
declare
  r public.order_events_core%rowtype;
begin
  insert into public.order_events_core (
    id, order_id, status, created_at, updated_at
  ) values (
    coalesce(new.id, gen_random_uuid()),
    new.order_id,
    public.sc_status_from_legacy(new.status),
    coalesce(new.created_at, now()),
    coalesce(new.updated_at, now())
  )
  returning * into r;

  new.id = r.id;
  new.status = public.sc_status_to_legacy(r.status);
  new.created_at = r.created_at;
  new.updated_at = r.updated_at;
  return new;
end;
$$;

create or replace function public.order_events_view_update()
returns trigger
language plpgsql
as $$
declare
  r public.order_events_core%rowtype;
begin
  update public.order_events_core
  set
    status = public.sc_status_from_legacy(coalesce(new.status, order_events_core.status)),
    updated_at = now()
  where id = old.id
  returning * into r;

  new.id = r.id;
  new.status = public.sc_status_to_legacy(r.status);
  new.created_at = r.created_at;
  new.updated_at = r.updated_at;
  return new;
end;
$$;

create or replace function public.order_events_view_delete()
returns trigger
language plpgsql
as $$
begin
  delete from public.order_events_core where id = old.id;
  return old;
end;
$$;

drop trigger if exists order_events_view_insert on public.order_events;
drop trigger if exists order_events_view_update on public.order_events;
drop trigger if exists order_events_view_delete on public.order_events;

create trigger order_events_view_insert instead of insert on public.order_events
for each row execute function public.order_events_view_insert();

create trigger order_events_view_update instead of update on public.order_events
for each row execute function public.order_events_view_update();

create trigger order_events_view_delete instead of delete on public.order_events
for each row execute function public.order_events_view_delete();
