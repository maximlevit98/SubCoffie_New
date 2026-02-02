import Foundation

struct CartLine: Identifiable, Equatable {
    let id: UUID
    let product: CafeProduct
    let quantity: Int

    init(id: UUID = UUID(), product: CafeProduct, quantity: Int = 1) {
        self.id = id
        self.product = product
        self.quantity = quantity
    }

    var title: String { product.name }
    var description: String { product.description }
    var unitPrice: Int { product.priceCredits }
    var lineTotal: Int { unitPrice * quantity }
}
