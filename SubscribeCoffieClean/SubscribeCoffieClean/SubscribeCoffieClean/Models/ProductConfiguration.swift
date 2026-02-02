import Foundation

struct ProductConfiguration: Equatable {
    /// Короткое описание выбранных опций (например: "M, oat, vanilla")
    let titleSuffix: String
    /// Итоговая цена за 1 шт (в Credits)
    let unitPriceCredits: Int
}
