import Foundation
import Supabase

private struct CafeIdRow: Decodable {
    let id: UUID
}

private struct MenuItemIdRow: Decodable {
    let id: UUID
}

func supabasePing() async -> Bool {
    do {
        let response: PostgrestResponse<[CafeIdRow]> = try await SupabaseClientProvider.client
            .from("cafes")
            .select("id")
            .limit(1)
            .execute()
        return !response.value.isEmpty
    } catch {
        print("Supabase ping failed: \(error.localizedDescription)")
        return false
    }
}

enum SupabaseMenuItemsSmokeResult {
    case ok
    case missingSchema
    case failed
}

func supabaseMenuItemsSmokeCheck() async -> SupabaseMenuItemsSmokeResult {
    let apiClient = SupabaseAPIClient()
    do {
        let _: [MenuItemIdRow] = try await apiClient.get(
            "menu_items",
            queryItems: [
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        return .ok
    } catch {
        if case NetworkError.httpStatus(let code, let body) = error, code == 404, isMenuSchemaMissing(body) {
            return .missingSchema
        }
        return .failed
    }
}

private func isMenuSchemaMissing(_ body: String?) -> Bool {
    guard let body, !body.isEmpty else { return false }
    let normalized = body.lowercased()
    return normalized.contains("menu_items")
        && (normalized.contains("schema cache") || normalized.contains("could not find"))
}
