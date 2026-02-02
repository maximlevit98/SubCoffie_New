-- Migration: Wallet Types + Mock Payment Infrastructure
-- Description: Adds support for two wallet types (CityPass and Cafe Wallet) and mock payment infrastructure
-- Date: 2026-02-01

-- ============================================================================
-- 1. Create wallet_networks table (networks of cafes)
-- ============================================================================

create table if not exists public.wallet_networks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  commission_rate decimal(5,2) default 3.00 check (commission_rate >= 0 and commission_rate <= 100),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

comment on table public.wallet_networks is 'Networks of cafes (e.g., Starbucks, Coffee Company) for Cafe Wallet';

-- Enable RLS
alter table public.wallet_networks enable row level security;

-- Policies for wallet_networks
create policy "Admin can manage networks"
  on public.wallet_networks for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Public can view networks"
  on public.wallet_networks for select
  using (true);

-- ============================================================================
-- 2. Create cafe_network_members table (many-to-many: cafes <-> networks)
-- ============================================================================

create table if not exists public.cafe_network_members (
  network_id uuid references public.wallet_networks(id) on delete cascade,
  cafe_id uuid references public.cafes(id) on delete cascade,
  joined_at timestamp with time zone default now(),
  primary key (network_id, cafe_id)
);

comment on table public.cafe_network_members is 'Links cafes to networks';

-- Enable RLS
alter table public.cafe_network_members enable row level security;

-- Policies for cafe_network_members
create policy "Admin can manage cafe network members"
  on public.cafe_network_members for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Public can view cafe network members"
  on public.cafe_network_members for select
  using (true);

-- ============================================================================
-- 3. Update wallets table to support wallet types
-- ============================================================================

-- Add wallet_type enum if not exists
do $$
begin
  if not exists (select 1 from pg_type where typname = 'wallet_type') then
    create type wallet_type as enum ('citypass', 'cafe_wallet');
  end if;
end
$$;

-- Add columns to wallets table
alter table public.wallets
  add column if not exists wallet_type wallet_type default 'citypass',
  add column if not exists cafe_id uuid references public.cafes(id) on delete set null,
  add column if not exists network_id uuid references public.wallet_networks(id) on delete set null;

-- Add constraint: cafe_wallet must have cafe_id OR network_id
alter table public.wallets
  drop constraint if exists wallets_cafe_wallet_check;

alter table public.wallets
  add constraint wallets_cafe_wallet_check check (
    (wallet_type = 'citypass') or
    (wallet_type = 'cafe_wallet' and (cafe_id is not null or network_id is not null))
  );

comment on column public.wallets.wallet_type is 'Type of wallet: citypass (universal) or cafe_wallet (tied to specific cafe/network)';
comment on column public.wallets.cafe_id is 'For cafe_wallet: specific cafe this wallet is tied to';
comment on column public.wallets.network_id is 'For cafe_wallet: network of cafes this wallet is tied to';

-- ============================================================================
-- 4. Create payment_methods table (mock cards)
-- ============================================================================

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  card_last4 text not null check (length(card_last4) = 4),
  card_brand text not null, -- 'visa', 'mastercard', 'mir', 'mock'
  is_default boolean default false,
  payment_provider text default 'mock' check (payment_provider in ('mock', 'stripe', 'yookassa')),
  provider_token text, -- empty for mock, real token later
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

comment on table public.payment_methods is 'User payment methods (cards). Mock for MVP, real tokens later.';

-- Enable RLS
alter table public.payment_methods enable row level security;

-- Policies for payment_methods
create policy "Users can manage their own payment methods"
  on public.payment_methods for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Index for user lookup
create index if not exists payment_methods_user_id_idx on public.payment_methods(user_id);

-- ============================================================================
-- 5. Create payment_transactions table (all transaction history)
-- ============================================================================

create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  wallet_id uuid references public.wallets(id) on delete set null,
  order_id uuid references public.orders_core(id) on delete set null,
  amount_credits int not null check (amount_credits > 0),
  commission_credits int default 0 check (commission_credits >= 0),
  transaction_type text not null check (transaction_type in ('topup', 'order_payment', 'refund')),
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  status text default 'pending' check (status in ('pending', 'completed', 'failed')),
  provider_transaction_id text, -- mock UUID for now
  created_at timestamp with time zone default now(),
  completed_at timestamp with time zone
);

comment on table public.payment_transactions is 'History of all payment transactions (mock and real)';

-- Enable RLS
alter table public.payment_transactions enable row level security;

-- Policies for payment_transactions
create policy "Users can view their own transactions"
  on public.payment_transactions for select
  using (auth.uid() = user_id);

create policy "Admin can view all transactions"
  on public.payment_transactions for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Indexes
create index if not exists payment_transactions_user_id_idx on public.payment_transactions(user_id);
create index if not exists payment_transactions_wallet_id_idx on public.payment_transactions(wallet_id);
create index if not exists payment_transactions_order_id_idx on public.payment_transactions(order_id);
create index if not exists payment_transactions_created_at_idx on public.payment_transactions(created_at desc);

-- ============================================================================
-- 6. Create commission_config table (commission rates configuration)
-- ============================================================================

create table if not exists public.commission_config (
  id uuid primary key default gen_random_uuid(),
  operation_type text unique not null check (operation_type in ('citypass_topup', 'cafe_wallet_topup', 'direct_order')),
  commission_percent decimal(5,2) not null check (commission_percent >= 0 and commission_percent <= 100),
  active boolean default true,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

comment on table public.commission_config is 'Commission rates configuration for different operation types';

-- Enable RLS
alter table public.commission_config enable row level security;

-- Policies for commission_config
create policy "Admin can manage commission config"
  on public.commission_config for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Public can view active commission config"
  on public.commission_config for select
  using (active = true);

-- Insert default commission rates
insert into public.commission_config (operation_type, commission_percent, active)
values
  ('citypass_topup', 7.00, true),
  ('cafe_wallet_topup', 4.00, true),
  ('direct_order', 17.00, true)
on conflict (operation_type) do nothing;

-- ============================================================================
-- 7. RPC Functions
-- ============================================================================

-- Function: calculate_commission
create or replace function public.calculate_commission(
  p_amount int,
  p_operation_type text,
  p_wallet_type wallet_type default null
)
returns int
language plpgsql
security definer
as $$
declare
  v_commission_percent decimal(5,2);
  v_commission_amount int;
  v_actual_operation_type text;
begin
  -- Determine operation type based on wallet type
  if p_operation_type = 'topup' and p_wallet_type is not null then
    if p_wallet_type = 'citypass' then
      v_actual_operation_type := 'citypass_topup';
    elsif p_wallet_type = 'cafe_wallet' then
      v_actual_operation_type := 'cafe_wallet_topup';
    else
      v_actual_operation_type := p_operation_type;
    end if;
  else
    v_actual_operation_type := p_operation_type;
  end if;

  -- Get commission rate
  select commission_percent into v_commission_percent
  from public.commission_config
  where operation_type = v_actual_operation_type and active = true;

  if v_commission_percent is null then
    raise exception 'Commission rate not found for operation type: %', v_actual_operation_type;
  end if;

  -- Calculate commission (rounded)
  v_commission_amount := round((p_amount * v_commission_percent / 100)::numeric);

  return v_commission_amount;
end;
$$;

-- Function: create_citypass_wallet
create or replace function public.create_citypass_wallet(p_user_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  v_wallet_id uuid;
begin
  -- Check if user already has a CityPass wallet
  select id into v_wallet_id
  from public.wallets
  where user_id = p_user_id and wallet_type = 'citypass';

  if v_wallet_id is not null then
    raise exception 'User already has a CityPass wallet';
  end if;

  -- Create CityPass wallet
  insert into public.wallets (user_id, wallet_type, balance_credits, lifetime_top_up_credits)
  values (p_user_id, 'citypass', 0, 0)
  returning id into v_wallet_id;

  return v_wallet_id;
end;
$$;

-- Function: create_cafe_wallet
create or replace function public.create_cafe_wallet(
  p_user_id uuid,
  p_cafe_id uuid default null,
  p_network_id uuid default null
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_wallet_id uuid;
begin
  -- Validate: must provide either cafe_id or network_id
  if p_cafe_id is null and p_network_id is null then
    raise exception 'Must provide either cafe_id or network_id';
  end if;

  if p_cafe_id is not null and p_network_id is not null then
    raise exception 'Cannot provide both cafe_id and network_id';
  end if;

  -- Check if user already has a wallet for this cafe/network
  select id into v_wallet_id
  from public.wallets
  where user_id = p_user_id
    and wallet_type = 'cafe_wallet'
    and (
      (p_cafe_id is not null and cafe_id = p_cafe_id) or
      (p_network_id is not null and network_id = p_network_id)
    );

  if v_wallet_id is not null then
    raise exception 'User already has a Cafe Wallet for this cafe/network';
  end if;

  -- Create Cafe Wallet
  insert into public.wallets (user_id, wallet_type, cafe_id, network_id, balance_credits, lifetime_top_up_credits)
  values (p_user_id, 'cafe_wallet', p_cafe_id, p_network_id, 0, 0)
  returning id into v_wallet_id;

  return v_wallet_id;
end;
$$;

-- Function: mock_wallet_topup (simulates payment)
create or replace function public.mock_wallet_topup(
  p_wallet_id uuid,
  p_amount int,
  p_payment_method_id uuid default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id uuid;
  v_wallet_type wallet_type;
  v_commission int;
  v_amount_credited int;
  v_transaction_id uuid;
  v_mock_provider_id text;
begin
  -- Get wallet info
  select user_id, wallet_type into v_user_id, v_wallet_type
  from public.wallets
  where id = p_wallet_id;

  if v_user_id is null then
    raise exception 'Wallet not found';
  end if;

  -- Calculate commission
  v_commission := public.calculate_commission(p_amount, 'topup', v_wallet_type);
  v_amount_credited := p_amount - v_commission;

  -- Generate mock provider transaction ID
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  -- Create transaction record
  insert into public.payment_transactions (
    user_id, wallet_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, provider_transaction_id, completed_at
  )
  values (
    v_user_id, p_wallet_id, p_amount, v_commission,
    'topup', p_payment_method_id, 'completed', v_mock_provider_id, now()
  )
  returning id into v_transaction_id;

  -- Update wallet balance
  update public.wallets
  set
    balance_credits = balance_credits + v_amount_credited,
    lifetime_top_up_credits = lifetime_top_up_credits + v_amount_credited,
    updated_at = now()
  where id = p_wallet_id;

  -- Return result
  return jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'commission', v_commission,
    'amount_credited', v_amount_credited,
    'provider_transaction_id', v_mock_provider_id
  );
end;
$$;

-- Function: mock_direct_order_payment (simulates direct payment without wallet)
create or replace function public.mock_direct_order_payment(
  p_order_id uuid,
  p_amount int,
  p_payment_method_id uuid default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id uuid;
  v_commission int;
  v_transaction_id uuid;
  v_mock_provider_id text;
begin
  -- Get order user_id
  select user_id into v_user_id
  from public.orders_core
  where id = p_order_id;

  if v_user_id is null then
    raise exception 'Order not found';
  end if;

  -- Calculate commission for direct order
  v_commission := public.calculate_commission(p_amount, 'direct_order');

  -- Generate mock provider transaction ID
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  -- Create transaction record
  insert into public.payment_transactions (
    user_id, order_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, provider_transaction_id, completed_at
  )
  values (
    v_user_id, p_order_id, p_amount, v_commission,
    'order_payment', p_payment_method_id, 'completed', v_mock_provider_id, now()
  )
  returning id into v_transaction_id;

  -- Update order status to paid (if it exists in orders_core)
  update public.orders_core
  set status = 'created', updated_at = now()
  where id = p_order_id;

  -- Return result
  return jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'commission', v_commission,
    'provider_transaction_id', v_mock_provider_id
  );
end;
$$;

-- Function: validate_wallet_for_order (checks if wallet can be used for this cafe)
create or replace function public.validate_wallet_for_order(
  p_wallet_id uuid,
  p_cafe_id uuid
)
returns boolean
language plpgsql
security definer
as $$
declare
  v_wallet_type wallet_type;
  v_wallet_cafe_id uuid;
  v_wallet_network_id uuid;
  v_is_in_network boolean;
begin
  -- Get wallet info
  select wallet_type, cafe_id, network_id
  into v_wallet_type, v_wallet_cafe_id, v_wallet_network_id
  from public.wallets
  where id = p_wallet_id;

  if v_wallet_type is null then
    return false; -- Wallet not found
  end if;

  -- CityPass: always valid
  if v_wallet_type = 'citypass' then
    return true;
  end if;

  -- Cafe Wallet: check if tied to this cafe
  if v_wallet_cafe_id is not null and v_wallet_cafe_id = p_cafe_id then
    return true;
  end if;

  -- Cafe Wallet: check if tied to network containing this cafe
  if v_wallet_network_id is not null then
    select exists(
      select 1 from public.cafe_network_members
      where network_id = v_wallet_network_id and cafe_id = p_cafe_id
    ) into v_is_in_network;

    if v_is_in_network then
      return true;
    end if;
  end if;

  -- Otherwise, not valid
  return false;
end;
$$;

-- Function: get_user_wallets (returns all wallets for user with details)
create or replace function public.get_user_wallets(p_user_id uuid)
returns table(
  id uuid,
  wallet_type wallet_type,
  balance_credits int,
  lifetime_top_up_credits int,
  cafe_id uuid,
  cafe_name text,
  network_id uuid,
  network_name text,
  created_at timestamp with time zone
)
language plpgsql
security definer
as $$
begin
  return query
  select
    w.id,
    w.wallet_type,
    w.balance_credits,
    w.lifetime_top_up_credits,
    w.cafe_id,
    c.name as cafe_name,
    w.network_id,
    wn.name as network_name,
    w.created_at
  from public.wallets w
  left join public.cafes c on w.cafe_id = c.id
  left join public.wallet_networks wn on w.network_id = wn.id
  where w.user_id = p_user_id
  order by w.created_at desc;
end;
$$;

-- ============================================================================
-- 8. Indexes and performance optimizations
-- ============================================================================

create index if not exists wallets_wallet_type_idx on public.wallets(wallet_type);
create index if not exists wallets_cafe_id_idx on public.wallets(cafe_id) where cafe_id is not null;
create index if not exists wallets_network_id_idx on public.wallets(network_id) where network_id is not null;

-- ============================================================================
-- 9. Comments and documentation
-- ============================================================================

comment on function public.calculate_commission is 'Calculates commission for an operation based on config';
comment on function public.create_citypass_wallet is 'Creates a universal CityPass wallet for user';
comment on function public.create_cafe_wallet is 'Creates a Cafe Wallet tied to specific cafe or network';
comment on function public.mock_wallet_topup is 'Mock simulation of wallet top-up payment (for MVP)';
comment on function public.mock_direct_order_payment is 'Mock simulation of direct order payment without wallet (for MVP)';
comment on function public.validate_wallet_for_order is 'Validates if wallet can be used for order at this cafe';
comment on function public.get_user_wallets is 'Returns all wallets for user with details';
