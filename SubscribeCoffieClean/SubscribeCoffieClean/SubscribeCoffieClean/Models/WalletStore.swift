import Foundation
import Combine

// MARK: - Temporary stub types (until loyalty system is implemented)
struct BonusLot: Codable {
    let id: UUID
    var amount: Int // Changed to var for mutations
    let expiresAt: Date?
}

enum LoyaltyPackage: String, Codable {
    case balanced
    case premium
    case basic
    case conservative // alias for basic
    case aggressive // alias for premium
    
    var titleRu: String {
        switch self {
        case .balanced: return "Баланс"
        case .premium, .aggressive: return "Премиум"
        case .basic, .conservative: return "Базовый"
        }
    }
}

enum LoyaltyTier: String, Codable {
    case bronze
    case silver
    case gold
    case platinum
    
    var titleRu: String {
        switch self {
        case .bronze: return "Бронза"
        case .silver: return "Серебро"
        case .gold: return "Золото"
        case .platinum: return "Платина"
        }
    }
}

@MainActor
final class WalletStore: ObservableObject {

    // MARK: - Published
    @Published private(set) var credits: Int
    @Published private(set) var bonusLots: [BonusLot]
    @Published var loyaltyPackage: LoyaltyPackage
    @Published private(set) var lifetimeTopUp: Int
    @Published private(set) var bonusSpentToday: Int

    // MARK: - Persistence keys
    private let kCredits = "sc_wallet_credits"
    private let kBonusLots = "sc_wallet_bonusLots"
    private let kPackage = "sc_wallet_package"
    private let kLifetime = "sc_wallet_lifetimeTopUp"
    private let kSpentDay = "sc_wallet_spentDay"
    private let kSpentAmount = "sc_wallet_spentAmount"

    private var spentDayKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let ud = UserDefaults.standard

        self.credits = ud.integer(forKey: kCredits)
        self.lifetimeTopUp = ud.integer(forKey: kLifetime)

        if let raw = ud.string(forKey: kPackage), let p = LoyaltyPackage(rawValue: raw) {
            self.loyaltyPackage = p
        } else {
            self.loyaltyPackage = .balanced
        }

        if let data = ud.data(forKey: kBonusLots),
           let lots = try? decoder.decode([BonusLot].self, from: data) {
            self.bonusLots = lots
        } else {
            self.bonusLots = []
        }

        let today = Self.dayKey(Date())
        let savedDay = ud.string(forKey: kSpentDay) ?? today
        self.spentDayKey = savedDay

        if savedDay == today {
            self.bonusSpentToday = ud.integer(forKey: kSpentAmount)
        } else {
            self.bonusSpentToday = 0
            ud.set(today, forKey: kSpentDay)
            ud.set(0, forKey: kSpentAmount)
            self.spentDayKey = today
        }

        // стартовые Credits для демо один раз
        if credits == 0 && lifetimeTopUp == 0 {
            credits = 800
            persistAll()
        }

        // Можно чистить протухшие бонусы при старте (это не UI-cycle)
        purgeExpiredBonusIfNeeded()
        persistAll()
    }

    // MARK: - Computed (PURE)
    var tier: LoyaltyTier {
        if lifetimeTopUp >= 10_000 { return .gold }
        if lifetimeTopUp >= 3_000  { return .silver }
        return .bronze
    }

    /// ВАЖНО: PURE, без мутаций bonusLots (иначе SwiftUI ругается).
    var bonusBalance: Int {
        let now = Date()
        return bonusLots
            .filter { $0.expiresAt == nil || $0.expiresAt! > now }
            .reduce(0) { $0 + $1.amount }
    }

    var bonusTtlDays: Int {
        switch loyaltyPackage {
        case .conservative, .basic: return 45
        case .balanced:             return 60
        case .aggressive, .premium: return 90
        }
    }

    // MARK: - Rules (3 пакета)
    private func bonusRate(for tier: LoyaltyTier) -> Double {
        switch loyaltyPackage {
        case .conservative, .basic:
            switch tier { case .bronze: return 0.02; case .silver: return 0.04; case .gold: return 0.06; case .platinum: return 0.08 }
        case .balanced:
            switch tier { case .bronze: return 0.04; case .silver: return 0.06; case .gold: return 0.08; case .platinum: return 0.10 }
        case .aggressive, .premium:
            switch tier { case .bronze: return 0.08; case .silver: return 0.10; case .gold: return 0.12; case .platinum: return 0.15 }
        }
    }

    private var dailyBonusCap: Int {
        switch loyaltyPackage {
        case .conservative, .basic: return 150
        case .balanced:             return 300
        case .aggressive, .premium: return 600
        }
    }

    private var orderBonusCapPercent: Double {
        switch loyaltyPackage {
        case .conservative, .basic: return 0.15
        case .balanced:             return 0.25
        case .aggressive, .premium: return 0.40
        }
    }

    private func categoryCapsPercent() -> (drinks: Double, food: Double, merch: Double) {
        switch loyaltyPackage {
        case .conservative, .basic: return (drinks: 0.08, food: 0.20, merch: 0.10)
        case .balanced:             return (drinks: 0.12, food: 0.30, merch: 0.15)
        case .aggressive, .premium: return (drinks: 0.20, food: 0.45, merch: 0.25)
        }
    }

    // MARK: - API
    func topUpDemo(credits amount: Int) {
        guard amount > 0 else { return }

        // действие пользователя — тут можно мутировать/чистить
        rollDailyIfNeeded()
        purgeExpiredBonusIfNeeded()

        credits += amount
        lifetimeTopUp += amount

        let earnedBonus = Int(Double(amount) * bonusPercentForTopUp(amount))
        if earnedBonus > 0 {
            let expires = Calendar.current.date(byAdding: .day, value: bonusTtlDays, to: Date()) ?? Date()
            bonusLots.append(BonusLot(id: UUID(), amount: earnedBonus, expiresAt: expires))
        }

        persistAll()
    }

    /// ВАЖНО: PURE (никаких roll/purge/persist внутри)
    func maxBonusAllowed(for cart: CartStore) -> Int {
        let subtotal = cart.subtotalCredits
        guard subtotal > 0 else { return 0 }

        // Правило продукта: выгодно на допы только если в корзине есть напиток
        // У тебя сейчас категория drinks, оставляем как есть.
        let hasDrink = cart.lines.contains { $0.product.category == .drinks }
        let hasNonDrink = cart.lines.contains { $0.product.category != .drinks }

        // Новая логика:
        // - Если есть напиток и вместе с ним выпечка/сироп/мерч → 50%
        // - Если только напиток → 10%
        // - Если только выпечка/сироп/мерч (без напитка) → 10%
        let capPercent: Double = (hasDrink && hasNonDrink) ? 0.5 : 0.1
        let orderCap = Int(Double(subtotal) * capPercent)

        let dailyRemaining = max(0, dailyBonusCap - bonusSpentToday)
        let available = bonusBalance

        return max(0, min(available, orderCap, dailyRemaining))
    }

    func pay(subtotalCredits: Int, requestedBonus: Int, cart: CartStore) -> (paidCredits: Int, usedBonus: Int) {

        // действие пользователя — тут можно мутировать/чистить
        rollDailyIfNeeded()
        purgeExpiredBonusIfNeeded()

        let maxBonus = maxBonusAllowed(for: cart)
        let useBonus = max(0, min(requestedBonus, maxBonus, subtotalCredits))
        let toPay = max(0, subtotalCredits - useBonus)

        guard credits >= toPay else { return (0, 0) }

        if useBonus > 0 {
            spendBonus(useBonus)
            bonusSpentToday += useBonus
            persistDailySpent()
        }

        credits -= toPay
        persistAll()
        return (toPay, useBonus)
    }

    func refund(paidCredits: Int, usedBonus: Int) {
        // действие системы (но не UI body) — можно чистить
        rollDailyIfNeeded()
        purgeExpiredBonusIfNeeded()

        if paidCredits > 0 { credits += paidCredits }
        if usedBonus > 0 {
            let expires = Calendar.current.date(byAdding: .day, value: bonusTtlDays, to: Date()) ?? Date()
            bonusLots.append(BonusLot(id: UUID(), amount: usedBonus, expiresAt: expires))
        }
        persistAll()
    }

    func resetDemoWallet() {
        credits = 800
        lifetimeTopUp = 0
        bonusLots = []
        bonusSpentToday = 0
        spentDayKey = Self.dayKey(Date())

        let ud = UserDefaults.standard
        ud.set(spentDayKey, forKey: kSpentDay)
        ud.set(0, forKey: kSpentAmount)

        persistAll()
    }

    // MARK: - internals
    func addBonus(_ amount: Int, expires: Date? = nil) {
        guard amount > 0 else { return }
        let exp = expires ?? (Calendar.current.date(byAdding: .day, value: bonusTtlDays, to: Date()) ?? Date())
        bonusLots.append(BonusLot(id: UUID(), amount: amount, expiresAt: exp))
        persistAll()
    }

    func spendBonus(_ amount: Int) {
        guard amount > 0 else { return }
        var remaining = amount
        purgeExpiredBonusIfNeeded()

        bonusLots.sort { ($0.expiresAt ?? Date.distantFuture) < ($1.expiresAt ?? Date.distantFuture) }

        for i in bonusLots.indices {
            if remaining <= 0 { break }
            if bonusLots[i].amount <= 0 { continue }

            let take = min(bonusLots[i].amount, remaining)
            bonusLots[i].amount -= take
            remaining -= take
        }

        bonusLots.removeAll { $0.amount <= 0 }
        persistAll()
    }

    func availableBonusBalance() -> Int {
        return bonusLots.reduce(0) { $0 + $1.amount }
    }

    func spendCredits(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        guard credits >= amount else { return false }
        credits -= amount
        persistAll()
        return true
    }

    // MARK: - Cashback helpers (pure)
    func cashbackBaseRate(for cart: CartStore) -> Double {
        // базовое правило: 4% если напиток + что-то ещё, иначе 2%
        if cart.hasDrink && cart.hasNonDrink {
            return 0.04
        } else {
            return 0.02
        }
    }

    func cashbackMultiplier(for cart: CartStore) -> Int {
        cart.hasMerch ? 2 : 1
    }

    func cashbackRate(for cart: CartStore) -> Double {
        cashbackBaseRate(for: cart) * Double(cashbackMultiplier(for: cart))
    }

    /// Теперь чистка НЕ делает persistAll() сама.
    /// Persist делаем в местах "действий" (topUp/pay/refund/init).
    private func purgeExpiredBonusIfNeeded() {
        let now = Date()
        bonusLots.removeAll { lot in
            guard let expires = lot.expiresAt else { return false }
            return expires <= now
        }
    }

    private func rollDailyIfNeeded() {
        let today = Self.dayKey(Date())
        if spentDayKey != today {
            spentDayKey = today
            bonusSpentToday = 0
            persistDailySpent()
        }
    }

    private func persistDailySpent() {
        let ud = UserDefaults.standard
        ud.set(spentDayKey, forKey: kSpentDay)
        ud.set(bonusSpentToday, forKey: kSpentAmount)
    }

    private func persistAll() {
        let ud = UserDefaults.standard
        ud.set(credits, forKey: kCredits)
        ud.set(lifetimeTopUp, forKey: kLifetime)
        ud.set(loyaltyPackage.rawValue, forKey: kPackage)

        if let data = try? encoder.encode(bonusLots) {
            ud.set(data, forKey: kBonusLots)
        }
    }

    private func bonusPercentForTopUp(_ amount: Int) -> Double {
        if amount >= 5_000 { return 0.15 }
        if amount >= 3_000 { return 0.10 }
        if amount > 1_000  { return 0.05 }
        if amount == 1_000 { return 0.02 }
        return 0.0
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
