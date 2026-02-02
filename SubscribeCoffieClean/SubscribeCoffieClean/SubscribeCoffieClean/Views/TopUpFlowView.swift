import Combine
import SwiftUI

struct TopUpFlowView: View {
    let cityPassWallet: WalletStore
    let cafeWallet: CafeWalletStore
    let cafeName: String
    let supportsCityPass: Bool
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .selectWallet
    @State private var selectedWallet: WalletType? = nil
    @State private var amountText: String = "500"
    @State private var isPaymentPresented: Bool = false
    @State private var paymentAmount: Int = 0

    private let presetAmounts: [Int] = [300, 500, 1000]
    private let maxAmount: Int = 999_999

    private enum Step {
        case selectWallet
        case amount
        case success
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch step {
                case .selectWallet:
                    selectionStep
                case .amount:
                    amountStep
                case .success:
                    successStep
                }
            }
            .padding()
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                        onDone()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .amount {
                        Button("Назад") {
                            step = .selectWallet
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isPaymentPresented) {
            FakePaymentView(
                amountCredits: paymentAmount,
                scopeTitle: selectedWalletTitle,
                onSuccess: {
                    applyTopUp(amount: paymentAmount)
                    isPaymentPresented = false
                    step = .success
                },
                onCancel: {
                    isPaymentPresented = false
                }
            )
        }
    }

    private var stepTitle: String {
        switch step {
        case .selectWallet:
            return "Выбор кошелька"
        case .amount:
            return "Сумма"
        case .success:
            return "Готово"
        }
    }

    private var selectionStep: some View {
        VStack(spacing: 16) {
            Text("Выберите кошелёк для пополнения")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if supportsCityPass {
                walletOption(
                    title: "CityPass",
                    subtitle: "Единый кошелёк сети",
                    icon: "creditcard.fill",
                    color: .blue
                ) {
                    selectedWallet = .citypass
                    step = .amount
                }
            }

            walletOption(
                title: "Кошелёк заведения",
                subtitle: cafeName.isEmpty ? "Для выбранной кофейни" : cafeName,
                icon: "cup.and.saucer.fill",
                color: .brown
            ) {
                selectedWallet = .cafe_wallet
                step = .amount
            }

            Spacer()
        }
    }

    private var amountStep: some View {
        VStack(spacing: 18) {
            balanceBlock
            amountGrid
            manualInput
            totalBlock
            payButton
            Spacer(minLength: 12)
        }
    }

    private var successStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Пополнение успешно")
                .font(.title3)
                .fontWeight(.semibold)
            Text("+\(paymentAmount) Credits на \(selectedWalletTitle)")
                .foregroundStyle(.secondary)
            Text("Баланс: \(currentBalance) Credits")
                .fontWeight(.semibold)
            Button("Готово") {
                dismiss()
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func walletOption(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var balanceBlock: some View {
        VStack(spacing: 6) {
            Text("Текущий баланс")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(currentBalance) Credits")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private var amountGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Сумма пополнения")
                .font(.headline)
            LazyVGrid(columns: [
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
                            .padding(.vertical, 12)
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

    private var totalBlock: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("К пополнению")
                    .font(.headline)
                Text(selectedWalletTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(parsedAmount) Credits")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(12)
    }

    private var payButton: some View {
        Button {
            startPayment()
        } label: {
            Text("Оплатить \(parsedAmount) Credits")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(parsedAmount <= 0)
    }

    private var parsedAmount: Int {
        let value = Int(amountText) ?? 0
        return min(max(value, 0), maxAmount)
    }

    private var selectedWalletTitle: String {
        switch selectedWallet {
        case .citypass:
            return "CityPass"
        case .cafe_wallet:
            return cafeName.isEmpty ? "Кошелёк заведения" : cafeName
        case .none:
            return "Кошелёк"
        }
    }

    private var currentBalance: Int {
        switch selectedWallet {
        case .citypass:
            return cityPassWallet.credits
        case .cafe_wallet:
            return cafeWallet.credits
        case .none:
            return 0
        }
    }

    private func startPayment() {
        guard parsedAmount > 0 else { return }
        paymentAmount = parsedAmount
        isPaymentPresented = true
    }

    private func applyTopUp(amount: Int) {
        switch selectedWallet {
        case .citypass:
            cityPassWallet.topUpDemo(credits: amount)
        case .cafe_wallet:
            cafeWallet.topUp(amount: amount)
        case .none:
            break
        }
    }
}

#Preview {
    TopUpFlowView(
        cityPassWallet: WalletStore(),
        cafeWallet: CafeWalletStore(),
        cafeName: "Coffee Point",
        supportsCityPass: true,
        onDone: {}
    )
}
