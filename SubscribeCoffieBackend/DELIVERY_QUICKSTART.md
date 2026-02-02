# Delivery System Quick Start Guide

## Quick Setup

### 1. Database Migration

Run the delivery migration:

```bash
cd SubscribeCoffieBackend
supabase db reset  # or apply migration individually
```

### 2. Create Test Delivery Zone

```sql
-- Connect to your Supabase project and run:
INSERT INTO delivery_zones (
  cafe_id,
  name,
  zone_type,
  center_latitude,
  center_longitude,
  radius_km,
  base_delivery_fee_credits,
  fee_per_km_credits,
  min_order_amount_credits,
  free_delivery_threshold_credits,
  is_active,
  max_delivery_time_minutes
) VALUES (
  (SELECT id FROM cafes LIMIT 1),  -- Use your test cafe ID
  'Test Delivery Zone',
  'radius',
  55.7558,  -- Moscow center
  37.6173,
  5.0,      -- 5km radius
  5000,     -- 50₽ base fee
  1000,     -- 10₽ per km
  30000,    -- 300₽ minimum order
  80000,    -- Free delivery above 800₽
  true,
  60
);
```

### 3. Create Test Courier

```sql
-- First, create a user account for the courier (or use existing)
-- Then create courier profile:
INSERT INTO couriers (
  user_id,
  full_name,
  phone,
  email,
  vehicle_type,
  status,
  is_verified,
  is_active,
  current_location_lat,
  current_location_lon
) VALUES (
  'YOUR_USER_ID_HERE',
  'Test Courier',
  '+79001234567',
  'courier@test.com',
  'bicycle',
  'available',
  true,
  true,
  55.7558,  -- Near cafe
  37.6173
);
```

### 4. iOS Integration

The delivery system is already integrated into `CheckoutView.swift`. To use it:

1. **For Customers:**
   - Open checkout
   - Select "Доставка" (Delivery) toggle
   - Enter delivery address
   - System will calculate delivery fee automatically
   - Complete order as usual

2. **For Couriers:**
   - Add a new tab or section for courier mode
   - Use `CourierDashboardView` as the root view
   - Pass courier ID from authentication

Example courier integration:

```swift
// In your main app structure
TabView {
    // ... existing tabs
    
    if userRole == .courier {
        NavigationView {
            CourierDashboardView(courierId: currentUser.id)
        }
        .tabItem {
            Label("Доставки", systemImage: "bicycle")
        }
    }
}
```

### 5. Testing Flow

**Test Delivery Order:**

1. As customer:
   - Add items to cart
   - Go to checkout
   - Select delivery
   - Enter test address: "Москва, ул. Тверская, 10"
   - Latitude: 55.7600, Longitude: 37.6200
   - Confirm delivery fee appears
   - Place order

2. As courier (in database):
   ```sql
   -- Manually assign courier to delivery
   SELECT assign_courier_to_order(
     (SELECT id FROM delivery_orders ORDER BY created_at DESC LIMIT 1),
     (SELECT id FROM couriers LIMIT 1),
     false
   );
   ```

3. As courier (in app):
   - Open courier dashboard
   - See assigned delivery
   - Update status: Picked Up → In Transit → Delivered

4. As customer:
   - Open order tracking
   - See delivery status updates
   - Rate courier after delivery

### 6. Key Features to Test

✅ **Delivery Fee Calculation**
- Enter different addresses and distances
- Test minimum order requirement
- Test free delivery threshold

✅ **Real-Time Tracking**
- View delivery on map
- Watch status updates
- See ETA changes

✅ **Courier Operations**
- Update location (automatic in app)
- Accept delivery
- Update status through lifecycle
- Report issues

✅ **Ratings**
- Rate courier after completion
- View courier rating in profile

## Common Issues

### "Delivery not available"

**Possible causes:**
1. No delivery zone configured for cafe
2. Address outside delivery radius
3. Order amount below minimum

**Fix:**
```sql
-- Check if delivery zone exists
SELECT * FROM delivery_zones WHERE cafe_id = 'your-cafe-id' AND is_active = true;

-- If not, create one (see step 2 above)
```

### "No available couriers"

**Possible causes:**
1. No couriers registered
2. All couriers offline/busy
3. No couriers near cafe

**Fix:**
```sql
-- Check courier status
SELECT id, full_name, status, current_location_lat, current_location_lon 
FROM couriers;

-- Set courier to available
UPDATE couriers SET status = 'available' WHERE id = 'courier-id';

-- Update courier location near cafe
UPDATE couriers 
SET current_location_lat = 55.7558, 
    current_location_lon = 37.6173
WHERE id = 'courier-id';
```

### Location tracking not working

1. Check iOS location permissions:
   - Settings → Privacy → Location Services → Your App
   - Should be "Always" or "While Using"

2. Verify Info.plist entries:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>We need your location to track deliveries</string>
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>We track your location to show delivery progress to customers</string>
   ```

## API Endpoints Reference

All endpoints use Supabase RPC format: `/rest/v1/rpc/{function_name}`

### Customer Endpoints

**Calculate Delivery Fee:**
```json
POST /rpc/calculate_delivery_fee
{
  "p_cafe_id": "uuid",
  "p_delivery_lat": 55.7600,
  "p_delivery_lon": 37.6200,
  "p_order_amount_credits": 45000
}
```

**Create Delivery Order:**
```json
POST /rpc/create_delivery_order
{
  "p_order_id": "uuid",
  "p_delivery_address": "Address string",
  "p_delivery_lat": 55.7600,
  "p_delivery_lon": 37.6200,
  "p_delivery_notes": "Optional notes",
  "p_customer_phone": "+79001234567",
  "p_customer_name": "Customer Name"
}
```

**Get Tracking:**
```json
POST /rpc/get_delivery_tracking
{
  "p_order_id": "uuid"
}
```

**Rate Courier:**
```json
POST /rpc/rate_courier
{
  "p_delivery_order_id": "uuid",
  "p_rating": 5,
  "p_feedback": "Great service!"
}
```

### Courier Endpoints

**Update Location:**
```json
POST /rpc/update_courier_location
{
  "p_courier_id": "uuid",
  "p_latitude": 55.7558,
  "p_longitude": 37.6173,
  "p_accuracy": 10.0,
  "p_speed": 5.0,
  "p_heading": 90.0
}
```

**Get Active Deliveries:**
```json
POST /rpc/get_courier_active_deliveries
{
  "p_courier_id": "uuid"
}
```

**Update Status:**
```json
POST /rpc/update_delivery_status
{
  "p_delivery_order_id": "uuid",
  "p_new_status": "picked_up",
  "p_reason": null
}
```

## Production Considerations

### Before Production Launch:

1. **Configure Real Delivery Zones**
   - Map actual cafe coverage areas
   - Set realistic pricing
   - Test with real addresses

2. **Set Up Courier Onboarding**
   - Verification process
   - Background checks (if required)
   - Training materials
   - Equipment (bags, etc.)

3. **Enable Push Notifications**
   - Courier assignment alerts
   - Status update notifications
   - Delivery completion alerts

4. **Add Monitoring**
   - Track delivery times
   - Monitor courier availability
   - Alert on delayed deliveries
   - Track customer ratings

5. **Legal Compliance**
   - Courier contracts
   - Insurance requirements
   - Tax documentation
   - GDPR/privacy compliance for location data

## Next Steps

After basic testing:

1. ✅ Verify all RPC functions work
2. ✅ Test full delivery lifecycle
3. ✅ Configure real delivery zones for your cafes
4. ✅ Onboard real couriers
5. 📋 Add push notifications
6. 📋 Set up monitoring dashboards
7. 📋 Create courier training materials
8. 📋 Launch beta with limited area

## Support

For implementation help:
- Review `DELIVERY_SYSTEM_IMPLEMENTATION.md` for detailed documentation
- Check migration file: `20260222000000_delivery.sql`
- Review iOS models: `DeliveryModels.swift`
- Test with included preview/sample data
