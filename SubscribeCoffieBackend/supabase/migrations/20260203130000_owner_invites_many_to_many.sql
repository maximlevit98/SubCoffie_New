-- ============================================================================
-- Owner Invitations System - Part 2: Many-to-Many + Enhanced Security
-- ============================================================================
-- Description: Extends owner system with many-to-many cafe_owners relationship
-- Date: 2026-02-03
-- 
-- Adds:
-- 1. cafe_owners table (many-to-many: owners ↔ cafes)
-- 2. redeem_owner_invitation RPC (secure token redemption)
-- 3. Enhanced RLS policies for strict scope isolation
-- 4. Helper functions for owner management
-- ============================================================================

-- ============================================================================
-- 1. Cafe Owners Table (Many-to-Many Relationship)
-- ============================================================================

create table if not exists public.cafe_owners (
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  
  -- Permissions & metadata
  role text not null default 'owner', -- 'owner', 'manager', 'staff' (future)
  can_edit_menu boolean not null default true,
  can_manage_orders boolean not null default true,
  can_view_finances boolean not null default true,
  
  -- Audit trail
  added_by uuid references auth.users(id),
  added_at timestamptz not null default now(),
  
  -- Metadata
  metadata jsonb default '{}'::jsonb,
  
  -- Primary key: composite
  primary key (cafe_id, owner_id),
  
  constraint cafe_owners_role_check check (role in ('owner', 'manager', 'staff'))
);

comment on table public.cafe_owners is 'Many-to-many relationship: owners can manage multiple cafes';
comment on column public.cafe_owners.role is 'Owner role within cafe context (future: manager, staff)';
comment on column public.cafe_owners.can_edit_menu is 'Permission to create/edit/delete menu items';
comment on column public.cafe_owners.can_manage_orders is 'Permission to view/update orders';
comment on column public.cafe_owners.can_view_finances is 'Permission to view financial data';

-- Indexes
create index if not exists cafe_owners_owner_id_idx on public.cafe_owners(owner_id);
create index if not exists cafe_owners_cafe_id_idx on public.cafe_owners(cafe_id);
create index if not exists cafe_owners_role_idx on public.cafe_owners(role);

-- Enable RLS
alter table public.cafe_owners enable row level security;

-- ============================================================================
-- 2. Sync accounts → cafe_owners (Migration Helper)
-- ============================================================================
-- For existing data: populate cafe_owners from accounts/cafes relationship

do $$
declare
  v_account record;
  v_cafe record;
begin
  -- For each account, link owner to all their cafes
  for v_account in 
    select id, owner_user_id from public.accounts
  loop
    -- Get all cafes for this account
    for v_cafe in
      select id from public.cafes where account_id = v_account.id
    loop
      -- Insert into cafe_owners (idempotent)
      insert into public.cafe_owners (
        cafe_id,
        owner_id,
        role,
        can_edit_menu,
        can_manage_orders,
        can_view_finances,
        added_by,
        added_at
      ) values (
        v_cafe.id,
        v_account.owner_user_id,
        'owner',
        true,
        true,
        true,
        v_account.owner_user_id, -- self-added (migration)
        now()
      )
      on conflict (cafe_id, owner_id) do nothing; -- Skip if exists
    end loop;
  end loop;
end $$;

-- ============================================================================
-- 3. RLS Policies - cafe_owners
-- ============================================================================

-- Owners can view their own cafe relationships
create policy "Owners can view own cafe relationships"
  on public.cafe_owners for select
  using (auth.uid() = owner_id);

-- Admins can view all cafe relationships
create policy "Admins can view all cafe relationships"
  on public.cafe_owners for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Only admins can insert/update/delete cafe_owners (via server or RPC)
-- Note: redeem_owner_invitation RPC uses SECURITY DEFINER to insert

create policy "Admins can manage cafe relationships"
  on public.cafe_owners for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================================================
-- 4. Enhanced RLS Policies - Cafes (Owner Scope)
-- ============================================================================

-- Drop old policy if exists (will recreate with cafe_owners support)
drop policy if exists "Owners can view own cafes" on public.cafes;

-- Owners can view cafes they have access to (via cafe_owners OR accounts)
create policy "Owners can view accessible cafes"
  on public.cafes for select
  using (
    -- Via cafe_owners (many-to-many)
    exists (
      select 1 from public.cafe_owners
      where cafe_id = cafes.id and owner_id = auth.uid()
    )
    or
    -- Via accounts (original method, backward compatible)
    account_id in (
      select id from public.accounts
      where owner_user_id = auth.uid()
    )
  );

-- Drop old policy
drop policy if exists "Owners can update own cafes" on public.cafes;

-- Owners can update cafes they have access to
create policy "Owners can update accessible cafes"
  on public.cafes for update
  using (
    exists (
      select 1 from public.cafe_owners
      where cafe_id = cafes.id and owner_id = auth.uid()
    )
    or
    account_id in (
      select id from public.accounts
      where owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 5. Enhanced RLS Policies - Menu Items (Owner Scope)
-- ============================================================================

-- Drop old policy
drop policy if exists "Owners can manage own cafe menu items" on public.menu_items;

-- Owners can manage menu items of cafes they have access to
create policy "Owners can manage accessible cafe menu items"
  on public.menu_items for all
  using (
    -- Check cafe_owners with menu permission
    exists (
      select 1 from public.cafe_owners
      where cafe_id = menu_items.cafe_id 
        and owner_id = auth.uid()
        and can_edit_menu = true
    )
    or
    -- Via accounts (backward compatible)
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = menu_items.cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 6. Enhanced RLS Policies - Orders (Owner Scope)
-- ============================================================================

-- Drop old policies
drop policy if exists "Owners can view own cafe orders" on public.orders_core;
drop policy if exists "Owners can update own cafe orders" on public.orders_core;

-- Owners can view orders from cafes they manage
create policy "Owners can view accessible cafe orders"
  on public.orders_core for select
  using (
    exists (
      select 1 from public.cafe_owners
      where cafe_id = orders_core.cafe_id 
        and owner_id = auth.uid()
        and can_manage_orders = true
    )
    or
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = orders_core.cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- Owners can update orders from cafes they manage
create policy "Owners can update accessible cafe orders"
  on public.orders_core for update
  using (
    exists (
      select 1 from public.cafe_owners
      where cafe_id = orders_core.cafe_id 
        and owner_id = auth.uid()
        and can_manage_orders = true
    )
    or
    exists (
      select 1 from public.cafes c
      join public.accounts a on c.account_id = a.id
      where c.id = orders_core.cafe_id and a.owner_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 7. RPC - redeem_owner_invitation (Secure Token Redemption)
-- ============================================================================

create or replace function public.redeem_owner_invitation(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token_hash text;
  v_invitation record;
  v_user_id uuid;
  v_user_email text;
  v_current_role text;
  v_account_id uuid;
begin
  -- 🛡️ SECURITY: Must be authenticated
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  
  -- Get user email from auth.users
  select email into v_user_email
  from auth.users
  where id = v_user_id;
  
  if v_user_email is null then
    raise exception 'User email not found';
  end if;
  
  -- Hash token for lookup
  v_token_hash := public.hash_invitation_token(p_token);
  
  -- Get and lock invitation (atomic operation)
  select * into v_invitation
  from public.owner_invitations
  where token_hash = v_token_hash
  for update; -- Lock row to prevent race conditions
  
  -- 🛡️ VALIDATION: Check invitation exists
  if v_invitation is null then
    raise exception 'Invalid invitation token';
  end if;
  
  -- 🛡️ VALIDATION: Check not expired
  if v_invitation.expires_at < now() then
    -- Auto-mark as expired
    update public.owner_invitations
    set status = 'expired', updated_at = now()
    where id = v_invitation.id;
    
    raise exception 'Invitation has expired';
  end if;
  
  -- 🛡️ VALIDATION: Check not already used
  if v_invitation.status != 'pending' then
    raise exception 'Invitation is no longer available (status: %)', v_invitation.status;
  end if;
  
  if v_invitation.use_count >= v_invitation.max_uses then
    raise exception 'Invitation has reached maximum usage limit';
  end if;
  
  -- 🛡️ SECURITY: Verify email matches
  if lower(trim(v_user_email)) != lower(trim(v_invitation.email)) then
    raise exception 'Email mismatch: invitation is for % but you are logged in as %',
      v_invitation.email, v_user_email;
  end if;
  
  -- Check current role
  select role into v_current_role
  from public.profiles
  where profiles.id = v_user_id;
  
  if v_current_role = 'owner' then
    raise exception 'User already has owner role';
  end if;
  
  if v_current_role = 'admin' then
    raise exception 'Cannot assign owner role to admin user';
  end if;
  
  -- 🎯 CRITICAL OPERATION: Assign owner role
  update public.profiles
  set role = 'owner',
      updated_at = now()
  where profiles.id = v_user_id;
  
  -- 🏢 CREATE OWNER ACCOUNT (if doesn't exist)
  select id into v_account_id
  from public.accounts
  where owner_user_id = v_user_id;
  
  if v_account_id is null then
    insert into public.accounts (
      owner_user_id,
      company_name,
      created_at,
      updated_at
    ) values (
      v_user_id,
      coalesce(v_invitation.company_name, 'My Company'),
      now(),
      now()
    )
    returning id into v_account_id;
  end if;
  
  -- 🏪 LINK TO CAFE (if cafe_id provided)
  if v_invitation.cafe_id is not null then
    -- Link via accounts
    update public.cafes
    set account_id = v_account_id,
        updated_at = now()
    where id = v_invitation.cafe_id;
    
    -- Link via cafe_owners (many-to-many)
    insert into public.cafe_owners (
      cafe_id,
      owner_id,
      role,
      can_edit_menu,
      can_manage_orders,
      can_view_finances,
      added_by,
      added_at
    ) values (
      v_invitation.cafe_id,
      v_user_id,
      'owner',
      true,
      true,
      true,
      v_invitation.created_by_admin_id,
      now()
    )
    on conflict (cafe_id, owner_id) do nothing; -- Skip if exists
  end if;
  
  -- ✅ MARK INVITATION AS USED
  update public.owner_invitations
  set status = 'accepted',
      accepted_by_user_id = v_user_id,
      accepted_at = now(),
      use_count = use_count + 1,
      updated_at = now()
  where id = v_invitation.id;
  
  -- 🔒 AUDIT: Log redemption
  insert into public.audit_logs (
    actor_user_id,
    action,
    table_name,
    record_id,
    payload
  ) values (
    v_user_id,
    'owner_invitation.redeemed',
    'owner_invitations',
    v_invitation.id,
    jsonb_build_object(
      'email', v_user_email,
      'invitation_email', v_invitation.email,
      'company_name', v_invitation.company_name,
      'cafe_id', v_invitation.cafe_id,
      'account_id', v_account_id
    )
  );
  
  -- Return success
  return jsonb_build_object(
    'success', true,
    'message', 'Invitation redeemed successfully',
    'account_id', v_account_id,
    'cafe_id', v_invitation.cafe_id,
    'redirect_url', case
      when v_invitation.cafe_id is not null then '/admin/owner/dashboard'
      else '/admin/owner/onboarding'
    end
  );
end;
$$;

comment on function public.redeem_owner_invitation is 'Redeem invitation token and assign owner role (SECURE)';
grant execute on function public.redeem_owner_invitation(text) to authenticated;

-- ============================================================================
-- 8. Helper Function - Check Owner Access to Cafe
-- ============================================================================

create or replace function public.has_owner_access_to_cafe(
  p_user_id uuid,
  p_cafe_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_has_access boolean;
begin
  -- Check via cafe_owners (many-to-many)
  select exists (
    select 1 from public.cafe_owners
    where cafe_id = p_cafe_id and owner_id = p_user_id
  ) into v_has_access;
  
  if v_has_access then
    return true;
  end if;
  
  -- Check via accounts (backward compatible)
  select exists (
    select 1 from public.cafes c
    join public.accounts a on c.account_id = a.id
    where c.id = p_cafe_id and a.owner_user_id = p_user_id
  ) into v_has_access;
  
  return v_has_access;
end;
$$;

comment on function public.has_owner_access_to_cafe is 'Check if user has owner access to cafe';
grant execute on function public.has_owner_access_to_cafe(uuid, uuid) to authenticated;

-- ============================================================================
-- 9. Helper Function - Get Owner's Cafes (Enhanced)
-- ============================================================================

create or replace function public.get_owner_accessible_cafes(p_user_id uuid default null)
returns setof public.cafes
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid;
begin
  -- Use provided user_id or current user
  v_user_id := coalesce(p_user_id, auth.uid());
  
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  
  -- Check caller can only get their own cafes (unless admin)
  if p_user_id is not null and p_user_id != auth.uid() then
    if not exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    ) then
      raise exception 'Unauthorized: can only access own cafes';
    end if;
  end if;
  
  -- Return cafes (via cafe_owners OR accounts)
  return query
  select distinct c.*
  from public.cafes c
  where 
    -- Via cafe_owners
    exists (
      select 1 from public.cafe_owners co
      where co.cafe_id = c.id and co.owner_id = v_user_id
    )
    or
    -- Via accounts (backward compatible)
    c.account_id in (
      select id from public.accounts
      where owner_user_id = v_user_id
    )
  order by c.created_at desc;
end;
$$;

comment on function public.get_owner_accessible_cafes is 'Get all cafes accessible to owner (via cafe_owners or accounts)';
grant execute on function public.get_owner_accessible_cafes(uuid) to authenticated;

-- ============================================================================
-- 10. Trigger - Auto-create cafe_owners entry when cafe created
-- ============================================================================

create or replace function public.tg__auto_create_cafe_owner()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_owner_user_id uuid;
begin
  -- Get owner_user_id from account
  if NEW.account_id is not null then
    select owner_user_id into v_owner_user_id
    from public.accounts
    where id = NEW.account_id;
    
    if v_owner_user_id is not null then
      -- Create cafe_owners entry
      insert into public.cafe_owners (
        cafe_id,
        owner_id,
        role,
        can_edit_menu,
        can_manage_orders,
        can_view_finances,
        added_by,
        added_at
      ) values (
        NEW.id,
        v_owner_user_id,
        'owner',
        true,
        true,
        true,
        v_owner_user_id,
        now()
      )
      on conflict (cafe_id, owner_id) do nothing;
    end if;
  end if;
  
  return NEW;
end;
$$;

drop trigger if exists tg_auto_create_cafe_owner on public.cafes;
create trigger tg_auto_create_cafe_owner
  after insert on public.cafes
  for each row execute function public.tg__auto_create_cafe_owner();

comment on function public.tg__auto_create_cafe_owner is 'Auto-create cafe_owners entry when cafe is created';

-- ============================================================================
-- 11. View - Owner Dashboard Stats
-- ============================================================================

create or replace view public.owner_dashboard_stats as
select
  co.owner_id,
  count(distinct co.cafe_id) as total_cafes,
  count(distinct mi.id) as total_menu_items,
  count(distinct oc.id) filter (where oc.status not in ('cancelled', 'refunded')) as total_orders,
  count(distinct oc.id) filter (where oc.status in ('created', 'paid')) as pending_orders,
  sum(oc.paid_credits) filter (where oc.status not in ('cancelled', 'refunded')) as total_revenue
from public.cafe_owners co
left join public.menu_items mi on mi.cafe_id = co.cafe_id
left join public.orders_core oc on oc.cafe_id = co.cafe_id
group by co.owner_id;

comment on view public.owner_dashboard_stats is 'Dashboard statistics for cafe owners';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
