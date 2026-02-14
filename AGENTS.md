# AGENTS.md

## Purpose
This file is the minimal “map of the repo” for AI assistants and new contributors.
Use it to avoid editing the wrong project, and to keep schema changes safe.

## Monorepo Layout (actual folder names)
- `SubscribeCoffieClean/` — **iOS app (SwiftUI)**. Primary client.
- `SubscribeCoffieBackend/` — **Supabase backend** (Postgres + RPC + Edge Functions).
- `subscribecoffie-admin/` — **Admin panel** (Next.js App Router).
- `SubscribeCoffie/` — legacy iOS project (avoid unless explicitly required).

## Guardrails
- **DB schema changes** must be done via new migration in
  `SubscribeCoffieBackend/supabase/migrations/`. Do not edit applied migrations.
- **Supabase RPC/API contracts** are shared across iOS + Admin. Avoid breaking changes
  without updating both clients.
- **Payments** include mock and real flows; be explicit about which path you change.

## Runbook (short)
Backend (Supabase):
- `cd SubscribeCoffieBackend`
- `supabase start`
- `supabase db reset`
- tests: `./tests/run_all_tests.sh`

iOS (SubscribeCoffieClean):
- `cd SubscribeCoffieClean`
- `./quick-run.sh`
- build: `xcodebuild -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj -scheme SubscribeCoffieClean -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- tests: see `SubscribeCoffieClean/README_TESTING.md`

Admin (Next.js):
- `cd subscribecoffie-admin`
- `npm install`
- `npm run dev`

## Env Files
- Backend: `SubscribeCoffieBackend/env.local.example`
- Admin: `subscribecoffie-admin/ENV_CONFIGURATION.md` (copy to `.env.local`)
- iOS: `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Helpers/Environment.swift`

## Key Entry Points
- iOS: `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieCleanApp.swift`
- Backend: `SubscribeCoffieBackend/supabase/migrations/` + `supabase/functions/*`
- Admin: `subscribecoffie-admin/app/layout.tsx`, `subscribecoffie-admin/app/page.tsx`

## Where to Look First
- iOS navigation/flow: `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/ContentView.swift`
- iOS API/RPC client: `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Helpers/SupabaseAPIClient.swift`
- Admin Supabase clients: `subscribecoffie-admin/src/lib/supabase/*`
- Backend API contracts: `SubscribeCoffieBackend/SUPABASE_API_CONTRACT.md`
