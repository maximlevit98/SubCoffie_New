-- Align schema with SUPABASE_API_CONTRACT
-- Ensure menu_items.name exists for legacy clients and keep it in sync with title.

create extension if not exists "pgcrypto";

-- menu_items: ensure name column exists and sync with title
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_items' and column_name = 'name'
  ) then
    alter table public.menu_items add column name text;
  end if;
end$$;

update public.menu_items
set name = coalesce(name, title)
where name is null and title is not null;

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

drop trigger if exists tg_menu_items_sync_name_title on public.menu_items;
create trigger tg_menu_items_sync_name_title
before insert or update on public.menu_items
for each row execute function public.tg__menu_items_sync_name_title();

alter table public.menu_items
  alter column name set not null;

-- Required indexes
create index if not exists menu_items_cafe_id_idx on public.menu_items (cafe_id);
create index if not exists menu_items_cafe_category_order_idx on public.menu_items (cafe_id, category, sort_order);
create index if not exists order_items_order_id_idx on public.order_items (order_id);
create index if not exists order_events_core_order_created_idx on public.order_events_core (order_id, created_at asc);
