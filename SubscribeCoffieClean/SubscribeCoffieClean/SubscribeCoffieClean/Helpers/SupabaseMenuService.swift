import Foundation

struct SupabaseMenuService {
    private let apiClient: SupabaseAPIClient

    init(apiClient: SupabaseAPIClient = SupabaseAPIClient()) {
        self.apiClient = apiClient
    }

    func fetchMenu(cafeId: UUID) async throws -> CafeMenu {
        print("🔍 [MENU DEBUG] ===== НАЧАЛО ЗАПРОСА МЕНЮ =====")
        print("🔍 [MENU DEBUG] Cafe ID: \(cafeId.uuidString)")
        print("🔍 [MENU DEBUG] URL будет: http://127.0.0.1:54321/rest/v1/menu_items?cafe_id=eq.\(cafeId.uuidString)")
        
        AppLogger.debug("Fetching menu_items for cafe \(cafeId.uuidString)")
        menuDebugLog(
            hypothesisId: "H1",
            location: "SupabaseMenuService.fetchMenu:entry",
            message: "Fetch menu_items",
            data: ["cafeId": cafeId.uuidString]
        )
        
        let items: [SupabaseMenuItemDTO] = try await apiClient.get(
            "menu_items",
            queryItems: [
                URLQueryItem(
                    name: "select",
                    value: "id,cafe_id,category,title,name,description,price_credits,sort_order,is_available,prep_time_sec"
                ),
                URLQueryItem(name: "cafe_id", value: "eq.\(cafeId.uuidString)"),
                URLQueryItem(name: "order", value: "category.asc,sort_order.asc")
            ]
        )

        print("🔍 [MENU DEBUG] Получено items: \(items.count)")
        print("🔍 [MENU DEBUG] Items: \(items.map { "[\($0.id?.uuidString ?? "nil")] \($0.name ?? "nil")" })")
        
        let menu = SupabaseMenuMapper.buildMenu(from: items)
        
        print("🔍 [MENU DEBUG] После buildMenu - drinks: \(menu.drinks.count), food: \(menu.food.count)")
        print("🔍 [MENU DEBUG] ===== КОНЕЦ ЗАПРОСА МЕНЮ =====")
        
        AppLogger.debug("Loaded menu items from Supabase: \(items.count)")
        menuDebugLog(
            hypothesisId: "H2",
            location: "SupabaseMenuService.fetchMenu:decoded",
            message: "Decoded menu_items",
            data: ["count": items.count]
        )
        return menu
    }
}
