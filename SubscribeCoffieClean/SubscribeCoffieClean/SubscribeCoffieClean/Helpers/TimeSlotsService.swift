import Foundation

struct TimeSlotsService {
    private let apiClient: SupabaseAPIClient

    init(apiClient: SupabaseAPIClient = SupabaseAPIClient()) {
        self.apiClient = apiClient
    }

    func fetchTimeSlots(cafeId: UUID, cartItems: [CartLine], now: Date) async throws -> [String] {
        let payload = TimeSlotsRequest(
            cafeId: cafeId,
            cartItems: cartItems.map {
                TimeSlotCartItem(
                    id: $0.product.id,
                    qty: $0.quantity,
                    prepTimeSec: prepTimeSeconds(for: $0.product)
                )
            },
            now: now
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(payload)

        #if DEBUG
        print("Time slots RPC payload items: \(payload.cartItems)")
        #endif
        let rows: [TimeSlotRow] = try await apiClient.post("rpc/get_time_slots", body: body)
        let slots = rows.compactMap { $0.asSlotString() }
        #if DEBUG
        print("Loaded time slots from Supabase: \(slots.count)")
        #endif
        return slots
    }

    private func prepTimeSeconds(for product: CafeProduct) -> Int {
        if let prepTimeSec = product.prepTimeSec, prepTimeSec > 0 {
            return prepTimeSec
        }
        switch product.category {
        case .drinks: return 120
        case .food: return 300
        case .syrups: return 60
        case .merch: return 30
        }
    }
}

private struct TimeSlotsRequest: Encodable {
    let cafeId: UUID
    let cartItems: [TimeSlotCartItem]
    let now: Date

    enum CodingKeys: String, CodingKey {
        case cafeId = "p_cafe_id"
        case cartItems = "p_cart_items"
        case now = "p_now"
    }
}

private struct TimeSlotCartItem: Encodable, CustomStringConvertible {
    let id: UUID
    let qty: Int
    let prepTimeSec: Int

    enum CodingKeys: String, CodingKey {
        case id
        case qty
        case prepTimeSec = "prep_time_sec"
    }

    var description: String {
        "{id:\(id.uuidString), qty:\(qty), prep_time_sec:\(prepTimeSec)}"
    }
}

private struct TimeSlotRow: Decodable {
    let slotStart: String

    enum CodingKeys: String, CodingKey {
        case slotStart = "slot_start"
    }

    func asSlotString() -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: slotStart) else { return nil }
        let output = DateFormatter()
        output.dateFormat = "HH:mm"
        output.locale = Locale(identifier: "ru_RU")
        return output.string(from: date)
    }
}
