import Supabase

enum SupabaseClientProvider {
    static let client: SupabaseClient = {
        let options = SupabaseClientOptions(
            auth: .init(
                storage: AuthClient.Configuration.defaultLocalStorage,
                emitLocalSessionAsInitialSession: true
            )
        )
        return SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }()
}
