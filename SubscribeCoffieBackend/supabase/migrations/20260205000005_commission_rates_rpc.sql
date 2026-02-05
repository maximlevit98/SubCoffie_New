-- Migration: Add RPC to get commission rates
-- Date: 2026-02-05
-- Priority: P0 (Remove hardcoded commissions from iOS)

-- ============================================================================
-- Function: get_commission_rates
-- Returns active commission rates for all operation types
-- ============================================================================

create or replace function public.get_commission_rates()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_result jsonb;
begin
  select jsonb_object_agg(operation_type, commission_percent)
  into v_result
  from public.commission_config
  where active = true;
  
  return coalesce(v_result, '{}'::jsonb);
end;
$$;

comment on function public.get_commission_rates is 
  'Returns active commission rates as JSON object. Public access (no auth required). Example: {"citypass_topup": 7.00, "cafe_wallet_topup": 4.00}';

-- ============================================================================
-- Function: get_commission_for_wallet
-- Returns commission rate for a specific wallet
-- ============================================================================

create or replace function public.get_commission_for_wallet(
  p_wallet_id uuid
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_wallet_type wallet_type;
  v_operation_type text;
  v_commission_percent decimal(5,2);
  v_result jsonb;
begin
  -- Get wallet type
  select wallet_type into v_wallet_type
  from public.wallets
  where id = p_wallet_id;
  
  if v_wallet_type is null then
    raise exception 'Wallet not found: %', p_wallet_id;
  end if;
  
  -- Determine operation type
  if v_wallet_type = 'citypass' then
    v_operation_type := 'citypass_topup';
  elsif v_wallet_type = 'cafe_wallet' then
    v_operation_type := 'cafe_wallet_topup';
  else
    raise exception 'Unknown wallet type: %', v_wallet_type;
  end if;
  
  -- Get commission rate
  select commission_percent into v_commission_percent
  from public.commission_config
  where operation_type = v_operation_type and active = true;
  
  if v_commission_percent is null then
    raise exception 'Commission rate not found for: %', v_operation_type;
  end if;
  
  -- Build result
  v_result := jsonb_build_object(
    'wallet_id', p_wallet_id,
    'wallet_type', v_wallet_type,
    'operation_type', v_operation_type,
    'commission_percent', v_commission_percent
  );
  
  return v_result;
end;
$$;

comment on function public.get_commission_for_wallet is 
  'Returns commission info for specific wallet. Example: {"wallet_id": "...", "wallet_type": "citypass", "commission_percent": 7.00}';

-- ============================================================================
-- Grant access (public can read commission rates)
-- ============================================================================

grant execute on function public.get_commission_rates() to anon, authenticated;
grant execute on function public.get_commission_for_wallet(uuid) to anon, authenticated;
