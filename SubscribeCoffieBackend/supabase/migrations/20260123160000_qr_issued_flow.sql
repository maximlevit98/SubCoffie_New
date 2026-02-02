-- Add "issued" status and QR redeem flow (non-breaking).
create extension if not exists "pgcrypto";

-- Status mapping updates (legacy <-> normalized).
create or replace function public.sc_status_from_legacy(p_status text)
returns text
language sql
as $$
  select case
    when p_status is null then null
    when p_status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show','issued') then p_status
    when p_status = 'Created' then 'created'
    when p_status = 'Accepted' then 'accepted'
    when p_status = 'Rejected' then 'rejected'
    when p_status = 'In progress' then 'in_progress'
    when p_status = 'Ready' then 'ready'
    when p_status = 'Picked up' then 'picked_up'
    when p_status = 'Canceled' then 'canceled'
    when p_status = 'Refunded' then 'refunded'
    when p_status = 'No-show' then 'no_show'
    when p_status = 'Issued' then 'issued'
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
    when p_status = 'issued' then 'Issued'
    else p_status
  end;
$$;

-- Extend status checks and issued_at on orders_core / order_events_core.
alter table public.orders_core
  add column if not exists issued_at timestamptz;

alter table public.orders_core drop constraint if exists orders_status_check;
alter table public.orders_core
  add constraint orders_status_check
  check (status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show','issued'));

alter table public.order_events_core drop constraint if exists order_events_status_check;
alter table public.order_events_core
  add constraint order_events_status_check
  check (status in ('created','accepted','rejected','in_progress','ready','picked_up','canceled','refunded','no_show','issued'));

-- Update REST view to expose issued_at.
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
  eta_sec,
  load_factor,
  scheduled_ready_at,
  calculated_start_at,
  issued_at,
  subtotal_credits,
  bonus_used,
  paid_credits,
  pickup_deadline,
  no_show_at,
  user_id,
  wallet_id
from public.orders_core;

-- Update view triggers to handle issued_at.
create or replace function public.orders_view_insert()
returns trigger
language plpgsql
as $$
declare
  r public.orders_core%rowtype;
begin
  insert into public.orders_core (
    id, created_at, updated_at, cafe_id, customer_phone, status,
    eta_minutes, eta_sec, load_factor, scheduled_ready_at, calculated_start_at,
    issued_at,
    subtotal_credits, bonus_used, paid_credits,
    pickup_deadline, no_show_at, user_id, wallet_id
  ) values (
    coalesce(new.id, gen_random_uuid()),
    coalesce(new.created_at, now()),
    coalesce(new.updated_at, now()),
    new.cafe_id,
    new.customer_phone,
    public.sc_status_from_legacy(new.status),
    coalesce(new.eta_minutes, 0),
    coalesce(new.eta_sec, 0),
    coalesce(new.load_factor, 1.0),
    new.scheduled_ready_at,
    new.calculated_start_at,
    new.issued_at,
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
  new.eta_sec = r.eta_sec;
  new.load_factor = r.load_factor;
  new.scheduled_ready_at = r.scheduled_ready_at;
  new.calculated_start_at = r.calculated_start_at;
  new.issued_at = r.issued_at;
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
    eta_sec = coalesce(new.eta_sec, orders_core.eta_sec),
    load_factor = coalesce(new.load_factor, orders_core.load_factor),
    scheduled_ready_at = coalesce(new.scheduled_ready_at, orders_core.scheduled_ready_at),
    calculated_start_at = coalesce(new.calculated_start_at, orders_core.calculated_start_at),
    issued_at = coalesce(new.issued_at, orders_core.issued_at),
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
  new.eta_sec = r.eta_sec;
  new.load_factor = r.load_factor;
  new.scheduled_ready_at = r.scheduled_ready_at;
  new.calculated_start_at = r.calculated_start_at;
  new.issued_at = r.issued_at;
  return new;
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

-- QR tokens table.
create table if not exists public.order_qr_tokens (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders_core(id) on delete cascade,
  token_hash text not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists order_qr_tokens_order_id_idx on public.order_qr_tokens (order_id);
create index if not exists order_qr_tokens_expires_at_idx on public.order_qr_tokens (expires_at);
create index if not exists order_qr_tokens_used_at_idx on public.order_qr_tokens (used_at);
create index if not exists order_qr_tokens_token_hash_idx on public.order_qr_tokens (token_hash);

-- RPC: create order QR token (returns plain token).
create or replace function public.create_order_qr_token(
  p_order_id uuid,
  p_expires_sec int
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  token_plain text;
  token_hash text;
  expires_at timestamptz;
begin
  if p_order_id is null then
    raise exception 'order_id required';
  end if;

  if not exists (select 1 from public.orders_core where id = p_order_id) then
    raise exception 'order not found';
  end if;

  token_plain := encode(gen_random_bytes(32), 'hex');
  token_hash := encode(digest(token_plain, 'sha256'), 'hex');
  expires_at := now() + make_interval(secs => greatest(coalesce(p_expires_sec, 600), 60));

  insert into public.order_qr_tokens (order_id, token_hash, expires_at)
  values (p_order_id, token_hash, expires_at);

  return token_plain;
end;
$$;

-- RPC: redeem order QR token (issues the order).
create or replace function public.redeem_order_qr(
  p_token text,
  p_actor_user_id uuid
)
returns table(order_id uuid, status text, issued_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token_hash text;
  v_order_id uuid;
  v_status text;
  v_issued_at timestamptz;
  v_used_at timestamptz;
  v_expires_at timestamptz;
begin
  if p_token is null or length(p_token) = 0 then
    raise exception 'token required';
  end if;

  v_token_hash := encode(digest(p_token, 'sha256'), 'hex');

  select oq.order_id, oq.used_at, oq.expires_at
  into v_order_id, v_used_at, v_expires_at
  from public.order_qr_tokens as oq
  where oq.token_hash = v_token_hash
  for update;

  if v_order_id is null then
    raise exception 'token not found';
  end if;
  if v_used_at is not null then
    raise exception 'token already used';
  end if;
  if v_expires_at < now() then
    raise exception 'token expired';
  end if;

  select o.status into v_status
  from public.orders_core as o
  where o.id = v_order_id
  for update;
  if v_status is null then
    raise exception 'order not found';
  end if;
  if v_status <> 'ready' then
    raise exception 'order not ready';
  end if;

  update public.orders_core as o
  set status = 'issued',
      issued_at = now()
  where o.id = v_order_id
  returning o.issued_at into v_issued_at;

  insert into public.order_events_core (order_id, status, created_at, updated_at)
  values (v_order_id, 'issued', now(), now());

  update public.order_qr_tokens
  set used_at = now()
  where token_hash = v_token_hash;

  return query select v_order_id, 'issued', v_issued_at;
end;
$$;

-- RLS: prevent direct status updates for anon/auth.
drop policy if exists anon_all_orders on public.orders_core;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='orders_core' and policyname='anon_select_orders'
  ) then
    create policy anon_select_orders on public.orders_core
      for select to anon, authenticated using (true);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='orders_core' and policyname='anon_insert_orders'
  ) then
    create policy anon_insert_orders on public.orders_core
      for insert to anon, authenticated with check (true);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='orders_core' and policyname='anon_update_orders_no_status_change'
  ) then
    create policy anon_update_orders_no_status_change on public.orders_core
      for update to anon, authenticated
      using (true)
      with check (
        status = (select o.status from public.orders_core o where o.id = orders_core.id)
      );
  end if;
end$$;
