//
//  WalletService.swift
//  SubscribeCoffieClean
//
//  Service for wallet and payment operations (mock for MVP)
//

import Foundation
import Combine
import Auth

private struct SupabaseRPCErrorBody: Decodable {
    let code: String?
    let message: String?
    let details: String?
    let hint: String?
}

// MARK: - Wallet Service Errors

enum WalletServiceError: LocalizedError {
    case authenticationRequired
    case userNotFoundInDatabase
    case networkError(Error)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Требуется авторизация. Пожалуйста, войдите снова."
        case .userNotFoundInDatabase:
            return "Пользователь не найден в базе данных. Требуется повторная авторизация."
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}

@MainActor
class WalletService: ObservableObject {
    private let apiClient: SupabaseAPIClient
    
    init(apiClient: SupabaseAPIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Error Mapping

    private func extractRPCErrorKey(from error: Error) -> String? {
        if let networkError = error as? NetworkError,
           case let .httpStatus(_, body) = networkError,
           let body,
           let data = body.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(SupabaseRPCErrorBody.self, from: data),
           let message = parsed.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        return nil
    }

    private func mapWalletRPCError(_ error: Error) async throws -> Never {
        let key = extractRPCErrorKey(from: error)
        let fallbackMessage = error.localizedDescription

        switch key {
        case "wallet_auth_required":
            try? await AuthService.shared.signOut()
            throw WalletServiceError.authenticationRequired
        case "wallet_user_not_found":
            try? await AuthService.shared.signOut()
            throw WalletServiceError.userNotFoundInDatabase
        case "wallet_not_found":
            throw WalletServiceError.unknown("Кошелёк не найден. Создайте кошелёк заново.")
        case "wallet_amount_invalid":
            throw WalletServiceError.unknown("Некорректная сумма пополнения")
        case "wallet_access_denied":
            throw WalletServiceError.unknown("Нет доступа к выбранному кошельку")
        case "wallet_scope_required":
            throw WalletServiceError.unknown("Выберите кофейню или сеть для создания кошелька")
        case "wallet_scope_conflict":
            throw WalletServiceError.unknown("Нельзя одновременно передавать cafe_id и network_id")
        case "wallet_cafe_not_found":
            throw WalletServiceError.unknown("Выбранная кофейня не найдена")
        case "wallet_network_not_found":
            throw WalletServiceError.unknown("Выбранная сеть не найдена")
        default:
            // Legacy compatibility for old migrations
            if fallbackMessage.contains("Not authenticated") || fallbackMessage.contains("PGRST301") {
                try? await AuthService.shared.signOut()
                throw WalletServiceError.authenticationRequired
            }

            if fallbackMessage.contains("User not found in auth.users") {
                try? await AuthService.shared.signOut()
                throw WalletServiceError.userNotFoundInDatabase
            }

            if fallbackMessage.contains("23503") &&
                (
                    fallbackMessage.contains("auth.users") ||
                    fallbackMessage.contains("wallets_user_id_fkey") ||
                    fallbackMessage.contains("table \\\"users\\\"")
                ) {
                try? await AuthService.shared.signOut()
                throw WalletServiceError.userNotFoundInDatabase
            }

            throw WalletServiceError.networkError(error)
        }
    }
    
    // MARK: - Wallet Operations
    
    /// Fetch all wallets for the current user
    func getUserWallets(userId: UUID) async throws -> [Wallet] {
        let response: [[String: AnyCodable]] = try await apiClient.rpc(
            "get_user_wallets",
            params: ["p_user_id": userId.uuidString]
        )
        
        var wallets: [Wallet] = []
        for item in response {
            if let id = item["id"]?.value as? String,
               let walletId = UUID(uuidString: id),
               let walletTypeStr = item["wallet_type"]?.value as? String,
               let walletType = WalletType(rawValue: walletTypeStr),
               let balance = item["balance_credits"]?.value as? Int,
               let lifetime = item["lifetime_top_up_credits"]?.value as? Int {
                
                let cafeIdStr = item["cafe_id"]?.value as? String
                let cafeId = cafeIdStr.flatMap { UUID(uuidString: $0) }
                let cafeName = item["cafe_name"]?.value as? String
                
                let networkIdStr = item["network_id"]?.value as? String
                let networkId = networkIdStr.flatMap { UUID(uuidString: $0) }
                let networkName = item["network_name"]?.value as? String
                
                let createdAtStr = item["created_at"]?.value as? String
                let createdAt = createdAtStr.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
                
                let wallet = Wallet(
                    id: walletId,
                    walletType: walletType,
                    balanceCredits: balance,
                    lifetimeTopUpCredits: lifetime,
                    cafeId: cafeId,
                    cafeName: cafeName,
                    networkId: networkId,
                    networkName: networkName,
                    createdAt: createdAt
                )
                wallets.append(wallet)
            }
        }
        
        return wallets
    }
    
    /// Create a CityPass wallet
    /// Note: userId parameter is kept for compatibility but server uses auth.uid() from JWT
    func createCityPassWallet(userId: UUID) async throws -> UUID {
        do {
            // RPC returns UUID directly as a string
            let response: String = try await apiClient.rpc(
                "create_citypass_wallet",
                params: ["p_user_id": userId.uuidString]
            )
            
            // Parse UUID from string response
            guard let walletId = UUID(uuidString: response) else {
                throw NetworkError.decoding(NSError(
                    domain: "WalletService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not parse wallet ID from response: \(response)"]
                ))
            }
            
            return walletId
        } catch {
            print("❌ [WalletService] createCityPassWallet error: \(error)")
            print("❌ [WalletService] Error localized: \(error.localizedDescription)")
            try await mapWalletRPCError(error)
        }
    }
    
    /// Create a Cafe Wallet
    /// Note: userId parameter is kept for compatibility but server uses auth.uid() from JWT
    func createCafeWallet(userId: UUID, cafeId: UUID?, networkId: UUID?) async throws -> UUID {
        var params: [String: Any] = ["p_user_id": userId.uuidString]
        
        if let cafeId = cafeId {
            params["p_cafe_id"] = cafeId.uuidString
        }
        if let networkId = networkId {
            params["p_network_id"] = networkId.uuidString
        }
        
        do {
            // RPC returns UUID directly as a string
            let response: String = try await apiClient.rpc(
                "create_cafe_wallet",
                params: params
            )
            
            // Parse UUID from string response
            guard let walletId = UUID(uuidString: response) else {
                throw NetworkError.decoding(NSError(
                    domain: "WalletService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not parse wallet ID from response: \(response)"]
                ))
            }
            
            return walletId
        } catch {
            print("❌ [WalletService] createCafeWallet error: \(error)")
            print("❌ [WalletService] Error localized: \(error.localizedDescription)")
            try await mapWalletRPCError(error)
        }
    }
    
    /// Mock wallet top-up (simulates payment) - DEMO MODE ONLY
    /// For MVP: This is the ONLY payment method available (instant credits, no real money)
    /// Real payments: Requires enabling backend real_payment_integration.sql and completing PAYMENT_SECURITY.md checklist
    /// 
    /// - Parameters:
    ///   - walletId: UUID of the wallet to top up
    ///   - amount: Amount in credits to add
    ///   - paymentMethodId: Optional payment method ID
    ///   - idempotencyKey: Optional idempotency key (if nil, generates automatically)
    /// - Returns: MockTopupResponse with transaction details
    func mockWalletTopup(
        walletId: UUID, 
        amount: Int, 
        paymentMethodId: UUID?,
        idempotencyKey: String? = nil  // ✅ NEW: Idempotency support
    ) async throws -> MockTopupResponse {
        var params: [String: Any] = [
            "p_wallet_id": walletId.uuidString,
            "p_amount": amount
        ]
        
        if let paymentMethodId = paymentMethodId {
            params["p_payment_method_id"] = paymentMethodId.uuidString
        }
        
        // ✅ Generate or use provided idempotency key
        let key: String
        if let providedKey = idempotencyKey {
            key = providedKey
        } else {
            // Format: {userId}_{timestamp}_{uuid}
            // Get userId from AuthService
            let userId: String
            if let currentUserId = await AuthService.shared.currentUser?.id {
                userId = currentUserId.uuidString.lowercased()
            } else {
                userId = "unknown"
            }
            
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let uuid = UUID().uuidString.lowercased()
            key = "\(userId)_\(timestamp)_\(uuid)"
        }
        
        params["p_idempotency_key"] = key
        
        #if DEBUG
        print("💳 [WalletService] Mock top-up with idempotency key: \(key)")
        #endif
        
        let response: MockTopupResponse
        do {
            response = try await apiClient.rpc(
                "mock_wallet_topup",
                params: params
            )
        } catch {
            try await mapWalletRPCError(error)
        }
        
        #if DEBUG
        if let message = response.message, message.contains("Idempotent") {
            print("♻️ [WalletService] Idempotent response: Transaction already processed")
        }
        #endif
        
        return response
    }
    
    // MARK: - Real Payment Integration (DISABLED FOR MVP)
    
    /// ⚠️ DISABLED: Create payment intent for real payment processing
    /// This function requires:
    /// 1. Backend: Enable real_payment_integration.sql migration
    /// 2. Backend: Enable create-payment Edge Function
    /// 3. Backend: Complete PAYMENT_SECURITY.md checklist
    /// 4. iOS: Restore PaymentService from _disabled_backup
    /// Currently NOT WORKING - backend RPC does not exist
    /*
    func createPaymentIntent(walletId: UUID, amount: Int, paymentMethodId: UUID?, description: String = "Wallet Top-Up") async throws -> PaymentIntentResponse {
        var params: [String: Any] = [
            "p_wallet_id": walletId.uuidString,
            "p_amount": amount,
            "p_description": description
        ]
        
        if let paymentMethodId = paymentMethodId {
            params["p_payment_method_id"] = paymentMethodId.uuidString
        }
        
        let response: PaymentIntentResponse = try await apiClient.rpc(
            "create_payment_intent",
            params: params
        )
        
        return response
    }
    */
    
    /// ⚠️ DISABLED: Get transaction status
    /// Requires real payment integration to be enabled
    /*
    func getTransactionStatus(transactionId: UUID) async throws -> TransactionStatusResponse {
        let response: TransactionStatusResponse = try await apiClient.rpc(
            "get_transaction_status",
            params: ["p_transaction_id": transactionId.uuidString]
        )
        
        return response
    }
    */
    
    // MARK: - Transaction History (Works with mock payments)
    
    /// Get user transaction history
    func getUserTransactionHistory(userId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [PaymentTransaction] {
        let response: [[String: AnyCodable]] = try await apiClient.rpc(
            "get_user_transaction_history",
            params: [
                "p_user_id": userId.uuidString,
                "p_limit": limit,
                "p_offset": offset
            ]
        )
        
        var transactions: [PaymentTransaction] = []
        for item in response {
            if let idStr = item["id"]?.value as? String,
               let id = UUID(uuidString: idStr),
               let type = item["transaction_type"]?.value as? String,
               let amount = item["amount_credits"]?.value as? Int,
               let commission = item["commission_credits"]?.value as? Int,
               let status = item["status"]?.value as? String,
               let createdAtStr = item["created_at"]?.value as? String,
               let createdAt = ISO8601DateFormatter().date(from: createdAtStr) {
                
                let userIdStr = item["user_id"]?.value as? String
                let userId = userIdStr.flatMap { UUID(uuidString: $0) }
                
                let walletIdStr = item["wallet_id"]?.value as? String
                let walletId = walletIdStr.flatMap { UUID(uuidString: $0) }
                
                let orderIdStr = item["order_id"]?.value as? String
                let orderId = orderIdStr.flatMap { UUID(uuidString: $0) }
                
                let providerTxId = item["provider_transaction_id"]?.value as? String
                
                let completedAtStr = item["completed_at"]?.value as? String
                let completedAt = completedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) }
                
                let transaction = PaymentTransaction(
                    id: id,
                    userId: userId,
                    walletId: walletId,
                    orderId: orderId,
                    amountCredits: amount,
                    commissionCredits: commission,
                    transactionType: type,
                    status: status,
                    providerTransactionId: providerTxId,
                    createdAt: createdAt,
                    completedAt: completedAt
                )
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    /// Validate if wallet can be used for order at specific cafe
    func validateWalletForOrder(walletId: UUID, cafeId: UUID) async throws -> Bool {
        let response: Bool = try await apiClient.rpc(
            "validate_wallet_for_order",
            params: [
                "p_wallet_id": walletId.uuidString,
                "p_cafe_id": cafeId.uuidString
            ]
        )
        
        return response
    }
    
    // MARK: - Payment Method Operations
    
    /// Fetch all payment methods for user
    func getPaymentMethods(userId: UUID) async throws -> [PaymentMethod] {
        let dtos: [SupabasePaymentMethodDTO] = try await apiClient.get(
            "payment_methods",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)"),
                URLQueryItem(name: "order", value: "is_default.desc,created_at.desc")
            ]
        )
        
        return dtos.compactMap { $0.asDomain() }
    }
    
    /// Add a mock payment method
    func addMockPaymentMethod(userId: UUID, cardLast4: String, cardBrand: String, isDefault: Bool = false) async throws -> PaymentMethod {
        let newMethod: [String: Any] = [
            "user_id": userId.uuidString,
            "card_last4": cardLast4,
            "card_brand": cardBrand,
            "is_default": isDefault,
            "payment_provider": "mock",
            "provider_token": ""
        ]
        
        let response: [SupabasePaymentMethodDTO] = try await apiClient.post(
            "payment_methods",
            body: [newMethod]
        )
        
        guard let method = response.first?.asDomain() else {
            throw NetworkError.emptyData
        }
        
        return method
    }
    
    /// Delete a payment method
    func deletePaymentMethod(methodId: UUID) async throws {
        try await apiClient.delete(
            "payment_methods",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(methodId.uuidString)")
            ]
        )
    }
    
    // MARK: - Network Operations
    
    /// Get network for a specific cafe
    func getCafeNetwork(cafeId: UUID) async throws -> NetworkInfo? {
        let response: [[String: AnyCodable]] = try await apiClient.rpc(
            "get_cafe_network",
            params: ["p_cafe_id": cafeId.uuidString]
        )
        
        guard let firstItem = response.first else {
            return nil
        }
        
        guard let networkIdStr = firstItem["network_id"]?.value as? String,
              let networkId = UUID(uuidString: networkIdStr),
              let networkName = firstItem["network_name"]?.value as? String,
              let commissionRate = firstItem["commission_rate"]?.value as? Double else {
            return nil
        }
        
        let cafeCount = firstItem["cafe_count"]?.value as? Int ?? 0
        
        return NetworkInfo(
            id: networkId,
            name: networkName,
            commissionRate: commissionRate,
            cafeCount: cafeCount,
            createdAt: Date()
        )
    }
    
    /// Get all cafes in a network
    func getNetworkCafes(networkId: UUID) async throws -> [NetworkCafe] {
        let response: [[String: AnyCodable]] = try await apiClient.rpc(
            "get_network_cafes",
            params: ["p_network_id": networkId.uuidString]
        )
        
        var cafes: [NetworkCafe] = []
        for item in response {
            if let cafeIdStr = item["cafe_id"]?.value as? String,
               let cafeId = UUID(uuidString: cafeIdStr),
               let name = item["cafe_name"]?.value as? String,
               let address = item["cafe_address"]?.value as? String,
               let mode = item["cafe_mode"]?.value as? String {
                
                let joinedAtStr = item["joined_at"]?.value as? String
                let joinedAt = joinedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
                
                let cafe = NetworkCafe(
                    id: cafeId,
                    name: name,
                    address: address,
                    mode: mode,
                    joinedAt: joinedAt
                )
                cafes.append(cafe)
            }
        }
        
        return cafes
    }
}

// AnyCodable is defined in LoyaltyService.swift to avoid duplication
