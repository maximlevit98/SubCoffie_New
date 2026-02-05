# Cafe Networks Migration Plan (P1)

**Date**: 2026-02-05 (Prompt 6)  
**Priority**: P1  
**Status**: ⏳ PLANNING

---

## Problem Analysis

### Current State

1. **✅ Tables exist**: `wallet_networks` and `cafe_network_members`
   - Created in `20260201000002_wallet_types_mock_payments.sql`
   - RLS enabled with basic policies

2. **❌ RPC functions disabled**: `20260206000000_cafe_networks_management.sql.disabled`
   - Contains 10 RPC functions for network management
   - Not applied to database

3. **⚠️ iOS calls disabled RPCs**:
   - `WalletService.swift`:
     - `getCafeNetwork(cafeId)` → calls `get_cafe_network`
     - `getNetworkCafes(networkId)` → calls `get_network_cafes`
   - `CafeView.swift`: calls `getCafeNetwork()` to display network badge
   - `WalletSelectionView.swift`: calls both RPCs to group cafes by network

4. **Status**: iOS code will fail when calling these RPCs (404/function not found)

---

## Decision: Enable Networks Feature

### Rationale

1. **✅ Tables already exist** and have proper structure
2. **✅ iOS UI already implemented** and expects these RPCs
3. **✅ Feature is useful**:
   - Groups cafes into networks (e.g., "Starbucks", "Coffee Company")
   - Cafe wallets can be tied to networks (not just individual cafes)
   - Lower commission for network wallets (4% vs 7%)

4. **✅ Migration is safe**:
   - RPC functions are read-heavy (mostly SELECT)
   - Security checks already implemented
   - No breaking changes to existing data

### Alternative (NOT chosen)
- ❌ Remove iOS calls and disable feature
- **Why not**: Feature is already partially implemented, tables exist, just need RPCs

---

## Migration Plan

### Phase 1: Enable RPC Functions ✅

**File**: Rename `20260206000000_cafe_networks_management.sql.disabled` → enabled

**Actions**:
1. Review RPC functions for security
2. Add missing RLS policies if needed
3. Grant execute permissions
4. Enable migration

**RPCs to enable** (10 total):
- `get_cafe_network(p_cafe_id)` ← **iOS uses this**
- `get_network_cafes(p_network_id)` ← **iOS uses this**
- `get_all_networks(p_limit, p_offset)` (admin only)
- `get_network_details(p_network_id)` (admin/owner)
- `create_network(p_name, p_owner_user_id, p_commission_rate)` (admin/owner)
- `add_cafe_to_network(p_network_id, p_cafe_id)` (admin/owner)
- `remove_cafe_from_network(p_network_id, p_cafe_id)` (admin/owner)
- `update_network(p_network_id, p_name, p_commission_rate)` (admin/owner)
- `delete_network(p_network_id)` (admin/owner)
- `get_available_cafes_for_network(p_network_id)` (public)

### Phase 2: Add Missing Security ✅

**Actions**:
1. Add grants for public RPCs:
   - `get_cafe_network` → anon, authenticated
   - `get_network_cafes` → anon, authenticated
   - `get_available_cafes_for_network` → anon, authenticated

2. Verify RLS policies on tables:
   - `wallet_networks` → ✅ already has policies
   - `cafe_network_members` → ✅ already has policies

3. Add additional checks if needed

### Phase 3: Test Backend ✅

**SQL Tests**:
```sql
-- Test 1: Create network (admin only)
SELECT public.create_network(
  'Test Network',
  auth.uid(),
  4.00
);

-- Test 2: Add cafe to network
SELECT public.add_cafe_to_network(
  'NETWORK_ID',
  'CAFE_ID'
);

-- Test 3: Get network cafes (public)
SELECT * FROM public.get_network_cafes('NETWORK_ID');

-- Test 4: Get cafe network (public)
SELECT * FROM public.get_cafe_network('CAFE_ID');

-- Test 5: Get all networks (admin only)
SELECT * FROM public.get_all_networks(10, 0);
```

### Phase 4: Test iOS Integration ✅

**iOS Tests**:
1. Test `getCafeNetwork()`:
   - Open CafeView for a cafe in a network
   - Check network badge displays

2. Test `getNetworkCafes()`:
   - Open WalletSelectionView
   - Check cafes grouped by network

3. Test error handling:
   - Call for cafe NOT in network
   - Should return nil (not crash)

### Phase 5: Seed Data ✅

**Create test networks**:
```sql
-- Insert test networks
INSERT INTO public.wallet_networks (name, commission_rate)
VALUES
  ('Coffee House Network', 4.00),
  ('Starbucks Russia', 4.00),
  ('Local Cafes Alliance', 3.50)
ON CONFLICT DO NOTHING;

-- Link cafes to networks
INSERT INTO public.cafe_network_members (network_id, cafe_id)
SELECT
  (SELECT id FROM public.wallet_networks WHERE name = 'Coffee House Network'),
  id
FROM public.cafes
WHERE name ILIKE '%coffee house%'
LIMIT 5;
```

### Phase 6: Documentation ✅

**Create**:
- `CAFE_NETWORKS_IMPLEMENTATION.md` - Feature guide
- Update `WALLET_SCHEMA_UNIFICATION.md` - Reference networks
- Admin guide: How to manage networks

---

## Security Review

### RLS Policies (Already Exist)

**`wallet_networks`**:
```sql
-- Admin can manage
create policy "Admin can manage networks"
  on public.wallet_networks for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Public can view
create policy "Public can view networks"
  on public.wallet_networks for select
  using (true);
```

**`cafe_network_members`**:
```sql
-- Admin can manage
create policy "Admin can manage cafe network members"
  on public.cafe_network_members for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Public can view
create policy "Public can view cafe network members"
  on public.cafe_network_members for select
  using (true);
```

### RPC Security (Built-in)

All management RPCs have security checks:
- `create_network`: admin/owner only
- `add_cafe_to_network`: admin/network owner only
- `remove_cafe_from_network`: admin/network owner only
- `update_network`: admin/network owner only
- `delete_network`: admin/network owner only (+ checks for wallets)

Read RPCs are public:
- `get_cafe_network`: public (needed for iOS)
- `get_network_cafes`: public (needed for iOS)
- `get_available_cafes_for_network`: public

**Security verdict**: ✅ Safe to enable

---

## Grants Required

Add to migration file:

```sql
-- Grant execute on public read RPCs
grant execute on function public.get_cafe_network(uuid) to anon, authenticated;
grant execute on function public.get_network_cafes(uuid) to anon, authenticated;
grant execute on function public.get_available_cafes_for_network(uuid) to anon, authenticated;

-- Management RPCs use security definer + internal auth checks
grant execute on function public.create_network(text, uuid, decimal) to authenticated;
grant execute on function public.add_cafe_to_network(uuid, uuid) to authenticated;
grant execute on function public.remove_cafe_from_network(uuid, uuid) to authenticated;
grant execute on function public.update_network(uuid, text, decimal) to authenticated;
grant execute on function public.delete_network(uuid) to authenticated;
grant execute on function public.get_all_networks(int, int) to authenticated;
grant execute on function public.get_network_details(uuid) to authenticated;
```

---

## Testing Checklist

### Backend

- [ ] Apply migration (rename .disabled file)
- [ ] Verify all RPCs created
- [ ] Test grants: anon can call `get_cafe_network`
- [ ] Test grants: authenticated can call management RPCs
- [ ] Test RLS: public can SELECT from tables
- [ ] Test security: non-admin cannot create network
- [ ] Test security: non-owner cannot delete network
- [ ] Seed test data

### iOS

- [ ] Open CafeView for networked cafe
- [ ] Check network badge displays
- [ ] Open WalletSelectionView
- [ ] Check cafes grouped by network
- [ ] Test with cafe NOT in network (should not crash)
- [ ] Create cafe wallet for network
- [ ] Verify 4% commission applied

### Admin Panel (Future)

- [ ] Add UI for network management
- [ ] List all networks
- [ ] Create/edit/delete networks
- [ ] Add/remove cafes from networks

---

## Risks & Mitigation

### Risk 1: RPC Performance
- **Risk**: `get_cafe_network` called for every cafe
- **Impact**: Many DB queries
- **Mitigation**: 
  - RPC uses indexes (network_id, cafe_id)
  - Results can be cached in iOS
  - Query is simple JOIN (fast)

### Risk 2: Breaking Changes
- **Risk**: Existing wallets/cafes affected
- **Impact**: Low - tables already exist, just adding RPCs
- **Mitigation**: No schema changes, only new functions

### Risk 3: Admin Access
- **Risk**: Anyone can create networks if security fails
- **Impact**: Medium - network spam
- **Mitigation**:
  - RPC has explicit role checks
  - security definer set
  - Test coverage for auth

---

## Timeline

1. **Review & Update**: 30 min
   - Review RPCs
   - Add grants
   - Update migration file

2. **Testing**: 1 hour
   - Backend SQL tests
   - iOS integration tests
   - Security tests

3. **Seed Data**: 15 min
   - Create test networks
   - Link cafes

4. **Documentation**: 30 min
   - Implementation guide
   - Admin guide

**Total**: ~2.5 hours

---

## Recommendation

✅ **ENABLE the migration**

**Reasons**:
1. Tables already exist and are used
2. iOS code expects these RPCs
3. Feature adds value (network wallets, lower commission)
4. Security is properly implemented
5. No breaking changes
6. Low risk, high benefit

**Action Items**:
1. Rename migration file (remove .disabled)
2. Add grants section
3. Apply to dev database
4. Test iOS integration
5. Create seed data
6. Document feature

---

**Status**: Ready for implementation  
**Risk Level**: Low  
**Effort**: ~2.5 hours  
**Value**: High (completes wallet types feature)
