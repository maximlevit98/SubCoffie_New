-- Seed Data: Cafe Networks
-- Description: Test networks and cafe memberships for development
-- Date: 2026-02-05
-- Usage: Run after 20260206000000_cafe_networks_management.sql

-- ============================================================================
-- 1. Create Test Networks
-- ============================================================================

-- Insert test networks (idempotent with ON CONFLICT)
insert into public.wallet_networks (id, name, commission_rate)
values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'Coffee House Network', 4.00),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'Starbucks Russia', 4.00),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'Local Cafes Alliance', 3.50),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'Premium Coffee Chain', 5.00)
on conflict (id) do update
set 
  name = excluded.name,
  commission_rate = excluded.commission_rate,
  updated_at = now();

-- ============================================================================
-- 2. Link Cafes to Networks
-- ============================================================================

-- Note: This assumes cafes exist. Adjust cafe_id values to match your data.
-- To find cafe IDs: SELECT id, name FROM public.cafes;

-- Example: Link cafes with 'coffee' in name to Coffee House Network
insert into public.cafe_network_members (network_id, cafe_id)
select
  '11111111-1111-1111-1111-111111111111'::uuid as network_id,
  id as cafe_id
from public.cafes
where lower(name) like '%coffee%'
  and id not in (
    select cafe_id from public.cafe_network_members
    where network_id = '11111111-1111-1111-1111-111111111111'::uuid
  )
limit 3
on conflict (network_id, cafe_id) do nothing;

-- Example: Link cafes with 'star' in name to Starbucks Russia
insert into public.cafe_network_members (network_id, cafe_id)
select
  '22222222-2222-2222-2222-222222222222'::uuid as network_id,
  id as cafe_id
from public.cafes
where lower(name) like '%star%'
  and id not in (
    select cafe_id from public.cafe_network_members
    where network_id = '22222222-2222-2222-2222-222222222222'::uuid
  )
limit 5
on conflict (network_id, cafe_id) do nothing;

-- Example: Link cafes with 'local' or 'cafe' in name to Local Cafes Alliance
insert into public.cafe_network_members (network_id, cafe_id)
select
  '33333333-3333-3333-3333-333333333333'::uuid as network_id,
  id as cafe_id
from public.cafes
where (lower(name) like '%local%' or lower(name) like '%cafe%')
  and id not in (
    select cafe_id from public.cafe_network_members
    where network_id = '33333333-3333-3333-3333-333333333333'::uuid
  )
limit 4
on conflict (network_id, cafe_id) do nothing;

-- ============================================================================
-- 3. Verification Queries
-- ============================================================================

-- Check created networks
select 
  id,
  name,
  commission_rate,
  (select count(*) from public.cafe_network_members where network_id = wn.id) as cafe_count
from public.wallet_networks wn
order by name;

-- Check cafe memberships
select
  wn.name as network_name,
  c.name as cafe_name,
  cnm.joined_at
from public.cafe_network_members cnm
inner join public.wallet_networks wn on wn.id = cnm.network_id
inner join public.cafes c on c.id = cnm.cafe_id
order by wn.name, c.name;

-- ============================================================================
-- 4. Test RPC Functions
-- ============================================================================

-- Test get_cafe_network (public access)
-- Replace CAFE_ID with actual cafe ID from your data
-- select * from public.get_cafe_network('CAFE_ID'::uuid);

-- Test get_network_cafes (public access)
select * from public.get_network_cafes('11111111-1111-1111-1111-111111111111'::uuid);

-- Test get_all_networks (admin only - will fail if not admin)
-- select * from public.get_all_networks(10, 0);

-- ============================================================================
-- 5. Manual Linking Examples
-- ============================================================================

-- To manually add a specific cafe to a network:
-- insert into public.cafe_network_members (network_id, cafe_id)
-- values (
--   '11111111-1111-1111-1111-111111111111'::uuid,  -- Coffee House Network
--   'YOUR_CAFE_ID'::uuid
-- )
-- on conflict do nothing;

-- To see all cafes NOT in any network:
-- select id, name, address
-- from public.cafes
-- where id not in (select cafe_id from public.cafe_network_members);

-- ============================================================================
-- Notes
-- ============================================================================

-- 1. Network IDs are hardcoded UUIDs for consistency across environments
-- 2. Cafe linking uses LIKE queries - adjust patterns to match your data
-- 3. Run verification queries to check results
-- 4. To reset: DELETE FROM public.cafe_network_members; DELETE FROM public.wallet_networks WHERE id IN (...);
