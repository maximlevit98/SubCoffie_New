-- Restore/create menu_items table for REST consumption
create extension if not exists "pgcrypto";

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  category text not null,
  title text not null,
  name text not null,
  description text,
  price_credits int not null,
  sort_order int not null default 0,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  constraint menu_items_category_check check (category in ('drinks','food','syrups','merch'))
);

create index if not exists menu_items_cafe_id_idx on public.menu_items (cafe_id);
create index if not exists menu_items_cafe_category_order_idx on public.menu_items (cafe_id, category, sort_order);

-- RLS select open for anon/auth (MVP)
alter table public.menu_items enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='menu_items' and policyname='anon_select_menu_items_v2'
  ) then
    create policy "anon_select_menu_items_v2" on public.menu_items
      for select to anon, authenticated using (true);
  end if;
end$$;
