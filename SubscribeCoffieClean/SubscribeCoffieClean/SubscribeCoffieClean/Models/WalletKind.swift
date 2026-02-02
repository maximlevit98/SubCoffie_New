import Foundation

enum WalletKind: String, CaseIterable, Identifiable {
    case cityPass
    case cafe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cityPass: return "CityPass"
        case .cafe: return "Cafe Wallet"
        }
    }
}
