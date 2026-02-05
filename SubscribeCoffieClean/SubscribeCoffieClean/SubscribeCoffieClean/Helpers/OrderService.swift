import Foundation

// MARK: - Order Service Errors

enum OrderServiceError: LocalizedError {
    case walletIdRequired
    case insufficientFunds(balance: Int, required: Int)
    case invalidWallet
    case walletNotFound
    case orderCreationFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .walletIdRequired:
            return "Wallet ID required for wallet payments"
        case .insufficientFunds(let balance, let required):
            return "Insufficient funds. Balance: \(balance) credits, Required: \(required) credits"
        case .invalidWallet:
            return "Wallet cannot be used at this cafe. Please use CityPass or create a Cafe Wallet for this cafe."
        case .walletNotFound:
            return "Wallet not found"
        case .orderCreationFailed(let message):
            return "Order creation failed: \(message)"
        }
    }
}

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
    ///   - walletId: Optional wallet ID for wallet payments (required if paymentMethod is "wallet")
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
        walletId: UUID? = nil,  // ✅ NEW: Wallet ID for wallet payments
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
        
        // ✅ NEW: Add wallet_id for wallet payments
        if let walletId = walletId {
            params["p_wallet_id"] = walletId.uuidString
        } else if paymentMethod == "wallet" {
            // Wallet payment requires wallet_id
            throw OrderServiceError.walletIdRequired
        } else {
            params["p_wallet_id"] = NSNull()
        }
        
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
        if let walletId = walletId {
            print("📦 [OrderService] Wallet ID: \(walletId)")
        }
        #endif
        
        // Call RPC function with error handling
        do {
            let response: CreateOrderResponse = try await apiClient.rpc("create_order", params: params)
            
            #if DEBUG
            print("✅ [OrderService] Order created successfully")
            print("✅ [OrderService] Order ID: \(response.orderId)")
            print("✅ [OrderService] Order Number: \(response.orderNumber)")
            print("✅ [OrderService] Total: \(response.totalCredits) credits")
            if let balanceAfter = response.walletBalanceAfter {
                print("✅ [OrderService] Wallet balance after: \(balanceAfter) credits")
            }
            #endif
            
            return response
        } catch {
            // Parse error messages from backend
            let errorMessage = error.localizedDescription
            
            #if DEBUG
            print("❌ [OrderService] Order creation failed: \(errorMessage)")
            #endif
            
            // Map backend errors to specific error types
            if errorMessage.contains("Insufficient funds") {
                // Extract balance and required from error message
                // Format: "Insufficient funds. Balance: X credits, Required: Y credits"
                let components = errorMessage.components(separatedBy: ":")
                if components.count >= 3 {
                    let balanceStr = components[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " credits, Required", with: "")
                    let requiredStr = components[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " credits", with: "")
                    if let balance = Int(balanceStr), let required = Int(requiredStr) {
                        throw OrderServiceError.insufficientFunds(balance: balance, required: required)
                    }
                }
                throw OrderServiceError.insufficientFunds(balance: 0, required: 0)
            } else if errorMessage.contains("Wallet cannot be used") {
                throw OrderServiceError.invalidWallet
            } else if errorMessage.contains("Wallet not found") {
                throw OrderServiceError.walletNotFound
            } else if errorMessage.contains("Wallet does not belong to you") {
                throw OrderServiceError.walletNotFound
            } else {
                throw OrderServiceError.orderCreationFailed(message: errorMessage)
            }
        }
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
    let walletBalanceAfter: Int?  // ✅ NEW: Balance after order payment
    let transactionId: UUID?  // ✅ NEW: Payment transaction ID
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNumber = "order_number"
        case totalCredits = "total_credits"
        case status
        case walletBalanceAfter = "wallet_balance_after"
        case transactionId = "transaction_id"
    }
}
