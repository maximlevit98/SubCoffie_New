import SwiftUI

/// Settings view for couriers
struct CourierSettingsView: View {
    let courierId: UUID
    @Binding var currentStatus: CourierStatus
    
    @State private var courierInfo: CourierInfo?
    @State private var isLoading = true
    @State private var selectedVehicle: VehicleType = .bicycle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let info = courierInfo {
                    profileSection(info: info)
                    statusSection
                    vehicleSection
                    statisticsSection(info: info)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadCourierInfo()
            }
        }
    }
    
    private func profileSection(info: CourierInfo) -> some View {
        Section("Профиль") {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.fullName)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(info.rating.rounded()) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", info.rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if info.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                }
            }
            
            LabeledContent("Телефон", value: info.phone)
            if let email = info.email {
                LabeledContent("Email", value: email)
            }
        }
    }
    
    private var statusSection: some View {
        Section("Статус") {
            Picker("Текущий статус", selection: $currentStatus) {
                Text(CourierStatus.available.displayName).tag(CourierStatus.available)
                Text(CourierStatus.busy.displayName).tag(CourierStatus.busy)
                Text(CourierStatus.onBreak.displayName).tag(CourierStatus.onBreak)
                Text(CourierStatus.offline.displayName).tag(CourierStatus.offline)
            }
            .pickerStyle(.menu)
        }
    }
    
    private var vehicleSection: some View {
        Section("Транспорт") {
            Picker("Тип транспорта", selection: $selectedVehicle) {
                ForEach(VehicleType.allCases, id: \.self) { vehicle in
                    HStack {
                        Image(systemName: vehicle.icon)
                        Text(vehicle.displayName)
                    }
                    .tag(vehicle)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private func statisticsSection(info: CourierInfo) -> some View {
        Section("Статистика") {
            LabeledContent("Всего доставок", value: "\(info.totalDeliveries)")
            LabeledContent("Успешных", value: "\(info.completedDeliveries)")
            
            if info.failedDeliveries > 0 {
                LabeledContent("Неудачных", value: "\(info.failedDeliveries)")
                    .foregroundColor(.red)
            }
            
            if info.totalDeliveries > 0 {
                let successRate = Double(info.completedDeliveries) / Double(info.totalDeliveries) * 100
                LabeledContent("Процент успеха", value: String(format: "%.1f%%", successRate))
                    .foregroundColor(.green)
            }
        }
    }
    
    private func loadCourierInfo() async {
        // Simulate loading courier info
        // In production, this would fetch from the API
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            self.courierInfo = CourierInfo(
                id: courierId,
                fullName: "Курьер",
                phone: "+7 (900) 123-45-67",
                email: "courier@example.com",
                vehicleType: .bicycle,
                rating: 4.8,
                totalDeliveries: 245,
                completedDeliveries: 238,
                failedDeliveries: 7,
                isVerified: true
            )
            self.selectedVehicle = courierInfo?.vehicleType ?? .bicycle
            self.isLoading = false
        }
    }
}

// MARK: - Courier Info Model

struct CourierInfo {
    let id: UUID
    let fullName: String
    let phone: String
    let email: String?
    let vehicleType: VehicleType
    let rating: Double
    let totalDeliveries: Int
    let completedDeliveries: Int
    let failedDeliveries: Int
    let isVerified: Bool
}

// MARK: - Preview

struct CourierSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CourierSettingsView(
            courierId: UUID(),
            currentStatus: .constant(.available)
        )
    }
}
