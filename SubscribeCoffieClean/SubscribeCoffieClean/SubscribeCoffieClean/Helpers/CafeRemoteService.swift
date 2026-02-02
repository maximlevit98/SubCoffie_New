import Foundation
import Supabase
import Combine

@MainActor
class CafeRemoteService: ObservableObject {

    func fetchCafes() async throws -> [CafeSummary] {
        do {
            let response: PostgrestResponse<[SupabaseCafeDTO]> = try await SupabaseClientProvider.client
                .from("cafes")
                .select("*")
                .order("name")
                .execute()

#if DEBUG
            let data = response.data
            if let raw = String(data: data, encoding: .utf8) {
                print("DEBUG cafes raw: \(raw)")
            }
#endif

            let cafes = response.value.compactMap { $0.asDomain() }
            #if DEBUG
            print("Loaded cafes from Supabase: \(cafes.count)")
            #endif
            return cafes
        } catch {
            print("fetchCafes failed: \(error.localizedDescription)")
            throw error
        }
    }
}
