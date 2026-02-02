create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  actor_user_id uuid,
  action text not null,
  table_name text not null,
  record_id uuid,
  payload jsonb not null default '{}'::jsonb
);

create index if not exists audit_logs_actor_user_id_idx
  on public.audit_logs (actor_user_id);

create index if not exists audit_logs_table_record_idx
  on public.audit_logs (table_name, record_id);

alter table public.audit_logs enable row level security;

drop policy if exists "Audit logs select admin" on public.audit_logs;
create policy "Audit logs select admin"
  on public.audit_logs for select
  using (
    exists (
      select 1
      from public.profiles as p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  );
