//
//  RecommendationModels.swift
//  SubscribeCoffieClean
//
//  Models for recommendation system
//

import Foundation

// MARK: - Personalized Recommendation

struct PersonalizedRecommendation: Identifiable, Codable {
    let menuItemId: UUID
    let cafeId: UUID
    let cafeName: String
    let category: CafeMenuCategory
    let title: String
    let name: String
    let description: String
    let priceCredits: Int
    let recommendationReason: String
    let relevanceScore: Double
    
    var id: UUID { menuItemId }
    
    enum CodingKeys: String, CodingKey {
        case menuItemId = "menu_item_id"
        case cafeId = "cafe_id"
        case cafeName = "cafe_name"
        case category
        case title
        case name
        case description
        case priceCredits = "price_credits"
        case recommendationReason = "recommendation_reason"
        case relevanceScore = "relevance_score"
    }
    
    // Convert to CafeProduct for display
    func asProduct() -> CafeProduct {
        CafeProduct(
            id: menuItemId,
            category: category,
            name: CafeProduct.normalizedTitle(title: title, name: name),
            description: description,
            priceCredits: priceCredits
        )
    }
}

// MARK: - Cafe Recommendation

struct CafeRecommendation: Identifiable, Codable {
    let cafeId: UUID
    let cafeName: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let recommendationReason: String
    let relevanceScore: Double
    
    var id: UUID { cafeId }
    
    enum CodingKeys: String, CodingKey {
        case cafeId = "cafe_id"
        case cafeName = "cafe_name"
        case address
        case latitude
        case longitude
        case recommendationReason = "recommendation_reason"
        case relevanceScore = "relevance_score"
    }
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    let id: UUID
    let userId: UUID
    let favoriteCafeIds: [UUID]
    let favoriteCategory: CafeMenuCategory?
    let preferredOrderTime: String?
    let avgOrderValueCredits: Int
    let lastUpdated: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case favoriteCafeIds = "favorite_cafe_ids"
        case favoriteCategory = "favorite_category"
        case preferredOrderTime = "preferred_order_time"
        case avgOrderValueCredits = "avg_order_value_credits"
        case lastUpdated = "last_updated"
        case createdAt = "created_at"
    }
}

// MARK: - Trending Item

struct TrendingItem: Identifiable, Codable {
    let menuItemId: UUID
    let cafeId: UUID
    let category: CafeMenuCategory
    let title: String
    let name: String
    let description: String?
    let priceCredits: Int
    let cafeName: String
    let cafeAddress: String
    let orderCount: Int
    let uniqueCustomers: Int
    let avgPrice: Int
    let lastOrderedAt: Date?
    
    var id: UUID { menuItemId }
    
    enum CodingKeys: String, CodingKey {
        case menuItemId = "menu_item_id"
        case cafeId = "cafe_id"
        case category
        case title
        case name
        case description
        case priceCredits = "price_credits"
        case cafeName = "cafe_name"
        case cafeAddress = "cafe_address"
        case orderCount = "order_count"
        case uniqueCustomers = "unique_customers"
        case avgPrice = "avg_price"
        case lastOrderedAt = "last_ordered_at"
    }
    
    // Convert to CafeProduct for display
    func asProduct() -> CafeProduct {
        CafeProduct(
            id: menuItemId,
            category: category,
            name: CafeProduct.normalizedTitle(title: title, name: name),
            description: description ?? "",
            priceCredits: priceCredits
        )
    }
}
