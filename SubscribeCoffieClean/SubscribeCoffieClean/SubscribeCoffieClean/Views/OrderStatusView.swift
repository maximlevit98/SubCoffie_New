//
//  OrderStatusView.swift
//  SubscribeCoffieClean
//
//  Real-time order status with data from Supabase
//

import SwiftUI
import Auth
import Combine

struct OrderStatusView: View {
    let orderId: UUID
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = OrderStatusViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.orderDetails == nil {
                loadingView
            } else if let orderDetails = viewModel.orderDetails {
                orderDetailsView(orderDetails)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            }
        }
        .task {
            await viewModel.loadOrderDetails(orderId: orderId)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Загрузка статуса заказа...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
            
            Text("Ошибка загрузки")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Попробовать снова") {
                Task {
                    await viewModel.loadOrderDetails(orderId: orderId)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Order Details View
    
    private func orderDetailsView(_ details: OrderDetails) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Icon
                statusIcon(details.order.status)
                
                // Order Number
                VStack(spacing: 8) {
                    Text("Заказ #\(details.order.orderNumber)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    statusText(details.order.status)
                }
                
                // Order Info Card
                orderInfoCard(details.order)
                
                // Items List
                if !details.items.isEmpty {
                    itemsCard(details.items)
                }
                
                // Timeline
                if !details.events.isEmpty {
                    timelineCard(details.events)
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
    }
    
    // MARK: - Status Icon
    
    private func statusIcon(_ status: String) -> some View {
        Group {
            switch status.lowercased() {
            case "pending":
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            case "preparing":
                Image(systemName: "flame.fill")
                    .foregroundColor(.blue)
            case "ready":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case "completed", "issued":
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            case "cancelled":
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            default:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 80))
    }
    
    private func statusText(_ status: String) -> some View {
        Text(localizedStatus(status))
            .font(.title2)
            .foregroundColor(statusColor(status))
    }
    
    // MARK: - Order Info Card
    
    private func orderInfoCard(_ order: OrderInfo) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Информация о заказе")
                    .font(.headline)
                Spacer()
            }
            
            infoRow(label: "Сумма", value: "\(order.totalCredits) ₽")
            
            if let cafeName = order.cafeName {
                infoRow(label: "Кофейня", value: cafeName)
            }
            
            if let paymentMethod = order.paymentMethod {
                infoRow(label: "Оплата", value: localizedPaymentMethod(paymentMethod))
            }
            
            infoRow(label: "Дата", value: formatDate(order.createdAt))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Items Card
    
    private func itemsCard(_ items: [OrderItem]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Состав заказа")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(items) { item in
                HStack {
                    Text("\(item.quantity)x")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    Text(item.title)
                        .font(.body)
                    
                    Spacer()
                    
                    Text("\(item.lineTotal) ₽")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Timeline Card
    
    private func timelineCard(_ events: [OrderEvent]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("История статусов")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline indicator
                    VStack(spacing: 0) {
                        Circle()
                            .fill(statusColor(event.status))
                            .frame(width: 12, height: 12)
                        
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 12)
                    
                    // Event info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedStatus(event.status))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(formatDate(event.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(minHeight: 40)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "pending":
            return .orange
        case "preparing":
            return .blue
        case "ready":
            return .green
        case "completed", "issued":
            return .green
        case "cancelled":
            return .red
        default:
            return .gray
        }
    }
    
    private func localizedStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "pending":
            return "Ожидает подтверждения"
        case "preparing":
            return "Готовится"
        case "ready":
            return "Готов к выдаче"
        case "completed", "issued":
            return "Выдан"
        case "cancelled":
            return "Отменён"
        default:
            return status
        }
    }
    
    private func localizedPaymentMethod(_ method: String) -> String {
        switch method.lowercased() {
        case "wallet":
            return "Кошелёк"
        case "card":
            return "Карта"
        case "cash":
            return "Наличные"
        default:
            return method
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "ru_RU")
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        
        return displayFormatter.string(from: date)
    }
}

// MARK: - View Model

@MainActor
class OrderStatusViewModel: ObservableObject {
    @Published var orderDetails: OrderDetails?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = SupabaseAPIClient.shared
    
    func loadOrderDetails(orderId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Call get_order_details RPC function
            let response: OrderDetailsResponse = try await apiClient.rpc(
                "get_order_details",
                params: ["order_id_param": orderId.uuidString]
            )
            
            await MainActor.run {
                self.orderDetails = response.toOrderDetails()
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

// MARK: - Models

struct OrderDetails {
    let order: OrderInfo
    let items: [OrderItem]
    let events: [OrderEvent]
}

struct OrderInfo: Codable {
    let id: UUID
    let orderNumber: String
    let cafeId: UUID?
    let cafeName: String?
    let status: String
    let totalCredits: Int
    let paymentMethod: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber = "order_number"
        case cafeId = "cafe_id"
        case cafeName = "cafe_name"
        case status
        case totalCredits = "total_credits"
        case paymentMethod = "payment_method"
        case createdAt = "created_at"
    }
}

struct OrderItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let quantity: Int
    let lineTotal: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case quantity
        case lineTotal = "line_total"
    }
}

struct OrderEvent: Codable, Identifiable {
    let id: UUID
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
    }
}

struct OrderDetailsResponse: Codable {
    let order: OrderInfo
    let items: [OrderItem]
    let events: [OrderEvent]
    
    func toOrderDetails() -> OrderDetails {
        OrderDetails(order: order, items: items, events: events)
    }
}

// MARK: - Preview

#Preview {
    OrderStatusView(orderId: UUID())
        .environmentObject(AuthService.shared)
}
