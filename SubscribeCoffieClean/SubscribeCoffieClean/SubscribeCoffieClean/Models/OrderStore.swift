import Foundation
import Combine


@MainActor
final class OrderStore: ObservableObject {

    @Published private(set) var activeOrder: Order? = nil

    private var scheduled: [DispatchWorkItem] = []

    // DEMO тайминги (быстро, чтобы удобно тестировать)
    private let acceptTimeoutSeconds: TimeInterval = 12
    private let acceptAfterSeconds: TimeInterval = 4
    private let inProgressAfterSeconds: TimeInterval = 8
    private let readyAfterSeconds: TimeInterval = 14

    func reset() {
        cancelScheduled()
        activeOrder = nil
    }

    func placeOrder(
        cafe: CafeSummary,
        cartItems: [CartLine],
        subtotalCredits: Int,
        bonusUsed: Int,
        paidCredits: Int,
        pickupSlot: String?
    ) {
        cancelScheduled()

        let items = cartItems.map {
            OrderItemSnapshot(title: $0.title,
                              unitCredits: $0.unitPrice,
                              quantity: $0.quantity,
                              category: $0.product.category)
        }

        let order = Order(
            cafeId: cafe.id,
            cafeName: cafe.name,
            pickupSlot: pickupSlot,
            status: .created,
            etaMinutes: cafe.etaMinutes,
            items: items,
            subtotalCredits: subtotalCredits,
            bonusUsed: bonusUsed,
            paidCredits: paidCredits,
            events: [OrderStatusEvent(status: .created)]
        )

        activeOrder = order

        // 1) Таймаут принятия -> автоотмена + возврат (в демо)
        schedule(after: acceptTimeoutSeconds) { [weak self] in
            guard let self, var current = self.activeOrder else { return }
            if current.status == .created {
                current.status = .canceled
                current.events.append(OrderStatusEvent(status: .canceled))
                current.status = .refunded
                current.events.append(OrderStatusEvent(status: .refunded))
                self.activeOrder = current
            }
        }

        // 2) Автопринятие/отклонение
        schedule(after: acceptAfterSeconds) { [weak self] in
            guard let self, var current = self.activeOrder else { return }
            guard current.status == .created else { return }

            if !cafe.canPlaceOrder {
                current.status = .rejected
                current.events.append(OrderStatusEvent(status: .rejected))
                current.status = .refunded
                current.events.append(OrderStatusEvent(status: .refunded))
                self.activeOrder = current
                return
            }

            current.status = .accepted
            current.events.append(OrderStatusEvent(status: .accepted))
            self.activeOrder = current
        }

        // 3) In progress
        schedule(after: inProgressAfterSeconds) { [weak self] in
            guard let self, var current = self.activeOrder else { return }
            guard current.status == .accepted else { return }
            current.status = .inProgress
            current.events.append(OrderStatusEvent(status: .inProgress))
            self.activeOrder = current
        }

        // 4) Ready
        schedule(after: readyAfterSeconds) { [weak self] in
            guard let self, var current = self.activeOrder else { return }
            guard current.status == .inProgress else { return }
            current.status = .ready
            current.events.append(OrderStatusEvent(status: .ready))
            self.activeOrder = current
        }
    }

    func markPickedUp() {
        guard var current = activeOrder else { return }
        guard current.status == .ready else { return }
        current.status = .pickedUp
        current.events.append(OrderStatusEvent(status: .pickedUp))
        activeOrder = current
    }

    var canCancelNow: Bool {
        guard let order = activeOrder else { return false }
        switch order.status {
        case .created:
            return true
        case .accepted:
            if let acceptedAt = order.events.first(where: { $0.status == .accepted })?.timestamp {
                return Date().timeIntervalSince(acceptedAt) <= 60
            }
            return false
        default:
            return false
        }
    }

    func cancelByUser() {
        guard var current = activeOrder else { return }
        guard canCancelNow else { return }
        current.status = .canceled
        current.events.append(OrderStatusEvent(status: .canceled))
        current.status = .refunded
        current.events.append(OrderStatusEvent(status: .refunded))
        activeOrder = current
    }

    // MARK: - Scheduling
    private func cancelScheduled() {
        scheduled.forEach { $0.cancel() }
        scheduled.removeAll()
    }

    private func schedule(after seconds: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
}
