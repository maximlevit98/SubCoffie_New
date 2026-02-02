# Supabase Local Setup (Backend)

## Requirements
- Supabase CLI installed
- Docker running

## Start stack
```bash
supabase start
supabase status
```
`supabase status --output=json | jq` shows API URL, anon key, and service role key.

## Reset database from migrations + seed
```bash
supabase db reset
```

## Keys and URLs
- Project URL: from `supabase status` (`API URL`)
- anon key: from `supabase status`
- service role key: from `supabase status` (do NOT use in client apps)

## Example REST calls (anon)
```bash
API_URL=http://127.0.0.1:54321
ANON_KEY="<paste anon key>"

curl "$API_URL/rest/v1/cafes?select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY"

curl "$API_URL/rest/v1/products?select=*&cafe_id=eq.11111111-1111-1111-1111-111111111111&category=eq.drinks" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY"
```

## SQL helper functions
All require authenticated user or service role:
- `init_user_profile_and_wallets(p_user uuid, p_phone text, p_full_name text, p_birth date, p_city text)`
- `get_or_create_citypass_wallet(p_user uuid)`
- `get_or_create_cafe_wallet(p_user uuid, p_cafe uuid)`

## Profiles + admin role
After registration, a row is auto-created in `public.profiles`.
To promote yourself to admin (local dev):
```sql
update public.profiles
set role = 'admin'
where email = '<your email>';
```
