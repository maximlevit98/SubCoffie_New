import Foundation

enum CafeMenuCategory: String, CaseIterable, Identifiable, Codable {
    case drinks
    case food
    case syrups
    case merch

    var id: String { rawValue }

    var titleRu: String {
        switch self {
        case .drinks: return "Напитки"
        case .food:   return "Еда"
        case .syrups: return "Сиропы"
        case .merch:  return "Мерч"
        }
    }
}

struct CafeProduct: Identifiable, Equatable, Codable {
    let id: UUID
    let category: CafeMenuCategory
    let name: String
    let description: String
    let priceCredits: Int
    let prepTimeSec: Int?

    init(
        id: UUID = UUID(),
        category: CafeMenuCategory,
        name: String,
        description: String,
        priceCredits: Int,
        prepTimeSec: Int? = nil
    ) {
        self.id = id
        self.category = category
        self.name = CafeProduct.normalizedTitle(title: name, name: nil)
        self.description = description
        self.priceCredits = priceCredits
        self.prepTimeSec = prepTimeSec
    }
}

extension CafeProduct {
    static func normalizedTitle(title: String?, name: String?) -> String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return "Без названия"
    }
}

struct CafeMenu: Equatable, Codable {
    var drinks: [CafeProduct]
    var food: [CafeProduct]
    var syrups: [CafeProduct]
    var merch: [CafeProduct]

    func products(for category: CafeMenuCategory) -> [CafeProduct] {
        switch category {
        case .drinks: return drinks
        case .food:   return food
        case .syrups: return syrups
        case .merch:  return merch
        }
    }
}
