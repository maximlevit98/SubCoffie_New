import Foundation

struct SupabaseOrderDTO: Decodable {
    let id: UUID
    let cafeId: UUID
    let customerPhone: String
    let status: String
    let etaMinutes: Int
    let subtotalCredits: Int
    let bonusUsed: Int
    let paidCredits: Int
    let pickupDeadline: Date?
    let createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case cafeId = "cafe_id"
        case customerPhone = "customer_phone"
        case status
        case etaMinutes = "eta_minutes"
        case subtotalCredits = "subtotal_credits"
        case bonusUsed = "bonus_used"
        case paidCredits = "paid_credits"
        case pickupDeadline = "pickup_deadline"
        case createdAt = "created_at"
    }

    func asDomain() -> Order? {
        guard let orderStatus = OrderStatusMapper.map(status) else { return nil }
        return Order(
            id: id,
            cafeId: cafeId,
            cafeName: nil,
            createdAt: createdAt,
            pickupSlot: nil,
            status: orderStatus,
            etaMinutes: etaMinutes,
            items: [],
            subtotalCredits: subtotalCredits,
            bonusUsed: bonusUsed,
            paidCredits: paidCredits,
            events: []
        )
    }
}

struct SupabaseOrderEventDTO: Decodable {
    let id: UUID
    let orderId: UUID
    let status: String
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case status
        case createdAt = "created_at"
    }

    func asDomain() -> OrderStatusEvent? {
        guard let s = OrderStatusMapper.map(status) else { return nil }
        return OrderStatusEvent(id: id, status: s, timestamp: createdAt)
    }
}

private enum OrderStatusMapper {
    static func map(_ raw: String) -> OrderStatus? {
        if let exact = OrderStatus(rawValue: raw) { return exact }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "created": return .created
        case "accepted": return .accepted
        case "rejected": return .rejected
        case "in_progress": return .inProgress
        case "ready": return .ready
        case "issued": return .issued
        case "picked_up": return .pickedUp
        case "canceled": return .canceled
        case "refunded": return .refunded
        case "no_show": return .noShow
        default: return nil
        }
    }
}
