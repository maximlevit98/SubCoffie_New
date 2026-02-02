//
//  WalletTopUpView.swift
//  SubscribeCoffieClean
//
//  View for topping up wallet with real payment integration
//

import SwiftUI
import SafariServices

struct WalletTopUpView: View {
    let wallet: Wallet
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletService = WalletService()
    @StateObject private var paymentService = PaymentService()
    @State private var amountText: String = "500"
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var topupResult: MockTopupResponse?
    @State private var paymentIntent: PaymentIntentResponse?
    @State private var showPaymentWebView = false
    @State private var useRealPayments = false // Toggle between mock and real payments
    
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
                    // Payment Mode Banner
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: useRealPayments ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(useRealPayments ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(useRealPayments ? "РЕАЛЬНАЯ ОПЛАТА" : "DEMO MODE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(useRealPayments ? "Платёж будет обработан через платёжную систему" : "Реальная оплата не производится")
                                    .font(.caption2)
                            }
                            Spacer()
                        }
                        
                        Toggle("Использовать реальные платежи", isOn: $useRealPayments)
                            .font(.caption)
                    }
                    .padding()
                    .background((useRealPayments ? Color.green : Color.yellow).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
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
            .alert("Пополнено! (Тестовый режим)", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let result = topupResult {
                    Text("Зачислено \(result.amount_credited ?? 0) ₽\nКомиссия: \(result.commission ?? 0) ₽")
                }
            }
        }
    }
    
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
    
    private var topUpButton: some View {
        Button {
            Task { await performTopUp() }
        } label: {
            if isProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    if !useRealPayments {
                        Text("DEMO")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    
                    Text(useRealPayments ? "Оплатить \(parsedAmount) ₽" : "Пополнить на \(parsedAmount) ₽")
                        .fontWeight(.semibold)
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
    
    private func performTopUp() async {
        guard parsedAmount > 0 else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            if useRealPayments {
                // Use real payment integration
                let intent = try await walletService.createPaymentIntent(
                    walletId: wallet.id,
                    amount: parsedAmount,
                    paymentMethodId: nil,
                    description: "Пополнение \(wallet.displayTitle)"
                )
                
                paymentIntent = intent
                
                // Process payment based on provider
                switch intent.provider {
                case .yookassa:
                    if let confirmationUrl = intent.confirmationUrl,
                       let url = URL(string: confirmationUrl) {
                        // Open payment page in Safari
                        await openPaymentURL(url)
                        
                        // Poll for payment status
                        try await pollPaymentStatus(transactionId: intent.transactionId)
                    }
                    
                case .stripe:
                    errorMessage = "Stripe integration coming soon. Please use YooKassa or mock payments."
                    isProcessing = false
                    return
                    
                case .mock:
                    // Mock payment completed immediately
                    showSuccessAlert = true
                }
                
                isProcessing = false
                if errorMessage == nil {
                    showSuccessAlert = true
                }
                
            } else {
                // Use mock payment (backward compatibility)
                let result = try await walletService.mockWalletTopup(
                    walletId: wallet.id,
                    amount: parsedAmount,
                    paymentMethodId: nil
                )
                
                topupResult = result
                showSuccessAlert = true
                isProcessing = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
    
    @MainActor
    private func openPaymentURL(_ url: URL) async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        rootViewController.present(safariVC, animated: true)
        
        // Store reference to dismiss later
        showPaymentWebView = true
    }
    
    private func pollPaymentStatus(transactionId: UUID) async throws {
        var attempts = 0
        let maxAttempts = 30
        
        while attempts < maxAttempts {
            let status = try await walletService.getTransactionStatus(transactionId: transactionId)
            
            switch status.status {
            case "completed":
                // Payment successful
                return
            case "failed":
                let errorMsg = status.providerErrorMessage ?? "Payment failed"
                throw NetworkError.serverError(errorMsg)
            case "pending":
                // Continue polling
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                attempts += 1
            default:
                throw NetworkError.serverError("Unknown status: \(status.status)")
            }
        }
        
        throw NetworkError.serverError("Payment timeout")
    }
    
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
