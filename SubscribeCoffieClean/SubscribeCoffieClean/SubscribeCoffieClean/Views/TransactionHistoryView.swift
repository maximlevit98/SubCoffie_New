//
//  TransactionHistoryView.swift
//  SubscribeCoffieClean
//
//  Transaction history view for displaying wallet transactions
//

import SwiftUI
import Auth

struct TransactionHistoryView: View {
    let wallet: Wallet
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletService = WalletService()
    @EnvironmentObject var authService: AuthService
    
    @State private var transactions: [PaymentTransaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isRefreshing = false
    
    // Pagination
    @State private var currentOffset = 0
    private let pageSize = 20
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading && transactions.isEmpty {
                    // Initial loading
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Загрузка транзакций...")
                            .foregroundColor(.secondary)
                    }
                } else if transactions.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Transaction list
                    transactionListView
                }
            }
            .navigationTitle("История транзакций")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await loadTransactions()
            }
        }
    }
    
    // MARK: - Transaction List
    
    private var transactionListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Wallet info header
                walletInfoHeader
                
                // Transactions
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                        
                        if transaction.id != transactions.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                // Load more button
                if transactions.count >= pageSize {
                    loadMoreButton
                }
            }
            .padding(.vertical, 16)
        }
        .refreshable {
            await refreshTransactions()
        }
    }
    
    // MARK: - Wallet Info Header
    
    private var walletInfoHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: wallet.walletType.icon)
                    .font(.title2)
                    .foregroundColor(colorForWalletType(wallet.walletType))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.displayTitle)
                        .font(.headline)
                    if let subtitle = wallet.displaySubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(wallet.balanceCredits) ₽")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Баланс")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Нет транзакций")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Здесь будет отображаться история пополнений и платежей")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Load More Button
    
    private var loadMoreButton: some View {
        Button(action: {
            Task {
                await loadMoreTransactions()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Загрузить ещё")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Loading Functions
    
    private func loadTransactions() async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedTransactions = try await walletService.getUserTransactionHistory(
                userId: userId,
                limit: pageSize,
                offset: 0
            )
            
            await MainActor.run {
                self.transactions = loadedTransactions
                self.currentOffset = 0
                self.isLoading = false
                
                #if DEBUG
                print("✅ [TransactionHistory] Loaded \(loadedTransactions.count) transactions")
                #endif
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
                
                #if DEBUG
                print("❌ [TransactionHistory] Error: \(error)")
                #endif
            }
        }
    }
    
    private func refreshTransactions() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isRefreshing = true
        
        do {
            let loadedTransactions = try await walletService.getUserTransactionHistory(
                userId: userId,
                limit: pageSize,
                offset: 0
            )
            
            await MainActor.run {
                self.transactions = loadedTransactions
                self.currentOffset = 0
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }
    
    private func loadMoreTransactions() async {
        guard let userId = authService.currentUser?.id else { return }
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let newOffset = currentOffset + pageSize
            let moreTransactions = try await walletService.getUserTransactionHistory(
                userId: userId,
                limit: pageSize,
                offset: newOffset
            )
            
            await MainActor.run {
                if !moreTransactions.isEmpty {
                    self.transactions.append(contentsOf: moreTransactions)
                    self.currentOffset = newOffset
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private func colorForWalletType(_ type: WalletType) -> Color {
        switch type {
        case .citypass:
            return .blue
        case .cafe_wallet:
            return .green
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: PaymentTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconForTransactionType(transaction.transactionType))
                .font(.title3)
                .foregroundColor(colorForTransactionType(transaction.transactionType))
                .frame(width: 40, height: 40)
                .background(colorForTransactionType(transaction.transactionType).opacity(0.1))
                .clipShape(Circle())
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayType)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    // Date
                    Text(formatDate(transaction.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Status badge
                    statusBadge(transaction.status)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(transaction))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForAmount(transaction))
                
                if transaction.commissionCredits > 0 {
                    Text("комиссия: \(transaction.commissionCredits) ₽")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
    
    // MARK: - Helpers
    
    private func iconForTransactionType(_ type: String) -> String {
        switch type {
        case "topup":
            return "arrow.down.circle.fill"
        case "order_payment":
            return "cart.fill"
        case "refund":
            return "arrow.uturn.backward.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    private func colorForTransactionType(_ type: String) -> Color {
        switch type {
        case "topup":
            return .green
        case "order_payment":
            return .blue
        case "refund":
            return .orange
        default:
            return .gray
        }
    }
    
    private func colorForAmount(_ transaction: PaymentTransaction) -> Color {
        switch transaction.transactionType {
        case "topup", "refund":
            return .green
        case "order_payment":
            return .primary
        default:
            return .primary
        }
    }
    
    private func formatAmount(_ transaction: PaymentTransaction) -> String {
        let amount = transaction.amountCredits
        
        switch transaction.transactionType {
        case "topup", "refund":
            return "+\(amount) ₽"
        case "order_payment":
            return "-\(amount) ₽"
        default:
            return "\(amount) ₽"
        }
    }
    
    private func statusBadge(_ status: String) -> some View {
        Text(transaction.displayStatus)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .cornerRadius(4)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed":
            return .green
        case "pending":
            return .orange
        case "failed":
            return .red
        default:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Сегодня, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Вчера, \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "d MMM, HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    TransactionHistoryView(
        wallet: Wallet(
            id: UUID(),
            walletType: .citypass,
            balanceCredits: 1500,
            lifetimeTopUpCredits: 5000,
            cafeId: nil,
            cafeName: nil,
            networkId: nil,
            networkName: nil,
            createdAt: Date()
        )
    )
    .environmentObject(AuthService.shared)
}
