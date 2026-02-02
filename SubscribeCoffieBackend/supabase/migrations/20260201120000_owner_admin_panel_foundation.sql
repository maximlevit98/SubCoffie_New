-- ============================================================================
-- Owner Admin Panel - Backend Foundation
-- ============================================================================
-- Description: Core tables, RLS policies, and API functions for Owner Admin Panel
-- Date: 2026-02-01
--
-- This migration creates:
-- 1. accounts table (organization/owner level)
-- 2. Enhanced cafes table with status machine
-- 3. menu_categories table
-- 4. menu_modifiers table
-- 5. cafe_publication_history table
-- 6. RLS policies for owner access
-- 7. Helper functions for owner operations
-- ============================================================================

-- ============================================================================
-- 1. Accounts Table (Organization Level)
-- ============================================================================

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  company_name text not null,
  inn text, -- Russian Tax ID
  bank_details jsonb, -- Bank account information
  legal_address text,
  contact_phone text,
  contact_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.accounts is 'Owner accounts (organizations) that can manage multiple cafes';
comment on column public.accounts.inn is 'Russian Tax ID (ИНН)';
comment on column public.accounts.bank_details is 'Bank account details for payouts';

create unique index if not exists accounts_owner_user_id_idx on public.accounts(owner_user_id);
create index if not exists accounts_created_at_idx on public.accounts(created_at desc);

-- Enable RLS
alter table public.accounts enable row level security;

-- Trigger for updated_at
drop trigger if exists tg_accounts_updated_at on public.accounts;
create trigger tg_accounts_updated_at
  before update on public.accounts
  for each row execute function public.tg__update_timestamp();

-- ============================================================================
-- 2. Enhance Cafes Table with Owner Features
-- ============================================================================

-- Add account_id to link cafes to accounts
alter table public.cafes
  add column if not exists account_id uuid references public.accounts(id) on delete cascade;

-- Add status field for publication workflow
alter table public.cafes
  add column if not exists status text not null default 'draft';

-- Add constraint for status
alter table public.cafes
  drop constraint if exists cafes_status_check;

alter table public.cafes
  add constraint cafes_status_check 
  check (status in ('draft', 'moderation', 'published', 'paused', 'rejected'));

-- Add working hours as jsonb for flexible schedules
alter table public.cafes
  add column if not exists working_hours jsonb;

comment on column public.cafes.account_id is 'Link to owner account';
comment on column public.cafes.status is 'Publication status: draft, moderation, published, paused, rejected';
comment on column public.cafes.working_hours is 'Weekly schedule: {mon: {open: "08:00", close: "20:00"}, ...}';

-- Add indexes
create index if not exists cafes_account_id_idx on public.cafes(account_id);
create index if not exists cafes_status_idx on public.cafes(status);
create index if not exists cafes_status_created_idx on public.cafes(status, created_at desc);

-- Add photo URLs for storefront
alter table public.cafes
  add column if not exists logo_url text,
  add column if not exists cover_url text,
  add column if not exists photo_urls text[] default '{}';

comment on column public.cafes.logo_url is 'Cafe logo for branding';
comment on column public.cafes.cover_url is 'Hero image for cafe page';
comment on column public.cafes.photo_urls is 'Gallery of cafe photos';

-- ============================================================================
-- 3. Menu Categories Table
-- ============================================================================

create table if not exists public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.menu_categories is 'Menu categories for organizing menu items';

create index if not exists menu_categories_cafe_id_idx on public.menu_categories(cafe_id);
create index if not exists menu_categories_cafe_sort_idx on public.menu_categories(cafe_id, sort_order);

-- Enable RLS
alter table public.menu_categories enable row level security;

-- Trigger for updated_at
drop trigger if exists tg_menu_categories_updated_at on public.menu_categories;
create trigger tg_menu_categories_updated_at
  before update on public.menu_categories
  for each row execute function public.tg__update_timestamp();

-- ============================================================================
-- 4. Enhance Menu Items Table
-- ============================================================================

-- Add category_id foreign key
alter table public.menu_items
  add column if not exists category_id uuid references public.menu_categories(id) on delete set null;

-- Add additional fields for owner management
alter table public.menu_items
  add column if not exists photo_urls text[] default '{}',
  add column if not exists prep_time_sec int default 300,
  add column if not exists availability_schedule jsonb,
  add column if not exists updated_at timestamptz not null default now();

comment on column public.menu_items.category_id is 'Link to menu category';
comment on column public.menu_items.photo_urls is 'Product photos (up to 5)';
comment on column public.menu_items.prep_time_sec is 'Preparation time in seconds';
comment on column public.menu_items.availability_schedule is 'Time-based availability: {days: [1,2,3], time_from: "08:00", time_to: "12:00"}';

-- Add indexes
create index if not exists menu_items_category_id_idx on public.menu_items(category_id);

-- Trigger for updated_at
drop trigger if exists tg_menu_items_updated_at on public.menu_items;
create trigger tg_menu_items_updated_at
  before update on public.menu_items
  for each row execute function public.tg__update_timestamp();

-- ============================================================================
-- 5. Menu Modifiers Table
-- ============================================================================

create table if not exists public.menu_modifiers (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  group_name text not null, -- "Volume", "Milk Type", "Syrups"
  modifier_name text not null, -- "Large", "Almond", "Vanilla"
  price_change int not null default 0, -- +30, +0, -20
  is_required boolean not null default false, -- Group is required
  allow_multiple boolean not null default false, -- Can select multiple in group
  sort_order int not null default 0,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.menu_modifiers is 'Modifiers for menu items (size, milk, add-ons)';
comment on column public.menu_modifiers.group_name is 'Modifier group (e.g., Volume, Milk Type)';
comment on column public.menu_modifiers.modifier_name is 'Specific modifier (e.g., Large, Almond)';
comment on column public.menu_modifiers.price_change is 'Price adjustment in credits';
comment on column public.menu_modifiers.is_required is 'Whether this modifier group is required';
comment on column public.menu_modifiers.allow_multiple is 'Allow multiple selections from this group';

create index if not exists menu_modifiers_item_id_idx on public.menu_modifiers(menu_item_id);
create index if not exists menu_modifiers_item_group_idx on public.menu_modifiers(menu_item_id, group_name, sort_order);

-- Enable RLS
alter table public.menu_modifiers enable row level security;

-- Trigger for updated_at
drop trigger if exists tg_menu_modifiers_updated_at on public.menu_modifiers;
create trigger tg_menu_modifiers_updated_at
  before update on public.menu_modifiers
  for each row execute function public.tg__update_timestamp();

-- ============================================================================
-- 6. Cafe Publication History Table
-- ============================================================================

create table if not exists public.cafe_publication_history (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  status text not null,
  moderator_comment text,
  moderator_user_id uuid references auth.users(id) on delete set null,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.cafe_publication_history is 'History of cafe publication status changes and moderation';

create index if not exists cafe_publication_history_cafe_id_idx on public.cafe_publication_history(cafe_id, created_at desc);

-- Enable RLS
alter table public.cafe_publication_history enable row level security;

-- ============================================================================
-- 7. Enhance Orders Table for Owner Management
-- ============================================================================
-- Note: Work with orders_core as orders might be a view at this point

-- Add customer_user_id if not exists (for linking orders to customers)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'orders_core' and column_name = 'customer_user_id'
  ) then
    alter table public.orders_core add column customer_user_id uuid references auth.users(id) on delete set null;
    create index orders_core_customer_user_id_idx on public.orders_core(customer_user_id);
  end if;
end$$;

-- Add order_type for subscription/preorder/now
alter table public.orders_core
  add column if not exists order_type text not null default 'now';

alter table public.orders_core
  drop constraint if exists orders_core_order_type_check;

alter table public.orders_core
  add constraint orders_core_order_type_check
  check (order_type in ('now', 'preorder', 'subscription'));

-- Add slot_time for preorders
alter table public.orders_core
  add column if not exists slot_time timestamptz;

-- Add payment_status
alter table public.orders_core
  add column if not exists payment_status text not null default 'pending';

alter table public.orders_core
  drop constraint if exists orders_core_payment_status_check;

alter table public.orders_core
  add constraint orders_core_payment_status_check
  check (payment_status in ('pending', 'paid', 'failed', 'refunded'));

comment on column public.orders_core.order_type is 'Order type: now, preorder, subscription';
comment on column public.orders_core.slot_time is 'Scheduled pickup time for preorders';
comment on column public.orders_core.payment_status is 'Payment status: pending, paid, failed, refunded';

-- Add indexes
create index if not exists orders_core_order_type_idx on public.orders_core(order_type);
create index if not exists orders_core_payment_status_idx on public.orders_core(payment_status);
create index if not exists orders_core_slot_time_idx on public.orders_core(slot_time) where slot_time is not null;

-- ============================================================================
-- 8. RLS Policies - Accounts
-- ============================================================================

-- Owners can view their own account
create policy "Owners can view own account"
  on public.accounts for select
  using (auth.uid() = owner_user_id);

-- Owners can update their own account
create policy "Owners can update own account"
  on public.accounts for update
  using (auth.uid() = owner_user_id);

-- Owners can create their own account
create policy "Owners can create own account"
  on public.accounts for insert
  with check (auth.uid() = owner_user_id);

-- Admins can view all accounts
create policy "Admins can view all accounts"
  on public.accounts for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================================================
-- 9. RLS Policies - Cafes (Owner Access)
-- ============================================================================

-- Drop existing public read policy to replace with more granular ones
drop policy if exists "Public read cafes" on public.cafes;

-- Public can view published cafes
create policy "Public can view published cafes"
  on public.cafes for select
  using (status = 'published');

-- Owners can view their own cafes (all statuses)
create policy "Owners can view own cafes"
  on public.cafes for select
  using (
    account_id in (
      select id from public.accounts
      where owner_user_id = auth.uid()
    )
  );

-- Owners can create cafes under their account
create policy "Owners can create cafes"
  on public.cafes for insert
  with check (
    account_id in (
      select id from public.accounts
      where owner_user_id = auth.uid()
    )
  );

-- Owners can update their own cafes
create policy "Owners can update own cafes"
  on public.cafes for update
  using (
    account_id in (
      select id from public.accounts
      where owner_user_id = auth.uid()
    )
  );

-- Admins can view all cafes
create policy "Admins can view all cafes"
  on public.cafes for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Admins can update all cafes
create policy "Admins can update all cafes"
  on public.cafes for update
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================================================
-- 10. RLS Policies - Menu Categories
-- ============================================================================

-- Public can view categories for published cafes
create policy "Public can view categories of published cafes"
  on public.menu_categories for select
  using (
    exists (
      select 1 from public.cafes
      where id = cafe_id and status = 'published'
    )
  );

-- Owners can manage categories of their cafes
create policy "Owners can manage own cafe categories"
  on public.menu_categories for all
  using (
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 11. RLS Policies - Menu Items (Enhanced)
-- ============================================================================

-- Drop existing public read policy
drop policy if exists "Public read menu_items" on public.menu_items;

-- Public can view menu items of published cafes
create policy "Public can view menu items of published cafes"
  on public.menu_items for select
  using (
    exists (
      select 1 from public.cafes
      where id = cafe_id and status = 'published'
    )
  );

-- Owners can manage menu items of their cafes
create policy "Owners can manage own cafe menu items"
  on public.menu_items for all
  using (
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 12. RLS Policies - Menu Modifiers
-- ============================================================================

-- Public can view modifiers for published cafes
create policy "Public can view modifiers of published cafes"
  on public.menu_modifiers for select
  using (
    exists (
      select 1 from public.menu_items mi
      join public.cafes c on mi.cafe_id = c.id
      where mi.id = menu_item_id and c.status = 'published'
    )
  );

-- Owners can manage modifiers of their cafe menu items
create policy "Owners can manage own cafe modifiers"
  on public.menu_modifiers for all
  using (
    exists (
      select 1 from public.menu_items mi
      join public.cafes c on mi.cafe_id = c.id
      join public.accounts a on c.account_id = a.id
      where mi.id = menu_item_id and a.owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 13. RLS Policies - Orders (Owner Access)
-- ============================================================================
-- Note: Work with orders_core as orders might be a view

-- Drop existing overly permissive policies
drop policy if exists "anon_all_orders" on public.orders;
drop policy if exists "anon_all_orders" on public.orders_core;

-- Owners can view orders for their cafes
create policy "Owners can view own cafe orders"
  on public.orders_core for select
  using (
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- Owners can update orders for their cafes (status changes)
create policy "Owners can update own cafe orders"
  on public.orders_core for update
  using (
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- Customers can view their own orders
create policy "Customers can view own orders"
  on public.orders_core for select
  using (auth.uid() = user_id OR auth.uid() = customer_user_id);

-- Customers can create orders
create policy "Customers can create orders"
  on public.orders_core for insert
  with check (auth.uid() = user_id OR auth.uid() = customer_user_id);

-- Anonymous users can create orders (for guest checkout)
create policy "Anonymous can create orders"
  on public.orders_core for insert
  with check (user_id is null AND customer_user_id is null);

-- ============================================================================
-- 14. RLS Policies - Publication History
-- ============================================================================

-- Owners can view their cafes' publication history
create policy "Owners can view own cafes publication history"
  on public.cafe_publication_history for select
  using (
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- Admins can view all publication history
create policy "Admins can view all publication history"
  on public.cafe_publication_history for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Admins can insert into publication history
create policy "Admins can insert publication history"
  on public.cafe_publication_history for insert
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================================================
-- 15. Helper Functions - Get or Create Account
-- ============================================================================

create or replace function public.get_or_create_owner_account(
  p_user_id uuid,
  p_company_name text default null
)
returns public.accounts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account public.accounts;
begin
  -- Check if user is calling for themselves
  if auth.uid() != p_user_id then
    raise exception 'Unauthorized: can only access own account';
  end if;

  -- Try to get existing account
  select * into v_account
  from public.accounts
  where owner_user_id = p_user_id
  limit 1;

  -- Create if not exists
  if v_account is null then
    insert into public.accounts (owner_user_id, company_name)
    values (p_user_id, coalesce(p_company_name, 'My Company'))
    returning * into v_account;
  end if;

  return v_account;
end;
$$;

comment on function public.get_or_create_owner_account is 'Get or create owner account for current user';
grant execute on function public.get_or_create_owner_account(uuid, text) to authenticated;

-- ============================================================================
-- 16. Helper Functions - Get Owner Cafes
-- ============================================================================

create or replace function public.get_owner_cafes(p_user_id uuid)
returns setof public.cafes
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Check if user is calling for themselves
  if auth.uid() != p_user_id then
    raise exception 'Unauthorized: can only access own cafes';
  end if;

  return query
  select c.*
  from public.cafes c
  join public.accounts a on c.account_id = a.id
  where a.owner_user_id = p_user_id
  order by c.created_at desc;
end;
$$;

comment on function public.get_owner_cafes is 'Get all cafes owned by user';
grant execute on function public.get_owner_cafes(uuid) to authenticated;

-- ============================================================================
-- 17. Helper Functions - Cafe Publication Checklist
-- ============================================================================

create or replace function public.get_cafe_publication_checklist(p_cafe_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cafe public.cafes;
  v_menu_count int;
  v_checklist jsonb;
begin
  -- Get cafe
  select * into v_cafe
  from public.cafes
  where id = p_cafe_id;

  if v_cafe is null then
    raise exception 'Cafe not found';
  end if;

  -- Check ownership
  if not exists (
    select 1 from public.accounts
    where id = v_cafe.account_id and owner_user_id = auth.uid()
  ) then
    raise exception 'Unauthorized: not your cafe';
  end if;

  -- Count menu items
  select count(*) into v_menu_count
  from public.menu_items
  where cafe_id = p_cafe_id and is_active = true;

  -- Build checklist
  v_checklist := jsonb_build_object(
    'basic_info', (
      v_cafe.name is not null and 
      v_cafe.address is not null and 
      v_cafe.phone is not null
    ),
    'working_hours', (
      v_cafe.working_hours is not null or
      (v_cafe.opening_time is not null and v_cafe.closing_time is not null)
    ),
    'storefront', (
      v_cafe.logo_url is not null and 
      v_cafe.cover_url is not null and 
      v_cafe.description is not null
    ),
    'menu', v_menu_count >= 3,
    'legal_data', exists (
      select 1 from public.accounts
      where id = v_cafe.account_id and inn is not null
    ),
    'coordinates', (
      v_cafe.latitude is not null and 
      v_cafe.longitude is not null
    )
  );

  return v_checklist;
end;
$$;

comment on function public.get_cafe_publication_checklist is 'Get publication readiness checklist for cafe';
grant execute on function public.get_cafe_publication_checklist(uuid) to authenticated;

-- ============================================================================
-- 18. Helper Functions - Submit Cafe for Moderation
-- ============================================================================

create or replace function public.submit_cafe_for_moderation(p_cafe_id uuid)
returns public.cafes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cafe public.cafes;
  v_checklist jsonb;
  v_ready boolean;
begin
  -- Get cafe
  select * into v_cafe
  from public.cafes
  where id = p_cafe_id;

  if v_cafe is null then
    raise exception 'Cafe not found';
  end if;

  -- Check ownership
  if not exists (
    select 1 from public.accounts
    where id = v_cafe.account_id and owner_user_id = auth.uid()
  ) then
    raise exception 'Unauthorized: not your cafe';
  end if;

  -- Check if cafe is in draft status
  if v_cafe.status != 'draft' and v_cafe.status != 'rejected' then
    raise exception 'Cafe must be in draft or rejected status to submit for moderation';
  end if;

  -- Get checklist
  v_checklist := public.get_cafe_publication_checklist(p_cafe_id);

  -- Check if all items are ready
  v_ready := (
    (v_checklist->>'basic_info')::boolean and
    (v_checklist->>'working_hours')::boolean and
    (v_checklist->>'storefront')::boolean and
    (v_checklist->>'menu')::boolean and
    (v_checklist->>'legal_data')::boolean and
    (v_checklist->>'coordinates')::boolean
  );

  if not v_ready then
    raise exception 'Cafe is not ready for publication. Complete all checklist items.';
  end if;

  -- Update status
  update public.cafes
  set status = 'moderation',
      updated_at = now()
  where id = p_cafe_id
  returning * into v_cafe;

  -- Add to publication history
  insert into public.cafe_publication_history (
    cafe_id,
    status,
    submitted_at
  ) values (
    p_cafe_id,
    'moderation',
    now()
  );

  return v_cafe;
end;
$$;

comment on function public.submit_cafe_for_moderation is 'Submit cafe for moderation review';
grant execute on function public.submit_cafe_for_moderation(uuid) to authenticated;

-- ============================================================================
-- 19. Helper Functions - Duplicate Cafe
-- ============================================================================

create or replace function public.duplicate_cafe(
  p_cafe_id uuid,
  p_new_name text default null
)
returns public.cafes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_cafe public.cafes;
  v_new_cafe public.cafes;
  v_category record;
  v_item record;
  v_new_category_id uuid;
  v_category_map jsonb := '{}';
begin
  -- Get source cafe
  select * into v_source_cafe
  from public.cafes
  where id = p_cafe_id;

  if v_source_cafe is null then
    raise exception 'Source cafe not found';
  end if;

  -- Check ownership
  if not exists (
    select 1 from public.accounts
    where id = v_source_cafe.account_id and owner_user_id = auth.uid()
  ) then
    raise exception 'Unauthorized: not your cafe';
  end if;

  -- Create new cafe
  insert into public.cafes (
    account_id,
    name,
    address,
    phone,
    email,
    description,
    mode,
    status,
    eta_minutes,
    max_active_orders,
    supports_citypass,
    latitude,
    longitude,
    opening_time,
    closing_time,
    working_hours,
    logo_url,
    cover_url,
    photo_urls
  ) values (
    v_source_cafe.account_id,
    coalesce(p_new_name, v_source_cafe.name || ' (Copy)'),
    v_source_cafe.address,
    v_source_cafe.phone,
    v_source_cafe.email,
    v_source_cafe.description,
    'closed', -- Start closed
    'draft', -- Start as draft
    v_source_cafe.eta_minutes,
    v_source_cafe.max_active_orders,
    v_source_cafe.supports_citypass,
    v_source_cafe.latitude,
    v_source_cafe.longitude,
    v_source_cafe.opening_time,
    v_source_cafe.closing_time,
    v_source_cafe.working_hours,
    v_source_cafe.logo_url,
    v_source_cafe.cover_url,
    v_source_cafe.photo_urls
  )
  returning * into v_new_cafe;

  -- Duplicate categories
  for v_category in
    select * from public.menu_categories
    where cafe_id = p_cafe_id
    order by sort_order
  loop
    insert into public.menu_categories (
      cafe_id,
      name,
      sort_order,
      is_visible
    ) values (
      v_new_cafe.id,
      v_category.name,
      v_category.sort_order,
      v_category.is_visible
    )
    returning id into v_new_category_id;

    -- Store category mapping
    v_category_map := v_category_map || jsonb_build_object(
      v_category.id::text,
      v_new_category_id
    );
  end loop;

  -- Duplicate menu items
  for v_item in
    select * from public.menu_items
    where cafe_id = p_cafe_id
    order by sort_order
  loop
    insert into public.menu_items (
      cafe_id,
      category_id,
      category,
      name,
      description,
      price_credits,
      sort_order,
      is_active,
      photo_urls,
      prep_time_sec,
      availability_schedule
    ) values (
      v_new_cafe.id,
      (v_category_map->>v_item.category_id::text)::uuid,
      v_item.category,
      v_item.name,
      v_item.description,
      v_item.price_credits,
      v_item.sort_order,
      v_item.is_active,
      v_item.photo_urls,
      v_item.prep_time_sec,
      v_item.availability_schedule
    );
  end loop;

  return v_new_cafe;
end;
$$;

comment on function public.duplicate_cafe is 'Duplicate a cafe with all its menu items and categories';
grant execute on function public.duplicate_cafe(uuid, text) to authenticated;

-- ============================================================================
-- 20. Create initial profile role if not exists
-- ============================================================================

-- Ensure profiles table has role column
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'role'
  ) then
    alter table public.profiles add column role text not null default 'user';
  end if;
end$$;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
