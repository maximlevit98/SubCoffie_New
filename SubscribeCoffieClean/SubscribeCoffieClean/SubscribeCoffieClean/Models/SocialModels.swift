import Foundation

// MARK: - Review Models

struct Review: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let cafeId: UUID?
    let menuItemId: UUID?
    let orderId: UUID?
    let rating: Int
    let comment: String?
    let photos: [String]?
    let helpfulCount: Int
    let isVerifiedPurchase: Bool
    let status: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case menuItemId = "menu_item_id"
        case orderId = "order_id"
        case rating
        case comment
        case photos
        case helpfulCount = "helpful_count"
        case isVerifiedPurchase = "is_verified_purchase"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ReviewSubmission {
    let userId: UUID
    let cafeId: UUID?
    let menuItemId: UUID?
    let orderId: UUID?
    let rating: Int
    let comment: String?
    let photos: [String]?
}

struct CafeReviewsSummary: Codable {
    let reviews: [ReviewWithUser]
    let averageRating: Double?
    let totalReviews: Int
    
    enum CodingKeys: String, CodingKey {
        case reviews
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
    }
}

struct ReviewWithUser: Identifiable, Codable {
    let reviewId: UUID
    let userId: UUID
    let rating: Int
    let comment: String?
    let photos: [String]?
    let helpfulCount: Int
    let isVerifiedPurchase: Bool
    let createdAt: Date
    
    var id: UUID { reviewId }
    
    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case userId = "user_id"
        case rating
        case comment
        case photos
        case helpfulCount = "helpful_count"
        case isVerifiedPurchase = "is_verified_purchase"
        case createdAt = "created_at"
    }
}

// MARK: - Favorite Models

struct Favorite: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let cafeId: UUID?
    let menuItemId: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case menuItemId = "menu_item_id"
        case createdAt = "created_at"
    }
}

struct FavoriteCafe: Identifiable, Codable {
    let favoriteId: UUID
    let cafeId: UUID
    let name: String
    let address: String
    let logoUrl: String?
    let favoritedAt: Date
    
    var id: UUID { favoriteId }
    
    enum CodingKeys: String, CodingKey {
        case favoriteId = "favorite_id"
        case cafeId = "cafe_id"
        case name
        case address
        case logoUrl = "logo_url"
        case favoritedAt = "favorited_at"
    }
}

struct FavoriteMenuItem: Identifiable, Codable {
    let favoriteId: UUID
    let menuItemId: UUID
    let name: String
    let description: String?
    let priceCredits: Int
    let imageUrl: String?
    let cafeId: UUID
    let favoritedAt: Date
    
    var id: UUID { favoriteId }
    
    enum CodingKeys: String, CodingKey {
        case favoriteId = "favorite_id"
        case menuItemId = "menu_item_id"
        case name
        case description
        case priceCredits = "price_credits"
        case imageUrl = "image_url"
        case cafeId = "cafe_id"
        case favoritedAt = "favorited_at"
    }
}

struct UserFavorites: Codable {
    let cafes: [FavoriteCafe]
    let menuItems: [FavoriteMenuItem]
    
    enum CodingKeys: String, CodingKey {
        case cafes
        case menuItems = "menu_items"
    }
}

// MARK: - Friend Models

struct Friend: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    let status: FriendStatus
    let createdAt: Date
    let acceptedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
    }
}

enum FriendStatus: String, Codable {
    case pending
    case accepted
    case blocked
}

struct FriendInfo: Identifiable, Codable {
    let friendId: UUID
    let requestId: UUID
    let status: FriendStatus
    let isInitiator: Bool
    let createdAt: Date
    let acceptedAt: Date?
    
    var id: UUID { friendId }
    
    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
        case requestId = "request_id"
        case status
        case isInitiator = "is_initiator"
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
    }
}

// MARK: - Shared Order Models

struct SharedOrder: Identifiable, Codable, Hashable {
    let id: UUID
    let orderId: UUID
    let initiatorUserId: UUID
    let totalAmountCredits: Int
    let status: SharedOrderStatus
    let createdAt: Date
    let confirmedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case initiatorUserId = "initiator_user_id"
        case totalAmountCredits = "total_amount_credits"
        case status
        case createdAt = "created_at"
        case confirmedAt = "confirmed_at"
    }
}

enum SharedOrderStatus: String, Codable {
    case pending
    case confirmed
    case cancelled
}

struct SharedOrderParticipant: Identifiable, Codable, Hashable {
    let id: UUID
    let sharedOrderId: UUID
    let userId: UUID
    let shareAmountCredits: Int
    let paymentStatus: ParticipantPaymentStatus
    let paidAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sharedOrderId = "shared_order_id"
        case userId = "user_id"
        case shareAmountCredits = "share_amount_credits"
        case paymentStatus = "payment_status"
        case paidAt = "paid_at"
        case createdAt = "created_at"
    }
}

enum ParticipantPaymentStatus: String, Codable {
    case pending
    case paid
    case declined
}

struct SharedOrderParticipantInput: Codable {
    let userId: UUID
    let shareAmountCredits: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case shareAmountCredits = "share_amount_credits"
    }
}
