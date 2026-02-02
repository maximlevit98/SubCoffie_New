create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role text not null default 'user',
  created_at timestamptz not null default now()
);

-- Ensure columns exist on older schemas (idempotent).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'email'
  ) then
    alter table public.profiles add column email text;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'role'
  ) then
    alter table public.profiles add column role text default 'user';
  end if;

  update public.profiles set role = 'user' where role is null;
  alter table public.profiles alter column role set not null;
end$$;

-- Keep email unique when present (allow nulls).
create unique index if not exists profiles_email_unique_idx
  on public.profiles (email) where email is not null;

-- Ensure role constraint exists.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_role_check' and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('user', 'admin'));
  end if;
end$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;

-- Helper to avoid RLS recursion when checking admin role.
create or replace function public.is_admin()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
begin
  perform set_config('row_security', 'off', true);
  select (role = 'admin') into is_admin
  from public.profiles
  where id = auth.uid()
  limit 1;
  return coalesce(is_admin, false);
end;
$$;

drop policy if exists "Profiles select own" on public.profiles;
drop policy if exists "Profiles update own" on public.profiles;
drop policy if exists "Profiles admin select all" on public.profiles;
drop policy if exists "Profiles admin update all" on public.profiles;

create policy "Profiles select own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Profiles update own"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Profiles admin select all"
  on public.profiles for select
  using (public.is_admin());

create policy "Profiles admin update all"
  on public.profiles for update
  using (public.is_admin());
