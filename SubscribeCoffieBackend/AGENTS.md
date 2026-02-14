# AGENTS.md (Backend)

## Scope
Supabase backend: Postgres schema, RPC functions, Edge Functions.

## Guardrails
- **Schema changes only via new migrations** in `supabase/migrations/`.
- Avoid editing existing migrations that have been applied.

## Entry Points
- Migrations: `supabase/migrations/`
- Edge Functions: `supabase/functions/*`
- Config: `supabase/config.toml`

## Runbook
- `supabase start`
- `supabase db reset`
- Tests: `./tests/run_all_tests.sh`

## Env
- Template: `env.local.example`
