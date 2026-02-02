-- Orders MVP schema
create extension if not exists "pgcrypto";

-- Helper trigger for updated_at
create or replace function public.tg__set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- orders table
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cafe_id uuid not null references public.cafes(id) on delete restrict,
  customer_phone text not null,
  status text not null,
  eta_minutes int not null default 0,
  subtotal_credits int not null default 0,
  bonus_used int not null default 0,
  paid_credits int not null default 0,
  pickup_deadline timestamptz null,
  no_show_at timestamptz null,
  constraint orders_status_check check (status in (
    'Created','Accepted','Rejected','In progress','Ready','Picked up','Canceled','Refunded','No-show'
  ))
);
create index if not exists orders_cafe_created_idx on public.orders (cafe_id, created_at desc);
-- Ensure customer_phone exists before creating index (idempotent with earlier migrations).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'orders' and column_name = 'customer_phone'
  ) then
    alter table public.orders add column customer_phone text; -- add missing column
    update public.orders set customer_phone = '' where customer_phone is null; -- avoid nulls
    alter table public.orders alter column customer_phone set not null; -- enforce contract
  end if;
end$$;
create index if not exists orders_phone_created_idx on public.orders (customer_phone, created_at desc);
drop trigger if exists tg_orders_updated_at on public.orders;
create trigger tg_orders_updated_at
before update on public.orders
for each row execute function public.tg__set_updated_at();

-- order_items
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid null references public.menu_items(id),
  title text not null,
  unit_credits int not null,
  quantity int not null,
  line_total int generated always as (unit_credits * quantity) stored,
  category text not null,
  created_at timestamptz not null default now(),
  constraint order_items_category_check check (category in ('drinks','food','syrups','merch'))
);
create index if not exists order_items_order_idx on public.order_items (order_id);

-- order_events
create table if not exists public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  created_at timestamptz not null default now()
);
create index if not exists order_events_order_created_idx on public.order_events (order_id, created_at asc);

-- RLS: enable and allow anon/auth SELECT/INSERT/UPDATE for MVP local
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='orders' and policyname='anon_all_orders'
  ) then
    create policy anon_all_orders on public.orders
      for all to anon, authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='order_items' and policyname='anon_all_order_items'
  ) then
    create policy anon_all_order_items on public.order_items
      for all to anon, authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='order_events' and policyname='anon_all_order_events'
  ) then
    create policy anon_all_order_events on public.order_events
      for all to anon, authenticated using (true) with check (true);
  end if;
end$$;
