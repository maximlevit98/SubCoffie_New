# Delivery System Implementation

## Overview

The delivery system enables customers to receive their coffee orders via courier delivery. The system includes real-time tracking, automatic courier assignment, and a complete courier management interface.

## Architecture

### Backend Components

#### Database Tables

1. **couriers** - Courier profiles and current status
   - Stores courier information, vehicle type, ratings, and location
   - Tracks courier status (available, busy, offline, on_break)
   - Real-time location updates

2. **courier_locations** - Location tracking history
   - Records all location updates from couriers
   - Enables route replay and analytics
   - Links to active deliveries for tracking

3. **delivery_orders** - Delivery order details
   - Links to regular orders
   - Stores delivery address and customer contact
   - Tracks delivery status through lifecycle
   - Records timestamps for each status change

4. **delivery_zones** - Delivery coverage areas
   - Defines where cafes can deliver
   - Configures pricing (base fee, per-km fee)
   - Sets minimum order amounts and free delivery thresholds

5. **courier_payouts** - Courier earnings and payments
   - Tracks courier earnings per period
   - Manages platform commission
   - Records payment status

#### RPC Functions

**For Customers:**
- `calculate_delivery_fee(cafe_id, delivery_lat, delivery_lon, order_amount)` - Calculate delivery cost
- `create_delivery_order(...)` - Create a new delivery order
- `get_delivery_tracking(order_id)` - Get real-time tracking info
- `rate_courier(delivery_order_id, rating, feedback)` - Rate courier after delivery

**For Couriers:**
- `update_courier_location(courier_id, lat, lon, ...)` - Update courier location
- `get_courier_active_deliveries(courier_id)` - Get courier's active orders
- `update_delivery_status(delivery_order_id, new_status, reason)` - Update delivery status

**For Admin/System:**
- `find_available_couriers(lat, lon, radius_km)` - Find nearby available couriers
- `assign_courier_to_order(delivery_order_id, courier_id, auto_assign)` - Assign courier

### iOS Components

#### Models
- `DeliveryModels.swift` - All delivery-related data structures
  - DeliveryStatus, CourierStatus, VehicleType enums
  - DeliveryAddress, DeliveryFeeInfo, Courier, DeliveryOrder
  - Request/Response models for API calls

#### Services
- `DeliveryService.swift` - API client for delivery operations
  - Customer methods (calculate fee, create order, track, rate)
  - Courier methods (update location, get deliveries, update status)

#### Customer Views
- `DeliveryAddressView.swift` - Address input with geocoding
- `DeliveryTrackingView.swift` - Real-time delivery tracking with map
- Updated `CheckoutView.swift` - Delivery option in checkout flow

#### Courier Views
- `CourierDashboardView.swift` - Main courier interface
- `CourierDeliveryDetailView.swift` - Detailed delivery view with actions
- `CourierSettingsView.swift` - Courier profile and settings

## Features

### For Customers

1. **Delivery Option in Checkout**
   - Toggle between pickup and delivery
   - Address input with search suggestions
   - Real-time delivery fee calculation
   - ETA display
   - Free delivery thresholds

2. **Real-Time Tracking**
   - Live courier location on map
   - Status updates (assigned, picked up, in transit, delivered)
   - ETA updates
   - Courier contact information
   - Direct call to courier

3. **Courier Rating**
   - Rate courier after delivery (1-5 stars)
   - Optional written feedback
   - Ratings affect courier stats

### For Couriers

1. **Location Tracking**
   - Automatic background location updates
   - Updates sent every 30 seconds or 10 meters
   - Respects battery life

2. **Order Management**
   - List of assigned deliveries
   - Route navigation integration
   - Status updates (picked up, in transit, delivered)
   - Customer contact information
   - Failure reporting with reasons

3. **Earnings Tracking**
   - Real-time earnings display
   - Delivery history
   - Success rate statistics
   - Rating display

### For Cafes

1. **Delivery Zones**
   - Configure delivery coverage area
   - Set radius-based or polygon zones
   - Pricing configuration:
     - Base delivery fee
     - Per-kilometer fee
     - Minimum order amount
     - Free delivery threshold

2. **Courier Assignment**
   - Automatic assignment to nearest available courier
   - Manual assignment option
   - Assignment notifications

## Delivery Flow

### Customer Flow
1. Customer selects delivery option in checkout
2. Enters delivery address
3. System calculates delivery fee based on distance and zone
4. Customer confirms order
5. Order is created with delivery_orders entry
6. System assigns nearest available courier
7. Customer receives tracking link
8. Customer can track courier in real-time
9. Courier updates status through delivery lifecycle
10. Customer rates courier after delivery

### Courier Flow
1. Courier starts shift and goes online
2. Location tracking begins
3. System assigns delivery based on proximity
4. Courier receives notification
5. Courier views delivery details and route
6. Courier picks up order from cafe (updates status)
7. Courier delivers to customer (updates status)
8. Courier completes delivery or reports failure
9. Earnings are tracked for payout

## Configuration

### Delivery Zone Setup

```sql
-- Example: Create delivery zone for a cafe
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
  'cafe-uuid',
  'Центр города',
  'radius',
  55.7558,
  37.6173,
  5.0,                    -- 5 km radius
  5000,                   -- 50 rubles base fee
  1000,                   -- 10 rubles per km
  30000,                  -- 300 rubles minimum order
  80000,                  -- free delivery above 800 rubles
  true,
  60                      -- 60 minutes max
);
```

### Courier Registration

```sql
-- Example: Register a new courier
INSERT INTO couriers (
  user_id,
  full_name,
  phone,
  email,
  vehicle_type,
  is_verified,
  is_active
) VALUES (
  'user-uuid',
  'Иван Петров',
  '+79001234567',
  'ivan@example.com',
  'bicycle',
  true,
  true
);
```

## Pricing Model

### Delivery Fees
- **Base Fee**: Fixed charge per delivery (e.g., 50₽)
- **Distance Fee**: Charge per kilometer (e.g., 10₽/km)
- **Free Delivery**: Waived above threshold (e.g., orders > 800₽)
- **Minimum Order**: Required order amount for delivery (e.g., 300₽)

### Courier Earnings
- Platform takes commission from delivery fee (e.g., 20%)
- Courier receives remainder
- Payouts processed weekly or bi-weekly

## Security & Permissions

### Row Level Security (RLS)

**Couriers:**
- Can view and update their own profile
- Can view and update their assigned deliveries
- Cannot view other couriers' data

**Customers:**
- Can view their own delivery orders
- Can view tracking for their orders
- Cannot view other customers' deliveries

**Cafe Owners:**
- Can manage delivery zones for their cafes
- Can view deliveries for orders from their cafes

**Admins:**
- Full access to all delivery data
- Can manage couriers and zones
- Can view analytics and reports

## Monitoring & Analytics

### Key Metrics

**Operational:**
- Average delivery time
- Courier utilization rate
- Delivery success rate
- Customer satisfaction (ratings)

**Business:**
- Total delivery revenue
- Commission earned
- Courier payouts
- Popular delivery zones

**Performance:**
- Order-to-assignment time
- Pickup time at cafe
- Transit time to customer
- Failed delivery rate

### Queries

```sql
-- Average delivery time by zone
SELECT 
  dz.name,
  AVG(EXTRACT(EPOCH FROM (do.delivered_at - do.created_at))/60) as avg_minutes
FROM delivery_orders do
JOIN orders o ON o.id = do.order_id
JOIN delivery_zones dz ON dz.cafe_id = o.cafe_id
WHERE do.status = 'delivered'
  AND do.delivered_at > NOW() - INTERVAL '30 days'
GROUP BY dz.name;

-- Courier performance
SELECT 
  c.full_name,
  c.rating,
  c.completed_deliveries,
  c.failed_deliveries,
  ROUND(c.completed_deliveries::numeric / NULLIF(c.total_deliveries, 0) * 100, 2) as success_rate
FROM couriers c
WHERE c.is_active = true
ORDER BY c.rating DESC;

-- Revenue by delivery
SELECT 
  DATE(do.created_at) as date,
  COUNT(*) as total_deliveries,
  SUM(do.delivery_fee_credits) as total_fee_credits,
  AVG(do.distance_km) as avg_distance_km
FROM delivery_orders do
WHERE do.status = 'delivered'
  AND do.created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(do.created_at)
ORDER BY date DESC;
```

## Future Enhancements

### Phase 1 (Completed)
- ✅ Basic delivery functionality
- ✅ Real-time tracking
- ✅ Courier interface
- ✅ Delivery zones
- ✅ Rating system

### Phase 2 (Planned)
- 🔄 Push notifications for status updates
- 🔄 In-app chat between courier and customer
- 🔄 Route optimization for multiple deliveries
- 🔄 Batch delivery assignments
- 🔄 Delivery time slot selection

### Phase 3 (Future)
- 📋 Drone delivery integration
- 📋 Autonomous vehicle support
- 📋 Multi-stop route planning
- 📋 Priority delivery option
- 📋 Scheduled deliveries
- 📋 Contactless delivery verification (photo proof)

## Testing

### Test Scenarios

1. **Delivery Fee Calculation**
   - Test various distances
   - Test minimum order enforcement
   - Test free delivery threshold
   - Test out-of-zone addresses

2. **Courier Assignment**
   - Test automatic assignment to nearest courier
   - Test manual assignment
   - Test when no couriers available
   - Test courier busy/offline handling

3. **Status Updates**
   - Test full delivery lifecycle
   - Test failure scenarios
   - Test cancellations
   - Test timestamp recording

4. **Location Tracking**
   - Test location update frequency
   - Test accuracy filtering
   - Test background updates
   - Test battery impact

### Test Delivery Zone

```sql
-- Create test delivery zone (covers central Moscow)
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
  (SELECT id FROM cafes LIMIT 1),
  'Test Zone',
  'radius',
  55.7558,
  37.6173,
  10.0,
  3000,
  500,
  20000,
  50000,
  true,
  45
);
```

## Troubleshooting

### Common Issues

1. **"No available couriers"**
   - Check courier online status
   - Verify courier locations are recent
   - Expand search radius
   - Check courier availability status

2. **Delivery fee calculation fails**
   - Verify delivery zone exists for cafe
   - Check zone is active
   - Validate coordinates are within zone
   - Check minimum order amount

3. **Location tracking not working**
   - Verify location permissions granted
   - Check background location enabled
   - Ensure courier status is not offline
   - Check network connectivity

4. **Failed deliveries**
   - Review failure reasons
   - Check customer contact info
   - Verify address accuracy
   - Analyze delivery time vs ETA

## API Examples

### Calculate Delivery Fee

```swift
let service = DeliveryService()
let feeInfo = try await service.calculateDeliveryFee(
    cafeId: cafeId,
    deliveryLocation: CLLocationCoordinate2D(latitude: 55.7600, longitude: 37.6200),
    orderAmount: 45000 // 450 rubles in credits
)

if feeInfo.available {
    print("Delivery fee: \(feeInfo.deliveryFeeCredits ?? 0) credits")
    print("ETA: \(feeInfo.estimatedTimeMinutes ?? 0) minutes")
} else {
    print("Delivery not available: \(feeInfo.reason ?? "Unknown")")
}
```

### Create Delivery Order

```swift
let deliveryAddress = DeliveryAddress(
    address: "ул. Тверская, д. 10, кв. 5",
    latitude: 55.7600,
    longitude: 37.6200,
    notes: "Домофон 123"
)

let response = try await service.createDeliveryOrder(
    orderId: orderId,
    deliveryAddress: deliveryAddress,
    customerPhone: "+79001234567",
    customerName: "Иван Петров"
)

if response.success {
    print("Delivery created: \(response.deliveryId!)")
}
```

### Update Courier Location

```swift
let service = DeliveryService()
try await service.updateCourierLocation(
    courierId: courierId,
    location: currentLocation
)
```

## Support

For issues or questions about the delivery system:
1. Check this documentation
2. Review database logs for errors
3. Check courier and order status in admin panel
4. Contact development team with delivery_order_id for specific issues
