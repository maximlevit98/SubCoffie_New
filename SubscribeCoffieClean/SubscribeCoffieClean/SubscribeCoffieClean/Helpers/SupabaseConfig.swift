import Foundation

struct SupabaseConfig {
    // DEV ONLY, потом перенесём в безопасный конфиг
    static let url: URL = {
        let base = EnvironmentConfig.supabaseBaseURLString
        if let resolved = URL(string: base) {
            return resolved
        }
        return URL(string: "http://127.0.0.1:54321")!
    }()

    static let anonKey: String = EnvironmentConfig.supabaseAnonKeyString

    /// REST база. Для симулятора подходит 127.0.0.1, для реального устройства нужно указать IP Mac.
    static var restBaseURL: URL {
        url.appendingPathComponent("rest/v1")
    }

    static let requestTimeout: TimeInterval = 20
}
