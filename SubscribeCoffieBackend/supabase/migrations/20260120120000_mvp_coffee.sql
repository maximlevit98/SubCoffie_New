-- MVP coffee schema, RLS, and helper functions
-- Safe to run on clean Supabase local.

-- Ensure UUID helpers
create extension if not exists "pgcrypto";

-- Updated_at helper trigger
create or replace function public.tg__update_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Cafes
create table if not exists public.cafes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  mode text not null,
  eta_minutes int,
  active_orders int not null default 0,
  max_active_orders int,
  distance_km numeric,
  supports_citypass boolean not null default true,
  brand_id uuid,
  created_at timestamptz not null default now(),
  constraint cafes_mode_check check (mode in ('open','busy','paused','closed'))
);
create index if not exists cafes_supports_citypass_idx on public.cafes (supports_citypass);
create index if not exists cafes_brand_id_idx on public.cafes (brand_id);

-- Products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  category text not null,
  name text not null,
  description text,
  price_credits int not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint products_category_check check (category in ('drinks','food','syrups','merch'))
);
create index if not exists products_cafe_category_idx on public.products (cafe_id, category);

-- Menu items (for app REST consumption)
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  category text not null,
  name text not null,
  description text not null,
  price_credits int not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint menu_items_category_check check (category in ('drinks','food','syrups','merch'))
);
create index if not exists menu_items_cafe_id_idx on public.menu_items (cafe_id);
create index if not exists menu_items_cafe_category_order_idx on public.menu_items (cafe_id, category, sort_order);

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  full_name text,
  birth_date date,
  city text,
  default_wallet_type text not null default 'citypass',
  default_cafe_id uuid references public.cafes(id),
  created_at timestamptz not null default now(),
  constraint profiles_default_wallet_type_check check (default_wallet_type in ('citypass','cafe'))
);

-- Wallets
create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  cafe_id uuid references public.cafes(id) on delete cascade,
  credits_balance int not null default 0,
  bonus_balance int not null default 0,
  updated_at timestamptz not null default now(),
  constraint wallets_type_check check (type in ('citypass','cafe')),
  constraint wallets_cafe_required check ((type <> 'cafe') or (cafe_id is not null))
);
create unique index if not exists wallets_citypass_unique_idx on public.wallets(user_id) where type = 'citypass';
create unique index if not exists wallets_cafe_unique_idx on public.wallets(user_id, cafe_id) where type = 'cafe';
create index if not exists wallets_user_id_idx on public.wallets (user_id);
create index if not exists wallets_cafe_id_idx on public.wallets (cafe_id);
drop trigger if exists set_wallets_updated_at on public.wallets;
create trigger set_wallets_updated_at before update on public.wallets for each row execute function public.tg__update_timestamp();

-- Orders
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  status text not null,
  subtotal_credits int not null,
  bonus_used int not null default 0,
  paid_credits int not null default 0,
  wallet_id uuid not null references public.wallets(id),
  eta_minutes int,
  created_at timestamptz not null default now(),
  constraint orders_status_check check (status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show'))
);
create index if not exists orders_user_id_idx on public.orders (user_id);
create index if not exists orders_cafe_id_idx on public.orders (cafe_id);
create index if not exists orders_status_idx on public.orders (status);

-- Order items
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  title text not null,
  unit_credits int not null,
  qty int not null,
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_id_idx on public.order_items (order_id);

-- RLS
alter table public.cafes enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='cafes' and policyname='Public read cafes'
  ) then
    create policy "Public read cafes" on public.cafes
      for select to anon, authenticated using (true);
  end if;
end$$;

alter table public.products enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='products' and policyname='Public read products'
  ) then
    create policy "Public read products" on public.products
      for select to anon, authenticated using (true);
  end if;
end$$;

alter table public.menu_items enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='menu_items' and policyname='Public read menu_items'
  ) then
    create policy "Public read menu_items" on public.menu_items
      for select to anon, authenticated using (true);
  end if;
end$$;

alter table public.profiles enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Own profile select'
  ) then
    create policy "Own profile select" on public.profiles
      for select using (auth.uid() = id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Own profile update'
  ) then
    create policy "Own profile update" on public.profiles
      for update using (auth.uid() = id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Own profile insert'
  ) then
    create policy "Own profile insert" on public.profiles
      for insert with check (auth.uid() = id);
  end if;
end$$;

alter table public.wallets enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='wallets' and policyname='Own wallets select'
  ) then
    create policy "Own wallets select" on public.wallets
      for select using (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='wallets' and policyname='Own wallets insert'
  ) then
    create policy "Own wallets insert" on public.wallets
      for insert with check (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='wallets' and policyname='Own wallets update'
  ) then
    create policy "Own wallets update" on public.wallets
      for update using (auth.uid() = user_id);
  end if;
end$$;

alter table public.orders enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='orders' and policyname='Own orders select'
  ) then
    create policy "Own orders select" on public.orders
      for select using (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='orders' and policyname='Own orders insert'
  ) then
    create policy "Own orders insert" on public.orders
      for insert with check (auth.uid() = user_id);
  end if;
end$$;

alter table public.order_items enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='order_items' and policyname='Order items select own'
  ) then
    create policy "Order items select own" on public.order_items
      for select using (
        exists (
          select 1 from public.orders o
          where o.id = order_id and o.user_id = auth.uid()
        )
      );
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='order_items' and policyname='Order items insert own order'
  ) then
    create policy "Order items insert own order" on public.order_items
      for insert with check (
        exists (
          select 1 from public.orders o
          where o.id = order_id and o.user_id = auth.uid()
        )
      );
  end if;
end$$;

-- Helper functions
create or replace function public.get_or_create_citypass_wallet(p_user uuid)
returns public.wallets
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  w public.wallets;
begin
  if auth.role() <> 'service_role' and auth.uid() <> p_user then
    raise exception 'unauthorized';
  end if;

  select * into w from public.wallets
  where user_id = p_user and type = 'citypass'
  limit 1;

  if not found then
    insert into public.wallets (id, user_id, type, credits_balance, bonus_balance)
    values (gen_random_uuid(), p_user, 'citypass', 0, 0)
    returning * into w;
  end if;

  return w;
end;
$$;
grant execute on function public.get_or_create_citypass_wallet(uuid) to authenticated;

create or replace function public.get_or_create_cafe_wallet(p_user uuid, p_cafe uuid)
returns public.wallets
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  w public.wallets;
begin
  if auth.role() <> 'service_role' and auth.uid() <> p_user then
    raise exception 'unauthorized';
  end if;

  select * into w from public.wallets
  where user_id = p_user and type = 'cafe' and cafe_id = p_cafe
  limit 1;

  if not found then
    insert into public.wallets (id, user_id, type, cafe_id, credits_balance, bonus_balance)
    values (gen_random_uuid(), p_user, 'cafe', p_cafe, 0, 0)
    returning * into w;
  end if;

  return w;
end;
$$;
grant execute on function public.get_or_create_cafe_wallet(uuid, uuid) to authenticated;

create or replace function public.init_user_profile_and_wallets(
  p_user uuid,
  p_phone text,
  p_full_name text,
  p_birth date,
  p_city text
) returns public.profiles
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  profile_row public.profiles;
begin
  if auth.role() <> 'service_role' and auth.uid() <> p_user then
    raise exception 'unauthorized';
  end if;

  insert into public.profiles (id, phone, full_name, birth_date, city, default_wallet_type)
  values (p_user, p_phone, p_full_name, p_birth, p_city, 'citypass')
  on conflict (id) do update
    set phone = excluded.phone,
        full_name = excluded.full_name,
        birth_date = excluded.birth_date,
        city = excluded.city,
        default_wallet_type = excluded.default_wallet_type
  returning * into profile_row;

  perform public.get_or_create_citypass_wallet(p_user);

  return profile_row;
end;
$$;
grant execute on function public.init_user_profile_and_wallets(uuid, text, text, date, text) to authenticated;
