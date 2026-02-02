-- Pre-order scheduling fields for orders_core and REST view alignment.
-- Formula: eta_sec = max_prep_time_sec * load_factor.

-- Add scheduling fields to orders_core (safe, idempotent).
alter table public.orders_core
  add column if not exists scheduled_ready_at timestamptz, -- requested ready time
  add column if not exists calculated_start_at timestamptz, -- computed start time
  add column if not exists eta_sec int not null default 0, -- computed ETA in seconds
  add column if not exists load_factor numeric not null default 1.0; -- workload multiplier

-- Recreate REST view to expose new fields.
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
  subtotal_credits,
  bonus_used,
  paid_credits,
  pickup_deadline,
  no_show_at,
  user_id,
  wallet_id
from public.orders_core;

-- Update view triggers to handle new fields.
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
