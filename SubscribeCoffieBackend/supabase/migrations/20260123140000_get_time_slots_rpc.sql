-- RPC: get_time_slots(cafe_id, cart_items, now) -> slot_start timestamptz[]
-- cart_items format: [{ "id": "...", "qty": 1, "prep_time_sec": 120 }, ...]
-- eta_sec formula: max(prep_time_sec) * load_factor

create or replace function public.get_time_slots(
  p_cafe_id uuid,
  p_cart_items jsonb,
  p_now timestamptz
)
returns table(slot_start timestamptz)
language plpgsql
as $$
declare
  cafe_mode text;
  max_prep int := 0;
  lf numeric := 1.0;
  base_ts timestamptz;
  step_sec int := 600; -- 10 minutes
  horizon_sec int := 7200; -- 120 minutes
  base_epoch numeric;
  rounded_epoch numeric;
begin
  select mode into cafe_mode
  from public.cafes
  where id = p_cafe_id;

  if cafe_mode is null or cafe_mode in ('paused','closed') then
    return;
  end if;

  if p_cart_items is not null then
    select coalesce(max((item->>'prep_time_sec')::int), 0)
    into max_prep
    from jsonb_array_elements(p_cart_items) as item;
  end if;

  select coalesce(
    (select o.load_factor from public.orders_core o where o.cafe_id = p_cafe_id order by o.created_at desc limit 1),
    1.0
  ) into lf;

  base_ts := p_now + make_interval(secs => ceil(max_prep * lf));
  base_epoch := extract(epoch from base_ts);
  rounded_epoch := ceil(base_epoch / step_sec) * step_sec;

  return query
  select to_timestamp(rounded_epoch) + (gs * step_sec) * interval '1 second'
  from generate_series(0, horizon_sec / step_sec) as gs;
end;
$$;
