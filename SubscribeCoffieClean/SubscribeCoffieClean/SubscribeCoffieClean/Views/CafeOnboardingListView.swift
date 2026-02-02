import SwiftUI

struct CafeOnboardingListView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var requests: [CafeOnboardingRequest] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showOnboardingForm: Bool = false
    @State private var selectedRequest: CafeOnboardingRequest?
    
    private let service = CafeOnboardingService()
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Загрузка...")
                } else if let error = errorMessage {
                    errorView(error)
                } else if requests.isEmpty {
                    emptyView
                } else {
                    requestsList
                }
            }
            .navigationTitle("Мои заявки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showOnboardingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showOnboardingForm) {
                CafeOnboardingFormView()
            }
            .sheet(item: $selectedRequest) { request in
                CafeOnboardingDetailView(request: request, onUpdate: {
                    loadRequests()
                })
            }
            .task {
                await loadRequestsAsync()
            }
            .refreshable {
                await loadRequestsAsync()
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Нет заявок")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Хотите подключить своё кафе к платформе?")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Создать заявку") {
                showOnboardingForm = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
    }
    
    private var requestsList: some View {
        List {
            ForEach(requests) { request in
                Button {
                    selectedRequest = request
                } label: {
                    CafeOnboardingRequestRow(request: request)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Ошибка загрузки")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Повторить") {
                loadRequests()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func loadRequests() {
        Task {
            await loadRequestsAsync()
        }
    }
    
    private func loadRequestsAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedRequests = try await service.getMyRequests()
            await MainActor.run {
                self.requests = fetchedRequests
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct CafeOnboardingRequestRow: View {
    let request: CafeOnboardingRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.cafeName)
                    .font(.headline)
                Spacer()
                statusBadge
            }
            
            Text(request.cafeAddress)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label(request.cafePhone, systemImage: "phone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formattedDate(request.submittedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusBadge: some View {
        Text(request.status.titleRu)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    CafeOnboardingListView()
}
