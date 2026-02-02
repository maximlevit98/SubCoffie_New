-- Add cafes filter fields and indexes (idempotent)

alter table public.cafes
  add column if not exists rating numeric,
  add column if not exists avg_check_credits int,
  add column if not exists distance_km numeric,
  add column if not exists supports_citypass boolean not null default true,
  add column if not exists brand_id uuid;

create index if not exists cafes_rating_idx on public.cafes (rating);
create index if not exists cafes_avg_check_idx on public.cafes (avg_check_credits);
create index if not exists cafes_distance_idx on public.cafes (distance_km);
create index if not exists cafes_supports_citypass_idx on public.cafes (supports_citypass);
create index if not exists cafes_brand_id_idx on public.cafes (brand_id);
