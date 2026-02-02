import Foundation

struct SupabaseCafeDTO: Decodable {
    let id: UUID?
    let name: String?
    let address: String?
    let mode: String?
    let etaMinutes: Int?
    let activeOrders: Int?
    let maxActiveOrders: Int?
    let distanceKm: Double?
    let rating: Double?
    let avgCheckCredits: Int?
    let supportsCitypass: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case mode
        case etaMinutes = "eta_minutes"
        case activeOrders = "active_orders"
        case maxActiveOrders = "max_active_orders"
        case distanceKm = "distance_km"
        case rating
        case avgCheckCredits = "avg_check_credits"
        case supportsCitypass = "supports_citypass"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        etaMinutes = try container.decodeIfPresent(Int.self, forKey: .etaMinutes)
        activeOrders = try container.decodeIfPresent(Int.self, forKey: .activeOrders)
        maxActiveOrders = try container.decodeIfPresent(Int.self, forKey: .maxActiveOrders)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        avgCheckCredits = try container.decodeIfPresent(Int.self, forKey: .avgCheckCredits)
        supportsCitypass = try container.decodeIfPresent(Bool.self, forKey: .supportsCitypass)
    }

    func asDomain() -> CafeSummary? {
        guard let id = id,
              let name = name,
              let address = address
        else { return nil }

        let normalizedMode = (mode ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let cafeMode = CafeMode(rawValue: normalizedMode) ?? .closed
        let derivedDistanceMinutes = distanceKm.map { Int($0 * 4.0) }
        return CafeSummary(
            id: id,
            name: name,
            address: address,
            mode: cafeMode,
            etaMinutes: etaMinutes ?? 0,
            activeOrders: activeOrders ?? 0,
            maxActiveOrders: maxActiveOrders ?? 18,
            distanceMinutes: derivedDistanceMinutes ?? 0,
            rating: rating,
            avgCheckCredits: avgCheckCredits
        )
    }
}

struct SupabaseMenuItemDTO: Decodable {
    let id: UUID?
    let cafeId: UUID?
    let category: String?
    let name: String?
    let title: String?
    let description: String?
    let priceCredits: Int?
    let prepTimeSec: Int?
    let isAvailable: Bool?
    let sortOrder: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case cafeId = "cafe_id"
        case category
        case name
        case title
        case description
        case priceCredits = "price_credits"
        case prepTimeSec = "prep_time_sec"
        case sortOrder = "sort_order"
        case isAvailable = "is_available"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        cafeId = try container.decodeIfPresent(UUID.self, forKey: .cafeId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        priceCredits = try container.decodeIfPresent(Int.self, forKey: .priceCredits)
        prepTimeSec = try container.decodeIfPresent(Int.self, forKey: .prepTimeSec)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    var displayTitle: String {
        CafeProduct.normalizedTitle(title: title, name: name)
    }

    func asDomain() -> CafeProduct? {
        print("🔍 [asDomain] Начало для: \(name ?? "nil")")
        print("🔍 [asDomain]   id: \(id?.uuidString ?? "nil")")
        print("🔍 [asDomain]   category: \(category ?? "nil")")
        print("🔍 [asDomain]   priceCredits: \(priceCredits?.description ?? "nil")")
        print("🔍 [asDomain]   isAvailable: \(isAvailable?.description ?? "nil")")
        
        guard let id else {
            print("🔍 [asDomain] ❌ GUARD 1: нет id")
            menuDebugLog(
                hypothesisId: "H3",
                location: "SupabaseMenuItemDTO.asDomain:missing-id",
                message: "Drop menu item: missing id",
                data: ["hasCategory": category != nil, "hasPrice": priceCredits != nil]
            )
            return nil
        }
        print("🔍 [asDomain] ✅ GUARD 1: id OK")
        
        guard let rawCategory = category else {
            print("🔍 [asDomain] ❌ GUARD 2: нет category")
            menuDebugLog(
                hypothesisId: "H3",
                location: "SupabaseMenuItemDTO.asDomain:missing-category",
                message: "Drop menu item: missing category",
                data: ["id": id.uuidString, "hasPrice": priceCredits != nil]
            )
            return nil
        }
        print("🔍 [asDomain] ✅ GUARD 2: category OK = '\(rawCategory)'")
        
        guard let priceCredits else {
            print("🔍 [asDomain] ❌ GUARD 3: нет priceCredits")
            menuDebugLog(
                hypothesisId: "H3",
                location: "SupabaseMenuItemDTO.asDomain:missing-price",
                message: "Drop menu item: missing price_credits",
                data: ["id": id.uuidString, "category": rawCategory]
            )
            return nil
        }
        print("🔍 [asDomain] ✅ GUARD 3: priceCredits OK = \(priceCredits)")

        let normalizedCategory = rawCategory
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        print("🔍 [asDomain] Normalized category: '\(normalizedCategory)'")
        
        guard let cat = CafeMenuCategory(rawValue: normalizedCategory) else {
            print("🔍 [asDomain] ❌ GUARD 4: invalid category rawValue. Доступные: \(CafeMenuCategory.allCases.map { $0.rawValue })")
            menuDebugLog(
                hypothesisId: "H3",
                location: "SupabaseMenuItemDTO.asDomain:invalid-category",
                message: "Drop menu item: invalid category",
                data: ["id": id.uuidString, "category": rawCategory]
            )
            return nil
        }
        print("🔍 [asDomain] ✅ GUARD 4: category enum OK = \(cat)")
        
        if (isAvailable ?? true) == false {
            print("🔍 [asDomain] ❌ GUARD 5: isAvailable = false")
            menuDebugLog(
                hypothesisId: "H4",
                location: "SupabaseMenuItemDTO.asDomain:is-available-false",
                message: "Drop menu item: is_available=false",
                data: ["id": id.uuidString, "category": rawCategory]
            )
            return nil
        }
        print("🔍 [asDomain] ✅ GUARD 5: isAvailable OK")
        print("🔍 [asDomain] ✅✅✅ УСПЕХ! Создаем CafeProduct")
        
        return CafeProduct(
            id: id,
            category: cat,
            name: displayTitle,
            description: description ?? "",
            priceCredits: priceCredits,
            prepTimeSec: prepTimeSec
        )
    }
}

enum SupabaseMenuMapper {
    static func buildMenu(from items: [SupabaseMenuItemDTO]) -> CafeMenu {
        print("🔍 [MAPPER DEBUG] ===== buildMenu START =====")
        print("🔍 [MAPPER DEBUG] Входящих items: \(items.count)")
        
        // Детальная инспекция каждого item ПЕРЕД маппингом
        for (index, item) in items.enumerated() {
            print("🔍 [MAPPER DEBUG] Item[\(index)]:")
            print("🔍 [MAPPER DEBUG]   id: \(item.id?.uuidString ?? "nil")")
            print("🔍 [MAPPER DEBUG]   name: \(item.name ?? "nil")")
            print("🔍 [MAPPER DEBUG]   category: \(item.category ?? "nil")")
            print("🔍 [MAPPER DEBUG]   priceCredits: \(item.priceCredits?.description ?? "nil")")
            print("🔍 [MAPPER DEBUG]   isAvailable: \(item.isAvailable?.description ?? "nil")")
            print("🔍 [MAPPER DEBUG]   Вызываю asDomain()...")
        }
        
        let available = items.compactMap { item -> CafeProduct? in
            print("🔍 [MAPPER DEBUG] compactMap: обрабатываю \(item.name ?? "nil")")
            let result = item.asDomain()
            if result == nil {
                print("🔍 [MAPPER DEBUG] ❌ Item НЕ смаплен: id=\(item.id?.uuidString ?? "nil"), name=\(item.name ?? "nil"), category=\(item.category ?? "nil")")
            } else {
                print("🔍 [MAPPER DEBUG] ✅ Item смаплен: id=\(item.id?.uuidString ?? "nil"), name=\(item.name ?? "nil")")
            }
            return result
        }
        
        print("🔍 [MAPPER DEBUG] Доступных после маппинга: \(available.count)")
        
        let drinks = available
            .filter { $0.category == .drinks }
            .sorted { $0.sortKey(items) < $1.sortKey(items) }
        let food = available
            .filter { $0.category == .food }
            .sorted { $0.sortKey(items) < $1.sortKey(items) }
        let syrups = available
            .filter { $0.category == .syrups }
            .sorted { $0.sortKey(items) < $1.sortKey(items) }
        let merch = available
            .filter { $0.category == .merch }
            .sorted { $0.sortKey(items) < $1.sortKey(items) }
        
        print("🔍 [MAPPER DEBUG] По категориям: drinks=\(drinks.count), food=\(food.count), syrups=\(syrups.count), merch=\(merch.count)")
        print("🔍 [MAPPER DEBUG] ===== buildMenu END =====")
        
        menuDebugLog(
            hypothesisId: "H2",
            location: "SupabaseMenuMapper.buildMenu",
            message: "Mapped menu",
            data: [
                "rawCount": items.count,
                "mappedCount": available.count,
                "drinks": drinks.count,
                "food": food.count,
                "syrups": syrups.count,
                "merch": merch.count
            ]
        )
        AppLogger.debug("Mapped menu: drinks=\(drinks.count), food=\(food.count), syrups=\(syrups.count), merch=\(merch.count)")
        return CafeMenu(drinks: drinks, food: food, syrups: syrups, merch: merch)
    }
}

private extension CafeProduct {
    func sortKey(_ items: [SupabaseMenuItemDTO]) -> String {
        if let dto = items.first(where: { $0.id == id }), let order = dto.sortOrder {
            return String(format: "%04d_%@", order, name)
        }
        return "9999_\(name)"
    }
}

// #region agent log
private let menuDebugLogPath = "/Users/maxim/Desktop/Кофе по подписке/Новый проект Кофе по подписке/SubscribeCoffie/SubscribeCoffieBackend/.cursor/debug.log"

func menuDebugLog(
    hypothesisId: String,
    location: String,
    message: String,
    data: [String: Any] = [:],
    runId: String = "menu-debug-1"
) {
    let payload: [String: Any] = [
        "sessionId": "debug-session",
        "runId": runId,
        "hypothesisId": hypothesisId,
        "location": location,
        "message": message,
        "data": data,
        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return }
    let newline = Data("\n".utf8)
    if let handle = FileHandle(forWritingAtPath: menuDebugLogPath) {
        handle.seekToEndOfFile()
        handle.write(json)
        handle.write(newline)
        try? handle.close()
    } else {
        FileManager.default.createFile(atPath: menuDebugLogPath, contents: json + newline)
    }
}
// #endregion
