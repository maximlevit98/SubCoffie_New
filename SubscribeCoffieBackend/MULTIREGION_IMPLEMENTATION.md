# Multi-Region and Franchise Management Implementation

## Overview

This implementation adds comprehensive support for multi-regional operations and franchise partner management to SubscribeCoffie. The system allows the platform to operate across multiple cities and regions, with support for franchise partnerships.

## Features Implemented

### 1. Backend (Supabase)

#### Database Schema

**Tables:**

- `regions` - Geographic regions where the platform operates
  - `id` (UUID, PK)
  - `name` (TEXT) - Display name (e.g., "Moscow Central")
  - `city` (TEXT) - City name
  - `country` (TEXT) - Country name
  - `timezone` (TEXT) - IANA timezone identifier
  - `is_active` (BOOLEAN) - Whether region accepts orders
  - `latitude`, `longitude` (DECIMAL) - Region center coordinates
  - `created_at`, `updated_at` (TIMESTAMP)

- `cafe_regions` - Maps cafes to their operating regions
  - `cafe_id` (UUID, FK → cafes.id)
  - `region_id` (UUID, FK → regions.id)
  - `assigned_at` (TIMESTAMP)

- `delivery_zones` - Delivery zones within regions with pricing
  - `id` (UUID, PK)
  - `region_id` (UUID, FK → regions.id)
  - `name` (TEXT) - Zone name
  - `boundary` (JSONB) - GeoJSON polygon for zone boundary
  - `base_delivery_fee` (DECIMAL) - Base delivery fee in credits
  - `min_order_amount` (DECIMAL) - Minimum order amount
  - `is_active` (BOOLEAN)

- `franchise_partners` - Franchise partners managing cafes
  - `id` (UUID, PK)
  - `user_id` (UUID, FK → profiles.id)
  - `company_name` (TEXT)
  - `contact_person` (TEXT)
  - `email` (TEXT)
  - `phone` (TEXT)
  - `tax_id` (TEXT, nullable)
  - `regions` (UUID[]) - Array of region IDs
  - `contract_number` (TEXT, nullable)
  - `contract_start_date`, `contract_end_date` (DATE, nullable)
  - `commission_rate` (DECIMAL) - Platform commission rate
  - `status` (TEXT) - 'active', 'suspended', 'terminated'
  - `notes` (TEXT, nullable)

#### RPC Functions

**Region Management:**

- `create_region(name, city, country, timezone, latitude, longitude)` - Create new region (admin only)
- `update_region(region_id, name, is_active, timezone, latitude, longitude)` - Update region details
- `get_all_regions(include_inactive)` - Get all regions with cafe counts
- `assign_cafe_to_region(cafe_id, region_id)` - Assign cafe to region
- `remove_cafe_from_region(cafe_id, region_id)` - Remove cafe from region
- `get_cafes_in_region(region_id, limit, offset)` - Get all cafes in a region

**Delivery:**

- `calculate_delivery_fee(cafe_id, user_latitude, user_longitude)` - Calculate delivery fee based on distance and zone

**Franchise Management:**

- `create_franchise_partner(user_id, company_name, contact_person, email, phone, tax_id, commission_rate)` - Create franchise partner
- `update_franchise_partner(franchise_id, ...)` - Update franchise partner details
- `get_all_franchise_partners(status, limit, offset)` - Get all franchise partners (admin only)
- `get_franchise_partner_details(franchise_id)` - Get detailed franchise partner info

#### Row Level Security (RLS)

All tables have RLS enabled with appropriate policies:
- Public can view active regions and delivery zones
- Admins can manage all data
- Franchise partners can view their own data

#### Seed Data

Default regions added:
- Moscow Central
- Saint Petersburg
- Novosibirsk

### 2. Admin Panel (Next.js)

#### New Pages

**Regions Management:**

- `/admin/regions` - List all regions
  - Create new regions
  - View region statistics (cafe count)
  - Filter active/inactive regions
  - Navigate to region details

- `/admin/regions/[id]` - Region detail page
  - Edit region details (name, timezone, coordinates, active status)
  - View cafes in region
  - Assign cafes to region
  - Remove cafes from region

**Franchise Management:**

- `/admin/franchise` - List all franchise partners
  - Create new franchise partners
  - Filter by status (active, suspended, terminated)
  - View partner statistics (regions, cafes, commission)
  - Navigate to partner details

- `/admin/franchise/[id]` - Franchise partner detail page
  - Edit partner details
  - View contract information
  - Update status
  - View regions and cafe count

#### Queries and Actions

New query files:
- `lib/supabase/queries/regions.ts` - Region data fetching
- `lib/supabase/queries/franchise.ts` - Franchise data fetching

New action files:
- `app/admin/regions/actions.ts` - Region management server actions
- `app/admin/franchise/actions.ts` - Franchise management server actions

### 3. iOS App (SwiftUI)

#### New Models

- `Region.swift` - Region data model
  - Properties: id, name, city, country, timezone, isActive, latitude, longitude, cafeCount, createdAt
  - Display helpers: displayName, fullLocation

#### New Services

- `RegionService.swift` - Region management service
  - `@Published var regions` - List of all regions
  - `@Published var selectedRegion` - Currently selected region
  - `fetchRegions(includeInactive:)` - Fetch all regions from API
  - `getCafesInRegion(regionId:)` - Get cafes in specific region
  - `selectRegion(_:)` - Select a region
  - `clearSelection()` - Clear selected region

#### New Components

- `RegionPickerView.swift` - Region picker button and sheet
  - Displays current region or "Select city"
  - Shows region picker sheet on tap
  - Auto-loads regions on appear

- `RegionSelectionSheet.swift` - Full-screen region selection
  - Lists all active regions
  - Shows region name, city, country
  - Displays cafe count per region
  - Checkmark for selected region

#### Updated Views

- `MapSelectionView.swift` - Enhanced with region filtering
  - Added region picker at the top
  - Integrated with RegionService
  - Filters cafes by selected region (when backend supports it)
  - Auto-loads regions on view appear

## Usage

### Admin Panel

1. **Create a Region:**
   - Navigate to `/admin/regions`
   - Fill in region form (name, city, country, timezone, coordinates)
   - Click "Add Region"

2. **Assign Cafes to Region:**
   - Navigate to `/admin/regions/[region-id]`
   - Select cafe from dropdown
   - Click "Assign"

3. **Create Franchise Partner:**
   - Navigate to `/admin/franchise`
   - Fill in partner form (user ID, company name, contact info, commission rate)
   - Click "Add Franchise Partner"

4. **Manage Franchise Partner:**
   - Navigate to `/admin/franchise/[partner-id]`
   - Edit details, update status, add notes
   - Click "Update Franchise Partner"

### iOS App

1. **Select Region:**
   - Open cafe selection screen
   - Tap region picker at the top
   - Select desired city/region
   - Cafes will be filtered (when backend support is added)

2. **View Available Regions:**
   - Regions are auto-loaded when app opens
   - Only active regions are shown
   - Cafe count displayed for each region

## Database Migration

To apply the migration:

```bash
cd SubscribeCoffieBackend
supabase db push
```

The migration file is: `supabase/migrations/20260220000000_multiregion.sql`

## API Endpoints

All RPC functions are accessible via Supabase client:

```typescript
// Get all regions
const { data } = await supabase.rpc('get_all_regions', { 
  p_include_inactive: false 
});

// Get cafes in region
const { data } = await supabase.rpc('get_cafes_in_region', {
  p_region_id: regionId,
  p_limit: 50,
  p_offset: 0
});

// Calculate delivery fee
const { data } = await supabase.rpc('calculate_delivery_fee', {
  p_cafe_id: cafeId,
  p_user_latitude: 55.7558,
  p_user_longitude: 37.6173
});
```

## Future Enhancements

1. **Geolocation Integration:**
   - Auto-detect user's region based on GPS
   - Show nearest region by default

2. **Advanced Delivery Zone Management:**
   - Visual map editor for delivery zones
   - Point-in-polygon validation using PostGIS
   - Dynamic pricing based on demand

3. **Franchise Dashboard:**
   - Dedicated dashboard for franchise partners
   - Revenue analytics per region
   - Performance metrics

4. **Multi-Region Analytics:**
   - Compare regions performance
   - Identify growth opportunities
   - Region-specific marketing campaigns

## Notes

- The delivery fee calculation is simplified. For production, consider using PostGIS for accurate point-in-polygon checks.
- Region filtering in iOS app requires backend to return cafe-region mappings via the existing cafe list API.
- Franchise partners currently link to regions via UUID array. Consider a separate junction table if more metadata is needed.

## Testing

1. **Backend:**
   - Run migration
   - Create test regions via admin panel
   - Assign cafes to regions
   - Test RPC functions via Supabase dashboard

2. **Admin Panel:**
   - Create regions and verify in database
   - Assign cafes and verify relationships
   - Create franchise partners with different statuses
   - Test all CRUD operations

3. **iOS App:**
   - Verify region picker appears
   - Test region selection
   - Verify regions load correctly
   - Test empty state handling

## Support

For issues or questions:
- Check Supabase logs for backend errors
- Check browser console for admin panel errors
- Check Xcode console for iOS app errors
- Review RLS policies if permission denied errors occur
