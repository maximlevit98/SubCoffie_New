import SwiftUI

struct CafeOnboardingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let request: CafeOnboardingRequest
    let onUpdate: () -> Void
    
    @State private var showCancelConfirmation: Bool = false
    @State private var isCancelling: Bool = false
    @State private var errorMessage: String?
    
    private let service = CafeOnboardingService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusSection
                    cafeInfoSection
                    businessInfoSection
                    
                    if request.status == .approved, let cafeId = request.createdCafeId {
                        approvedSection(cafeId: cafeId)
                    }
                    
                    if let comment = request.reviewComment {
                        reviewSection(comment: comment)
                    }
                    
                    if let reason = request.rejectionReason {
                        rejectionSection(reason: reason)
                    }
                    
                    if request.status == .pending {
                        cancelButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Детали заявки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Отменить заявку?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                Button("Отменить заявку", role: .destructive) {
                    cancelRequest()
                }
                Button("Не отменять", role: .cancel) { }
            } message: {
                Text("Эту операцию нельзя отменить. Вы сможете создать новую заявку позже.")
            }
            .disabled(isCancelling)
            .overlay {
                if isCancelling {
                    ProgressView("Отмена...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 50))
                .foregroundColor(statusColor)
            
            Text(request.status.titleRu)
                .font(.title2)
                .fontWeight(.semibold)
            
            if let submittedDate = formattedDate(request.submittedAt) {
                Text("Отправлено: \(submittedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let reviewedDate = request.reviewedAt, let formatted = formattedDate(reviewedDate) {
                Text("Рассмотрено: \(formatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var cafeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Информация о кафе")
                .font(.headline)
            
            InfoRow(label: "Название", value: request.cafeName)
            InfoRow(label: "Адрес", value: request.cafeAddress)
            InfoRow(label: "Телефон", value: request.cafePhone)
            InfoRow(label: "Email", value: request.cafeEmail)
            
            if let description = request.cafeDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Описание")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.body)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var businessInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Детали бизнеса")
                .font(.headline)
            
            if let businessType = request.businessType {
                InfoRow(label: "Тип бизнеса", value: businessType.titleRu)
            }
            
            InfoRow(label: "Документов загружено", value: "\(request.documentCount)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func approvedSection(cafeId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Заявка одобрена!")
                    .font(.headline)
            }
            
            Text("Ваше кафе создано и готово к настройке.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("ID кафе: \(cafeId.uuidString)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func reviewSection(comment: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Комментарий")
                .font(.headline)
            
            Text(comment)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func rejectionSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Причина отклонения")
                    .font(.headline)
            }
            
            Text(reason)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var cancelButton: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button("Отменить заявку") {
                showCancelConfirmation = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }
    
    private var statusIcon: String {
        switch request.status {
        case .pending: return "clock.fill"
        case .underReview: return "magnifyingglass.circle.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .underReview: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .cancelled: return .gray
        }
    }
    
    private func formattedDate(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func cancelRequest() {
        errorMessage = nil
        isCancelling = true
        
        Task {
            do {
                try await service.cancelRequest(requestId: request.id)
                
                await MainActor.run {
                    isCancelling = false
                    onUpdate()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCancelling = false
                    errorMessage = "Ошибка отмены: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

#Preview {
    CafeOnboardingDetailView(
        request: CafeOnboardingRequest(
            id: UUID(),
            status: .pending,
            cafeName: "Кофейня \"Уютная\"",
            cafeAddress: "ул. Пушкина, д. 10",
            cafePhone: "+7 (999) 123-45-67",
            cafeEmail: "info@cozy-cafe.ru",
            cafeDescription: "Уютная кофейня с авторским кофе и домашней выпечкой",
            businessType: .independent,
            submittedAt: Date(),
            reviewedAt: nil,
            reviewComment: nil,
            rejectionReason: nil,
            createdCafeId: nil,
            documentCount: 3
        ),
        onUpdate: {}
    )
}
