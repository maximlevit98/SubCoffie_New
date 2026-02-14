# AGENTS.md (iOS client)

## Scope
This folder contains the active iOS app built with SwiftUI.
Avoid editing `SubscribeCoffie/` unless explicitly required.

## Architecture
- MVVM-like with `ObservableObject` stores.
- Navigation state is in `ContentView.AppScreen`.

## Entry Points
- App: `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieCleanApp.swift`
- Navigation: `SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/ContentView.swift`

## Networking
- Supabase REST/RPC wrapper: `Helpers/SupabaseAPIClient.swift`
- Auth: `Helpers/AuthService.swift`

## Runbook
- `./quick-run.sh` (simulator)
- Build: `xcodebuild -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj -scheme SubscribeCoffieClean -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- Tests: see `README_TESTING.md`

## Env
- Local Supabase URL/keys are in `Helpers/Environment.swift`.
