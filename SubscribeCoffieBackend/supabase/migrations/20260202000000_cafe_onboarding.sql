-- Migration: Cafe Onboarding System
-- Description: Tables and RPCs for cafe application and approval process
-- Date: 2026-02-02

-- ============================================================================
-- 1. Create cafe_onboarding_requests table
-- ============================================================================

create table if not exists public.cafe_onboarding_requests (
  id uuid primary key default gen_random_uuid(),
  applicant_name text not null,
  applicant_email text not null,
  applicant_phone text,
  cafe_name text not null,
  cafe_address text not null,
  cafe_description text,
  status text default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_comment text,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

comment on table public.cafe_onboarding_requests is 'Applications from cafe owners to join the platform';

-- Enable RLS
alter table public.cafe_onboarding_requests enable row level security;

-- Policies for cafe_onboarding_requests
create policy "Admin can view all onboarding requests"
  on public.cafe_onboarding_requests for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Admin can update onboarding requests"
  on public.cafe_onboarding_requests for update
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Anyone can submit onboarding request"
  on public.cafe_onboarding_requests for insert
  with check (true); -- Open for anyone, can be restricted later

-- Indexes
create index if not exists cafe_onboarding_requests_status_idx on public.cafe_onboarding_requests(status);
create index if not exists cafe_onboarding_requests_created_at_idx on public.cafe_onboarding_requests(created_at desc);

-- ============================================================================
-- 2. Create cafe_documents table
-- ============================================================================

create table if not exists public.cafe_documents (
  id uuid primary key default gen_random_uuid(),
  onboarding_request_id uuid references public.cafe_onboarding_requests(id) on delete cascade,
  cafe_id uuid references public.cafes(id) on delete cascade,
  document_type text not null check (document_type in ('logo', 'menu_photo', 'license', 'other')),
  file_name text not null,
  file_url text not null, -- Supabase Storage URL
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamp with time zone default now()
);

comment on table public.cafe_documents is 'Documents uploaded during cafe onboarding (logos, photos, licenses)';

-- Enable RLS
alter table public.cafe_documents enable row level security;

-- Policies for cafe_documents
create policy "Admin can view all cafe documents"
  on public.cafe_documents for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Admin can manage cafe documents"
  on public.cafe_documents for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Indexes
create index if not exists cafe_documents_onboarding_request_id_idx on public.cafe_documents(onboarding_request_id);
create index if not exists cafe_documents_cafe_id_idx on public.cafe_documents(cafe_id);

-- ============================================================================
-- 3. RPC: submit_cafe_application
-- ============================================================================

create or replace function public.submit_cafe_application(
  p_applicant_name text,
  p_applicant_email text,
  p_cafe_name text,
  p_cafe_address text,
  p_applicant_phone text default null,
  p_cafe_description text default null
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_request_id uuid;
begin
  -- Validate inputs
  if p_applicant_name is null or trim(p_applicant_name) = '' then
    raise exception 'Applicant name is required';
  end if;

  if p_applicant_email is null or trim(p_applicant_email) = '' then
    raise exception 'Applicant email is required';
  end if;

  if p_cafe_name is null or trim(p_cafe_name) = '' then
    raise exception 'Cafe name is required';
  end if;

  if p_cafe_address is null or trim(p_cafe_address) = '' then
    raise exception 'Cafe address is required';
  end if;

  -- Create onboarding request
  insert into public.cafe_onboarding_requests (
    applicant_name,
    applicant_email,
    applicant_phone,
    cafe_name,
    cafe_address,
    cafe_description,
    status
  )
  values (
    trim(p_applicant_name),
    trim(p_applicant_email),
    trim(p_applicant_phone),
    trim(p_cafe_name),
    trim(p_cafe_address),
    trim(p_cafe_description),
    'pending'
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.submit_cafe_application is 'Submit a new cafe onboarding application';

-- ============================================================================
-- 4. RPC: approve_cafe (creates cafe and updates request status)
-- ============================================================================

create or replace function public.approve_cafe(
  p_request_id uuid,
  p_admin_user_id uuid,
  p_admin_comment text default null
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_request record;
  v_cafe_id uuid;
begin
  -- Validate admin role
  if not exists (
    select 1 from public.profiles
    where id = p_admin_user_id and role = 'admin'
  ) then
    raise exception 'Only admin users can approve cafes';
  end if;

  -- Get request details
  select * into v_request
  from public.cafe_onboarding_requests
  where id = p_request_id;

  if v_request is null then
    raise exception 'Onboarding request not found';
  end if;

  if v_request.status != 'pending' then
    raise exception 'Only pending requests can be approved';
  end if;

  -- Create cafe
  insert into public.cafes (
    name,
    address,
    mode,
    eta_minutes,
    active_orders,
    max_active_orders,
    distance_km,
    supports_citypass,
    rating,
    avg_check_credits
  )
  values (
    v_request.cafe_name,
    v_request.cafe_address,
    'closed', -- Default to closed, owner will set it to open
    15, -- Default ETA
    0, -- No active orders yet
    18, -- Default max
    0.0, -- Distance will be calculated based on user location
    true, -- Default to supporting CityPass
    0.0, -- No rating yet
    250 -- Default average check
  )
  returning id into v_cafe_id;

  -- Update request status
  update public.cafe_onboarding_requests
  set
    status = 'approved',
    approved_by = p_admin_user_id,
    approved_at = now(),
    admin_comment = p_admin_comment,
    updated_at = now()
  where id = p_request_id;

  -- Move documents to cafe
  update public.cafe_documents
  set cafe_id = v_cafe_id
  where onboarding_request_id = p_request_id;

  -- TODO: Send email notification to applicant
  -- TODO: Create owner profile if not exists

  return v_cafe_id;
end;
$$;

comment on function public.approve_cafe is 'Approve a cafe onboarding request and create the cafe';

-- ============================================================================
-- 5. RPC: reject_cafe (updates request status)
-- ============================================================================

create or replace function public.reject_cafe(
  p_request_id uuid,
  p_admin_user_id uuid,
  p_admin_comment text default null
)
returns void
language plpgsql
security definer
as $$
declare
  v_request record;
begin
  -- Validate admin role
  if not exists (
    select 1 from public.profiles
    where id = p_admin_user_id and role = 'admin'
  ) then
    raise exception 'Only admin users can reject cafes';
  end if;

  -- Get request details
  select * into v_request
  from public.cafe_onboarding_requests
  where id = p_request_id;

  if v_request is null then
    raise exception 'Onboarding request not found';
  end if;

  if v_request.status != 'pending' then
    raise exception 'Only pending requests can be rejected';
  end if;

  -- Update request status
  update public.cafe_onboarding_requests
  set
    status = 'rejected',
    admin_comment = p_admin_comment,
    updated_at = now()
  where id = p_request_id;

  -- TODO: Send email notification to applicant
end;
$$;

comment on function public.reject_cafe is 'Reject a cafe onboarding request';

-- ============================================================================
-- 6. Create updated_at trigger for cafe_onboarding_requests
-- ============================================================================

create or replace function update_cafe_onboarding_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger tg_cafe_onboarding_requests_updated_at
before update on public.cafe_onboarding_requests
for each row
execute function update_cafe_onboarding_requests_updated_at();
