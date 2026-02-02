# Cafe Networks Implementation Summary

## Overview
Implementation of cafe networks feature allowing cafe owners to group multiple cafes into networks, and users to create Cafe Wallets that work across all cafes in a network.

## Implementation Date
2026-02-06

---

## Backend Implementation

### Migration: `20260206000000_cafe_networks_management.sql`

#### RPC Functions Created:

1. **`create_network(name, owner_user_id, commission_rate)`**
   - Creates a new cafe network
   - Admin/owner only
   - Validates commission rate (0-100%)

2. **`add_cafe_to_network(network_id, cafe_id)`**
   - Adds a cafe to an existing network
   - Admin/network owner only
   - Prevents duplicate membership

3. **`remove_cafe_from_network(network_id, cafe_id)`**
   - Removes a cafe from a network
   - Admin/network owner only

4. **`get_network_cafes(network_id)`**
   - Returns all cafes in a network with details
   - Public access

5. **`get_cafe_network(cafe_id)`**
   - Returns the network a cafe belongs to (if any)
   - Public access

6. **`get_all_networks(limit, offset)`**
   - Lists all networks with cafe counts
   - Admin only

7. **`get_network_details(network_id)`**
   - Detailed network information including wallet counts
   - Admin/network owner only

8. **`update_network(network_id, name, commission_rate)`**
   - Updates network name and/or commission rate
   - Admin/network owner only

9. **`delete_network(network_id)`**
   - Deletes a network (only if no wallets are tied to it)
   - Admin/network owner only

10. **`get_available_cafes_for_network(network_id)`**
    - Lists all cafes with their network membership status
    - Useful for admin UI

#### Database Tables Used:
- `wallet_networks` (already existed from migration 20260201000000)
- `cafe_network_members` (already existed from migration 20260201000000)

---

## iOS App Implementation

### Models Updated/Added

#### `WalletModels.swift`
Added new models:
- `NetworkInfo`: Basic network information
- `NetworkDetails`: Detailed network information with statistics
- `NetworkCafe`: Cafe information within a network
- `SupabaseNetworkDTO`: DTO for network data from Supabase

### Services Updated

#### `WalletService.swift`
Added network operations:
- `getCafeNetwork(cafeId:)`: Get network for a specific cafe
- `getNetworkCafes(networkId:)`: Get all cafes in a network

### Views Updated

#### `WalletSelectionView.swift`
**Major Updates:**
1. `CreateWalletSheet` now supports cafe/network selection for Cafe Wallets
2. Added `CafeNetworkSelectionView`: New view for selecting cafe or network
   - Segmented control to switch between cafes and networks
   - Lists all available cafes
   - Lists all available networks with their cafe counts
   - Shows which cafes are in each network
3. Validates that Cafe Wallet has either a cafe or network selected before creation

**User Flow:**
1. User selects "Create Cafe Wallet"
2. User is prompted to choose between individual cafe or network
3. User can browse cafes or networks
4. Selection is displayed with name
5. Wallet is created with proper cafe_id or network_id

#### `CafeView.swift`
**Updates:**
1. Added network loading on view appearance
2. `CafeHeroHeader` now displays network badge if cafe belongs to a network
   - Green badge with network icon
   - Shows "Сеть: [Network Name]"
3. Network information is loaded asynchronously

**Visual Enhancement:**
- Network badge appears alongside mode badge and ETA
- Uses green color to distinguish from other badges
- Shows building icon to indicate network membership

---

## Usage Examples

### Backend (PostgreSQL/Supabase)

```sql
-- Create a network
SELECT create_network(
  'Starbucks Russia',
  '12345678-1234-1234-1234-123456789012'::uuid,
  4.5
);

-- Add cafes to network
SELECT add_cafe_to_network(
  'network-uuid'::uuid,
  'cafe-uuid'::uuid
);

-- Get all cafes in a network
SELECT * FROM get_network_cafes('network-uuid'::uuid);

-- Check if a cafe is in a network
SELECT * FROM get_cafe_network('cafe-uuid'::uuid);
```

### iOS App

```swift
// Get network for a cafe
let walletService = WalletService()
let network = try await walletService.getCafeNetwork(cafeId: cafeId)

// Get all cafes in a network
let cafes = try await walletService.getNetworkCafes(networkId: networkId)

// Create a Cafe Wallet for a network
let walletId = try await walletService.createCafeWallet(
    userId: userId,
    cafeId: nil,
    networkId: networkId
)
```

---

## Benefits

### For Users:
1. **Convenience**: Single wallet works across all locations in a network
2. **Lower commission**: Network wallets have lower commission than CityPass (3-5% vs 5-10%)
3. **Network loyalty**: Can follow favorite cafe chains

### For Cafe Owners:
1. **Multi-location support**: Easy management of cafe chains
2. **Customer loyalty**: Users with network wallets are more likely to visit multiple locations
3. **Branding**: Network identity strengthens brand recognition

### For Platform:
1. **Scalability**: Support for large cafe chains
2. **Flexibility**: Cafes can be independent or part of networks
3. **Revenue**: Commission from network wallets

---

## Validation Rules

1. **Network Creation**:
   - Name is required
   - Commission rate must be 0-100%
   - Only admins and cafe owners can create networks

2. **Cafe Membership**:
   - A cafe can only be in one network at a time (enforced by RPC)
   - Cafes can be removed from networks
   - Network owner or admin can manage membership

3. **Wallet Creation**:
   - Cafe Wallet must have either cafe_id OR network_id (not both)
   - User can have multiple Cafe Wallets (one per cafe/network)
   - User can have only one CityPass wallet

4. **Wallet Usage**:
   - CityPass works everywhere
   - Cafe Wallet (cafe): works only at that specific cafe
   - Cafe Wallet (network): works at all cafes in the network

5. **Network Deletion**:
   - Can only delete network if no wallets are tied to it
   - Prevents orphaned wallets

---

## Testing Checklist

### Backend:
- [x] Create network RPC function
- [x] Add/remove cafe from network
- [x] Get network cafes
- [x] Get cafe network
- [x] Update network
- [x] Delete network (with wallet constraint)
- [x] All RLS policies work correctly

### iOS App:
- [x] Load and display network info on CafeView
- [x] Create Cafe Wallet with cafe selection
- [x] Create Cafe Wallet with network selection
- [x] Display network badge on cafe header
- [x] List networks with cafe counts
- [x] Show cafe names under each network

### Integration:
- [ ] Create network via admin panel
- [ ] Add cafes to network via admin panel
- [ ] User creates network wallet
- [ ] User uses network wallet at different cafes in network
- [ ] Verify commission calculation for network wallets
- [ ] Verify wallet cannot be used at cafe not in network

---

## Future Enhancements

1. **Admin Panel**: Create UI for network management (not in this implementation)
2. **Network Analytics**: Track usage across network locations
3. **Network Promotions**: Special offers for network wallet holders
4. **Network Transfers**: Allow transferring wallets between networks
5. **Network Hierarchy**: Support for sub-networks or franchises

---

## Files Modified/Created

### Backend:
- `/supabase/migrations/20260206000000_cafe_networks_management.sql` (NEW)

### iOS:
- `/Models/WalletModels.swift` (UPDATED)
- `/Helpers/WalletService.swift` (UPDATED)
- `/Views/WalletSelectionView.swift` (UPDATED)
- `/Views/CafeView.swift` (UPDATED)

---

## Notes

- Tables `wallet_networks` and `cafe_network_members` were created in migration `20260201000000_wallet_types_mock_payments.sql`
- Wallet validation logic (`validate_wallet_for_order`) already supports networks
- Commission config already includes network wallet commission rates
- The existing `get_user_wallets` RPC already returns network information

---

## Related Documentation

- [Development Roadmap](../subscribecoffie_development_roadmap.plan.md) - Section 1.6
- [Wallet Types Implementation](./20260201000000_wallet_types_mock_payments.sql)
- [API Contract](./SUPABASE_API_CONTRACT.md)
