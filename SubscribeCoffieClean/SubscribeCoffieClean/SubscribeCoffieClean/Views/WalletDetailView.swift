//
//  WalletDetailView.swift
//  SubscribeCoffieClean
//
//  Detailed wallet view with balance, statistics, and transaction history
//

import SwiftUI
import Auth

struct WalletDetailView: View {
    let wallet: Wallet
    var onTopUp: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletService = WalletService()
    @EnvironmentObject var authService: AuthService
    
    @State private var transactions: [PaymentTransaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTransactionHistory = false
    
    private let recentTransactionsLimit = 5
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Wallet Header Card
                    walletHeaderCard
                    
                    // Statistics Card
                    statisticsCard
                    
                    // Quick Actions
                    quickActionsCard
                    
                    // Recent Transactions
                    if !transactions.isEmpty {
                        recentTransactionsCard
                    }
                }
                .padding()
            }
            .navigationTitle("Кошелёк")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task {
                await loadRecentTransactions()
            }
            .sheet(isPresented: $showTransactionHistory) {
                TransactionHistoryView(wallet: wallet)
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Wallet Header Card
    
    private var walletHeaderCard: some View {
        VStack(spacing: 16) {
            // Icon and Type
            VStack(spacing: 12) {
                Image(systemName: wallet.walletType.icon)
                    .font(.system(size: 50))
                    .foregroundColor(colorForWalletType(wallet.walletType))
                    .frame(width: 80, height: 80)
                    .background(colorForWalletType(wallet.walletType).opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text(wallet.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let subtitle = wallet.displaySubtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Balance
            VStack(spacing: 8) {
                Text("Текущий баланс")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(wallet.balanceCredits) ₽")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(colorForWalletType(wallet.walletType))
            }
            
            // Created Date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Создан: \(formatDate(wallet.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Статистика")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Пополнений",
                    value: "\(topUpCount)",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Оплачено",
                    value: "\(paymentCount)",
                    icon: "cart.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Всего пополнено",
                    value: "\(wallet.lifetimeTopUpCredits) ₽",
                    icon: "creditcard.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Потрачено",
                    value: "\(totalSpent) ₽",
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Quick Actions Card
    
    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            // Top-up button
            Button {
                onTopUp?()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Пополнить кошелёк")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(colorForWalletType(wallet.walletType))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // View all transactions button
            Button {
                showTransactionHistory = true
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title3)
                    Text("Вся история транзакций")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Recent Transactions Card
    
    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Последние операции")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Все") {
                    showTransactionHistory = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(transactions.prefix(recentTransactionsLimit))) { transaction in
                    TransactionRowView(transaction: transaction)
                    
                    if transaction.id != transactions.prefix(recentTransactionsLimit).last?.id {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Computed Properties
    
    private var topUpCount: Int {
        transactions.filter { $0.transactionType == "topup" }.count
    }
    
    private var paymentCount: Int {
        transactions.filter { $0.transactionType == "order_payment" }.count
    }
    
    private var totalSpent: Int {
        transactions
            .filter { $0.transactionType == "order_payment" }
            .reduce(0) { $0 + $1.amountCredits }
    }
    
    // MARK: - Loading Functions
    
    private func loadRecentTransactions() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedTransactions = try await walletService.getUserTransactionHistory(
                userId: userId,
                limit: 20, // Load more to calculate stats
                offset: 0
            )
            
            await MainActor.run {
                self.transactions = loadedTransactions
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    WalletDetailView(
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
        ),
        onTopUp: {
            print("Top up tapped")
        }
    )
    .environmentObject(AuthService.shared)
}
