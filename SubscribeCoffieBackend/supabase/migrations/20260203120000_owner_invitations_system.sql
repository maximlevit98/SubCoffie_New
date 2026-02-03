-- ============================================================================
-- Owner Invitations System (Invite-only Registration)
-- ============================================================================
-- Description: Secure invite-only system for Owner registration
-- Date: 2026-02-03
-- Security: Token hashing, expiry, one-time use, audit logging
-- 
-- Flow:
-- 1. Admin creates invitation → generates token, stores hash
-- 2. Owner clicks link → validates token → registers → role assigned
-- 3. Invitation marked as used → audit log created
-- ============================================================================

-- ============================================================================
-- 1. Owner Invitations Table
-- ============================================================================

create table if not exists public.owner_invitations (
  id uuid primary key default gen_random_uuid(),
  
  -- Invitation details
  email text not null,
  token_hash text not null unique, -- SHA256 hash of token
  company_name text, -- Suggested company name
  cafe_id uuid references public.cafes(id) on delete set null, -- Optional: link to existing cafe
  
  -- Status tracking
  status text not null default 'pending', -- 'pending', 'accepted', 'expired', 'revoked'
  accepted_by_user_id uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  
  -- Expiry and security
  expires_at timestamptz not null,
  max_uses int not null default 1, -- Usually 1, but can be multiple for testing
  use_count int not null default 0,
  
  -- Audit trail
  created_by_admin_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  -- Metadata
  metadata jsonb default '{}'::jsonb, -- For future extensions (e.g., custom permissions)
  
  constraint owner_invitations_status_check check (status in ('pending', 'accepted', 'expired', 'revoked'))
);

comment on table public.owner_invitations is 'Secure invite-only system for Owner registration';
comment on column public.owner_invitations.token_hash is 'SHA256 hash of invitation token (never store plaintext)';
comment on column public.owner_invitations.cafe_id is 'Optional: pre-link invitation to existing cafe';
comment on column public.owner_invitations.max_uses is 'Maximum number of times token can be used (usually 1)';

-- Indexes
create index if not exists owner_invitations_email_idx on public.owner_invitations(email);
create index if not exists owner_invitations_token_hash_idx on public.owner_invitations(token_hash);
create index if not exists owner_invitations_status_idx on public.owner_invitations(status);
create index if not exists owner_invitations_created_by_idx on public.owner_invitations(created_by_admin_id);
create index if not exists owner_invitations_expires_at_idx on public.owner_invitations(expires_at);

-- Enable RLS
alter table public.owner_invitations enable row level security;

-- Trigger for updated_at
drop trigger if exists tg_owner_invitations_updated_at on public.owner_invitations;
create trigger tg_owner_invitations_updated_at
  before update on public.owner_invitations
  for each row execute function public.tg__update_timestamp();

-- ============================================================================
-- 2. RLS Policies - Owner Invitations
-- ============================================================================

-- Admins can view all invitations
create policy "Admins can view all invitations"
  on public.owner_invitations for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Admins can create invitations
create policy "Admins can create invitations"
  on public.owner_invitations for insert
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Admins can update invitations (e.g., revoke)
create policy "Admins can update invitations"
  on public.owner_invitations for update
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Admins can delete invitations
create policy "Admins can delete invitations"
  on public.owner_invitations for delete
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================================================
-- 3. Helper Function - Generate Token Hash
-- ============================================================================

create or replace function public.hash_invitation_token(token text)
returns text
language plpgsql
immutable
as $$
begin
  -- SHA256 hash of token
  return encode(digest(token || '::owner_invitation_salt', 'sha256'), 'hex');
end;
$$;

comment on function public.hash_invitation_token is 'Generate SHA256 hash for invitation token';

-- ============================================================================
-- 4. RPC - Admin Create Owner Invitation
-- ============================================================================

create or replace function public.admin_create_owner_invitation(
  p_email text,
  p_company_name text default null,
  p_cafe_id uuid default null,
  p_expires_in_hours int default 168 -- 7 days default
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin_role text;
  v_token text;
  v_token_hash text;
  v_invitation_id uuid;
  v_expires_at timestamptz;
begin
  -- 🛡️ SECURITY: Check caller is admin
  select role into v_admin_role
  from public.profiles
  where profiles.id = auth.uid();
  
  if v_admin_role != 'admin' then
    raise exception 'Unauthorized: Admin role required';
  end if;
  
  -- 🛡️ VALIDATION: Email format
  if p_email is null or p_email !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'Invalid email format';
  end if;
  
  -- 🛡️ VALIDATION: Check if email already has owner role
  if exists (
    select 1 from auth.users u
    join public.profiles p on p.id = u.id
    where u.email = p_email and p.role = 'owner'
  ) then
    raise exception 'User with this email already has owner role';
  end if;
  
  -- 🛡️ VALIDATION: Check if cafe exists (if provided)
  if p_cafe_id is not null and not exists (
    select 1 from public.cafes where id = p_cafe_id
  ) then
    raise exception 'Cafe not found';
  end if;
  
  -- Generate secure random token (32 bytes = 256 bits)
  v_token := encode(gen_random_bytes(32), 'base64');
  v_token := replace(replace(replace(v_token, '+', '-'), '/', '_'), '=', ''); -- URL-safe
  
  -- Hash token for storage
  v_token_hash := public.hash_invitation_token(v_token);
  
  -- Calculate expiry
  v_expires_at := now() + (p_expires_in_hours || ' hours')::interval;
  
  -- Create invitation
  insert into public.owner_invitations (
    email,
    token_hash,
    company_name,
    cafe_id,
    expires_at,
    created_by_admin_id,
    status
  ) values (
    lower(trim(p_email)),
    v_token_hash,
    p_company_name,
    p_cafe_id,
    v_expires_at,
    auth.uid(),
    'pending'
  )
  returning id into v_invitation_id;
  
  -- 🔒 AUDIT: Log invitation creation
  insert into public.audit_logs (
    actor_user_id,
    action,
    table_name,
    record_id,
    payload
  ) values (
    auth.uid(),
    'owner_invitation.created',
    'owner_invitations',
    v_invitation_id,
    jsonb_build_object(
      'email', lower(trim(p_email)),
      'company_name', p_company_name,
      'cafe_id', p_cafe_id,
      'expires_at', v_expires_at
    )
  );
  
  -- Return invitation details with plaintext token (only time it's visible!)
  return jsonb_build_object(
    'invitation_id', v_invitation_id,
    'email', lower(trim(p_email)),
    'token', v_token, -- ⚠️ CRITICAL: Only returned once, never stored
    'expires_at', v_expires_at,
    'invite_url', format('https://your-domain.com/register/owner?token=%s', v_token)
  );
end;
$$;

comment on function public.admin_create_owner_invitation is 'Create owner invitation (ADMIN ONLY). Returns token once.';
grant execute on function public.admin_create_owner_invitation(text, text, uuid, int) to authenticated;

-- ============================================================================
-- 5. RPC - Validate and Get Invitation by Token
-- ============================================================================

create or replace function public.validate_owner_invitation(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token_hash text;
  v_invitation record;
  v_is_valid boolean;
  v_error_reason text;
begin
  -- Hash the provided token
  v_token_hash := public.hash_invitation_token(p_token);
  
  -- Get invitation
  select * into v_invitation
  from public.owner_invitations
  where token_hash = v_token_hash
  limit 1;
  
  -- Check if invitation exists
  if v_invitation is null then
    return jsonb_build_object(
      'valid', false,
      'error', 'Invalid or expired invitation token'
    );
  end if;
  
  -- Validate invitation
  v_is_valid := true;
  v_error_reason := null;
  
  -- Check status
  if v_invitation.status != 'pending' then
    v_is_valid := false;
    v_error_reason := case v_invitation.status
      when 'accepted' then 'This invitation has already been used'
      when 'expired' then 'This invitation has expired'
      when 'revoked' then 'This invitation has been revoked'
      else 'Invitation is not available'
    end;
  end if;
  
  -- Check expiry
  if v_invitation.expires_at < now() then
    v_is_valid := false;
    v_error_reason := 'This invitation has expired';
    
    -- Auto-mark as expired
    update public.owner_invitations
    set status = 'expired', updated_at = now()
    where id = v_invitation.id and status = 'pending';
  end if;
  
  -- Check use count
  if v_invitation.use_count >= v_invitation.max_uses then
    v_is_valid := false;
    v_error_reason := 'This invitation has reached its maximum usage limit';
  end if;
  
  -- Return validation result
  if v_is_valid then
    return jsonb_build_object(
      'valid', true,
      'invitation_id', v_invitation.id,
      'email', v_invitation.email,
      'company_name', v_invitation.company_name,
      'cafe_id', v_invitation.cafe_id,
      'expires_at', v_invitation.expires_at
    );
  else
    return jsonb_build_object(
      'valid', false,
      'error', v_error_reason
    );
  end if;
end;
$$;

comment on function public.validate_owner_invitation is 'Validate invitation token (public, no auth required)';
grant execute on function public.validate_owner_invitation(text) to anon, authenticated;

-- ============================================================================
-- 6. RPC - Accept Owner Invitation (After Signup)
-- ============================================================================

create or replace function public.accept_owner_invitation(
  p_token text,
  p_user_email text default null -- Optional: for double-check
)
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
  
  -- Get user email
  select email into v_user_email
  from auth.users
  where id = v_user_id;
  
  -- Hash token
  v_token_hash := public.hash_invitation_token(p_token);
  
  -- Get and lock invitation (FOR UPDATE to prevent race conditions)
  select * into v_invitation
  from public.owner_invitations
  where token_hash = v_token_hash
  for update;
  
  -- Validate invitation
  if v_invitation is null then
    raise exception 'Invalid invitation token';
  end if;
  
  if v_invitation.status != 'pending' then
    raise exception 'Invitation is not available (status: %)', v_invitation.status;
  end if;
  
  if v_invitation.expires_at < now() then
    raise exception 'Invitation has expired';
  end if;
  
  if v_invitation.use_count >= v_invitation.max_uses then
    raise exception 'Invitation has reached maximum usage limit';
  end if;
  
  -- 🛡️ SECURITY: Verify email matches
  if lower(trim(v_user_email)) != lower(trim(v_invitation.email)) then
    raise exception 'Email mismatch: This invitation is for % but you are logged in as %',
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
  
  -- 🎯 ASSIGN OWNER ROLE (critical operation!)
  update public.profiles
  set role = 'owner',
      updated_at = now()
  where profiles.id = v_user_id;
  
  -- 🏢 CREATE OWNER ACCOUNT
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
  
  -- 🏪 LINK TO CAFE (if cafe_id provided in invitation)
  if v_invitation.cafe_id is not null then
    update public.cafes
    set account_id = v_account_id,
        updated_at = now()
    where id = v_invitation.cafe_id;
  end if;
  
  -- ✅ MARK INVITATION AS ACCEPTED
  update public.owner_invitations
  set status = 'accepted',
      accepted_by_user_id = v_user_id,
      accepted_at = now(),
      use_count = use_count + 1,
      updated_at = now()
  where id = v_invitation.id;
  
  -- 🔒 AUDIT: Log acceptance
  insert into public.audit_logs (
    actor_user_id,
    action,
    table_name,
    record_id,
    payload
  ) values (
    v_user_id,
    'owner_invitation.accepted',
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
    'message', 'Owner role assigned successfully',
    'account_id', v_account_id,
    'cafe_id', v_invitation.cafe_id,
    'redirect_url', case
      when v_invitation.cafe_id is not null then '/admin/owner/dashboard'
      else '/admin/owner/onboarding'
    end
  );
end;
$$;

comment on function public.accept_owner_invitation is 'Accept invitation and assign owner role (requires auth)';
grant execute on function public.accept_owner_invitation(text, text) to authenticated;

-- ============================================================================
-- 7. RPC - Admin Revoke Invitation
-- ============================================================================

create or replace function public.admin_revoke_owner_invitation(p_invitation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin_role text;
begin
  -- 🛡️ SECURITY: Check caller is admin
  select role into v_admin_role
  from public.profiles
  where profiles.id = auth.uid();
  
  if v_admin_role != 'admin' then
    raise exception 'Unauthorized: Admin role required';
  end if;
  
  -- Revoke invitation
  update public.owner_invitations
  set status = 'revoked',
      updated_at = now()
  where id = p_invitation_id
    and status = 'pending';
  
  if not found then
    raise exception 'Invitation not found or already processed';
  end if;
  
  -- 🔒 AUDIT: Log revocation
  insert into public.audit_logs (
    actor_user_id,
    action,
    table_name,
    record_id,
    payload
  ) values (
    auth.uid(),
    'owner_invitation.revoked',
    'owner_invitations',
    p_invitation_id,
    jsonb_build_object('revoked_by', auth.uid())
  );
  
  return jsonb_build_object(
    'success', true,
    'message', 'Invitation revoked successfully'
  );
end;
$$;

comment on function public.admin_revoke_owner_invitation is 'Revoke pending invitation (ADMIN ONLY)';
grant execute on function public.admin_revoke_owner_invitation(uuid) to authenticated;

-- ============================================================================
-- 8. View - Invitation Statistics for Admins
-- ============================================================================

create or replace view public.owner_invitation_stats as
select
  count(*) filter (where status = 'pending') as pending_count,
  count(*) filter (where status = 'accepted') as accepted_count,
  count(*) filter (where status = 'expired') as expired_count,
  count(*) filter (where status = 'revoked') as revoked_count,
  count(*) as total_count
from public.owner_invitations;

comment on view public.owner_invitation_stats is 'Statistics for owner invitations (admin only)';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
