import SwiftUI

struct PhoneLoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var phoneNumber: String = ""
    @State private var otpCode: String = ""
    @State private var isOTPSent: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    // Callback for successful authentication (to show profile setup if needed)
    var onAuthSuccess: () -> Void
    
    var body: some View {
            VStack(spacing: 24) {
            if !isOTPSent {
                // Phone input screen
                phoneInputView
                } else {
                // OTP verification screen
                otpVerificationView
            }
            }
        .padding()
    }
    
    // MARK: - Phone Input View
    
    private var phoneInputView: some View {
        VStack(spacing: 20) {
            Text("Вход по телефону")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Введите номер телефона для получения кода")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Phone input
            HStack(spacing: 8) {
                Text("+7")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
                
                TextField("999 123 45 67", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.body)
                    .padding(.vertical, 12)
                    .onChange(of: phoneNumber) { _, newValue in
                        // Format phone number as user types
                        phoneNumber = formatPhoneNumber(newValue)
                    }
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: sendOTP) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Получить код")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(isPhoneValid ? Color.blue : Color.gray)
            .cornerRadius(10)
            .disabled(!isPhoneValid || isLoading)
            
            #if DEBUG
            Text("Тестовые номера: +79991234567 или +79991234568\nКод: 123456 или 654321")
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.top)
            #endif
        }
    }
    
    // MARK: - OTP Verification View
    
    private var otpVerificationView: some View {
        VStack(spacing: 20) {
            Text("Введите код")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Код отправлен на номер\n+7\(phoneNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // OTP input
            TextField("Код из SMS", text: $otpCode)
                .keyboardType(.numberPad)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .onChange(of: otpCode) { _, newValue in
                    // Auto-verify when 6 digits entered
                    if newValue.count == 6 {
                        Task {
                            await verifyOTP()
                    }
                }
                }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await verifyOTP()
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Подтвердить")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(otpCode.count == 6 ? Color.blue : Color.gray)
            .cornerRadius(10)
            .disabled(otpCode.count != 6 || isLoading)
            
            Button(action: {
                isOTPSent = false
                otpCode = ""
                errorMessage = nil
            }) {
                Text("Изменить номер")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Actions
    
    private func sendOTP() {
        guard isPhoneValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        let fullPhone = "+7\(phoneNumber.filter { $0.isNumber })"
        
        Task {
            do {
                try await authService.signInWithPhone(phone: fullPhone)
                await MainActor.run {
                    isOTPSent = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось отправить код: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyOTP() async {
        isLoading = true
        errorMessage = nil
        
        let fullPhone = "+7\(phoneNumber.filter { $0.isNumber })"
        
            do {
            try await authService.verifyPhoneOTP(phone: fullPhone, token: otpCode)
                await MainActor.run {
                    isLoading = false
                onAuthSuccess()
                }
            } catch {
                await MainActor.run {
                errorMessage = "Неверный код. Попробуйте еще раз"
                    isLoading = false
                    otpCode = ""
                }
            }
    }
    
    // MARK: - Helpers
    
    private var isPhoneValid: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        return digits.count == 10
    }
    
    private func formatPhoneNumber(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let limited = String(digits.prefix(10))
        
        var formatted = ""
        for (index, char) in limited.enumerated() {
            if index == 3 || index == 6 || index == 8 {
                formatted += " "
            }
            formatted.append(char)
        }
        return formatted
        }
    }

#Preview {
    PhoneLoginView {
        print("Auth success")
    }
    .environmentObject(AuthService.shared)
}
