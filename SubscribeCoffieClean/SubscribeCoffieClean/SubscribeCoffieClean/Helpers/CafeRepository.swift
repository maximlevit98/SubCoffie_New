import Foundation

struct CafeRepository {
    private let apiClient: SupabaseAPIClient
    private let menuService: SupabaseMenuService

    init(apiClient: SupabaseAPIClient = SupabaseAPIClient()) {
        self.apiClient = apiClient
        self.menuService = SupabaseMenuService(apiClient: apiClient)
    }

    func fetchCafes() async -> CafeFetchResult {
        do {
            let cafes: [SupabaseCafeDTO] = try await apiClient.get(
                "cafes",
                queryItems: [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "distance_km.asc")
                ]
            )
            let mapped = cafes.compactMap { $0.asDomain() }
            AppLogger.debug("Supabase OK: cafes \(mapped.count)")
            return CafeFetchResult(cafes: mapped, usedFallback: false)
        } catch {
            AppLogger.debug("Не удалось получить кафе из Supabase: \(error.localizedDescription)")
            return CafeFetchResult(cafes: [], usedFallback: true)
        }
    }

    func fetchMenu(cafeId: UUID) async -> CafeMenu {
        let result = await fetchMenuResult(cafeId: cafeId)
        return result.menu
    }

    func fetchMenuResult(cafeId: UUID) async -> MenuFetchResult {
        do {
            let menu = try await menuService.fetchMenu(cafeId: cafeId)
            if !menu.hasContent {
                AppLogger.debug("Supabase menu_items OK, but empty for cafe \(cafeId.uuidString)")
            }
            return MenuFetchResult(menu: menu, schemaMissing: false)
        } catch {
            if case NetworkError.httpStatus(let code, let body) = error, code == 404, isMenuSchemaMissing(body) {
                #if DEBUG
                print("Menu schema missing (menu_items 404)")
                #endif
                return MenuFetchResult(menu: CafeMenu(drinks: [], food: [], syrups: [], merch: []), schemaMissing: true)
            }
            #if DEBUG
            print("Menu fetch failed: \(error.localizedDescription)")
            #endif
            return MenuFetchResult(menu: CafeMenu(drinks: [], food: [], syrups: [], merch: []), schemaMissing: false)
        }
    }

    func selfTest() async -> Bool {
        do {
            let _: [SupabaseIdProbe] = try await apiClient.get(
                "cafes",
                queryItems: [
                    URLQueryItem(name: "select", value: "id"),
                    URLQueryItem(name: "limit", value: "1")
                ]
            )
            AppLogger.debug("Supabase OK")
            return true
        } catch {
            AppLogger.debug("Supabase fallback: \(error.localizedDescription)")
            return false
        }
    }
}

private extension CafeMenu {
    var hasContent: Bool {
        !drinks.isEmpty || !food.isEmpty || !syrups.isEmpty || !merch.isEmpty
    }
}

private struct SupabaseIdProbe: Decodable {
    let id: UUID
}

private func isMenuSchemaMissing(_ body: String?) -> Bool {
    guard let body, !body.isEmpty else { return false }
    let normalized = body.lowercased()
    return normalized.contains("menu_items")
        && (normalized.contains("schema cache") || normalized.contains("could not find"))
}

struct MenuFetchResult {
    let menu: CafeMenu
    let schemaMissing: Bool
}

struct CafeFetchResult {
    let cafes: [CafeSummary]
    let usedFallback: Bool
}
