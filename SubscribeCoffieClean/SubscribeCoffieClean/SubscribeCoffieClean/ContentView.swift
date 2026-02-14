import SwiftUI

struct ContentView: View {

    private let cafeRepository = CafeRepository()

    // MARK: - Screens
    enum AppScreen {
        case login
        case profileSetup
        case walletChoice
        case selectCafeForWallet
        case onboarding
        case map
        case cafe
        case cart
        case checkout
        case orderStatus
    }

    // MARK: - Auth Service
    @StateObject private var authService = AuthService.shared
    
    // MARK: - Wallet type persistence (kept for wallet selection)
    @AppStorage("sc_defaultWalletKind") private var defaultWalletKind: String = ""
    @AppStorage("sc_lastCafeId") private var lastCafeId: String = ""
    @AppStorage("sc_lastCafeName") private var lastCafeName: String = ""
    @AppStorage("sc_cafeWalletCafeId") private var cafeWalletCafeId: String = ""
    @AppStorage("sc_cafeWalletCafeName") private var cafeWalletCafeName: String = ""
    @AppStorage("sc_walletType") private var walletType: String = ""
    @AppStorage("sc_walletScopeId") private var walletScopeId: String = ""
    @AppStorage("sc_walletScopeTitle") private var walletScopeTitle: String = ""

    // MARK: - UI State
    @State private var isLoading: Bool = true
    @State private var currentScreen: AppScreen = .login

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
    @StateObject private var realWalletStore = RealWalletStore()
    @StateObject private var filterStore = FilterStore()

    @State private var lastRefundedOrderId: UUID? = nil
    @State private var lastCreatedOrderId: UUID? = nil
    @State private var useLocalOrderStatus: Bool = false

    // sheets
    @State private var isCityPassCafesPresented: Bool = false
    @State private var walletTopUpWallet: Wallet? = nil
    @State private var isWalletDemoPresented: Bool = false
    @State private var pendingWalletType: WalletType? = nil
    @State private var pendingWalletScopeId: String? = nil
    @State private var pendingWalletScopeName: String? = nil
    @State private var pendingBonusToUse: Int = 0
    @State private var isProfilePresented: Bool = false
    @State private var isWalletFlowLoading: Bool = false
    @State private var walletFlowErrorMessage: String? = nil
    @State private var showWalletFlowError: Bool = false
    @State private var showWalletCreateStep: Bool = false
    @State private var walletCreateType: WalletType = .citypass
    @State private var walletCreateScopeName: String? = nil
    @State private var walletCreateCafeId: UUID? = nil
    
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

    private var hasPresentedModal: Bool {
        isCityPassCafesPresented ||
        walletTopUpWallet != nil ||
        isWalletDemoPresented ||
        isProfilePresented ||
        isWalletFlowLoading ||
        showWalletCreateStep
    }

    private var canGoBack: Bool {
        switch currentScreen {
        case .login, .onboarding, .walletChoice:
            return false
        case .profileSetup, .map, .cafe, .cart, .checkout, .orderStatus, .selectCafeForWallet:
            return true
        }
    }

    private var topBarTitle: String {
        switch currentScreen {
        case .login:        return "Вход"
        case .profileSetup: return "Анкета"
            case .walletChoice: return "Выбор кошелька"
            case .selectCafeForWallet: return "Выбор кофейни для кошелька"
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
            // Handled by AuthContainerView now
            break

        case .walletChoice:
            break

        case .onboarding:
            break

        case .map:
            currentScreen = .onboarding

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
            // Show auth screen if not authenticated
            if !authService.isAuthenticated {
                AuthContainerView()
                    .environmentObject(authService)
            } else if isLoading {
                ProgressView().scaleEffect(1.4)
                Text("Загружаем приложение…")
                    .padding(.top, 12)
            } else {
                switch currentScreen {

                case .login:
                    // Handled by AuthContainerView
                    EmptyView()

                case .profileSetup:
                    // Handled by AuthContainerView
                    EmptyView()

                case .walletChoice:
                    WalletChoiceView(
                        hasCityPassWallet: realWalletStore.hasCityPass,
                        onCityPassSelected: {
                            Task {
                                await startCityPassTopUpFlow()
                            }
                        },
                        onCityPassCafes: {
                            if !hasPresentedModal {
                                isCityPassCafesPresented = true
                            }
                        },
                        onCafeWalletSelected: {
                            pendingWalletType = .cafe_wallet
                            pendingWalletScopeId = nil
                            pendingWalletScopeName = nil
                            currentScreen = .selectCafeForWallet
                        }
                    )

                case .onboarding:
                    OnboardingView {
                        currentScreen = .map
                    }

                case .map:
                    CafePickerView { cafe in
                        Task {
                            await handleCafeSelection(cafe, persistLastCafe: true)
                        }
                    }

                case .selectCafeForWallet:
                    CafePickerView { cafe in
                        Task {
                            await startCafeWalletTopUpFlow(for: cafe)
                        }
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
                                Task {
                                    await startCityPassTopUpFlow()
                                }
                            },
                            onTopUpCafeWallet: {
                                Task {
                                    await startCafeWalletTopUpFlow(for: cafe)
                                }
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
                    showsLogout: authService.isAuthenticated,
                    onLogout: { logout() },
                    showsProfile: authService.isAuthenticated,
                    onProfile: { isProfilePresented = true },
                    showsWalletButton: authService.isAuthenticated && currentScreen != .login,
                    onWallet: {
                        guard !hasPresentedModal else { return }
                        isWalletDemoPresented = true
                    }
                )
                .zIndex(1)
            }
        }
        .overlay {
            if isWalletFlowLoading {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Подготавливаем кошелек...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(isPresented: $isCityPassCafesPresented) {
            CityPassCafesView(cafes: cityPassCafes)
        }
        .sheet(item: $walletTopUpWallet, onDismiss: {
            handleWalletTopUpDismiss()
        }) { walletToTopUp in
            WalletTopUpView(wallet: walletToTopUp, onTopUpSuccess: {
                Task {
                    await realWalletStore.refreshWallets()
                    await MainActor.run {
                        if let refreshedWallet = realWalletStore.wallet(by: walletToTopUp.id) {
                            realWalletStore.selectWallet(refreshedWallet)
                        }
                        proceedAfterWalletSetup()
                    }
                }
            })
        }
        .sheet(isPresented: $isWalletDemoPresented) {
            WalletChoiceView(
                hasCityPassWallet: realWalletStore.hasCityPass,
                onCityPassSelected: {
                    isWalletDemoPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        Task {
                            await startCityPassTopUpFlow()
                        }
                    }
                },
                onCityPassCafes: {
                    isWalletDemoPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !hasPresentedModal {
                            isCityPassCafesPresented = true
                        }
                    }
                },
                onCafeWalletSelected: {
                    pendingWalletType = .cafe_wallet
                    pendingWalletScopeId = nil
                    pendingWalletScopeName = nil
                    isWalletDemoPresented = false
                    currentScreen = .selectCafeForWallet
                }
            )
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileView(
                fullName: authService.userProfile?.fullName ?? "",
                phone: authService.userProfile?.phone ?? "",
                birthDate: authService.userProfile?.birthDate.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                city: authService.userProfile?.city ?? "",
                realWalletStore: realWalletStore,
                availableCafes: availableCafes,
                onClose: { isProfilePresented = false },
                onLogout: {
                    isProfilePresented = false
                    logout()
                }
            )
        }
        .sheet(isPresented: $showWalletCreateStep) {
            WalletCreateStepView(
                walletType: walletCreateType,
                scopeName: walletCreateScopeName,
                onCreate: {
                    try await handleWalletCreate()
                },
                onCancel: {
                    showWalletCreateStep = false
                    pendingWalletType = nil
                    pendingWalletScopeId = nil
                    pendingWalletScopeName = nil
                }
            )
        }
        .alert("Ошибка кошелька", isPresented: $showWalletFlowError) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text(walletFlowErrorMessage ?? "Неизвестная ошибка")
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
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                routeAfterAuth()
            } else {
                realWalletStore.resetForSignOut()
            }
        }
        .environmentObject(authService)
        .environmentObject(realWalletStore)
    }

    // MARK: - Auth logic (real Supabase Auth)
    // routeAfterAuth is defined later as an async function
    
    // MARK: - Wallet setup logic
    private func proceedAfterWalletSetup() {
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
        // Если пополнение отменили — сбрасываем выбор и возвращаемся к выбору кошелька
        if pendingWalletType != nil {
            pendingWalletType = nil
            pendingWalletScopeId = nil
            pendingWalletScopeName = nil
            if currentScreen == .selectCafeForWallet || walletType.isEmpty {
                currentScreen = .walletChoice
            }
        }
    }

    private func cafeById(_ idString: String) -> CafeSummary? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return availableCafes.first(where: { $0.id == uuid })
    }

    private func routeAfterAuth() {
        Task {
            await realWalletStore.loadWallets()
            let screen = await determineStartScreen()
            await MainActor.run { currentScreen = screen }
        }
    }

    private func determineStartScreen() async -> AppScreen {
        if !authService.isAuthenticated { return .login }

        if !realWalletStore.hasWallets {
            return .walletChoice
        }

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
            let boundId = cafeWalletCafeId
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
        await realWalletStore.loadWallets()

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

    @MainActor
    private func startCityPassTopUpFlow() async {
        isWalletFlowLoading = true
        defer { isWalletFlowLoading = false }

        isCityPassCafesPresented = false
        isWalletDemoPresented = false

        pendingWalletType = .citypass
        pendingWalletScopeId = nil
        pendingWalletScopeName = nil

        if authService.currentUser == nil {
            await authService.checkSession()
        }

        guard authService.currentUser != nil else {
            handleWalletFlowError(WalletServiceError.authenticationRequired)
            return
        }

        await realWalletStore.loadWallets()

        // Check if wallet already exists
        if let existingWallet = realWalletStore.cityPassWallet {
            // Wallet exists -> go directly to top-up
            realWalletStore.selectWallet(existingWallet)
            walletTopUpWallet = existingWallet
        } else {
            // Wallet doesn't exist -> show create step
            walletCreateType = .citypass
            walletCreateScopeName = nil
            walletCreateCafeId = nil
            showWalletCreateStep = true
        }
    }

    @MainActor
    private func startCafeWalletTopUpFlow(for cafe: CafeSummary) async {
        isWalletFlowLoading = true
        defer { isWalletFlowLoading = false }

        isCityPassCafesPresented = false
        isWalletDemoPresented = false

        pendingWalletType = .cafe_wallet
        pendingWalletScopeId = cafe.id.uuidString
        pendingWalletScopeName = cafe.name
        cafeWalletCafeId = cafe.id.uuidString
        cafeWalletCafeName = cafe.name

        if authService.currentUser == nil {
            await authService.checkSession()
        }

        guard authService.currentUser != nil else {
            handleWalletFlowError(WalletServiceError.authenticationRequired)
            return
        }

        await realWalletStore.loadWallets()

        // Check if wallet already exists for this cafe
        if let existingWallet = realWalletStore.cafeWallet(forCafe: cafe.id) {
            // Wallet exists -> go directly to top-up
            realWalletStore.selectWallet(existingWallet)
            walletTopUpWallet = existingWallet
        } else {
            // Wallet doesn't exist -> show create step
            walletCreateType = .cafe_wallet
            walletCreateScopeName = cafe.name
            walletCreateCafeId = cafe.id
            showWalletCreateStep = true
        }
    }

    @MainActor
    private func handleWalletFlowError(_ error: Error) {
        pendingWalletType = nil
        pendingWalletScopeId = nil
        pendingWalletScopeName = nil

        walletFlowErrorMessage = error.localizedDescription
        showWalletFlowError = true
    }

    @MainActor
    private func handleWalletCreate() async throws {
        switch walletCreateType {
        case .citypass:
            // Create CityPass wallet
            let createdWallet = try await realWalletStore.createCityPassWallet()
            
            // Close create step
            showWalletCreateStep = false
            
            // Select the newly created wallet
            realWalletStore.selectWallet(createdWallet)
            
            // Small delay to ensure sheet dismissal before opening next one
            try await Task.sleep(for: .milliseconds(200))
            
            // Open top-up view
            walletTopUpWallet = createdWallet
            
        case .cafe_wallet:
            guard let cafeId = walletCreateCafeId else {
                throw WalletServiceError.unknown("Cafe ID отсутствует")
            }
            
            // Create Cafe Wallet
            let createdWallet = try await realWalletStore.createCafeWallet(cafeId: cafeId, networkId: nil)
            
            // Close create step
            showWalletCreateStep = false
            
            // Select the newly created wallet
            realWalletStore.selectWallet(createdWallet)
            
            // Small delay to ensure sheet dismissal before opening next one
            try await Task.sleep(for: .milliseconds(200))
            
            // Open top-up view
            walletTopUpWallet = createdWallet
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
        Task {
            try? await authService.signOut()
        }
        cart.reset()
        orderStore.reset()
        realWalletStore.resetForSignOut()
        walletTopUpWallet = nil
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
}

#Preview {
    ContentView()
}
