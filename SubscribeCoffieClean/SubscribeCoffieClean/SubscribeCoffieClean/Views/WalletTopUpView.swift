//
//  WalletTopUpView.swift
//  SubscribeCoffieClean
//
//  DEMO MODE ONLY: Mock payments, no real money
//  Real payment integration: See PAYMENT_SECURITY.md in backend
//

import SwiftUI

struct WalletTopUpView: View {
    let wallet: Wallet
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletService = WalletService()
    @State private var amountText: String = "500"
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var topupResult: MockTopupResponse?
    
    private let presetAmounts: [Int] = [300, 500, 1000, 2000]
    private let maxAmount: Int = 99999
    
    // Commission rate based on wallet type
    private var commissionPercent: Double {
        switch wallet.walletType {
        case .citypass:
            return 7.0 // CityPass: 7%
        case .cafe_wallet:
            return 4.0 // Cafe Wallet: 4%
        }
    }
    
    private var commissionAmount: Int {
        return Int(Double(parsedAmount) * commissionPercent / 100.0)
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
                Text("Комиссия (\(String(format: "%.0f", commissionPercent))%)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                Spacer()
                Text("-\(commissionAmount) ₽")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
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
    
    private func performTopUp() async {
        guard parsedAmount > 0 else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            // Use mock payment (demo mode)
            let result = try await walletService.mockWalletTopup(
                walletId: wallet.id,
                amount: parsedAmount,
                paymentMethodId: nil
            )
            
            topupResult = result
            showSuccessAlert = true
            isProcessing = false
            
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
            isProcessing = false
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
}
