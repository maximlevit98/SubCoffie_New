//
//  OrderHistoryView.swift
//  SubscribeCoffieClean
//
//  User order history with real data from Supabase
//

import SwiftUI
import Auth
import Combine

struct OrderHistoryView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = OrderHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    loadingView
                } else if viewModel.orders.isEmpty {
                    emptyStateView
                } else {
                    ordersList
                }
            }
            .navigationTitle("История заказов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task {
                if let userId = authService.currentUser?.id {
                    await viewModel.loadOrders(userId: userId)
                }
            }
            .refreshable {
                if let userId = authService.currentUser?.id {
                    await viewModel.loadOrders(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Загрузка заказов...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.secondary)
            
            Text("Нет заказов")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Ваши заказы будут отображаться здесь")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    
    // MARK: - Orders List
    
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.orders) { order in
                    OrderHistoryCard(order: order)
                }
            }
            .padding()
        }
    }
}

// MARK: - Order History Card

private struct OrderHistoryCard: View {
    let order: OrderHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Заказ #\(order.orderNumber)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(formatDate(order.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge(order.status)
            }
            
            // Cafe info
            if let cafeName = order.cafeName {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption)
                        .foregroundColor(.brown)
                    Text(cafeName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Order details
            HStack {
                Text("Сумма:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(order.totalCredits) ₽")
                    .font(.body)
                    .fontWeight(.semibold)
            }
            
            if let paymentMethod = order.paymentMethod {
                HStack {
                    Text("Оплата:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(localizedPaymentMethod(paymentMethod))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func statusBadge(_ status: String) -> some View {
        Text(localizedStatus(status))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .cornerRadius(8)
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
            return "Ожидает"
        case "preparing":
            return "Готовится"
        case "ready":
            return "Готов"
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
class OrderHistoryViewModel: ObservableObject {
    @Published var orders: [OrderHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = SupabaseAPIClient.shared
    
    func loadOrders(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Query orders_core table directly with RLS
            let response: [OrderHistoryItem] = try await apiClient.get(
                "orders_core",
                queryItems: [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "customer_user_id", value: "eq.\(userId.uuidString)"),
                    URLQueryItem(name: "order", value: "created_at.desc"),
                    URLQueryItem(name: "limit", value: "50")
                ]
            )
            
            await MainActor.run {
                self.orders = response
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

struct OrderHistoryItem: Codable, Identifiable {
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

// MARK: - Preview

#Preview {
    OrderHistoryView()
        .environmentObject(AuthService.shared)
}
