import SwiftUI

struct EmailLoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSignUpMode: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showPasswordReset: Bool = false
    
    // Callback for successful authentication
    var onAuthSuccess: () -> Void
    
    var body: some View {
            VStack(spacing: 24) {
                // Header
            Text(isSignUpMode ? "Регистрация" : "Вход")
                .font(.title2)
                        .fontWeight(.bold)
                    
            Text(isSignUpMode ? "Создайте аккаунт для заказа кофе" : "Войдите в свой аккаунт")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
            
            // Email input
            TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // Password input
            SecureField("Пароль", text: $password)
                            .textContentType(isSignUpMode ? .newPassword : .password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // Confirm password (only for sign up)
            if isSignUpMode {
                SecureField("Подтвердите пароль", text: $confirmPassword)
                                .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // Main action button
            Button(action: handleMainAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text(isSignUpMode ? "Зарегистрироваться" : "Войти")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(isFormValid ? Color.blue : Color.gray)
            .cornerRadius(10)
            .disabled(!isFormValid || isLoading)
            
            // Forgot password (only for sign in)
            if !isSignUpMode {
                Button(action: { showPasswordReset = true }) {
                    Text("Забыли пароль?")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // Toggle sign up / sign in
            HStack {
                Text(isSignUpMode ? "Уже есть аккаунт?" : "Нет аккаунта?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                        isSignUpMode.toggle()
                        errorMessage = nil
                    confirmPassword = ""
                }) {
                    Text(isSignUpMode ? "Войти" : "Создать аккаунт")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
                    .padding()
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView()
                .environmentObject(authService)
        }
    }
    
    // MARK: - Actions
    
    private func handleMainAction() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                if isSignUpMode {
                    try await authService.signUpWithEmail(email: email, password: password)
                } else {
                    try await authService.signInWithEmail(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                    onAuthSuccess()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        
        if isSignUpMode {
            return emailValid && passwordValid && password == confirmPassword
        } else {
            return emailValid && passwordValid
        }
    }
}

// MARK: - Password Reset View

struct PasswordResetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Сброс пароля")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Введите email для получения ссылки сброса пароля")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                if let successMessage = successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: sendResetEmail) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Отправить ссылку")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(email.contains("@") ? Color.blue : Color.gray)
                .cornerRadius(10)
                .disabled(!email.contains("@") || isLoading)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendResetEmail() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await authService.sendPasswordResetEmail(email: email)
                await MainActor.run {
                    successMessage = "Ссылка отправлена на \(email)"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось отправить: \(error.localizedDescription)"
                    isLoading = false
                }
                }
            }
        }
    }
    
#Preview {
    EmailLoginView {
        print("Auth success")
    }
    .environmentObject(AuthService.shared)
}
