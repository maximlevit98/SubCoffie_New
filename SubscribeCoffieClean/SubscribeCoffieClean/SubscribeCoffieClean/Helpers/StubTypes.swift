//
//  StubTypes.swift
//  SubscribeCoffieClean
//
//  Temporary stub types for disabled services
//

import Foundation
import Combine

// MARK: - Auth Stubs
import Supabase

struct LoginHistoryItemStub: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let createdAt: Date // Alias for timestamp
    let method: String
    let loginMethod: String // Alias for method
    let success: Bool
    let userAgent: String?
    
    init(id: UUID, timestamp: Date, method: String, success: Bool, userAgent: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.createdAt = timestamp // Same as timestamp
        self.method = method
        self.loginMethod = method // Same as method
        self.success = success
        self.userAgent = userAgent
    }
}

// MARK: - Order Stubs
struct OrderHistoryItem: Codable, Identifiable {
    let id: UUID
    let cafeId: UUID
    let cafeName: String
    let totalAmount: Int
    let status: String
    let createdAt: Date
}

struct OrderStatistics: Codable {
    let totalOrders: Int
    let totalSpent: Int
    let averageOrderValue: Int
    let favoriteCategory: String?
}

// MARK: - Delivery Stubs
struct DeliveryFeeInfo: Codable {
    let baseFee: Int
    let distanceFee: Int
    let totalFee: Int
    let estimatedTime: Int
    let available: Bool
    let deliveryFeeCredits: Int
    
    init(baseFee: Int = 0, distanceFee: Int = 0, totalFee: Int = 0, estimatedTime: Int = 30, available: Bool = false) {
        self.baseFee = baseFee
        self.distanceFee = distanceFee
        self.totalFee = totalFee
        self.deliveryFeeCredits = totalFee
        self.estimatedTime = estimatedTime
        self.available = available
    }
}

// MARK: - Service Stubs (for Views that reference them)
// AuthService moved to separate file (Helpers/AuthService.swift)

// OrderService moved to separate file (Helpers/OrderService.swift)

// PaymentService: See _disabled_backup/PaymentService.swift.disabled
// For MVP: Using mock payments only (demo mode)
// Real payment integration requires:
// 1. Enable backend/supabase/migrations/20260202010000_real_payment_integration.sql
// 2. Complete PAYMENT_SECURITY.md checklist
// 3. Restore PaymentService from disabled backup
// 4. Update WalletTopUpView to use real payment flow

@MainActor
class SocialService: ObservableObject {
    static let shared = SocialService()
    
    func toggleFavorite(cafeId: UUID) async throws {}
    func isFavorite(cafeId: UUID) async throws -> Bool { return false }
    func getFavorites() async throws -> [UUID] { return [] }
    
    func submitReview(cafeId: UUID, rating: Int, comment: String?) async throws {}
    func getReviews(cafeId: UUID) async throws -> [Review] { return [] }
}

@MainActor
class RecommendationService: ObservableObject {
    static let shared = RecommendationService()
    
    func getRecommendations(userId: UUID) async throws -> [CafeSummary] {
        return []
    }
}

@MainActor
class RegionService: ObservableObject {
    static let shared = RegionService()
    
    func getAvailableRegions() async throws -> [RegionModel] {
        return []
    }
}

@MainActor
class RealtimeOrderService: ObservableObject {
    static let shared = RealtimeOrderService()
    
    func subscribeToOrder(orderId: UUID) {}
    func unsubscribe() {}
}

@MainActor
class ActiveOrdersRealtimeService: ObservableObject {
    static let shared = ActiveOrdersRealtimeService()
}

@MainActor
class LoyaltyService: ObservableObject {
    static let shared = LoyaltyService()
}

// MARK: - Supporting Types (renamed to avoid conflicts)
struct RegionModel: Codable, Identifiable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
}
