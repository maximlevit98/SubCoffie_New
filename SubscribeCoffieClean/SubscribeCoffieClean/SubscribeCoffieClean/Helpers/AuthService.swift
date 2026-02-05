import Foundation
import Combine
import Supabase
import AuthenticationServices
import SwiftUI

/// Authentication service that handles all auth methods: Email, OAuth (Google, Apple), and Phone
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClientProvider.client
    
    private init() {
        Task { @MainActor in
            await checkSession()
        }
    }
    
    // MARK: - Session Management
    
    @MainActor
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
            
            // Fetch user profile
            await fetchUserProfile()
        } catch {
            AppLogger.debug("No active session: \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
            userProfile = nil
        }
    }
    
    @MainActor
    func fetchUserProfile() async {
        guard currentUser != nil else { return }
        
        do {
            let response: UserProfile = try await supabase.rpc("get_my_profile").execute().value
            userProfile = response
            AppLogger.debug("✅ Fetched user profile: \(response.fullName ?? "Unknown")")
        } catch {
            AppLogger.error("Failed to fetch user profile: \(error.localizedDescription)")
            errorMessage = "Не удалось загрузить профиль"
        }
    }
    
    // MARK: - Email Authentication
    
    @MainActor
    func signUpWithEmail(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            currentUser = response.user
            isAuthenticated = response.session != nil
            
            AppLogger.debug("✅ Email sign up successful: \(email)")
            
            if isAuthenticated {
                await fetchUserProfile()
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Email sign up failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            currentUser = response.user
            isAuthenticated = true
            
            AppLogger.debug("✅ Email sign in successful: \(email)")
            
            await fetchUserProfile()
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Email sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func sendPasswordResetEmail(email: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            AppLogger.debug("✅ Password reset email sent to: \(email)")
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Phone Authentication
    
    @MainActor
    func signInWithPhone(phone: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signInWithOTP(phone: phone)
            AppLogger.debug("✅ SMS OTP sent to: \(phone)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Phone sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func verifyPhoneOTP(phone: String, token: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await supabase.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            
            currentUser = response.user
            isAuthenticated = response.session != nil
            
            AppLogger.debug("✅ Phone OTP verified: \(phone)")
            
            if isAuthenticated {
                await fetchUserProfile()
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Phone OTP verification failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - OAuth Authentication
    
    @MainActor
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let url = try await supabase.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: URL(string: "subscribecoffie://auth/callback")
            )
            
            AppLogger.debug("🔗 Opening Google OAuth URL")
            await openURL(url)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Google OAuth failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func signInWithApple(authorization: ASAuthorization) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }
        
        do {
            let response = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )
            
            currentUser = response.user
            isAuthenticated = true
            
            AppLogger.debug("✅ Apple sign in successful")
            
            if isAuthenticated {
            // Update profile with Apple ID data if available
            if let fullName = appleIDCredential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !name.isEmpty {
                    _ = try? await updateProfile(fullName: name)
                }
            }
            
            await fetchUserProfile()
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Apple sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func handleOAuthCallback(url: URL) async throws {
        // Handle OAuth callback from deep link
        do {
            try await supabase.auth.session(from: url)
            await checkSession()
            AppLogger.debug("✅ OAuth callback handled successfully")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("OAuth callback failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Profile Management
    
    /// Initialize user profile after signup (called after registration with full data)
    @MainActor
    func initializeProfile(
        fullName: String,
        phone: String?,
        birthDate: Date?,
        city: String = "Москва"
    ) async throws {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }
        
        do {
            var params: [String: AnyJSON] = [
                "p_full_name": AnyJSON.string(fullName),
                "p_city": AnyJSON.string(city)
            ]
            
            if let phone = phone {
                params["p_phone"] = AnyJSON.string(phone)
            }
            
            if let birthDate = birthDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                params["p_birth_date"] = AnyJSON.string(formatter.string(from: birthDate))
            }
            
            let response: UserProfile = try await supabase.rpc("init_user_profile", params: params).execute().value
            userProfile = response
            
            AppLogger.debug("✅ Profile initialized: \(fullName)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Profile initialization failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func updateProfile(
        fullName: String? = nil,
        phone: String? = nil,
        birthDate: Date? = nil,
        city: String? = nil,
        avatarURL: String? = nil
    ) async throws -> UserProfile {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }
        
        do {
            var params: [String: AnyJSON] = [:]
            
            if let fullName = fullName {
                params["p_full_name"] = AnyJSON.string(fullName)
            }
            if let phone = phone {
                params["p_phone"] = AnyJSON.string(phone)
            }
            if let birthDate = birthDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                params["p_birth_date"] = AnyJSON.string(formatter.string(from: birthDate))
            }
            if let city = city {
                params["p_city"] = AnyJSON.string(city)
            }
            if let avatarURL = avatarURL {
                params["p_avatar_url"] = AnyJSON.string(avatarURL)
            }
            
            let response: UserProfile = try await supabase.rpc("update_my_profile", params: params).execute().value
            userProfile = response
            
            AppLogger.debug("✅ Profile updated")
            return response
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Profile update failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    @MainActor
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signOut()
            currentUser = nil
            userProfile = nil
            isAuthenticated = false
            AppLogger.debug("✅ Signed out successfully")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Sign out failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func openURL(_ url: URL) async {
        await MainActor.run {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}

// MARK: - Models

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var email: String?
    var phone: String?
    var fullName: String?
    var avatarUrl: String?
    var birthDate: String?
    var city: String?
    var authProvider: String
    var role: String
    var defaultWalletType: String?
    var defaultCafeId: UUID?
    var createdAt: String
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case birthDate = "birth_date"
        case city
        case authProvider = "auth_provider"
        case role
        case defaultWalletType = "default_wallet_type"
        case defaultCafeId = "default_cafe_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredential
    case invalidToken
    case emailAlreadyExists
    case weakPassword
    case networkError
    case profileIncomplete
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Пожалуйста, войдите в систему"
        case .invalidCredential:
            return "Неверные учетные данные"
        case .invalidToken:
            return "Недействительный токен"
        case .emailAlreadyExists:
            return "Email уже зарегистрирован"
        case .weakPassword:
            return "Пароль слишком слабый (минимум 6 символов)"
        case .networkError:
            return "Ошибка сети. Проверьте подключение"
        case .profileIncomplete:
            return "Пожалуйста, заполните профиль"
        }
    }
}
