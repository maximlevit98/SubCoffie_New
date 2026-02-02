import Foundation

enum OrderStatus: String, CaseIterable, Codable {
    case created = "Created"
    case accepted = "Accepted"
    case rejected = "Rejected"
    case inProgress = "In progress"
    case ready = "Ready"
    case issued = "Issued"
    case pickedUp = "Picked up"
    case canceled = "Canceled"
    case refunded = "Refunded"
    case noShow = "No-show"

    var titleRu: String {
        switch self {
        case .created:    return "Создан"
        case .accepted:   return "Принят"
        case .rejected:   return "Отклонён"
        case .inProgress: return "Готовится"
        case .ready:      return "Готов"
        case .issued:     return "Выдан"
        case .pickedUp:   return "Выдан"
        case .canceled:   return "Отменён"
        case .refunded:   return "Возврат"
        case .noShow:     return "Не пришли"
        }
    }
}

struct OrderStatusEvent: Identifiable, Equatable, Codable {
    let id: UUID
    let status: OrderStatus
    let timestamp: Date

    init(id: UUID = UUID(), status: OrderStatus, timestamp: Date = Date()) {
        self.id = id
        self.status = status
        self.timestamp = timestamp
    }
}

struct OrderItemSnapshot: Identifiable, Equatable, Codable {
    let id: UUID
    let orderId: UUID?
    let title: String
    let unitCredits: Int
    let quantity: Int
    let category: CafeMenuCategory

    init(id: UUID = UUID(), orderId: UUID? = nil, title: String, unitCredits: Int, quantity: Int, category: CafeMenuCategory) {
        self.id = id
        self.orderId = orderId
        self.title = title
        self.unitCredits = unitCredits
        self.quantity = quantity
        self.category = category
    }

    var totalCredits: Int { unitCredits * quantity }
}

struct Order: Identifiable, Equatable, Codable {
    let id: UUID
    let cafeId: UUID
    let cafeName: String?
    let createdAt: Date?
    let pickupSlot: String?
    var status: OrderStatus
    let etaMinutes: Int

    let items: [OrderItemSnapshot]

    /// До скидки
    let subtotalCredits: Int
    /// Списали Bonus+ как скидку
    let bonusUsed: Int
    /// Оплатили Credits
    let paidCredits: Int

    var events: [OrderStatusEvent]

    init(
        id: UUID = UUID(),
        cafeId: UUID,
        cafeName: String? = nil,
        createdAt: Date? = Date(),
        pickupSlot: String? = nil,
        status: OrderStatus,
        etaMinutes: Int,
        items: [OrderItemSnapshot],
        subtotalCredits: Int,
        bonusUsed: Int,
        paidCredits: Int,
        events: [OrderStatusEvent]
    ) {
        self.id = id
        self.cafeId = cafeId
        self.cafeName = cafeName
        self.createdAt = createdAt
        self.pickupSlot = pickupSlot
        self.status = status
        self.etaMinutes = etaMinutes
        self.items = items
        self.subtotalCredits = subtotalCredits
        self.bonusUsed = bonusUsed
        self.paidCredits = paidCredits
        self.events = events
    }

    var qrPayload: String {
        "SC|order=\(id.uuidString)|cafe=\(cafeId.uuidString)"
    }
}
