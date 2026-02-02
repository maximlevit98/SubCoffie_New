import Foundation
import Combine
import SwiftUI

@MainActor
final class CafeWalletStore: ObservableObject {
    @Published private(set) var cafeId: String?
    @Published private(set) var cafeName: String?
    @Published private(set) var credits: Int
    @Published private(set) var bonus: Int

    private let kId = "sc_cafeWallet_id"
    private let kName = "sc_cafeWallet_name"
    private let kCredits = "sc_cafeWallet_credits"
    private let kBonus = "sc_cafeWallet_bonus"

    init() {
        let ud = UserDefaults.standard
        self.cafeId = ud.string(forKey: kId)
        self.cafeName = ud.string(forKey: kName)
        self.credits = ud.integer(forKey: kCredits)
        self.bonus = ud.integer(forKey: kBonus)
    }

    func selectCafe(_ cafe: CafeSummary) {
        cafeId = cafe.id.uuidString
        cafeName = cafe.name
        persist()
    }

    func topUp(amount: Int) {
        guard amount > 0 else { return }
        credits += amount
        bonus += Int(Double(amount) * 0.1) // демо кэшбек при пополнении
        persist()
    }

    func addBonus(_ amount: Int) {
        guard amount > 0 else { return }
        bonus += amount
        persist()
    }

    func spendBonus(_ amount: Int) {
        guard amount > 0 else { return }
        bonus = max(0, bonus - amount)
        persist()
    }

    func reset() {
        credits = 0
        bonus = 0
        persist()
    }

    func clearSelection() {
        cafeId = nil
        cafeName = nil
        reset()
        let ud = UserDefaults.standard
        ud.removeObject(forKey: kId)
        ud.removeObject(forKey: kName)
    }

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(cafeId, forKey: kId)
        ud.set(cafeName, forKey: kName)
        ud.set(credits, forKey: kCredits)
        ud.set(bonus, forKey: kBonus)
    }
}
