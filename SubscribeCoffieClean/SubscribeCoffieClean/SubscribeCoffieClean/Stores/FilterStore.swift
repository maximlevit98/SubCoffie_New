import Combine
import Foundation

enum CafeSortKey: String, CaseIterable, Identifiable, Codable {
    case distance
    case rating
    case avgCheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distance:
            return "Удалённость"
        case .rating:
            return "Рейтинг"
        case .avgCheck:
            return "Средний чек"
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable, Codable {
    case ascending
    case descending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ascending:
            return "По возрастанию"
        case .descending:
            return "По убыванию"
        }
    }
}

struct FilterState: Equatable, Codable {
    var sortKey: CafeSortKey = .distance
    var sortOrder: SortOrder = .ascending

    var summaryTitle: String {
        "\(sortKey.title) · \(sortOrder == .ascending ? "↑" : "↓")"
    }
}

final class FilterStore: ObservableObject {
    @Published var state: FilterState = FilterState()
}
