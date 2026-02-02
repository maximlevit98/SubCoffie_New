import SwiftUI

struct CafeView: View {
    let cafe: CafeSummary
    let menu: CafeMenu
    let menuSchemaUnavailable: Bool
    let supportsCityPass: Bool
    @ObservedObject var cart: CartStore
    let onOpenCart: () -> Void
    let onTopUpCityPass: () -> Void
    let onTopUpCafeWallet: () -> Void

    @State private var selectedCategory: CafeMenuCategory = .drinks
    @State private var searchText: String = ""
    @State private var showingSearch: Bool = false
    @Namespace private var animation
    @State private var cafeNetwork: NetworkInfo?
    @State private var isLoadingNetwork = false
    
    // Recommendations
    @State private var personalizedRecommendations: [PersonalizedRecommendation] = []
    @State private var isLoadingRecommendations = false
    @StateObject private var recommendationService = RecommendationService()

    private let categories: [CafeMenuCategory] = CafeMenuCategory.allCases
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var filteredProducts: [CafeProduct] {
        let products = menu.products(for: selectedCategory)
        if searchText.isEmpty {
            return products
        }
        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(searchText) ||
            product.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header с градиентом
                    CafeHeroHeader(cafe: cafe, network: cafeNetwork)
                        .padding(.bottom, 16)

                    // Wallet Actions (опционально)
                    // TODO: Добавить кнопки пополнения, если требуется

                    if menuSchemaUnavailable {
                        Text("⚠️ Меню недоступно")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    // Категории (sticky)
                    CategoryChipsView(
                        categories: categories,
                        selectedCategory: $selectedCategory,
                        animation: animation
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)

                    // Search Bar (опционально)
                    if showingSearch {
                        SearchBar(text: $searchText)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Personalized Recommendations
                    if !personalizedRecommendations.isEmpty && !isLoadingRecommendations {
                        PersonalizedRecommendationsSection(
                            recommendations: personalizedRecommendations.filter { $0.cafeId == cafe.id },
                            cart: cart,
                            cafe: cafe
                        )
                    }

                    // Menu Grid
                    if filteredProducts.isEmpty {
                        EmptyMenuView(category: selectedCategory)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(filteredProducts.enumerated()), id: \.element.id) { index, product in
                                MenuItemCard(
                                    product: product,
                                    cafe: cafe,
                                    cart: cart,
                                    index: index
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }
            }

            // Floating Cart Button
            if cart.totalItems > 0 {
                FloatingCartButton(
                    cart: cart,
                    onOpenCart: onOpenCart
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingSearch.toggle()
                    }
                } label: {
                    Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                        .foregroundColor(.primary)
                        .font(.title3)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cart.totalItems)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategory)
        .task {
            await loadCafeNetwork()
            await loadRecommendations()
        }
    }
    
    private func loadCafeNetwork() async {
        isLoadingNetwork = true
        defer { isLoadingNetwork = false }
        
        let walletService = WalletService()
        do {
            cafeNetwork = try await walletService.getCafeNetwork(cafeId: cafe.id)
        } catch {
            // Network not found or error - this is OK, not all cafes are in networks
            cafeNetwork = nil
        }
    }
    
    private func loadRecommendations() async {
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        
        guard let userId = try? await SupabaseAPIClient.shared.getCurrentUserId() else {
            return
        }
        
        // TODO: Re-implement when RecommendationService is ready
        personalizedRecommendations = []
        /*
        do {
            personalizedRecommendations = try await recommendationService.getPersonalizedRecommendations(
                userId: userId,
                limit: 10
            )
        } catch {
            print("Failed to load personalized recommendations: \(error)")
            personalizedRecommendations = []
        }
        */
    }
}

// MARK: - Hero Header

private struct CafeHeroHeader: View {
    let cafe: CafeSummary
    let network: NetworkInfo?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient Background
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.6),
                    Color.accentColor.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            // Cafe Info
            VStack(alignment: .leading, spacing: 8) {
                Text(cafe.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                HStack(spacing: 12) {
                    if let rating = cafe.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                    }

                    Text(cafe.address)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    CafeModeBadge(mode: cafe.mode)

                    Text("\(cafe.etaMinutes) мин")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    // Network badge
                    if let network = network {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.caption2)
                            Text("Сеть: \(network.name)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.9))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Category Chips

private struct CategoryChipsView: View {
    let categories: [CafeMenuCategory]
    @Binding var selectedCategory: CafeMenuCategory
    let animation: Namespace.ID

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        animation: animation
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct CategoryChip: View {
    let category: CafeMenuCategory
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: category))
                    .font(.system(size: 16, weight: .semibold))

                Text(category.titleRu)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "category_background", in: animation)
                } else {
                    Capsule()
                        .fill(Color(.systemGray6))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func iconName(for category: CafeMenuCategory) -> String {
        switch category {
        case .drinks: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .syrups: return "drop.fill"
        case .merch: return "gift.fill"
        }
    }
}

// MARK: - Menu Item Card

private struct MenuItemCard: View {
    let product: CafeProduct
    let cafe: CafeSummary
    @ObservedObject var cart: CartStore
    let index: Int

    @State private var isPressed: Bool = false
    @State private var showAddAnimation: Bool = false

    private var quantityInCart: Int {
        cart.lines.first(where: { $0.product.id == product.id })?.quantity ?? 0
    }

    private var canAddToCart: Bool {
        cafe.mode == .open && cafe.activeOrders < cafe.maxActiveOrders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Placeholder / Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                categoryColor.opacity(0.3),
                                categoryColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)

                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(categoryColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Name
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                // Description
                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                // Price & Add Button
                HStack {
                    HStack(spacing: 2) {
                        Text("\(product.priceCredits)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text("₽")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    AddToCartButton(
                        quantity: quantityInCart,
                        canAdd: canAddToCart,
                        showAnimation: $showAddAnimation
                    ) {
                        addToCart()
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(canAddToCart ? 1.0 : 0.6)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showAddAnimation)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: index)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: 50, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var categoryColor: Color {
        switch product.category {
        case .drinks: return .blue
        case .food: return .orange
        case .syrups: return .purple
        case .merch: return .pink
        }
    }

    private var iconName: String {
        switch product.category {
        case .drinks: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .syrups: return "drop.fill"
        case .merch: return "gift.fill"
        }
    }

    private func addToCart() {
        guard canAddToCart else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        cart.add(product: product)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            showAddAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showAddAnimation = false
            }
        }
    }
}

// MARK: - Add to Cart Button

private struct AddToCartButton: View {
    let quantity: Int
    let canAdd: Bool
    @Binding var showAnimation: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if quantity > 0 {
                    Text("\(quantity)")
                        .font(.system(size: 14, weight: .bold))
                        .transition(.scale)
                }
                Image(systemName: showAnimation ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
            }
            .foregroundColor(canAdd ? .accentColor : .gray)
            .scaleEffect(showAnimation ? 1.2 : 1.0)
        }
        .disabled(!canAdd)
        .buttonStyle(.plain)
    }
}

// MARK: - Search Bar

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Поиск по меню...", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Empty Menu View

private struct EmptyMenuView: View {
    let category: CafeMenuCategory

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)

            Text("Нет позиций в категории \"\(category.titleRu)\"")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Попробуйте выбрать другую категорию")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Floating Cart Button

private struct FloatingCartButton: View {
    @ObservedObject var cart: CartStore
    let onOpenCart: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onOpenCart()
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "cart.fill")
                        .font(.title3)

                    if cart.totalItems > 0 {
                        Text("\(cart.totalItems)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Корзина")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(cart.subtotalCredits) ₽")
                        .font(.caption)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cafe Mode Badge

private struct CafeModeBadge: View {
    let mode: CafeMode

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(modeColor)
                .frame(width: 6, height: 6)
            Text(modeText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.2))
        .cornerRadius(8)
    }

    private var modeColor: Color {
        switch mode {
        case .open: return .green
        case .busy: return .yellow
        case .paused: return .orange
        case .closed: return .red
        }
    }

    private var modeText: String {
        switch mode {
        case .open: return "Открыто"
        case .busy: return "Много заказов"
        case .paused: return "Приостановлено"
        case .closed: return "Закрыто"
        }
    }
}

// MARK: - Personalized Recommendations Section

private struct PersonalizedRecommendationsSection: View {
    let recommendations: [PersonalizedRecommendation]
    @ObservedObject var cart: CartStore
    let cafe: CafeSummary
    
    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.title3)
                    Text("Попробуйте что-то новое")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendations) { recommendation in
                            RecommendedItemCard(
                                recommendation: recommendation,
                                cart: cart,
                                cafe: cafe
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.05))
        }
    }
}

private struct RecommendedItemCard: View {
    let recommendation: PersonalizedRecommendation
    @ObservedObject var cart: CartStore
    let cafe: CafeSummary
    
    @State private var showAddAnimation = false
    
    private var quantityInCart: Int {
        cart.lines.first(where: { $0.product.id == recommendation.menuItemId })?.quantity ?? 0
    }
    
    private var canAddToCart: Bool {
        cafe.mode == .open && cafe.activeOrders < cafe.maxActiveOrders
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor.opacity(0.2))
                    .frame(height: 70)
                
                VStack(spacing: 4) {
                    Image(systemName: categoryIcon)
                        .font(.title2)
                        .foregroundColor(categoryColor)
                    
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(CafeProduct.normalizedTitle(title: recommendation.title, name: recommendation.name))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(recommendation.recommendationReason)
                    .font(.caption2)
                    .foregroundColor(.purple)
                    .lineLimit(1)
                
                if !recommendation.description.isEmpty {
                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                HStack {
                    Text("\(recommendation.priceCredits) ₽")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Button {
                        addToCart()
                    } label: {
                        HStack(spacing: 4) {
                            if quantityInCart > 0 {
                                Text("\(quantityInCart)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Image(systemName: showAddAnimation ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundColor(canAddToCart ? .accentColor : .gray)
                        .scaleEffect(showAddAnimation ? 1.2 : 1.0)
                    }
                    .disabled(!canAddToCart)
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .purple.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
        )
        .opacity(canAddToCart ? 1.0 : 0.6)
    }
    
    private var categoryColor: Color {
        switch recommendation.category {
        case .drinks: return .blue
        case .food: return .orange
        case .syrups: return .purple
        case .merch: return .pink
        }
    }
    
    private var categoryIcon: String {
        switch recommendation.category {
        case .drinks: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .syrups: return "drop.fill"
        case .merch: return "gift.fill"
        }
    }
    
    private func addToCart() {
        guard canAddToCart else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        cart.add(product: recommendation.asProduct())
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            showAddAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showAddAnimation = false
            }
        }
    }
}
