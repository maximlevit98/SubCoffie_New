# Admin Panel - Delivery Management Guide

This guide provides implementation details for the delivery management features in the admin panel.

## Overview

The delivery management system allows administrators and cafe owners to:
- View and manage active deliveries
- Monitor courier performance
- Manage delivery zones
- Assign couriers to orders
- View delivery analytics

## Required Pages

### 1. Active Deliveries Dashboard (`/admin/deliveries`)

**Purpose:** Real-time view of all active deliveries across the platform.

**Features:**
- List of all active deliveries with status
- Filters: status, cafe, courier, date range
- Search by order ID or customer phone
- Real-time updates via polling or websockets
- Ability to manually assign couriers
- Map view showing all active deliveries

**API Endpoints:**
```typescript
// Fetch active deliveries
const { data, error } = await supabase
  .from('active_deliveries')
  .select('*')
  .order('created_at', { ascending: false });

// Manual courier assignment
const { data, error } = await supabase
  .rpc('assign_courier_to_order', {
    p_delivery_order_id: deliveryId,
    p_courier_id: courierId
  });
```

**UI Components:**
- DeliveryList component
- DeliveryCard component (status, cafe, courier, customer, ETA)
- CourierAssignmentModal
- DeliveryMapView

### 2. Courier Management (`/admin/couriers`)

**Purpose:** Manage courier accounts and monitor their performance.

**Features:**
- List of all couriers with status (available, busy, offline, on_break)
- Add new courier accounts
- Edit courier information
- View courier performance metrics
- Deactivate/reactivate couriers
- View courier location on map (for active couriers)
- View shift history

**API Endpoints:**
```typescript
// Fetch all couriers
const { data, error } = await supabase
  .from('courier_performance')
  .select('*')
  .order('courier_name');

// Create new courier
const { data, error } = await supabase
  .from('couriers')
  .insert({
    user_id: userId,
    first_name: firstName,
    last_name: lastName,
    phone: phone,
    vehicle_type: vehicleType
  });

// Update courier
const { data, error } = await supabase
  .from('couriers')
  .update({ ...updates })
  .eq('id', courierId);
```

**UI Components:**
- CourierList component
- CourierCard component (name, rating, total deliveries, status, vehicle type)
- CourierForm component (add/edit)
- CourierPerformanceChart
- CourierLocationMap

### 3. Delivery Zones Management (`/admin/delivery-zones`)

**Purpose:** Configure delivery zones for each cafe.

**Features:**
- List of all delivery zones by cafe
- Create new delivery zone (with map drawing tool)
- Edit zone parameters (base fee, max distance)
- Activate/deactivate zones
- Visual map showing all zones

**API Endpoints:**
```typescript
// Fetch delivery zones
const { data, error } = await supabase
  .from('delivery_zones')
  .select('*, cafes(name)')
  .order('cafe_id');

// Create delivery zone
const { data, error } = await supabase
  .from('delivery_zones')
  .insert({
    cafe_id: cafeId,
    zone_name: zoneName,
    zone_polygon: polygon, // GeoJSON
    base_delivery_fee_credits: baseFee,
    max_distance_km: maxDistance
  });
```

**UI Components:**
- ZoneList component
- ZoneForm component with map editor
- ZoneMap component showing all zones
- PolygonDrawingTool

### 4. Delivery Analytics (`/admin/analytics/delivery`)

**Purpose:** Visualize delivery performance and metrics.

**Metrics:**
- Total deliveries (today, this week, this month)
- Average delivery time
- Delivery success rate
- Revenue from delivery fees
- Most active couriers
- Peak delivery hours
- Popular delivery areas (heatmap)

**API Endpoints:**
```typescript
// Delivery stats
const { data, error } = await supabase
  .rpc('get_delivery_stats', {
    date_from: startDate,
    date_to: endDate,
    cafe_id: cafeId // optional
  });

// Courier performance
const { data, error } = await supabase
  .from('courier_performance')
  .select('*');
```

**UI Components:**
- StatsCards (total deliveries, avg time, success rate, revenue)
- DeliveryTimeChart (line chart)
- CourierLeaderboard
- DeliveryHeatmap
- PeakHoursChart (bar chart)

### 5. Delivery Detail View (`/admin/deliveries/[id]`)

**Purpose:** Detailed view of a specific delivery.

**Features:**
- Full delivery information
- Order details
- Courier information with current location
- Customer information
- Status timeline
- Map with route
- Ability to contact customer or courier
- Manual status updates (if needed)
- Issue resolution

**API Endpoints:**
```typescript
// Fetch delivery details
const { data: delivery, error } = await supabase
  .from('delivery_orders')
  .select(`
    *,
    orders(*),
    couriers(*),
    cafes(*)
  `)
  .eq('id', deliveryId)
  .single();

// Fetch courier location history
const { data: locations, error } = await supabase
  .from('courier_locations')
  .select('*')
  .eq('courier_id', courierId)
  .gte('recorded_at', startTime)
  .order('recorded_at', { ascending: true });
```

## Implementation Examples

### React/Next.js Components

#### ActiveDeliveriesPage.tsx
```tsx
'use client';

import { useEffect, useState } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';

export default function ActiveDeliveriesPage() {
  const [deliveries, setDeliveries] = useState([]);
  const [loading, setLoading] = useState(true);
  const supabase = createClientComponentClient();

  useEffect(() => {
    fetchDeliveries();
    
    // Set up real-time subscription
    const channel = supabase
      .channel('delivery_updates')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'delivery_orders' },
        () => fetchDeliveries()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  async function fetchDeliveries() {
    const { data, error } = await supabase
      .from('active_deliveries')
      .select('*')
      .order('created_at', { ascending: false });

    if (!error) {
      setDeliveries(data || []);
    }
    setLoading(false);
  }

  if (loading) return <div>Loading...</div>;

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">Active Deliveries</h1>
      
      <div className="grid gap-4">
        {deliveries.map(delivery => (
          <DeliveryCard key={delivery.delivery_id} delivery={delivery} />
        ))}
      </div>
    </div>
  );
}
```

#### DeliveryCard.tsx
```tsx
import Link from 'next/link';

interface DeliveryCardProps {
  delivery: any;
}

export function DeliveryCard({ delivery }: DeliveryCardProps) {
  const statusColors = {
    pending_courier: 'bg-orange-100 text-orange-800',
    assigned: 'bg-blue-100 text-blue-800',
    courier_on_way_to_cafe: 'bg-blue-100 text-blue-800',
    picked_up: 'bg-purple-100 text-purple-800',
    on_way_to_customer: 'bg-green-100 text-green-800',
    delivered: 'bg-green-500 text-white',
    failed: 'bg-red-500 text-white',
  };

  return (
    <Link href={`/admin/deliveries/${delivery.delivery_id}`}>
      <div className="bg-white rounded-lg shadow p-4 hover:shadow-md transition-shadow">
        <div className="flex justify-between items-start mb-3">
          <div>
            <h3 className="font-semibold text-lg">{delivery.cafe_name}</h3>
            <p className="text-sm text-gray-600">
              Order #{delivery.order_id.slice(0, 8)}
            </p>
          </div>
          
          <span className={`px-3 py-1 rounded-full text-xs font-medium ${statusColors[delivery.delivery_status]}`}>
            {delivery.delivery_status.replace(/_/g, ' ').toUpperCase()}
          </span>
        </div>

        <div className="space-y-2 text-sm">
          <div className="flex items-center gap-2">
            <span className="text-gray-500">Courier:</span>
            <span className="font-medium">
              {delivery.courier_name || 'Not assigned'}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-gray-500">Delivery to:</span>
            <span className="font-medium">{delivery.delivery_address}</span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-gray-500">Distance:</span>
            <span className="font-medium">{delivery.distance_km?.toFixed(1)} km</span>
          </div>

          {delivery.estimated_delivery_time && (
            <div className="flex items-center gap-2">
              <span className="text-gray-500">ETA:</span>
              <span className="font-medium">~{delivery.estimated_delivery_time} min</span>
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}
```

#### CouriersPage.tsx
```tsx
'use client';

import { useEffect, useState } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';

export default function CouriersPage() {
  const [couriers, setCouriers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const supabase = createClientComponentClient();

  useEffect(() => {
    fetchCouriers();
  }, []);

  async function fetchCouriers() {
    const { data, error } = await supabase
      .from('courier_performance')
      .select('*')
      .order('courier_name');

    if (!error) {
      setCouriers(data || []);
    }
    setLoading(false);
  }

  if (loading) return <div>Loading...</div>;

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Couriers</h1>
        <button
          onClick={() => setShowAddForm(true)}
          className="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600"
        >
          Add Courier
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {couriers.map(courier => (
          <CourierCard key={courier.courier_id} courier={courier} />
        ))}
      </div>

      {showAddForm && (
        <CourierFormModal
          onClose={() => setShowAddForm(false)}
          onSuccess={() => {
            setShowAddForm(false);
            fetchCouriers();
          }}
        />
      )}
    </div>
  );
}
```

#### CourierCard.tsx
```tsx
interface CourierCardProps {
  courier: any;
}

export function CourierCard({ courier }: CourierCardProps) {
  const statusColors = {
    available: 'bg-green-500',
    busy: 'bg-orange-500',
    offline: 'bg-gray-500',
    on_break: 'bg-yellow-500',
  };

  return (
    <div className="bg-white rounded-lg shadow p-4">
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-lg">
            {courier.courier_name.charAt(0)}
          </div>
          
          <div>
            <h3 className="font-semibold">{courier.courier_name}</h3>
            <div className="flex items-center gap-2">
              <div className={`w-2 h-2 rounded-full ${statusColors[courier.status]}`} />
              <span className="text-xs text-gray-600">{courier.status}</span>
            </div>
          </div>
        </div>

        <div className="text-right">
          <div className="flex items-center gap-1">
            <span className="text-yellow-500">★</span>
            <span className="font-semibold">{courier.rating?.toFixed(1)}</span>
          </div>
          <span className="text-xs text-gray-600">
            {courier.total_deliveries} deliveries
          </span>
        </div>
      </div>

      <div className="border-t pt-3 space-y-2 text-sm">
        <div className="flex justify-between">
          <span className="text-gray-600">Vehicle:</span>
          <span className="font-medium">{courier.vehicle_type}</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-600">Today:</span>
          <span className="font-medium">
            {courier.completed_deliveries_today || 0} deliveries
          </span>
        </div>

        {courier.avg_delivery_time_today && (
          <div className="flex justify-between">
            <span className="text-gray-600">Avg time:</span>
            <span className="font-medium">
              {courier.avg_delivery_time_today.toFixed(0)} min
            </span>
          </div>
        )}

        {courier.earnings_today && (
          <div className="flex justify-between">
            <span className="text-gray-600">Earnings:</span>
            <span className="font-medium text-green-600">
              {(courier.earnings_today / 100).toFixed(0)} ₽
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
```

## Security Considerations

### Row Level Security (RLS)

The migration already includes RLS policies, but ensure:

1. **Admins** can view and manage all deliveries and couriers
2. **Cafe owners** can only view deliveries for their cafes
3. **Couriers** can only view and update their assigned deliveries

### API Security

- All admin endpoints should require authentication
- Validate user roles before allowing access
- Implement rate limiting for location updates
- Sanitize all user inputs

## Real-time Updates

### Websocket Implementation

```typescript
// Set up real-time subscription for active deliveries
const channel = supabase
  .channel('active_deliveries')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'delivery_orders',
      filter: 'delivery_status=neq.delivered'
    },
    (payload) => {
      console.log('Delivery updated:', payload);
      // Update UI
    }
  )
  .subscribe();
```

### Polling for Courier Locations

```typescript
// Poll courier locations every 10 seconds
useEffect(() => {
  const interval = setInterval(async () => {
    const { data } = await supabase
      .from('couriers')
      .select(`
        id,
        current_lat:ST_Y(current_location::geometry),
        current_lon:ST_X(current_location::geometry)
      `)
      .eq('status', 'busy');
    
    // Update map markers
    updateCourierMarkers(data);
  }, 10000);

  return () => clearInterval(interval);
}, []);
```

## Testing

### Test Scenarios

1. **Create delivery order** - Verify delivery record is created with correct fee
2. **Assign courier** - Test manual and automatic assignment
3. **Update status** - Verify status transitions are valid
4. **Track location** - Verify courier location updates work
5. **Complete delivery** - Verify courier stats are updated
6. **Rate delivery** - Verify rating updates courier average
7. **Shift management** - Test shift start/end flow

### Sample Test Data

```sql
-- Insert test courier
INSERT INTO couriers (user_id, first_name, last_name, phone, vehicle_type, status, is_active)
VALUES (
  'test-user-id',
  'Test',
  'Courier',
  '+7 999 999 9999',
  'bicycle',
  'available',
  true
);

-- Insert test delivery zone
INSERT INTO delivery_zones (cafe_id, zone_name, zone_polygon, base_delivery_fee_credits, max_distance_km)
VALUES (
  'test-cafe-id',
  'Test Zone',
  ST_Buffer(ST_MakePoint(37.6173, 55.7558)::geography, 5000)::geography,
  5000,
  5.0
);
```

## Monitoring and Alerts

### Key Metrics to Monitor

- Average time to assign courier
- Average delivery time
- Delivery success rate
- Courier utilization rate
- Peak demand times

### Alert Triggers

- No available couriers for > 5 minutes
- Delivery taking > 2x estimated time
- Courier offline during active delivery
- Failed delivery

## Next Steps

1. Implement the admin panel pages as described
2. Add real-time map visualization
3. Implement push notifications for couriers
4. Add delivery analytics dashboard
5. Implement courier shift scheduling
6. Add support for multiple delivery zones per cafe
7. Implement delivery fee optimization algorithms
