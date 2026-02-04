import SwiftUI
import AuthenticationServices

struct AuthContainerView: View {
    @StateObject private var authService = AuthService.shared
    @State private var selectedAuthMethod: AuthMethod = .email
    @State private var showProfileSetup: Bool = false
    @State private var needsProfileSetup: Bool = false
    
    enum AuthMethod: String, CaseIterable {
        case email = "Email"
        case phone = "Телефон"
    }
    
    var body: some View {
            ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
                ScrollView {
                VStack(spacing: 32) {
                    // App Logo/Title
                    VStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 60))
                                .foregroundColor(.brown)
                            
                            Text("SubscribeCoffie")
                            .font(.title)
                                .fontWeight(.bold)
                            
                        Text("Кофе по подписке")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    .padding(.top, 60)
                        
                    // Auth method selector
                    Picker("Метод входа", selection: $selectedAuthMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                            
                    // Auth forms
                    VStack(spacing: 20) {
                        if selectedAuthMethod == .email {
                            EmailLoginView {
                                handleAuthSuccess()
                            }
                            .environmentObject(authService)
                        } else {
                            PhoneLoginView {
                                handleAuthSuccess()
                            }
                            .environmentObject(authService)
                        }
                        }
                        .padding(.horizontal)
                        
                        // Divider
                    HStack {
                            Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("или")
                            .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                    .padding(.horizontal, 32)
                        
                    // OAuth buttons
                    VStack(spacing: 16) {
                        // Sign in with Apple
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                        )
                        .frame(height: 50)
                        .cornerRadius(10)
                        .padding(.horizontal, 32)
                        
                        // Sign in with Google
                        Button(action: {
                            Task {
                                do {
                                    try await authService.signInWithGoogle()
                                } catch {
                                    print("Google sign in failed: \(error)")
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.title3)
                                Text("Войти через Google")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Terms and privacy
                        VStack(spacing: 8) {
                        Text("Продолжая, вы принимаете")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                            Button("Условия использования") {
                                // TODO: Open terms
                            }
                                        .font(.caption)
                                
                                Text("и")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                            Button("Политику конфиденциальности") {
                                // TODO: Open privacy policy
                            }
                            .font(.caption)
                            }
                        }
                    .padding(.bottom, 32)
                    }
                }
        }
        .sheet(isPresented: $showProfileSetup) {
            ProfileSetupView {
                showProfileSetup = false
                // Profile is now complete, authService will update
            }
            .environmentObject(authService)
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                // Check if profile needs setup
                        Task {
                    await authService.fetchUserProfile()
                    if let profile = authService.userProfile {
                        let needsSetup = profile.fullName == nil || profile.fullName?.isEmpty == true
                        await MainActor.run {
                            if needsSetup {
                                showProfileSetup = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Handlers
    
    private func handleAuthSuccess() {
        // Check if profile needs setup
        Task {
            await authService.fetchUserProfile()
                await MainActor.run {
                if let profile = authService.userProfile {
                    let needsSetup = profile.fullName == nil || profile.fullName?.isEmpty == true
                    if needsSetup {
                    showProfileSetup = true
                }
            }
        }
    }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
                switch result {
                case .success(let authorization):
                do {
                    try await authService.signInWithApple(authorization: authorization)
                        handleAuthSuccess()
            } catch {
                    print("Apple sign in failed: \(error)")
                }
                
            case .failure(let error):
                print("Apple authorization failed: \(error)")
            }
        }
    }
}

#Preview {
    AuthContainerView()
}
