# Delivery System - Quick Start Guide

## Overview

The delivery system enables couriers to deliver orders from cafes to customers, with real-time tracking, automatic courier assignment, and comprehensive admin management.

## Features Implemented

### Backend (✅ Complete)
- Database schema for couriers, deliveries, zones, and shifts
- RPC functions for delivery operations
- Automatic and manual courier assignment
- Delivery fee calculation based on distance and zones
- Real-time location tracking
- Courier shift management
- Row Level Security (RLS) policies
- Analytics views

### iOS Customer App (✅ Complete)
- Delivery option in checkout flow
- Address input with geocoding
- Real-time delivery tracking with map
- Courier information display
- Delivery rating system
- ETA calculations

### iOS Courier App (✅ Complete)
- Courier dashboard with shift management
- Active deliveries list
- Delivery detail view with navigation
- Status updates workflow
- Location tracking integration
- Performance statistics

### Admin Panel (📖 Documentation Ready)
- Implementation guide created
- React/Next.js component examples
- Active deliveries management
- Courier management
- Delivery zones configuration
- Analytics dashboard

## Quick Setup

### 1. Run Migration

```bash
cd SubscribeCoffieBackend
supabase db reset  # Reset database with new migration
# or
supabase migration up  # Apply new migration only
```

The migration `20260222_delivery.sql` creates:
- `couriers` table
- `courier_locations` table (tracking history)
- `delivery_orders` table
- `delivery_zones` table
- `courier_shifts` table
- All necessary RPC functions
- Views for analytics
- RLS policies

### 2. Add Sample Data (Optional)

```sql
-- Create a test courier
INSERT INTO couriers (user_id, first_name, last_name, phone, vehicle_type, status, is_active)
VALUES (
  'your-user-id',  -- Replace with actual user ID
  'Иван',
  'Иванов',
  '+7 999 123 4567',
  'bicycle',
  'offline',
  true
);

-- Create delivery zones for existing cafes
-- This is already in the migration for first 3 cafes
-- Add more as needed:
INSERT INTO delivery_zones (cafe_id, zone_name, zone_polygon, base_delivery_fee_credits, max_distance_km)
SELECT 
  id,
  'Zone 1 - 5km radius',
  ST_Buffer(location::geometry, 0.05)::geography,  -- ~5km radius
  5000,  -- 50 rubles base fee
  5.0
FROM cafes
WHERE id = 'your-cafe-id';
```

### 3. iOS App Integration

The delivery models and views are already created in the iOS app. To integrate:

#### Add to your checkout flow:

```swift
import SwiftUI

struct CheckoutView: View {
    @State private var fulfillmentType: OrderFulfillmentType = .pickup
    @State private var deliveryAddress = ""
    @State private var deliveryLocation: CLLocationCoordinate2D?
    @State private var deliveryInstructions = ""
    @State private var deliveryFee = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ... existing checkout UI ...
                
                // Add delivery option
                DeliveryOptionView(
                    cafeId: cafe.id,
                    fulfillmentType: $fulfillmentType,
                    deliveryAddress: $deliveryAddress,
                    deliveryLocation: $deliveryLocation,
                    deliveryInstructions: $deliveryInstructions,
                    deliveryFee: $deliveryFee
                )
                
                // ... rest of checkout ...
            }
        }
    }
    
    func placeOrder() async {
        // Create regular order first
        let order = try await OrderService.createOrder(...)
        
        // If delivery selected, create delivery order
        if fulfillmentType == .delivery, let location = deliveryLocation {
            try await DeliveryService.shared.createDeliveryOrder(
                orderId: order.id,
                deliveryAddress: deliveryAddress,
                latitude: location.latitude,
                longitude: location.longitude,
                instructions: deliveryInstructions.isEmpty ? nil : deliveryInstructions
            )
        }
    }
}
```

#### Track delivery:

```swift
// Navigate to tracking view after order is placed
NavigationLink(destination: DeliveryTrackingView(orderId: order.id)) {
    Text("Отследить доставку")
}
```

#### Courier app setup:

Add courier dashboard to your app:

```swift
// In your main navigation or separate courier app
NavigationLink(destination: CourierDashboardView()) {
    Text("Courier Mode")
}
```

### 4. Admin Panel Setup

Follow the guide in `DELIVERY_ADMIN_PANEL_GUIDE.md` to implement:

1. Create Next.js pages in your admin panel:
   - `/admin/deliveries` - Active deliveries
   - `/admin/couriers` - Courier management
   - `/admin/delivery-zones` - Zone configuration
   - `/admin/analytics/delivery` - Analytics

2. Use the provided React component examples as templates

3. Set up real-time subscriptions for live updates

## API Usage Examples

### Calculate Delivery Fee

```typescript
const { data, error } = await supabase
  .rpc('calculate_delivery_fee', {
    p_cafe_id: cafeId,
    p_delivery_lat: 55.7558,
    p_delivery_lon: 37.6173
  });

console.log(data);
// {
//   success: true,
//   can_deliver: true,
//   distance_km: 3.2,
//   base_fee: 5000,
//   distance_fee: 600,
//   total_fee: 5600,
//   estimated_time: 31
// }
```

### Create Delivery Order

```typescript
const { data, error } = await supabase
  .rpc('create_delivery_order', {
    p_order_id: orderId,
    p_delivery_address: 'ул. Арбат, 20, кв. 5',
    p_delivery_lat: 55.7539,
    p_delivery_lon: 37.5984,
    p_delivery_instructions: 'Домофон 123, 5 этаж'
  });
```

### Assign Courier (Automatic)

```typescript
// Automatically finds nearest available courier
const { data, error } = await supabase
  .rpc('assign_courier_to_order', {
    p_delivery_order_id: deliveryId
    // p_courier_id is optional - if not provided, finds automatically
  });
```

### Assign Courier (Manual)

```typescript
const { data, error } = await supabase
  .rpc('assign_courier_to_order', {
    p_delivery_order_id: deliveryId,
    p_courier_id: specificCourierId
  });
```

### Update Courier Location

```typescript
const { data, error } = await supabase
  .rpc('update_courier_location', {
    p_courier_id: courierId,
    p_lat: 55.7558,
    p_lon: 37.6173,
    p_accuracy: 10.5,  // meters
    p_speed: 5.2,      // m/s
    p_heading: 270     // degrees
  });
```

### Update Delivery Status

```typescript
const { data, error } = await supabase
  .rpc('update_delivery_status', {
    p_delivery_order_id: deliveryId,
    p_new_status: 'picked_up',
    p_courier_notes: 'Package collected successfully'
  });
```

### Get Courier Deliveries

```typescript
const { data, error } = await supabase
  .rpc('get_courier_deliveries', {
    p_courier_id: courierId,
    p_include_completed: false
  });
```

### Start/End Courier Shift

```typescript
// Start shift
const { data, error } = await supabase
  .rpc('start_courier_shift', {
    p_courier_id: courierId
  });

// End shift
const { data, error } = await supabase
  .rpc('end_courier_shift', {
    p_courier_id: courierId
  });
```

## Workflow

### Customer Workflow

1. **Browse cafes** → Select cafe
2. **Build order** → Add items to cart
3. **Checkout** → Choose "Delivery" option
4. **Enter address** → System validates delivery zone and calculates fee
5. **Add instructions** → Optional delivery notes
6. **Place order** → Order is created with delivery
7. **Track delivery** → Real-time tracking with courier location
8. **Receive order** → Courier delivers
9. **Rate delivery** → Provide feedback

### Courier Workflow

1. **Start shift** → Changes status to "available"
2. **Wait for assignment** → System automatically assigns nearby deliveries
3. **Accept delivery** → View delivery details
4. **Navigate to cafe** → Update status to "on way to cafe"
5. **Pick up order** → Update status to "picked up"
6. **Navigate to customer** → Update status to "on way to customer"
7. **Deliver order** → Update status to "delivered"
8. **Repeat** or **End shift**

### Admin Workflow

1. **Monitor active deliveries** → Dashboard view
2. **Manual assignment** → Assign courier if automatic fails
3. **Handle issues** → Contact courier or customer
4. **Manage couriers** → Add/edit courier accounts
5. **Configure zones** → Set up delivery areas for cafes
6. **View analytics** → Monitor performance metrics

## Status Flow

```
pending_courier → assigned → courier_on_way_to_cafe → 
picked_up → on_way_to_customer → delivered
                                 ↓
                               failed
```

## Courier Status

- **offline** - Not working
- **available** - On shift, ready for deliveries
- **busy** - Currently delivering
- **on_break** - Taking a break

## Performance Optimization

### Location Updates

- Update every 10 seconds when on delivery
- Use significant location changes to save battery
- Stop updates when shift ends

### Real-time Subscriptions

- Subscribe to delivery status changes for active orders only
- Unsubscribe when delivery is completed
- Use connection pooling for admin panel

### Database Indexes

All necessary indexes are created in the migration:
- Location indexes using GIST
- Status indexes for fast filtering
- Foreign key indexes for joins

## Testing

### Test Delivery Fee Calculation

```sql
-- Should succeed
SELECT calculate_delivery_fee(
  'cafe-id-here',
  55.7558,  -- Within 5km
  37.6173
);

-- Should fail (outside zone)
SELECT calculate_delivery_fee(
  'cafe-id-here',
  56.0000,  -- Far away
  37.0000
);
```

### Test Courier Assignment

```sql
-- Create test delivery
SELECT create_delivery_order(
  'order-id-here',
  'Test Address',
  55.7558,
  37.6173,
  'Test instructions'
);

-- Assign courier (automatic)
SELECT assign_courier_to_order('delivery-id-here');
```

## Monitoring

### Key Metrics

```sql
-- Active deliveries by status
SELECT delivery_status, COUNT(*) 
FROM delivery_orders 
WHERE delivery_status NOT IN ('delivered', 'failed')
GROUP BY delivery_status;

-- Courier performance today
SELECT * FROM courier_performance;

-- Average delivery time
SELECT AVG(actual_delivery_time) as avg_time_minutes
FROM delivery_orders
WHERE delivery_status = 'delivered'
  AND DATE(delivered_time) = CURRENT_DATE;
```

## Troubleshooting

### Issue: No couriers available

**Solution:**
- Check if any couriers have status 'available'
- Verify couriers are on shift (active shift in courier_shifts)
- Check if couriers have location data
- Increase search radius

### Issue: Delivery fee calculation fails

**Solution:**
- Verify cafe has delivery zones configured
- Check if location is within zone polygon
- Verify zone is active (is_active = true)

### Issue: Location updates not working

**Solution:**
- Check location permissions in iOS app
- Verify courier is on active shift
- Check network connectivity
- Review update_courier_location RPC logs

### Issue: Status update fails

**Solution:**
- Verify status transition is valid (see status flow)
- Check if courier owns the delivery
- Review RLS policies
- Check if delivery exists

## Next Steps

1. ✅ Backend migration - **COMPLETE**
2. ✅ iOS customer views - **COMPLETE**
3. ✅ iOS courier views - **COMPLETE**
4. ⏳ Admin panel implementation - **READY FOR DEVELOPMENT**
5. ⏳ Real-time location tracking optimization
6. ⏳ Push notifications for couriers
7. ⏳ Advanced analytics and reporting
8. ⏳ Route optimization algorithms
9. ⏳ Multiple delivery zones per cafe
10. ⏳ Delivery time slot booking

## Related Files

- **Backend Migration:** `/supabase/migrations/20260222_delivery.sql`
- **iOS Models:** `/Models/DeliveryModels.swift`
- **iOS Service:** `/Helpers/DeliveryService.swift`
- **Customer Views:**
  - `/Views/DeliveryOptionView.swift`
  - `/Views/DeliveryTrackingView.swift`
- **Courier Views:**
  - `/Views/CourierDashboardView.swift`
  - `/Views/CourierDeliveryDetailView.swift`
- **Admin Guide:** `/DELIVERY_ADMIN_PANEL_GUIDE.md`

## Support

For questions or issues:
1. Check this quickstart guide
2. Review the admin panel guide
3. Check RPC function implementations in migration
4. Review RLS policies in migration
5. Test with sample data

## License

Part of SubscribeCoffie platform.
