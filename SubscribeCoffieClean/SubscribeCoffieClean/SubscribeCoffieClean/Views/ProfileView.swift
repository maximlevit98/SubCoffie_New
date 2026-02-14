import Combine
import SwiftUI

struct ProfileView: View {
    let fullName: String
    let phone: String
    let birthDate: Date
    let city: String

    @ObservedObject var realWalletStore: RealWalletStore

    let availableCafes: [CafeSummary]
    let onClose: () -> Void
    let onLogout: () -> Void

    @State private var isCafePickerPresented: Bool = false
    @State private var isLogoutConfirmPresented: Bool = false
    @State private var isOrderHistoryPresented: Bool = false
    @State private var navigateToOrder: UUID?
    @State private var showCafeOnboarding: Bool = false
    @State private var showLoyaltyDashboard: Bool = false
    @State private var showSubscriptionPlans: Bool = false
    @State private var showTransactionHistory: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileSection
                    subscriptionSection
                    loyaltySection
                    orderHistorySection
                    transactionHistorySection
                    cityPassSection
                    cafeWalletSection
                    cafeOnboardingSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", action: onClose)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        isLogoutConfirmPresented = true
                    } label: {
                        Text("Выйти")
                    }
                }
            }
            .confirmationDialog("Выйти из аккаунта?", isPresented: $isLogoutConfirmPresented, titleVisibility: .visible) {
                Button("Выйти", role: .destructive, action: onLogout)
                Button("Отмена", role: .cancel) { }
            }
            .sheet(isPresented: $isCafePickerPresented) {
                CafePickerSheet(
                    cafes: availableCafes,
                    onSelect: { cafe in
                        Task {
                            await createCafeWallet(cafeId: cafe.id)
                        }
                        isCafePickerPresented = false
                    },
                    onClose: { isCafePickerPresented = false }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isOrderHistoryPresented) {
                OrderHistoryView()
            }
            .sheet(isPresented: $showCafeOnboarding) {
                CafeOnboardingListView()
            }
            .sheet(isPresented: $showLoyaltyDashboard) {
                // TODO: Re-enable when LoyaltyDashboardView is fixed
                VStack(spacing: 20) {
                    Text("Программа лояльности")
                        .font(.title)
                    Text("Эта функция временно недоступна")
                        .foregroundColor(.secondary)
                    Button("Закрыть") {
                        showLoyaltyDashboard = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .sheet(isPresented: $showSubscriptionPlans) {
                // Note: In production, extract user ID from auth session
                if let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                    SubscriptionPlansView(userId: userId)
                }
            }
            .sheet(isPresented: $showTransactionHistory) {
                if let selectedWallet = realWalletStore.selectedWallet {
                    TransactionHistoryView(wallet: selectedWallet)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Кошелёк не выбран")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Пожалуйста, выберите кошелёк для просмотра истории транзакций")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Закрыть") {
                            showTransactionHistory = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .task {
                await realWalletStore.loadWallets()
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Данные пользователя")
                .font(.headline)
            infoRow(label: "ФИО", value: fullName.isEmpty ? "—" : fullName)
            infoRow(label: "Телефон", value: phone.isEmpty ? "—" : phone)
            infoRow(label: "Дата рождения", value: formattedDate(birthDate))
            infoRow(label: "Город", value: city.isEmpty ? "—" : city)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
    
    private var subscriptionSection: some View {
        Button(action: {
            showSubscriptionPlans = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
                        Text("Подписка")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("Premium планы с кэшбеком и преимуществами")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var loyaltySection: some View {
        Button(action: {
            showLoyaltyDashboard = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Программа лояльности")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("Уровни, достижения и баллы")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var orderHistorySection: some View {
        Button(action: {
            isOrderHistoryPresented = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("История заказов")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Посмотреть все заказы и повторить предыдущие")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
    }
    
    private var transactionHistorySection: some View {
        Button(action: {
            showTransactionHistory = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .foregroundColor(.blue)
                        Text("История транзакций")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("Пополнения, платежи и возвраты")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
    }

    private var cityPassSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CityPass кошелёк")
                    .font(.headline)
                Spacer()
                if let cityPass = realWalletStore.wallets.first(where: { $0.walletType == .citypass }) {
                    badge(text: "\(cityPass.balanceCredits) ₽")
                } else {
                    badge(text: "Не создан")
                }
            }
            
            if let cityPass = realWalletStore.wallets.first(where: { $0.walletType == .citypass }) {
                walletRow(label: "Баланс", value: cityPass.balanceCredits)
                walletRow(label: "Всего пополнено", value: cityPass.lifetimeTopUpCredits)
                
                Button("Выбрать как активный") {
                    realWalletStore.selectWallet(cityPass)
                }
                .buttonStyle(.borderedProminent)
                .disabled(realWalletStore.selectedWallet?.id == cityPass.id)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CityPass кошелёк не создан")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Создать CityPass") {
                        Task {
                            await createCityPassWallet()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private var cafeWalletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Кошелёк кофейни")
                    .font(.headline)
                Spacer()
                if let cafeWallet = realWalletStore.wallets.first(where: { $0.walletType == .cafe_wallet }) {
                    badge(text: cafeWallet.displaySubtitle ?? "Кафе")
                } else {
                    badge(text: "Не создан")
                }
            }

            if let cafeWallet = realWalletStore.wallets.first(where: { $0.walletType == .cafe_wallet }) {
                if let cafeName = cafeWallet.cafeName {
                    infoRow(label: "Кофейня/бренд", value: cafeName)
                }
                walletRow(label: "Баланс", value: cafeWallet.balanceCredits)
                walletRow(label: "Всего пополнено", value: cafeWallet.lifetimeTopUpCredits)

                Button("Выбрать как активный") {
                    realWalletStore.selectWallet(cafeWallet)
                }
                .buttonStyle(.borderedProminent)
                .disabled(realWalletStore.selectedWallet?.id == cafeWallet.id)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Кошелёк кофейни не подключён")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Выбрать кофейню/бренд") {
                        isCafePickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
    
    private var cafeOnboardingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.accentColor)
                Text("Для владельцев кафе")
                    .font(.headline)
                Spacer()
            }
            
            Text("Хотите подключить своё кафе к платформе?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Подать заявку на подключение") {
                showCafeOnboarding = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func walletRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.15))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
    
    // MARK: - Wallet Actions
    
    private func createCityPassWallet() async {
        do {
            _ = try await realWalletStore.createCityPassWallet()
            await realWalletStore.loadWallets()
        } catch {
            print("❌ Failed to create CityPass wallet: \(error)")
        }
    }
    
    private func createCafeWallet(cafeId: UUID?) async {
        do {
            _ = try await realWalletStore.createCafeWallet(cafeId: cafeId, networkId: nil)
            await realWalletStore.loadWallets()
        } catch {
            print("❌ Failed to create Cafe wallet: \(error)")
        }
    }
}

private struct CafePickerSheet: View {
    let cafes: [CafeSummary]
    let onSelect: (CafeSummary) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List(cafes) { cafe in
                Button {
                    onSelect(cafe)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cafe.name)
                            .font(.headline)
                        Text("ETA ~ \(cafe.etaMinutes) мин")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Выберите кофейню")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", action: onClose)
                }
            }
        }
    }
}
