import Foundation

enum CafeMode: String, CaseIterable, Codable {
    case open
    case busy
    case paused
    case closed

    var titleRu: String {
        switch self {
        case .open:   return "Open"
        case .busy:   return "Busy"
        case .paused: return "Paused"
        case .closed: return "Closed"
        }
    }
}

struct CafeSummary: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let address: String
    let mode: CafeMode

    let etaMinutes: Int
    let activeOrders: Int
    let maxActiveOrders: Int
    let distanceMinutes: Int
    let rating: Double?
    let avgCheckCredits: Int?

    init(
        id: UUID,
        name: String,
        address: String,
        mode: CafeMode,
        etaMinutes: Int,
        activeOrders: Int,
        maxActiveOrders: Int,
        distanceMinutes: Int,
        rating: Double? = nil,
        avgCheckCredits: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.mode = mode
        self.etaMinutes = etaMinutes
        self.activeOrders = activeOrders
        self.maxActiveOrders = maxActiveOrders
        self.distanceMinutes = distanceMinutes
        self.rating = rating
        self.avgCheckCredits = avgCheckCredits
    }

    var isOverloaded: Bool { activeOrders >= maxActiveOrders }

    var canPlaceOrder: Bool {
        switch mode {
        case .open, .busy:
            return !isOverloaded
        case .paused, .closed:
            return false
        }
    }
    var distanceKm: Double {
        // заглушка: переводим "минуты до кофейни" в "км"
        // можешь менять коэффициент как хочешь
        Double(distanceMinutes) * 0.25
    }
}
