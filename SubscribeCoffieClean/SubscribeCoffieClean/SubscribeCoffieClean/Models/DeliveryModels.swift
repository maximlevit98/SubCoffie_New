import Foundation
import CoreLocation

// MARK: - Courier
struct Courier: Identifiable, Codable {
    let id: UUID
    let userId: UUID?
    let firstName: String
    let lastName: String
    let phone: String
    let email: String?
    let vehicleType: VehicleType
    let status: CourierStatus
    let rating: Double
    let totalDeliveries: Int
    let currentLocation: CLLocationCoordinate2D?
    let lastLocationUpdate: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case phone
        case email
        case vehicleType = "vehicle_type"
        case status
        case rating
        case totalDeliveries = "total_deliveries"
        case currentLat = "current_lat"
        case currentLon = "current_lon"
        case lastLocationUpdate = "last_location_update"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        phone = try container.decode(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        vehicleType = try container.decode(VehicleType.self, forKey: .vehicleType)
        status = try container.decode(CourierStatus.self, forKey: .status)
        rating = try container.decode(Double.self, forKey: .rating)
        totalDeliveries = try container.decode(Int.self, forKey: .totalDeliveries)
        
        // Decode location
        if let lat = try container.decodeIfPresent(Double.self, forKey: .currentLat),
           let lon = try container.decodeIfPresent(Double.self, forKey: .currentLon) {
            currentLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            currentLocation = nil
        }
        
        lastLocationUpdate = try container.decodeIfPresent(Date.self, forKey: .lastLocationUpdate)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(phone, forKey: .phone)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(vehicleType, forKey: .vehicleType)
        try container.encode(status, forKey: .status)
        try container.encode(rating, forKey: .rating)
        try container.encode(totalDeliveries, forKey: .totalDeliveries)
        
        if let location = currentLocation {
            try container.encode(location.latitude, forKey: .currentLat)
            try container.encode(location.longitude, forKey: .currentLon)
        }
        
        try container.encodeIfPresent(lastLocationUpdate, forKey: .lastLocationUpdate)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Vehicle Type
enum VehicleType: String, Codable, CaseIterable {
    case bicycle
    case scooter
    case car
    case motorcycle
    case walk
    
    var icon: String {
        switch self {
        case .bicycle: return "bicycle"
        case .scooter: return "scooter"
        case .car: return "car.fill"
        case .motorcycle: return "🏍️"
        case .walk: return "figure.walk"
        }
    }
    
    var displayName: String {
        switch self {
        case .bicycle: return "Велосипед"
        case .scooter: return "Самокат"
        case .car: return "Автомобиль"
        case .motorcycle: return "Мотоцикл"
        case .walk: return "Пешком"
        }
    }
}

// MARK: - Courier Status
enum CourierStatus: String, Codable, CaseIterable {
    case available
    case busy
    case offline
    case onBreak = "on_break"
    
    var displayName: String {
        switch self {
        case .available: return "Доступен"
        case .busy: return "Занят"
        case .offline: return "Не в сети"
        case .onBreak: return "На перерыве"
        }
    }
    
    var color: String {
        switch self {
        case .available: return "green"
        case .busy: return "orange"
        case .offline: return "gray"
        case .onBreak: return "yellow"
        }
    }
}

// MARK: - Delivery Order
struct DeliveryOrder: Identifiable, Codable {
    let id: UUID
    let orderId: UUID
    let courierId: UUID?
    let deliveryAddress: String
    let deliveryLocation: CLLocationCoordinate2D
    let deliveryInstructions: String?
    let deliveryFeeCredits: Int
    let distanceKm: Double
    let estimatedDeliveryTime: Int?
    let actualDeliveryTime: Int?
    let pickupTime: Date?
    let deliveredTime: Date?
    let deliveryStatus: DeliveryStatus
    let customerRating: Int?
    let customerFeedback: String?
    let courierNotes: String?
    let createdAt: Date
    let updatedAt: Date
    
    var deliveryFeeRubles: Double {
        Double(deliveryFeeCredits) / 100.0
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case courierId = "courier_id"
        case deliveryAddress = "delivery_address"
        case deliveryLat = "delivery_lat"
        case deliveryLon = "delivery_lon"
        case deliveryInstructions = "delivery_instructions"
        case deliveryFeeCredits = "delivery_fee_credits"
        case distanceKm = "distance_km"
        case estimatedDeliveryTime = "estimated_delivery_time"
        case actualDeliveryTime = "actual_delivery_time"
        case pickupTime = "pickup_time"
        case deliveredTime = "delivered_time"
        case deliveryStatus = "delivery_status"
        case customerRating = "customer_rating"
        case customerFeedback = "customer_feedback"
        case courierNotes = "courier_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        orderId = try container.decode(UUID.self, forKey: .orderId)
        courierId = try container.decodeIfPresent(UUID.self, forKey: .courierId)
        deliveryAddress = try container.decode(String.self, forKey: .deliveryAddress)
        
        let lat = try container.decode(Double.self, forKey: .deliveryLat)
        let lon = try container.decode(Double.self, forKey: .deliveryLon)
        deliveryLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        deliveryInstructions = try container.decodeIfPresent(String.self, forKey: .deliveryInstructions)
        deliveryFeeCredits = try container.decode(Int.self, forKey: .deliveryFeeCredits)
        distanceKm = try container.decode(Double.self, forKey: .distanceKm)
        estimatedDeliveryTime = try container.decodeIfPresent(Int.self, forKey: .estimatedDeliveryTime)
        actualDeliveryTime = try container.decodeIfPresent(Int.self, forKey: .actualDeliveryTime)
        pickupTime = try container.decodeIfPresent(Date.self, forKey: .pickupTime)
        deliveredTime = try container.decodeIfPresent(Date.self, forKey: .deliveredTime)
        deliveryStatus = try container.decode(DeliveryStatus.self, forKey: .deliveryStatus)
        customerRating = try container.decodeIfPresent(Int.self, forKey: .customerRating)
        customerFeedback = try container.decodeIfPresent(String.self, forKey: .customerFeedback)
        courierNotes = try container.decodeIfPresent(String.self, forKey: .courierNotes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderId, forKey: .orderId)
        try container.encodeIfPresent(courierId, forKey: .courierId)
        try container.encode(deliveryAddress, forKey: .deliveryAddress)
        try container.encode(deliveryLocation.latitude, forKey: .deliveryLat)
        try container.encode(deliveryLocation.longitude, forKey: .deliveryLon)
        try container.encodeIfPresent(deliveryInstructions, forKey: .deliveryInstructions)
        try container.encode(deliveryFeeCredits, forKey: .deliveryFeeCredits)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encodeIfPresent(estimatedDeliveryTime, forKey: .estimatedDeliveryTime)
        try container.encodeIfPresent(actualDeliveryTime, forKey: .actualDeliveryTime)
        try container.encodeIfPresent(pickupTime, forKey: .pickupTime)
        try container.encodeIfPresent(deliveredTime, forKey: .deliveredTime)
        try container.encode(deliveryStatus, forKey: .deliveryStatus)
        try container.encodeIfPresent(customerRating, forKey: .customerRating)
        try container.encodeIfPresent(customerFeedback, forKey: .customerFeedback)
        try container.encodeIfPresent(courierNotes, forKey: .courierNotes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Delivery Status
enum DeliveryStatus: String, Codable, CaseIterable {
    case pendingCourier = "pending_courier"
    case assigned
    case courierOnWayToCafe = "courier_on_way_to_cafe"
    case pickedUp = "picked_up"
    case onWayToCustomer = "on_way_to_customer"
    case delivered
    case failed
    
    var displayName: String {
        switch self {
        case .pendingCourier: return "Ищем курьера"
        case .assigned: return "Курьер назначен"
        case .courierOnWayToCafe: return "Курьер едет в кафе"
        case .pickedUp: return "Заказ забран"
        case .onWayToCustomer: return "Курьер едет к вам"
        case .delivered: return "Доставлено"
        case .failed: return "Не доставлено"
        }
    }
    
    var icon: String {
        switch self {
        case .pendingCourier: return "magnifyingglass"
        case .assigned: return "person.fill.checkmark"
        case .courierOnWayToCafe: return "arrow.right.circle"
        case .pickedUp: return "bag.fill"
        case .onWayToCustomer: return "shippingbox.fill"
        case .delivered: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pendingCourier: return "orange"
        case .assigned: return "blue"
        case .courierOnWayToCafe: return "blue"
        case .pickedUp: return "purple"
        case .onWayToCustomer: return "green"
        case .delivered: return "green"
        case .failed: return "red"
        }
    }
    
    var progressValue: Double {
        switch self {
        case .pendingCourier: return 0.1
        case .assigned: return 0.25
        case .courierOnWayToCafe: return 0.4
        case .pickedUp: return 0.6
        case .onWayToCustomer: return 0.8
        case .delivered: return 1.0
        case .failed: return 0.0
        }
    }
}

// MARK: - Delivery Zone
struct DeliveryZone: Identifiable, Codable, Equatable {
    let id: UUID
    let cafeId: UUID
    let zoneName: String
    let baseDeliveryFeeCredits: Int
    let maxDistanceKm: Double
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    var baseDeliveryFeeRubles: Double {
        Double(baseDeliveryFeeCredits) / 100.0
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case cafeId = "cafe_id"
        case zoneName = "zone_name"
        case baseDeliveryFeeCredits = "base_delivery_fee_credits"
        case maxDistanceKm = "max_distance_km"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Delivery Fee Calculation Response
struct DeliveryFeeResponse: Codable {
    let success: Bool
    let canDeliver: Bool
    let distanceKm: Double
    let baseFee: Int
    let distanceFee: Int
    let totalFee: Int
    let estimatedTime: Int?
    let error: String?
    
    var totalFeeRubles: Double {
        Double(totalFee) / 100.0
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case canDeliver = "can_deliver"
        case distanceKm = "distance_km"
        case baseFee = "base_fee"
        case distanceFee = "distance_fee"
        case totalFee = "total_fee"
        case estimatedTime = "estimated_time"
        case error
    }
}

// MARK: - Active Delivery View Model
struct ActiveDeliveryDetail: Identifiable, Codable {
    let deliveryId: UUID
    let orderId: UUID
    let cafeName: String
    let cafeAddress: String
    let cafeLocation: CLLocationCoordinate2D
    let deliveryAddress: String
    let deliveryLocation: CLLocationCoordinate2D
    let deliveryStatus: DeliveryStatus
    let estimatedTime: Int?
    let customerPhone: String
    let deliveryInstructions: String?
    let orderTotal: Int
    let createdAt: Date
    
    var id: UUID { deliveryId }
    
    enum CodingKeys: String, CodingKey {
        case deliveryId = "delivery_id"
        case orderId = "order_id"
        case cafeName = "cafe_name"
        case cafeAddress = "cafe_address"
        case cafeLat = "cafe_lat"
        case cafeLon = "cafe_lon"
        case deliveryAddress = "delivery_address"
        case deliveryLat = "delivery_lat"
        case deliveryLon = "delivery_lon"
        case deliveryStatus = "delivery_status"
        case estimatedTime = "estimated_time"
        case customerPhone = "customer_phone"
        case deliveryInstructions = "delivery_instructions"
        case orderTotal = "order_total"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deliveryId = try container.decode(UUID.self, forKey: .deliveryId)
        orderId = try container.decode(UUID.self, forKey: .orderId)
        cafeName = try container.decode(String.self, forKey: .cafeName)
        cafeAddress = try container.decode(String.self, forKey: .cafeAddress)
        
        let cafeLat = try container.decode(Double.self, forKey: .cafeLat)
        let cafeLon = try container.decode(Double.self, forKey: .cafeLon)
        cafeLocation = CLLocationCoordinate2D(latitude: cafeLat, longitude: cafeLon)
        
        deliveryAddress = try container.decode(String.self, forKey: .deliveryAddress)
        
        let deliveryLat = try container.decode(Double.self, forKey: .deliveryLat)
        let deliveryLon = try container.decode(Double.self, forKey: .deliveryLon)
        deliveryLocation = CLLocationCoordinate2D(latitude: deliveryLat, longitude: deliveryLon)
        
        deliveryStatus = try container.decode(DeliveryStatus.self, forKey: .deliveryStatus)
        estimatedTime = try container.decodeIfPresent(Int.self, forKey: .estimatedTime)
        customerPhone = try container.decode(String.self, forKey: .customerPhone)
        deliveryInstructions = try container.decodeIfPresent(String.self, forKey: .deliveryInstructions)
        orderTotal = try container.decode(Int.self, forKey: .orderTotal)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deliveryId, forKey: .deliveryId)
        try container.encode(orderId, forKey: .orderId)
        try container.encode(cafeName, forKey: .cafeName)
        try container.encode(cafeAddress, forKey: .cafeAddress)
        try container.encode(cafeLocation.latitude, forKey: .cafeLat)
        try container.encode(cafeLocation.longitude, forKey: .cafeLon)
        try container.encode(deliveryAddress, forKey: .deliveryAddress)
        try container.encode(deliveryLocation.latitude, forKey: .deliveryLat)
        try container.encode(deliveryLocation.longitude, forKey: .deliveryLon)
        try container.encode(deliveryStatus, forKey: .deliveryStatus)
        try container.encodeIfPresent(estimatedTime, forKey: .estimatedTime)
        try container.encode(customerPhone, forKey: .customerPhone)
        try container.encodeIfPresent(deliveryInstructions, forKey: .deliveryInstructions)
        try container.encode(orderTotal, forKey: .orderTotal)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
