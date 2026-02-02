-- RPC: calculate_ready_slots(cafe_id, items) -> slot_start timestamptz[]
-- items format: [{ "id": "...", "qty": 1, "prep_time_sec": 120 }, ...]
-- Example:
-- select * from public.calculate_ready_slots(
--   '11111111-1111-1111-1111-111111111111',
--   '[{"id":"x","qty":1,"prep_time_sec":120}]'::jsonb
-- );

create or replace function public.calculate_ready_slots(
  p_cafe_id uuid,
  p_items jsonb
)
returns table(slot_start timestamptz)
language plpgsql
as $$
declare
  cafe_mode text;
  max_prep int := 0;
  mode_factor numeric := 1.0;
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

  if cafe_mode = 'busy' then
    mode_factor := 1.3;
  end if;

  if p_items is not null then
    select coalesce(max((item->>'prep_time_sec')::int), 0)
    into max_prep
    from jsonb_array_elements(p_items) as item;
  end if;

  base_ts := now() + make_interval(secs => ceil(max_prep * mode_factor));
  base_epoch := extract(epoch from base_ts);
  rounded_epoch := ceil(base_epoch / step_sec) * step_sec;

  return query
  select to_timestamp(rounded_epoch) + (gs * step_sec) * interval '1 second'
  from generate_series(0, horizon_sec / step_sec) as gs;
end;
$$;
