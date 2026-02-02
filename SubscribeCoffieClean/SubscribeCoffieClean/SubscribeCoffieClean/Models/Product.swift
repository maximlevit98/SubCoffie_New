import Foundation

enum ProductType: String, Codable {
    case drink
    case food
    case merch
}

struct Product: Identifiable, Equatable {
    let id: String
    let categoryId: String
    let title: String
    let subtitle: String
    let type: ProductType
    let basePriceCredits: Int
    let isAvailable: Bool
}
