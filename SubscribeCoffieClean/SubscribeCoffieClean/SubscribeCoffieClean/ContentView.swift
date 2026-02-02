import SwiftUI

struct ContentView: View {

    private let cafeRepository = CafeRepository()

    // MARK: - Screens
    enum AppScreen {
        case login
        case profileSetup
        case walletChoice
        case selectCafeForWallet
        case walletTopUp
        case onboarding
        case map
        case cafe
        case cart
        case checkout
        case orderStatus
    }

    // MARK: - Persisted auth/profile (AppStorage)
    @AppStorage("sc_isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("sc_knownPhones") private var knownPhonesCSV: String = ""
    @AppStorage("sc_phone") private var savedPhone: String = ""
    @AppStorage("sc_fullName") private var savedFullName: String = ""
    @AppStorage("sc_birthTS") private var savedBirthTS: Double = Date().timeIntervalSince1970
    @AppStorage("sc_city") private var savedCity: String = "Москва"
    @AppStorage("sc_defaultWalletKind") private var defaultWalletKind: String = ""
    @AppStorage("sc_lastCafeId") private var lastCafeId: String = ""
    @AppStorage("sc_lastCafeName") private var lastCafeName: String = ""
    @AppStorage("sc_cafeWalletCafeId") private var cafeWalletCafeId: String = ""
    @AppStorage("sc_cafeWalletCafeName") private var cafeWalletCafeName: String = ""
    
    // MARK: - Wallet type persistence
    @AppStorage("sc_walletType") private var walletType: String = ""
    @AppStorage("sc_walletScopeId") private var walletScopeId: String = ""
    @AppStorage("sc_walletScopeTitle") private var walletScopeTitle: String = ""

    // MARK: - UI State
    @State private var isLoading: Bool = true
    @State private var currentScreen: AppScreen = .login
    @State private var pendingPhoneForProfile: String = ""

    // выбранная кофейня/меню
    @State private var selectedCafe: CafeSummary? = nil
    @State private var selectedCafeName: String = "Coffee Point ☕️"
    @State private var selectedMenu: CafeMenu = MockCafeService.sampleMenu()
    @State private var cafes: [CafeSummary] = []
    @State private var cafesAreLoading: Bool = false
    @State private var cafesLoadError: String? = nil
    @State private var isMenuLoading: Bool = false
    @State private var menuSchemaUnavailable: Bool = false
    @State private var supabaseAvailable: Bool = true
    @State private var didLoadCafes: Bool = false

    // Stores
    @StateObject private var cart = CartStore()
    @StateObject private var orderStore = OrderStore()
    @StateObject private var wallet = WalletStore()
    @StateObject private var cafeWallet = CafeWalletStore()
    @StateObject private var filterStore = FilterStore()

    @State private var lastRefundedOrderId: UUID? = nil
    @State private var lastCreatedOrderId: UUID? = nil
    @State private var useLocalOrderStatus: Bool = false

    // sheets
    @State private var isCityPassCafesPresented: Bool = false
    @State private var isWalletTopUpPresented: Bool = false
    @State private var isWalletDemoPresented: Bool = false
    @State private var isCafeWalletPickerPresented: Bool = false
    @State private var walletTopUpType: WalletType = .citypass
    @State private var walletTopUpScopeTitle: String = "CityPass"
    @State private var pendingWalletType: WalletType? = nil
    @State private var pendingWalletScopeId: String? = nil
    @State private var pendingWalletScopeName: String? = nil
    @State private var isSelectingWalletCafe: Bool = false
    @State private var didCompleteWalletTopUp: Bool = false
    @State private var pendingBonusToUse: Int = 0
    @State private var isProfilePresented: Bool = false
    @State private var isTopUpFlowPresented: Bool = false
    
    // Services
    private let orderService = OrderService()

    // DEBUG: отслеживание попыток входа в корзину
    @State private var debugCartAttempt: Int = 0
    @State private var debugCartFailureMessage: String? = nil

    // MARK: - Computed
    private let topBarHeight: CGFloat = 56
    private var availableCafes: [CafeSummary] { cafes }
    
    private var cityPassCafes: [CafeSummary] {
        // Первые 3 кофейни поддерживают CityPass (заглушка)
        Array(availableCafes.prefix(3))
    }
    
    private var cafeWalletSupportedCafes: [CafeSummary] {
        availableCafes.filter { $0.canPlaceOrder }
    }

    private var canGoBack: Bool {
        switch currentScreen {
        case .login, .onboarding, .walletChoice:
            return false
        case .profileSetup, .walletTopUp, .map, .cafe, .cart, .checkout, .orderStatus, .selectCafeForWallet:
            return true
        }
    }

    private var topBarTitle: String {
        switch currentScreen {
        case .login:        return "Вход"
        case .profileSetup: return "Анкета"
            case .walletChoice: return "Выбор кошелька"
            case .selectCafeForWallet: return "Выбор кофейни для кошелька"
        case .walletTopUp:  return "Пополнение"
        case .onboarding:   return "SubscribeCoffie"
        case .map:          return "Выбор кофейни"
        case .cafe:         return selectedCafeName
        case .cart:         return "Корзина"
        case .checkout:     return "Оформление"
        case .orderStatus:  return "Статус заказа"
        }
    }

    private func handleBack() {
        switch currentScreen {
        case .login:
            break

        case .profileSetup:
            currentScreen = .login
            pendingPhoneForProfile = ""

        case .walletChoice:
            break

        case .walletTopUp:
            currentScreen = .walletChoice

        case .onboarding:
            break

        case .map:
            if isSelectingWalletCafe {
                isSelectingWalletCafe = false
                currentScreen = .walletChoice
            } else {
                currentScreen = .onboarding
            }

        case .selectCafeForWallet:
            currentScreen = .walletChoice

        case .cafe:
            currentScreen = .map

        case .cart:
            currentScreen = .cafe

        case .checkout:
            currentScreen = .cafe

                case .orderStatus:
                    currentScreen = .cafe
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
            if isLoading {
                ProgressView().scaleEffect(1.4)
                Text("Загружаем приложение…")
                    .padding(.top, 12)
            } else {
                switch currentScreen {

                case .login:
                    LoginView {
                        handleLoginVerified("")
                    }

                case .profileSetup:
                    ProfileSetupView(phone: pendingPhoneForProfile) { fullName, birthDate, city in
                        completeProfile(fullName: fullName, birthDate: birthDate, city: city)
                    }

                case .walletChoice:
                    WalletChoiceView(
                        onCityPassSelected: {
                            pendingWalletType = .citypass
                            pendingWalletScopeId = nil
                            pendingWalletScopeName = nil
                            walletTopUpType = .citypass
                            walletTopUpScopeTitle = "CityPass"
                            isWalletTopUpPresented = true
                        },
                        onCityPassCafes: {
                            isCityPassCafesPresented = true
                        },
                        onCafeWalletSelected: {
                            pendingWalletType = .cafe_wallet
                            pendingWalletScopeId = nil
                            pendingWalletScopeName = nil
                            currentScreen = .selectCafeForWallet
                        }
                    )

                case .walletTopUp:
                    // Temporary: Create a mock Wallet from WalletStore data
                    let tempWallet = Wallet(
                        id: UUID(),
                        walletType: .citypass,
                        balanceCredits: wallet.credits,
                        lifetimeTopUpCredits: wallet.lifetimeTopUp,
                        cafeId: nil,
                        cafeName: nil,
                        networkId: nil,
                        networkName: nil,
                        createdAt: Date()
                    )
                    WalletTopUpView(wallet: tempWallet)

                case .onboarding:
                    OnboardingView {
                        currentScreen = .map
                    }

                case .map:
                    MapSelectionView(
                        cafes: availableCafes,
                        isLoading: cafesAreLoading,
                        errorMessage: cafesLoadError,
                        onRetry: {
                            Task { await fetchCafesIfNeeded(force: true) }
                        },
                        onSelectCafe: { cafe in
                            if isSelectingWalletCafe {
                pendingWalletScopeId = cafe.id.uuidString
                pendingWalletScopeName = cafe.name
                walletTopUpType = .cafe_wallet
                walletTopUpScopeTitle = cafe.name
                isWalletTopUpPresented = true
                                isSelectingWalletCafe = false
                            } else {
                                Task {
                                    await handleCafeSelection(cafe, persistLastCafe: true)
                                }
                            }
                        }
                    )
                    .task {
                        await fetchCafesIfNeeded()
                    }

                case .selectCafeForWallet:
                    MapSelectionView(
                        cafes: availableCafes,
                        isLoading: cafesAreLoading,
                        errorMessage: cafesLoadError,
                        onRetry: {
                            Task { await fetchCafesIfNeeded(force: true) }
                        },
                        onSelectCafe: { cafe in
                            Task {
                                await handleCafeWalletSelection(cafe)
                            }
                        }
                    )
                    .task {
                        await fetchCafesIfNeeded()
                    }

                case .cafe:
                    if let cafe = selectedCafe {
                        CafeView(
                            cafe: cafe,
                            menu: selectedMenu,
                            menuSchemaUnavailable: menuSchemaUnavailable,
                            supportsCityPass: supportsCityPass(for: cafe),
                            cart: cart,
                            onOpenCart: {
                                currentScreen = .cart
                            },
                            onTopUpCityPass: {
                                isTopUpFlowPresented = true
                            },
                            onTopUpCafeWallet: {
                                isTopUpFlowPresented = true
                            }
                        )
                    } else {
                        Text("Кофейня не выбрана")
                            .foregroundColor(.secondary)
                    }

                case .cart:
                    CartView(
                        cart: cart,
                        wallet: wallet,
                        menu: selectedMenu,
                        cafeName: selectedCafeName,
                        isCafeOrderable: selectedCafe?.canPlaceOrder ?? false,
                        onCheckout: { bonusToUse, _ in
                            pendingBonusToUse = bonusToUse
                            currentScreen = .checkout
                        }
                    )

                case .checkout:
                    if let cafe = selectedCafe {
                        CheckoutView(
                            isPresented: .constant(true),
                            cart: cart,
                            wallet: wallet,
                            selectedCafe: cafe,
                            onOrderSuccess: { orderId in
                                lastCreatedOrderId = orderId
                                cart.reset()
                                currentScreen = .orderStatus
                            }
                        )
                    } else {
                        Text("Кофейня не выбрана")
                            .foregroundColor(.secondary)
                    }

                case .orderStatus:
                    if let orderId = lastCreatedOrderId {
                        OrderStatusView(orderId: orderId)
                    } else {
                        Text("Заказ не найден")
                    }
                @unknown default:
                    EmptyView()
                }
            }
        }
        }
        .padding(.top, isLoading ? 0 : topBarHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: currentScreen, initial: false) { oldValue, newValue in
            logScreenChange(runId: "cart-debug-3", from: oldValue, to: newValue, cartCount: cart.totalItems, subtotal: cart.subtotalCredits)
        }
        .onAppear {
            Task { await bootstrap() }
        }
        .overlay(alignment: .top) {
            if !isLoading {
                TopBarView(
                    title: topBarTitle,
                    canGoBack: canGoBack,
                    onBack: { handleBack() },
                    showsLogout: isLoggedIn,
                    onLogout: { logout() },
                    showsProfile: isLoggedIn,
                    onProfile: { isProfilePresented = true },
                    showsWalletButton: isLoggedIn && currentScreen != .login,
                    onWallet: { isWalletDemoPresented = true }
                )
                .zIndex(1)
            }
        }
        .sheet(isPresented: $isCityPassCafesPresented) {
            CityPassCafesView(cafes: cityPassCafes)
        }
        .sheet(isPresented: $isCafeWalletPickerPresented) {
            CafeWalletCafePickerView(cafes: cafeWalletSupportedCafes) { cafe in
                pendingWalletScopeId = cafe.id.uuidString
                pendingWalletScopeName = cafe.name
                walletTopUpType = .cafe_wallet
                walletTopUpScopeTitle = cafe.name
                isCafeWalletPickerPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isWalletTopUpPresented = true
                }
            }
        }
        .sheet(isPresented: $isWalletTopUpPresented, onDismiss: {
            handleWalletTopUpDismiss()
        }) {
            let tempWallet = Wallet(
                id: UUID(),
                walletType: .citypass,
                balanceCredits: wallet.credits,
                lifetimeTopUpCredits: wallet.lifetimeTopUp,
                cafeId: nil,
                cafeName: nil,
                networkId: nil,
                networkName: nil,
                createdAt: Date()
            )
            WalletTopUpView(wallet: tempWallet)
        }
        .sheet(isPresented: $isWalletDemoPresented) {
            WalletChoiceView(
                onCityPassSelected: {
                    walletTopUpType = .citypass
                    walletTopUpScopeTitle = "CityPass"
                    isWalletTopUpPresented = true
                },
                onCityPassCafes: {
                    isCityPassCafesPresented = true
                },
                onCafeWalletSelected: {
                    pendingWalletType = .cafe_wallet
                    pendingWalletScopeId = nil
                    pendingWalletScopeName = nil
                    isWalletDemoPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isCafeWalletPickerPresented = true
                    }
                }
            )
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileView(
                fullName: savedFullName,
                phone: savedPhone,
                birthDate: Date(timeIntervalSince1970: savedBirthTS),
                city: savedCity,
                cityPassWallet: wallet,
                cafeWallet: cafeWallet,
                availableCafes: availableCafes,
                onClose: { isProfilePresented = false },
                onLogout: {
                    isProfilePresented = false
                    logout()
                }
            )
        }
        .sheet(isPresented: $isTopUpFlowPresented) {
            TopUpFlowView(
                cityPassWallet: wallet,
                cafeWallet: cafeWallet,
                cafeName: selectedCafeName,
                supportsCityPass: selectedCafe.map { supportsCityPass(for: $0) } ?? true,
                onDone: {
                    isTopUpFlowPresented = false
                }
            )
        }
#if DEBUG
        .task {
            let ok = await supabasePing()
            print("Supabase ping OK: \(ok)")
            let menuSmoke = await supabaseMenuItemsSmokeCheck()
            switch menuSmoke {
            case .ok:
                print("Supabase menu_items OK")
            case .missingSchema:
                print("Supabase menu_items 404 (schema missing)")
                await MainActor.run {
                    menuSchemaUnavailable = true
                }
            case .failed:
                print("Supabase menu_items smoke failed")
            }
        }
#endif
    }

    // MARK: - Auth logic (mock)
    private func handleLoginVerified(_ phoneDigits: String) {
        let normalized = phoneDigits.filter { $0.isNumber }

        let known = knownPhonesSet()
        if known.contains(normalized) {
            savedPhone = normalized
            isLoggedIn = true
            routeAfterAuth()
        } else {
            pendingPhoneForProfile = normalized
            currentScreen = .profileSetup
        }
    }

    private func completeProfile(fullName: String, birthDate: Date, city: String) {
        savedFullName = fullName
        savedBirthTS = birthDate.timeIntervalSince1970
        savedCity = city
        savedPhone = pendingPhoneForProfile

        var known = knownPhonesSet()
        known.insert(pendingPhoneForProfile)
        knownPhonesCSV = known.sorted().joined(separator: ",")

        pendingPhoneForProfile = ""
        isLoggedIn = true
        
        // Проверяем, выбран ли тип кошелька
        routeAfterAuth()
    }
    
    // MARK: - Wallet setup logic
    private func proceedAfterWalletSetup() {
        didCompleteWalletTopUp = true

        if let pendingType = pendingWalletType {
            walletType = pendingType.rawValue
            defaultWalletKind = pendingType.rawValue
            if pendingType == .cafe_wallet, let scopeId = pendingWalletScopeId {
                walletScopeId = scopeId
                walletScopeTitle = pendingWalletScopeName ?? ""
                cafeWalletCafeId = scopeId
                cafeWalletCafeName = pendingWalletScopeName ?? ""
            } else {
                walletScopeId = ""
                walletScopeTitle = ""
            }
        }

        pendingWalletType = nil
        pendingWalletScopeId = nil
        pendingWalletScopeName = nil
        currentScreen = .map
    }

    private func handleWalletTopUpDismiss() {
        if didCompleteWalletTopUp {
            didCompleteWalletTopUp = false
            return
        }

        // Если пополнение отменили — сбрасываем выбор и возвращаемся к выбору кошелька
        pendingWalletType = nil
        pendingWalletScopeId = nil
        pendingWalletScopeName = nil
        if walletType.isEmpty {
            currentScreen = .walletChoice
        }
    }

    private func cafeById(_ idString: String) -> CafeSummary? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return availableCafes.first(where: { $0.id == uuid })
    }

    private func routeAfterAuth() {
        Task {
            let screen = await determineStartScreen()
            await MainActor.run { currentScreen = screen }
        }
    }

    private func determineStartScreen() async -> AppScreen {
        if !isLoggedIn { return .login }

        // если default wallet kind не задан — старое поведение
        if defaultWalletKind.isEmpty {
            return .map
        }

        if defaultWalletKind == WalletType.citypass.rawValue {
            if let cafe = cafeById(lastCafeId) {
                let result = await cafeRepository.fetchMenuResult(cafeId: cafe.id)
                await MainActor.run {
                    menuSchemaUnavailable = result.schemaMissing
                    applyCafeSelection(cafe: cafe, menu: result.menu, persistLastCafe: true)
                }
                return .cafe
            }
            return .map
        }

        if defaultWalletKind == WalletType.cafe_wallet.rawValue {
            let boundId = !cafeWalletCafeId.isEmpty ? cafeWalletCafeId : (cafeWallet.cafeId ?? "")
            if let cafe = cafeById(boundId) {
                let result = await cafeRepository.fetchMenuResult(cafeId: cafe.id)
                await MainActor.run {
                    menuSchemaUnavailable = result.schemaMissing
                    applyCafeSelection(cafe: cafe, menu: result.menu, persistLastCafe: true)
                }
                return .cafe
            }
            // привязки нет — отправляем на выбор
            return .walletChoice
        }

        return walletType.isEmpty ? .walletChoice : .map
    }

    private func bootstrap() async {
        await fetchCafesIfNeeded(force: true)

        let screen = await determineStartScreen()
        await MainActor.run {
            currentScreen = screen
            isLoading = false
        }
    }

    private func fetchCafesIfNeeded(force: Bool = false) async {
        if cafesAreLoading { return }
        if didLoadCafes && !force { return }
        await fetchCafes()
    }

    private func fetchCafes() async {
        await MainActor.run {
            cafesAreLoading = true
            cafesLoadError = nil
        }

        let result = await cafeRepository.fetchCafes()
        await MainActor.run {
            cafes = result.cafes
            supabaseAvailable = !result.usedFallback
            cafesLoadError = result.usedFallback ? "Supabase недоступен, данные недоступны." : nil
            cafesAreLoading = false
            didLoadCafes = true
        }
    }

    private func handleCafeSelection(_ cafe: CafeSummary, persistLastCafe: Bool) async {
        await MainActor.run {
            isMenuLoading = true
            cafesLoadError = nil
            menuSchemaUnavailable = false
        }
        let result = await cafeRepository.fetchMenuResult(cafeId: cafe.id)
        await MainActor.run {
            menuSchemaUnavailable = result.schemaMissing
            applyCafeSelection(cafe: cafe, menu: result.menu, persistLastCafe: persistLastCafe)
            cart.reset()
            isMenuLoading = false
            currentScreen = .cafe
        }
    }

    private func handleCafeWalletSelection(_ cafe: CafeSummary) async {
        await MainActor.run { isMenuLoading = true }
        let result = await cafeRepository.fetchMenuResult(cafeId: cafe.id)
        await MainActor.run {
            cafeWalletCafeId = cafe.id.uuidString
            cafeWalletCafeName = cafe.name
            cafeWallet.selectCafe(cafe)
            menuSchemaUnavailable = result.schemaMissing
            applyCafeSelection(cafe: cafe, menu: result.menu, persistLastCafe: true)
            isMenuLoading = false
            currentScreen = .cafe
        }
    }

    private func applyCafeSelection(cafe: CafeSummary, menu: CafeMenu, persistLastCafe: Bool) {
        selectedCafe = cafe
        selectedCafeName = cafe.name
        selectedMenu = menu
        if persistLastCafe {
            lastCafeId = cafe.id.uuidString
            lastCafeName = cafe.name
        }
    }

    private func logout() {
        isLoggedIn = false
        cart.reset()
        orderStore.reset()
        selectedCafe = nil
        defaultWalletKind = ""
        lastCafeId = ""
        lastCafeName = ""
        // Не сбрасываем walletType и walletScopeId при выходе
        currentScreen = .login
    }
    
    // #region agent log
    private func logCartNav(runId: String = "cart-debug-1", before: AppScreen? = nil, after: AppScreen? = nil, cartCount: Int, subtotal: Int, note: String = "") {
        #if DEBUG
        var dataDict: [String: Any] = [
            "cartCount": cartCount,
            "subtotal": subtotal
        ]
        if let before = before { dataDict["before"] = "\(before)" }
        if let after = after { dataDict["after"] = "\(after)" }
        if !note.isEmpty { dataDict["note"] = note }
        print("H3[\(runId)] Nav to cart:", dataDict)
        #endif
    }

    private func logScreenChange(runId: String = "cart-debug-3", from: AppScreen, to: AppScreen, cartCount: Int, subtotal: Int) {
        #if DEBUG
        print("H6[\(runId)] Screen change from \(from) to \(to), cartCount=\(cartCount), subtotal=\(subtotal)")
        #endif
    }
    // #endregion

    private func supportsCityPass(for cafe: CafeSummary) -> Bool {
        let prefix = cafe.id.uuidString.prefix(1)
        return prefix == "1" || prefix == "2" || prefix == "3"
    }

    private func knownPhonesSet() -> Set<String> {
        let items = knownPhonesCSV
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
        return Set(items)
    }
}

#Preview {
    ContentView()
}
