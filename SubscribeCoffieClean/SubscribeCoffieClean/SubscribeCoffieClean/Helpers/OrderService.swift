import Foundation

/// Service for creating and managing orders via Supabase RPC
struct OrderService {
    static let shared = OrderService()
    
    private let apiClient: SupabaseAPIClient
    
    init(apiClient: SupabaseAPIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Create Order
    
    /// Creates a new order using the create_order RPC function
    /// - Parameters:
    ///   - cafeId: UUID of the cafe
    ///   - orderType: Type of order ("now", "scheduled", etc.)
    ///   - slotTime: Optional scheduled time for pickup (ISO8601 string)
    ///   - customerName: Customer name
    ///   - customerPhone: Customer phone number
    ///   - customerNotes: Optional notes from customer
    ///   - paymentMethod: Payment method ("wallet", "card", "cash")
    ///   - items: Array of order items with menu_item_id, quantity, and modifiers
    /// - Returns: CreateOrderResponse with order_id, order_number, and total_credits
    func createOrder(
        cafeId: UUID,
        orderType: String = "now",
        slotTime: Date? = nil,
        customerName: String,
        customerPhone: String,
        customerNotes: String? = nil,
        paymentMethod: String = "wallet",
        items: [OrderItemRequest]
    ) async throws -> CreateOrderResponse {
        // Prepare items JSON
        let itemsJSON = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "menu_item_id": item.menuItemId.uuidString,
                "quantity": item.quantity
            ]
            
            // Add modifiers if present
            if !item.modifiers.isEmpty {
                dict["modifiers"] = item.modifiers.map { modifier -> [String: Any] in
                    [
                        "name": modifier.name,
                        "price": modifier.price
                    ]
                }
            }
            
            return dict
        }
        
        // Prepare RPC parameters
        var params: [String: Any] = [
            "p_cafe_id": cafeId.uuidString,
            "p_order_type": orderType,
            "p_customer_name": customerName,
            "p_customer_phone": customerPhone,
            "p_payment_method": paymentMethod,
            "p_items": itemsJSON
        ]
        
        // Add optional parameters
        if let slotTime = slotTime {
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            params["p_slot_time"] = iso8601.string(from: slotTime)
        } else {
            params["p_slot_time"] = NSNull()
        }
        
        if let customerNotes = customerNotes {
            params["p_customer_notes"] = customerNotes
        } else {
            params["p_customer_notes"] = NSNull()
        }
        
        #if DEBUG
        print("📦 [OrderService] Creating order for cafe \(cafeId)")
        print("📦 [OrderService] Items count: \(items.count)")
        print("📦 [OrderService] Payment method: \(paymentMethod)")
        #endif
        
        // Call RPC function
        let response: CreateOrderResponse = try await apiClient.rpc("create_order", params: params)
        
        #if DEBUG
        print("✅ [OrderService] Order created successfully")
        print("✅ [OrderService] Order ID: \(response.orderId)")
        print("✅ [OrderService] Order Number: \(response.orderNumber)")
        print("✅ [OrderService] Total: \(response.totalCredits) credits")
        #endif
        
        return response
    }
}

// MARK: - Request Models

struct OrderItemRequest {
    let menuItemId: UUID
    let quantity: Int
    let modifiers: [OrderModifierRequest]
    
    init(menuItemId: UUID, quantity: Int, modifiers: [OrderModifierRequest] = []) {
        self.menuItemId = menuItemId
        self.quantity = quantity
        self.modifiers = modifiers
    }
}

struct OrderModifierRequest {
    let name: String
    let price: Int
}

// MARK: - Response Models

struct CreateOrderResponse: Decodable {
    let orderId: UUID
    let orderNumber: String
    let totalCredits: Int
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNumber = "order_number"
        case totalCredits = "total_credits"
        case status
    }
}
