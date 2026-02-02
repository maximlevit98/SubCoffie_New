-- Ensure menu_items exists and is exposed via REST (schema cache) with public SELECT.
-- Each DDL line is commented for clarity.

-- Ensure UUID generator is available.
create extension if not exists "pgcrypto";

-- Create table if missing with contract fields.
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(), -- unique identifier
  cafe_id uuid not null references public.cafes(id) on delete cascade, -- FK to cafes
  category text not null, -- drinks/food/syrups/merch
  title text not null, -- display title
  name text not null, -- legacy alias of title
  description text null, -- optional description
  price_credits int not null, -- price in credits
  sort_order int not null default 0, -- ordering within category
  is_available boolean not null default true, -- availability flag
  created_at timestamptz not null default now(), -- creation timestamp
  updated_at timestamptz not null default now(), -- update timestamp
  constraint menu_items_category_check check (category in ('drinks','food','syrups','merch')) -- valid categories
);

-- Add missing columns if table already exists (safe for partial schema).
alter table public.menu_items
  add column if not exists title text, -- ensure title exists
  add column if not exists name text, -- ensure name exists
  add column if not exists description text, -- ensure description exists
  add column if not exists price_credits int, -- ensure price exists
  add column if not exists sort_order int default 0, -- ensure sort order exists
  add column if not exists prep_time_sec int not null default 0, -- prep time in seconds
  add column if not exists is_available boolean default true, -- ensure availability exists
  add column if not exists created_at timestamptz default now(), -- ensure created_at exists
  add column if not exists updated_at timestamptz default now(); -- ensure updated_at exists

-- Keep legacy name/title in sync for REST compatibility.
create or replace function public.tg__menu_items_sync_name_title()
returns trigger
language plpgsql
as $$
begin
  if new.title is null and new.name is not null then
    new.title = new.name;
  end if;
  if new.name is null and new.title is not null then
    new.name = new.title;
  end if;
  return new;
end;
$$;

drop trigger if exists tg_menu_items_sync_name_title on public.menu_items; -- drop old trigger if present
create trigger tg_menu_items_sync_name_title -- create sync trigger
before insert or update on public.menu_items
for each row execute function public.tg__menu_items_sync_name_title();

-- Indexes for common lookups.
create index if not exists menu_items_cafe_id_idx on public.menu_items (cafe_id); -- by cafe
create index if not exists menu_items_cafe_category_order_idx on public.menu_items (cafe_id, category, sort_order); -- menu sorting

-- Enable RLS and allow public read for anon/auth.
alter table public.menu_items enable row level security; -- enable RLS
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'menu_items' and policyname = 'public_select_menu_items'
  ) then
    create policy public_select_menu_items on public.menu_items -- allow read for anon/auth
      for select to anon, authenticated using (true);
  end if;
end$$;
