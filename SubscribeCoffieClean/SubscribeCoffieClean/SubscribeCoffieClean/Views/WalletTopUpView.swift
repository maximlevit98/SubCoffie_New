//
//  WalletTopUpView.swift
//  SubscribeCoffieClean
//
//  DEMO MODE ONLY: Mock payments, no real money
//  Real payment integration: See PAYMENT_SECURITY.md in backend
//  UPDATED: 2026-02-05 - Commission rates from backend (P0)
//

import SwiftUI
import Supabase
import PostgREST

// MARK: - Commission Response Model

struct CommissionResponse: Codable {
    let wallet_id: String
    let wallet_type: String
    let operation_type: String
    let commission_percent: Double
}

struct WalletTopUpView: View {
    let wallet: Wallet
    var onTopUpSuccess: (() -> Void)? = nil // Callback to refresh wallets
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var walletService = WalletService()
    @State private var amountText: String = "500"
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var topupResult: MockTopupResponse?
    
    // Commission from backend
    @State private var commissionPercent: Double? = nil
    @State private var isLoadingCommission: Bool = true
    
    private let presetAmounts: [Int] = [300, 500, 1000, 2000]
    private let maxAmount: Int = 99999
    
    // Fallback commission rates (used if backend unavailable)
    private var fallbackCommissionPercent: Double {
        switch wallet.walletType {
        case .citypass:
            return 7.0 // CityPass fallback: 7%
        case .cafe_wallet:
            return 4.0 // Cafe Wallet fallback: 4%
        }
    }
    
    // Actual commission to use (from backend or fallback)
    private var actualCommissionPercent: Double {
        return commissionPercent ?? fallbackCommissionPercent
    }
    
    private var commissionAmount: Int {
        return Int(Double(parsedAmount) * actualCommissionPercent / 100.0)
    }
    
    private var amountCredited: Int {
        return parsedAmount - commissionAmount
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // DEMO MODE Banner (Always visible)
                    demoBanner
                    
                    // Commission loading indicator
                    if isLoadingCommission {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Загрузка тарифов комиссии...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    header
                    balanceBlock
                    amountGrid
                    manualInput
                    commissionBlock
                    topUpButton
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Пополнение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await fetchCommissionRate()
            }
            .alert("✅ Кошелёк пополнен!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let result = topupResult {
                    VStack(spacing: 8) {
                        Text("🎉 Тестовое пополнение успешно")
                        Text("Зачислено: \(result.amount_credited ?? 0) ₽")
                        Text("Комиссия: \(result.commission ?? 0) ₽")
                    }
                }
            }
        }
    }
    
    // MARK: - Demo Banner
    
    private var demoBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEMO MODE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Реальная оплата не производится")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Кредиты начисляются мгновенно для тестирования")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Info about real payments
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Для реальных платежей требуется интеграция с платёжной системой")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: wallet.walletType.icon)
                .font(.system(size: 44))
                .foregroundStyle(colorFor(wallet.walletType))
                .padding(12)
                .background(colorFor(wallet.walletType).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Text(wallet.displayTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            if let subtitle = wallet.displaySubtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Balance Block
    
    private var balanceBlock: some View {
        VStack(spacing: 8) {
            Text("Текущий баланс")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(wallet.balanceCredits) ₽")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Amount Grid
    
    private var amountGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сумма пополнения")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(presetAmounts, id: \.self) { amount in
                    Button {
                        amountText = "\(amount)"
                    } label: {
                        Text("+\(amount)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(parsedAmount == amount ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(parsedAmount == amount ? Color.accentColor : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Manual Input
    
    private var manualInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Своя сумма")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Введите сумму", text: $amountText)
                .keyboardType(.numberPad)
                .font(.title3)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onChange(of: amountText, initial: false) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    let capped = String(digits.prefix(6))
                    if capped != amountText {
                        amountText = capped
                    }
                }
        }
    }
    
    // MARK: - Commission Block
    
    private var commissionBlock: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Сумма платежа")
                    .font(.subheadline)
                Spacer()
                Text("\(parsedAmount) ₽")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                HStack(spacing: 4) {
                    Text("Комиссия (\(String(format: "%.2f", actualCommissionPercent))%)")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    if commissionPercent != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Text("-\(commissionAmount) ₽")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            if commissionPercent == nil {
                Text("Используется локальный тариф (backend недоступен)")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            HStack {
                Text("Будет зачислено")
                    .font(.headline)
                Spacer()
                Text("\(amountCredited) ₽")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Top-Up Button
    
    private var topUpButton: some View {
        Button {
            Task { await performTopUp() }
        } label: {
            if isProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                    
                    Text("Пополнить на \(parsedAmount) ₽")
                        .fontWeight(.semibold)
                    
                    Text("(DEMO)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .background(Color.accentColor)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(parsedAmount <= 0 || isProcessing)
    }
    
    // MARK: - Top-Up Logic
    
    /// Fetch commission rate from backend
    private func fetchCommissionRate() async {
        isLoadingCommission = true
        
        do {
            // Call RPC to get commission for this wallet
            let supabase = SupabaseClientProvider.client
            
            let response: CommissionResponse = try await supabase
                .rpc("get_commission_for_wallet", params: ["p_wallet_id": wallet.id.uuidString])
                .execute()
                .value
            
            // Update commission from backend
            await MainActor.run {
                self.commissionPercent = response.commission_percent
                self.isLoadingCommission = false
            }
            
            print("✅ Commission loaded from backend: \(response.commission_percent)% for \(response.wallet_type)")
            
        } catch {
            // Fallback to hardcoded rates
            print("⚠️ Failed to load commission from backend, using fallback: \(error.localizedDescription)")
            await MainActor.run {
                self.commissionPercent = nil // Will use fallback
                self.isLoadingCommission = false
            }
        }
    }
    
    private func performTopUp() async {
        guard parsedAmount > 0 else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            let walletId = try await resolveWalletIdForTopUp()

            // Use mock payment (demo mode)
            let result = try await walletService.mockWalletTopup(
                walletId: walletId,
                amount: parsedAmount,
                paymentMethodId: nil
            )
            
            await MainActor.run {
                topupResult = result
                showSuccessAlert = true
                isProcessing = false
            }
            
            // Call callback to refresh wallets
            onTopUpSuccess?()
            
            // Auto-dismiss after short delay
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Ошибка: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    /// Resolve an актуальный wallet ID before top-up.
    /// This prevents "Wallet not found" when local state contains stale IDs after db reset.
    private func resolveWalletIdForTopUp() async throws -> UUID {
        let userId = await MainActor.run {
            authService.currentUser?.id ?? AuthService.shared.currentUser?.id
        }
        
        guard let userId else {
            throw WalletServiceError.authenticationRequired
        }
        
        let wallets = try await walletService.getUserWallets(userId: userId)
        
        // Current ID is still valid
        if wallets.contains(where: { $0.id == wallet.id }) {
            return wallet.id
        }
        
        switch wallet.walletType {
        case .citypass:
            if let existing = wallets.first(where: { $0.walletType == .citypass }) {
                return existing.id
            }
            throw WalletServiceError.unknown("Кошелёк не найден. Сначала создайте CityPass кошелёк.")
            
        case .cafe_wallet:
            if let byCafe = wallet.cafeId {
                if let existing = wallets.first(where: { $0.walletType == .cafe_wallet && $0.cafeId == byCafe }) {
                    return existing.id
                }
                throw WalletServiceError.unknown("Кошелёк кофейни не найден. Сначала создайте кошелёк для этой кофейни.")
            }
            
            if let byNetwork = wallet.networkId {
                if let existing = wallets.first(where: { $0.walletType == .cafe_wallet && $0.networkId == byNetwork }) {
                    return existing.id
                }
                throw WalletServiceError.unknown("Кошелёк сети не найден. Сначала создайте кошелёк для этой сети.")
            }
            
            throw WalletServiceError.unknown("Кошелёк кофейни не привязан к кафе или сети")
        }
    }
    
    // MARK: - Helpers
    
    private var parsedAmount: Int {
        let value = Int(amountText) ?? 0
        return min(max(value, 0), maxAmount)
    }
    
    private func colorFor(_ type: WalletType) -> Color {
        switch type {
        case .citypass:
            return .blue
        case .cafe_wallet:
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    WalletTopUpView(
        wallet: Wallet(
            id: UUID(),
            walletType: .citypass,
            balanceCredits: 1000,
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
