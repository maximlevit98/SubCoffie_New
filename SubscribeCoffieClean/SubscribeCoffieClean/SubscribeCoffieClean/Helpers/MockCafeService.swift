import Foundation

import Foundation

enum MockCafeService {

    // MARK: - Cafe ids (фиксированные UUID, чтобы не было лишней нагрузки компилятора)
    private static let coffeePointId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let brewLabId     = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let roastGoId     = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let morningCupId  = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private static let nordicBeansId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    // 5 кофеен для выбора
    static func demoCafes() -> [CafeSummary] {
        let cafes: [CafeSummary] = [
            CafeSummary(
                id: coffeePointId,
                name: "Coffee Point ☕️",
                address: "ул. Примерная, 10",
                mode: CafeMode.open,
                etaMinutes: 8,
                activeOrders: 6,
                maxActiveOrders: 18,
                distanceMinutes: 6
            ),
            CafeSummary(
                id: brewLabId,
                name: "Brew Lab",
                address: "пр-т Кофейный, 21",
                mode: CafeMode.busy,
                etaMinutes: 14,
                activeOrders: 16,
                maxActiveOrders: 18,
                distanceMinutes: 9
            ),
            CafeSummary(
                id: roastGoId,
                name: "Roast & Go",
                address: "ул. Центральная, 5",
                mode: CafeMode.paused,
                etaMinutes: 0,
                activeOrders: 0,
                maxActiveOrders: 18,
                distanceMinutes: 12
            ),
            CafeSummary(
                id: morningCupId,
                name: "Morning Cup",
                address: "наб. Уютная, 3",
                mode: CafeMode.open,
                etaMinutes: 10,
                activeOrders: 18,
                maxActiveOrders: 18, // перегруз
                distanceMinutes: 15
            ),
            CafeSummary(
                id: nordicBeansId,
                name: "Nordic Beans",
                address: "пл. Севера, 1",
                mode: CafeMode.closed,
                etaMinutes: 0,
                activeOrders: 0,
                maxActiveOrders: 18,
                distanceMinutes: 22
            )
        ]

        return cafes.sorted { $0.distanceMinutes < $1.distanceMinutes }
    }

    // MARK: - Menu API

    static func sampleMenu() -> CafeMenu {
        buildMenu()
    }

    static func menu(for cafeId: UUID) -> CafeMenu {
        // пока одинаковое меню для всех кофеен (заглушка)
        buildMenu()
    }

    // MARK: - Menu builder (10/10/10/10)

    private static func buildMenu() -> CafeMenu {

        let drinks: [CafeProduct] = [
            .init(category: CafeMenuCategory.drinks, name: "Эспрессо", description: "Классический, насыщенный шот", priceCredits: 150),
            .init(category: CafeMenuCategory.drinks, name: "Американо", description: "Эспрессо + горячая вода", priceCredits: 180),
            .init(category: CafeMenuCategory.drinks, name: "Капучино", description: "Эспрессо, молоко, плотная пена", priceCredits: 240),
            .init(category: CafeMenuCategory.drinks, name: "Латте", description: "Мягкий кофе с молоком", priceCredits: 260),
            .init(category: CafeMenuCategory.drinks, name: "Флэт уайт", description: "Более крепкий и бархатный", priceCredits: 270),
            .init(category: CafeMenuCategory.drinks, name: "Раф ванильный", description: "Сливочный, сладкий, ваниль", priceCredits: 320),
            .init(category: CafeMenuCategory.drinks, name: "Матча латте", description: "Матча + молоко, бодрит мягко", priceCredits: 310),
            .init(category: CafeMenuCategory.drinks, name: "Какао", description: "Тёплый шоколадный напиток", priceCredits: 260),
            .init(category: CafeMenuCategory.drinks, name: "Чай чёрный", description: "Классический, крепкий", priceCredits: 160),
            .init(category: CafeMenuCategory.drinks, name: "Айс-латте", description: "Латте со льдом", priceCredits: 290)
        ]

        let food: [CafeProduct] = [
            .init(category: CafeMenuCategory.food, name: "Круассан классический", description: "Сливочное тесто, хрустящая корочка", priceCredits: 180),
            .init(category: CafeMenuCategory.food, name: "Круассан миндальный", description: "Миндальный крем и лепестки", priceCredits: 220),
            .init(category: CafeMenuCategory.food, name: "Синнабон", description: "Булочка с корицей и глазурью", priceCredits: 240),
            .init(category: CafeMenuCategory.food, name: "Чизкейк Нью-Йорк", description: "Нежный сырный десерт", priceCredits: 320),
            .init(category: CafeMenuCategory.food, name: "Брауни", description: "Шоколадный, влажный", priceCredits: 210),
            .init(category: CafeMenuCategory.food, name: "Сэндвич с курицей", description: "Курица, соус, салат, хлеб", priceCredits: 360),
            .init(category: CafeMenuCategory.food, name: "Сэндвич с лососем", description: "Лосось, сливочный сыр, зелень", priceCredits: 420),
            .init(category: CafeMenuCategory.food, name: "Овсянка ягодная", description: "Овсянка + ягоды + мёд", priceCredits: 280),
            .init(category: CafeMenuCategory.food, name: "Йогурт с гранолой", description: "Йогурт, гранола, фрукты", priceCredits: 260),
            .init(category: CafeMenuCategory.food, name: "Маффин шоколадный", description: "С кусочками шоколада", priceCredits: 190)
        ]

        let syrups: [CafeProduct] = [
            .init(category: CafeMenuCategory.syrups, name: "Ваниль", description: "Добавка к напитку (1 порция)", priceCredits: 40),
            .init(category: CafeMenuCategory.syrups, name: "Карамель", description: "Добавка к напитку (1 порция)", priceCredits: 40),
            .init(category: CafeMenuCategory.syrups, name: "Лесной орех", description: "Добавка к напитку (1 порция)", priceCredits: 40),
            .init(category: CafeMenuCategory.syrups, name: "Шоколад", description: "Добавка к напитку (1 порция)", priceCredits: 45),
            .init(category: CafeMenuCategory.syrups, name: "Кокос", description: "Добавка к напитку (1 порция)", priceCredits: 45),
            .init(category: CafeMenuCategory.syrups, name: "Мята", description: "Добавка к напитку (1 порция)", priceCredits: 45),
            .init(category: CafeMenuCategory.syrups, name: "Корица", description: "Добавка к напитку (1 порция)", priceCredits: 35),
            .init(category: CafeMenuCategory.syrups, name: "Имбирь", description: "Добавка к напитку (1 порция)", priceCredits: 35),
            .init(category: CafeMenuCategory.syrups, name: "Солёная карамель", description: "Добавка к напитку (1 порция)", priceCredits: 50),
            .init(category: CafeMenuCategory.syrups, name: "Кленовый", description: "Добавка к напитку (1 порция)", priceCredits: 50)
        ]

        let merch: [CafeProduct] = [
            .init(category: CafeMenuCategory.merch, name: "Кружка брендированная", description: "Керамика, 350 мл", priceCredits: 550),
            .init(category: CafeMenuCategory.merch, name: "Термокружка", description: "Держит тепло 4–6 часов", priceCredits: 890),
            .init(category: CafeMenuCategory.merch, name: "Футболка Coffee Club", description: "Хлопок, унисекс", priceCredits: 990),
            .init(category: CafeMenuCategory.merch, name: "Худи Coffee Club", description: "Плотный материал, oversize", priceCredits: 1790),
            .init(category: CafeMenuCategory.merch, name: "Кепка с логотипом", description: "Регулируемый ремешок", priceCredits: 690),
            .init(category: CafeMenuCategory.merch, name: "Шоппер", description: "Плотная ткань, длинные ручки", priceCredits: 520),
            .init(category: CafeMenuCategory.merch, name: "Набор стикеров", description: "10 шт, водостойкие", priceCredits: 190),
            .init(category: CafeMenuCategory.merch, name: "Пин металлический", description: "Эмаль, фирменный дизайн", priceCredits: 240),
            .init(category: CafeMenuCategory.merch, name: "Дрип-пакеты (10 шт)", description: "Кофе для заваривания дома", priceCredits: 760),
            .init(category: CafeMenuCategory.merch, name: "Зёрна 250 г", description: "Фирменная обжарка", priceCredits: 980)
        ]

        return CafeMenu(drinks: drinks, food: food, syrups: syrups, merch: merch)
    }
}
