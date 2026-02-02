import Foundation

// MARK: - Enums

enum CafeOnboardingStatus: String, Codable, CaseIterable {
    case pending
    case underReview = "under_review"
    case approved
    case rejected
    case cancelled
    
    var titleRu: String {
        switch self {
        case .pending: return "Ожидает"
        case .underReview: return "На рассмотрении"
        case .approved: return "Одобрено"
        case .rejected: return "Отклонено"
        case .cancelled: return "Отменено"
        }
    }
    
    var colorName: String {
        switch self {
        case .pending: return "orange"
        case .underReview: return "blue"
        case .approved: return "green"
        case .rejected: return "red"
        case .cancelled: return "gray"
        }
    }
}

enum CafeBusinessType: String, Codable, CaseIterable {
    case independent
    case franchise
    case chain
    
    var titleRu: String {
        switch self {
        case .independent: return "Независимое"
        case .franchise: return "Франшиза"
        case .chain: return "Сеть"
        }
    }
}

enum CafeDocumentType: String, Codable, CaseIterable {
    case logo
    case menuPhoto = "menu_photo"
    case interiorPhoto = "interior_photo"
    case businessLicense = "business_license"
    case other
    
    var titleRu: String {
        switch self {
        case .logo: return "Логотип"
        case .menuPhoto: return "Фото меню"
        case .interiorPhoto: return "Фото интерьера"
        case .businessLicense: return "Бизнес-лицензия"
        case .other: return "Другое"
        }
    }
}

// MARK: - Models

struct CafeOnboardingRequest: Identifiable, Codable {
    let id: UUID
    let status: CafeOnboardingStatus
    let cafeName: String
    let cafeAddress: String
    let cafePhone: String
    let cafeEmail: String
    let cafeDescription: String?
    let businessType: CafeBusinessType?
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewComment: String?
    let rejectionReason: String?
    let createdCafeId: UUID?
    let documentCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case cafeName = "cafe_name"
        case cafeAddress = "cafe_address"
        case cafePhone = "cafe_phone"
        case cafeEmail = "cafe_email"
        case cafeDescription = "cafe_description"
        case businessType = "business_type"
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case reviewComment = "review_comment"
        case rejectionReason = "rejection_reason"
        case createdCafeId = "created_cafe_id"
        case documentCount = "document_count"
    }
}

struct CafeOnboardingSubmission: Codable {
    let cafeName: String
    let cafeAddress: String
    let cafePhone: String
    let cafeEmail: String
    let cafeDescription: String?
    let businessType: CafeBusinessType?
    let openingHours: String?
    let estimatedDailyOrders: Int?
    
    enum CodingKeys: String, CodingKey {
        case cafeName = "p_cafe_name"
        case cafeAddress = "p_cafe_address"
        case cafePhone = "p_cafe_phone"
        case cafeEmail = "p_cafe_email"
        case cafeDescription = "p_cafe_description"
        case businessType = "p_business_type"
        case openingHours = "p_opening_hours"
        case estimatedDailyOrders = "p_estimated_daily_orders"
    }
}

struct CafeDocument: Identifiable, Codable {
    let id: UUID
    let requestId: UUID
    let documentType: CafeDocumentType
    let fileName: String
    let filePath: String
    let fileSize: Int?
    let mimeType: String?
    let uploadedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case documentType = "document_type"
        case fileName = "file_name"
        case filePath = "file_path"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case uploadedAt = "uploaded_at"
    }
}
