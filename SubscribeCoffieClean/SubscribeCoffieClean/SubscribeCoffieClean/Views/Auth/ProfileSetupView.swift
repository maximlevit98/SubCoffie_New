import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthService
    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var city: String = "Москва"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    // Callback for successful profile setup
    var onComplete: () -> Void
    
    // Available cities
    private let cities = ["Москва", "Санкт-Петербург", "Казань", "Нижний Новгород", "Екатеринбург", "Новосибирск"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Заполните профиль")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Это поможет нам обслуживать вас лучше")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // Full Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Имя и фамилия *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Иван Иванов", text: $fullName)
                        .textContentType(.name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Phone (optional if signed up with email)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Телефон")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text("+7")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                        
                        TextField("999 123 45 67", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .font(.body)
                            .padding(.vertical, 12)
                            .onChange(of: phone) { _, newValue in
                                phone = formatPhoneNumber(newValue)
                            }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // Birth Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Дата рождения *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker(
                        "Дата рождения",
                        selection: $birthDate,
                        in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // City
                VStack(alignment: .leading, spacing: 8) {
                    Text("Город *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Menu {
                        ForEach(cities, id: \.self) { cityOption in
                            Button(action: {
                                city = cityOption
                            }) {
                                HStack {
                                    Text(cityOption)
                                    if city == cityOption {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(city)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Save button
                Button(action: saveProfile) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Сохранить и продолжить")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(isFormValid ? Color.blue : Color.gray)
                .cornerRadius(10)
                .disabled(!isFormValid || isLoading)
                .padding(.top, 8)
                
                Text("* Обязательные поля")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .onAppear {
            // Pre-fill phone if authenticated via phone
            if let userProfile = authService.userProfile,
               let existingPhone = userProfile.phone {
                let digits = existingPhone.filter { $0.isNumber }
                if digits.hasPrefix("7") {
                    phone = formatPhoneNumber(String(digits.dropFirst()))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        let phoneToSave: String? = {
            let digits = phone.filter { $0.isNumber }
            return digits.count == 10 ? "+7\(digits)" : nil
        }()
        
        Task {
            do {
                try await authService.initializeProfile(
                    fullName: fullName,
                    phone: phoneToSave,
                    birthDate: birthDate,
                    city: city
                )
                
                await MainActor.run {
                    isLoading = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось сохранить профиль: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Helpers
    
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
    ProfileSetupView {
        print("Profile setup complete")
    }
    .environmentObject(AuthService.shared)
}
