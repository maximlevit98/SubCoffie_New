# AGENTS.md (Admin)

## Scope
Next.js admin panel (App Router) using Supabase SSR/Browser clients.

## Entry Points
- Layout: `app/layout.tsx`
- Root redirect: `app/page.tsx`
- Routes: `app/admin/*`, `app/cafe-owner/*`, `app/login`

## Supabase
- Browser client: `src/lib/supabase/client.ts`
- Server client: `src/lib/supabase/server.ts`
- Queries: `lib/supabase/queries/*`

## Runbook
- `npm install`
- `npm run dev`
- `npm run build`
- `npm run lint`

## Env
- See `ENV_CONFIGURATION.md` (copy to `.env.local`).
