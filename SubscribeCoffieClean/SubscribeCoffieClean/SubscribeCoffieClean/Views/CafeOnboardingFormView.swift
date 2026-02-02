import SwiftUI

struct CafeOnboardingFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var cafeName: String = ""
    @State private var cafeAddress: String = ""
    @State private var cafePhone: String = ""
    @State private var cafeEmail: String = ""
    @State private var cafeDescription: String = ""
    @State private var businessType: CafeBusinessType?
    @State private var openingHours: String = ""
    @State private var estimatedDailyOrders: String = ""
    
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    
    private let service = CafeOnboardingService()
    
    var body: some View {
        NavigationStack {
            Form {
                cafeInfoSection
                businessDetailsSection
                additionalInfoSection
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Подключить кафе")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Отправить") {
                        submitApplication()
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    ProgressView("Отправка заявки...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
            .alert("Заявка отправлена!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Ваша заявка на подключение кафе отправлена. Мы свяжемся с вами в ближайшее время.")
            }
        }
    }
    
    private var cafeInfoSection: some View {
        Section {
            TextField("Название кафе", text: $cafeName)
                .textContentType(.organizationName)
            
            TextField("Адрес", text: $cafeAddress)
                .textContentType(.fullStreetAddress)
            
            TextField("Телефон", text: $cafePhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            
            TextField("Email", text: $cafeEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
        } header: {
            Text("Основная информация")
        } footer: {
            Text("Укажите название, адрес и контактные данные вашего кафе")
        }
    }
    
    private var businessDetailsSection: some View {
        Section {
            Picker("Тип бизнеса", selection: $businessType) {
                Text("Не выбрано").tag(nil as CafeBusinessType?)
                ForEach(CafeBusinessType.allCases, id: \.self) { type in
                    Text(type.titleRu).tag(type as CafeBusinessType?)
                }
            }
            
            TextField("Часы работы", text: $openingHours)
                .textContentType(.none)
            
            TextField("Ожидаемое кол-во заказов в день", text: $estimatedDailyOrders)
                .keyboardType(.numberPad)
        } header: {
            Text("Детали бизнеса")
        } footer: {
            Text("Эта информация поможет нам лучше понять ваш бизнес")
        }
    }
    
    private var additionalInfoSection: some View {
        Section {
            TextEditor(text: $cafeDescription)
                .frame(minHeight: 100)
        } header: {
            Text("Описание кафе (необязательно)")
        } footer: {
            Text("Расскажите о вашем кафе: концепция, меню, особенности")
        }
    }
    
    private var isFormValid: Bool {
        !cafeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cafeAddress.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cafePhone.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cafeEmail.trimmingCharacters(in: .whitespaces).isEmpty &&
        cafeEmail.contains("@")
    }
    
    private func submitApplication() {
        errorMessage = nil
        isSubmitting = true
        
        let estimatedOrders: Int? = {
            guard !estimatedDailyOrders.isEmpty else { return nil }
            return Int(estimatedDailyOrders)
        }()
        
        Task {
            do {
                _ = try await service.submitApplication(
                    cafeName: cafeName.trimmingCharacters(in: .whitespaces),
                    cafeAddress: cafeAddress.trimmingCharacters(in: .whitespaces),
                    cafePhone: cafePhone.trimmingCharacters(in: .whitespaces),
                    cafeEmail: cafeEmail.trimmingCharacters(in: .whitespaces),
                    cafeDescription: cafeDescription.isEmpty ? nil : cafeDescription.trimmingCharacters(in: .whitespaces),
                    businessType: businessType,
                    openingHours: openingHours.isEmpty ? nil : openingHours.trimmingCharacters(in: .whitespaces),
                    estimatedDailyOrders: estimatedOrders
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                    AppLogger.debug("Cafe onboarding application submitted successfully")
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Ошибка отправки заявки: \(error.localizedDescription)"
                    AppLogger.debug("Failed to submit cafe onboarding: \(error)")
                }
            }
        }
    }
}

#Preview {
    CafeOnboardingFormView()
}
