import Foundation

/// Application environment configuration
enum AppEnvironment: String {
    case development
    case staging
    case production
    
    /// Current environment based on build configuration
    static var current: AppEnvironment {
        #if DEBUG
        // In debug builds, check for override from UserDefaults
        if let envString = UserDefaults.standard.string(forKey: "sc_environment"),
           let env = AppEnvironment(rawValue: envString) {
            return env
        }
        return .development
        #else
        // Production builds always use production environment
        return .production
        #endif
    }
    
    var name: String {
        switch self {
        case .development: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }
    
    var isProduction: Bool {
        return self == .production
    }
}

/// Environment-specific configuration
enum EnvironmentConfig {
    
    // MARK: - Supabase Configuration
    
    /// Supabase project URL
    static var supabaseBaseURLString: String {
        // Allow manual override via UserDefaults (for testing)
        if let custom = UserDefaults.standard.string(forKey: "sc_supabase_base_url"), !custom.isEmpty {
            return custom
        }
        
        switch AppEnvironment.current {
        case .development:
            // Local Supabase instance
            // For real device testing, replace with Mac's IP: http://192.168.X.X:54321
            return "http://127.0.0.1:54321"
            
        case .staging:
            // TODO: Replace with your staging project URL when ready
            return "https://your-staging-ref.supabase.co"
            
        case .production:
            // TODO: Replace with your production project URL
            // Get this from: https://app.supabase.com → Your Project → Settings → API
            return "https://your-production-ref.supabase.co"
        }
    }
    
    /// Supabase anonymous (public) key
    static var supabaseAnonKeyString: String {
        // Allow manual override via UserDefaults (for testing)
        if let custom = UserDefaults.standard.string(forKey: "sc_supabase_anon_key"), !custom.isEmpty {
            return custom
        }
        
        switch AppEnvironment.current {
        case .development:
            // Local Supabase anon key (default from supabase start)
            return "eyJhbGciOiJFUzI1NiIsImtpZCI6ImI4MTI2OWYxLTIxZDgtNGYyZS1iNzE5LWMyMjQwYTg0MGQ5MCIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjIwODUxMjQwNzB9.56-YVSqsoeDSxQF8l97Kdap-0RuohlPdmp36jfrHjT50g-WLMqW3bQAdS0I04IqC7O88dMv561gMQ_LfY-SZkQ"
            
        case .staging:
            // TODO: Replace with your staging anon key
            return "your-staging-anon-key"
            
        case .production:
            // TODO: Replace with your production anon key
            // Get this from: https://app.supabase.com → Your Project → Settings → API
            // This key is safe to use in the app (it only allows operations permitted by RLS policies)
            return "your-production-anon-key"
        }
    }
    
    // MARK: - Feature Flags
    
    /// Enable debug logging
    static var enableDebugLogging: Bool {
        return !AppEnvironment.current.isProduction
    }
    
    /// Enable mock payments (set to true until real payment integration)
    static var enableMockPayments: Bool {
        switch AppEnvironment.current {
        case .development, .staging:
            return true
        case .production:
            // TODO: Set to false when real payments are integrated
            return true
        }
    }
    
    /// API timeout in seconds
    static var apiTimeout: TimeInterval {
        return 30.0
    }
    
    /// Enable crash reporting (Sentry, etc)
    static var enableCrashReporting: Bool {
        return AppEnvironment.current.isProduction
    }
    
    /// Enable analytics tracking
    static var enableAnalytics: Bool {
        return AppEnvironment.current.isProduction
    }
    
    // MARK: - Manual Configuration (for testing)
    
    /// Set custom Supabase URL (for testing purposes only)
    static func setSupabaseBaseURL(_ urlString: String) {
        UserDefaults.standard.set(urlString, forKey: "sc_supabase_base_url")
        print("⚙️ Supabase URL overridden: \(urlString)")
    }
    
    /// Set custom Supabase anon key (for testing purposes only)
    static func setSupabaseAnonKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "sc_supabase_anon_key")
        print("⚙️ Supabase anon key overridden")
    }
    
    /// Set environment override (debug builds only)
    static func setEnvironment(_ environment: AppEnvironment) {
        #if DEBUG
        UserDefaults.standard.set(environment.rawValue, forKey: "sc_environment")
        print("⚙️ Environment overridden: \(environment.name)")
        #else
        print("⚠️ Cannot override environment in production build")
        #endif
    }
    
    /// Reset all configuration overrides
    static func resetOverrides() {
        UserDefaults.standard.removeObject(forKey: "sc_supabase_base_url")
        UserDefaults.standard.removeObject(forKey: "sc_supabase_anon_key")
        UserDefaults.standard.removeObject(forKey: "sc_environment")
        print("⚙️ Configuration overrides reset")
    }
    
    /// Print current configuration (for debugging)
    static func printCurrentConfiguration() {
        print("""
        
        ╔═══════════════════════════════════════════╗
        ║     SubscribeCoffie Configuration         ║
        ╚═══════════════════════════════════════════╝
        
        Environment: \(AppEnvironment.current.name)
        Supabase URL: \(supabaseBaseURLString)
        Debug Logging: \(enableDebugLogging)
        Mock Payments: \(enableMockPayments)
        Crash Reporting: \(enableCrashReporting)
        Analytics: \(enableAnalytics)
        
        ═══════════════════════════════════════════
        
        """)
    }
}
