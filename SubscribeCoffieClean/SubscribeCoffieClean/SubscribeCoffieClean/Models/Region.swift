import Foundation

struct Region: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let city: String
    let country: String
    let timezone: String
    let isActive: Bool
    let latitude: Double?
    let longitude: Double?
    let cafeCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "region_id"
        case name = "region_name"
        case city
        case country
        case timezone
        case isActive = "is_active"
        case latitude
        case longitude
        case cafeCount = "cafe_count"
        case createdAt = "created_at"
    }
}

// MARK: - Display helpers

extension Region {
    var displayName: String {
        name
    }
    
    var fullLocation: String {
        "\(city), \(country)"
    }
}
