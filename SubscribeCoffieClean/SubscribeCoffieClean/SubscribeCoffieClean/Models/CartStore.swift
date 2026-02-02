import Foundation
import Combine

@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var lines: [CartLine] = []

    init() {}

    func reset() {
        lines = []
    }

    var totalItems: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }

    var subtotalCredits: Int {
        lines.reduce(0) { $0 + $1.lineTotal }
    }

    var hasDrink: Bool {
        lines.contains(where: { $0.product.category == .drinks })
    }

    var hasNonDrink: Bool {
        lines.contains(where: { $0.product.category != .drinks })
    }

    var hasFood: Bool {
        lines.contains(where: { $0.product.category == .food })
    }

    var hasSyrup: Bool {
        lines.contains(where: { $0.product.category == .syrups })
    }

    var hasMerch: Bool {
        lines.contains(where: { $0.product.category == .merch })
    }

    func add(product: CafeProduct, quantity: Int = 1) {
        guard quantity > 0 else { return }
        if let idx = lines.firstIndex(where: { $0.product.id == product.id }) {
            let current = lines[idx]
            lines[idx] = CartLine(id: current.id, product: current.product, quantity: current.quantity + quantity)
        } else {
            lines.append(CartLine(product: product, quantity: quantity))
        }
    }

    func increment(lineId: UUID) {
        guard let idx = lines.firstIndex(where: { $0.id == lineId }) else { return }
        let current = lines[idx]
        lines[idx] = CartLine(id: current.id, product: current.product, quantity: current.quantity + 1)
    }

    func decrement(lineId: UUID) {
        guard let idx = lines.firstIndex(where: { $0.id == lineId }) else { return }
        let current = lines[idx]
        let newQty = current.quantity - 1
        if newQty <= 0 {
            lines.remove(at: idx)
        } else {
            lines[idx] = CartLine(id: current.id, product: current.product, quantity: newQty)
        }
    }

    func remove(lineId: UUID) {
        lines.removeAll { $0.id == lineId }
    }
}
