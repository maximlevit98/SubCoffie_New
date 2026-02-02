-- Add additional fields to cafes table for admin panel

-- Add phone, email, description
alter table public.cafes
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists description text;

-- Add coordinates for map
alter table public.cafes
  add column if not exists latitude numeric(10, 6),
  add column if not exists longitude numeric(10, 6);

-- Add working hours
alter table public.cafes
  add column if not exists opening_time time,
  add column if not exists closing_time time;

-- Add indexes for coordinates (for future geospatial queries)
create index if not exists cafes_coordinates_idx on public.cafes (latitude, longitude);

-- Comments
comment on column public.cafes.phone is 'Contact phone number';
comment on column public.cafes.email is 'Contact email';
comment on column public.cafes.description is 'Short description of the cafe';
comment on column public.cafes.latitude is 'Latitude coordinate for map';
comment on column public.cafes.longitude is 'Longitude coordinate for map';
comment on column public.cafes.opening_time is 'Opening time';
comment on column public.cafes.closing_time is 'Closing time';
