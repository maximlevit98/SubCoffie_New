import SwiftUI

struct FakePaymentView: View {
    let amountCredits: Int
    let scopeTitle: String
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing: Bool = false
    @State private var isSuccess: Bool = false
    @State private var selectedMethod: PaymentMethod = .applePay
    
    private var expectedBonus: Int {
        let percent: Double
        if amountCredits >= 5_000 { percent = 0.15 }
        else if amountCredits >= 3_000 { percent = 0.10 }
        else if amountCredits > 1_000 { percent = 0.05 }
        else if amountCredits == 1_000 { percent = 0.02 }
        else { percent = 0.0 }
        return Int(Double(amountCredits) * percent)
    }
    
    enum PaymentMethod: String, CaseIterable, Identifiable {
        case applePay = "Apple Pay"
        case card = "Банковская карта"
        case wallet = "Другой кошелек"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .applePay: return "applelogo"
            case .card: return "creditcard.fill"
            case .wallet: return "wallet.pass"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                methodPicker
                bonusInfo
                
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.accentColor)
                        Text("Обрабатываем оплату…")
                            .foregroundStyle(.secondary)
                    }
                } else if isSuccess {
                    successBlock
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Отмена") {
                        dismiss()
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        startPayment()
                    } label: {
                        Text(isSuccess ? "Готово" : "Оплатить")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
            }
            .padding()
            .navigationTitle("Оплата")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var header: some View {
        VStack(spacing: 10) {
            Text(scopeTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("\(amountCredits) Credits")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Способ оплаты")
                .font(.headline)
            
            Picker("Способ оплаты", selection: $selectedMethod) {
                ForEach(PaymentMethod.allCases) { method in
                    HStack {
                        Image(systemName: method.icon)
                        Text(method.rawValue)
                    }.tag(method)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var bonusInfo: some View {
        Group {
            if expectedBonus > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Бонус за пополнение")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("+\(expectedBonus) Credits будут начислены после оплаты")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
            }
        }
    }
    
    private var successBlock: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Оплата успешна")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Credits будут зачислены немедленно.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
    }
    
    private func startPayment() {
        if isSuccess {
            dismiss()
            onSuccess()
            return
        }
        
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            isProcessing = false
            isSuccess = true
        }
    }
}

#Preview {
    FakePaymentView(
        amountCredits: 500,
        scopeTitle: "CityPass",
        onSuccess: {},
        onCancel: {}
    )
}
