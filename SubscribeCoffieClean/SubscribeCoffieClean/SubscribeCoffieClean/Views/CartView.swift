import SwiftUI

struct CartView: View {
    @ObservedObject var cart: CartStore
    let wallet: WalletStore
    let menu: CafeMenu?
    let cafeName: String
    let isCafeOrderable: Bool
    /// onCheckout(bonusToUse, payCredits)
    let onCheckout: (Int, Int) -> Void

    @State private var bonusToUse: Int = 0
    @State private var highlightUpsell: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if cart.lines.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        listSection(scrollToUpsell: {
                            scrollToUpsell(proxy: proxy)
                        })
                        summarySection
                    }
                }
            }
        }
        .onAppear { recalcBonusToUse() }
        .onChange(of: cart.subtotalCredits, initial: false) { _, _ in recalcBonusToUse() }
        .onChange(of: cart.hasDrink, initial: false) { _, _ in recalcBonusToUse() }
    }

    // MARK: - Sections
    private var header: some View {
        VStack(spacing: 8) {
            Text("Корзина")
                .font(.largeTitle.weight(.bold))
            Text(cafeName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !isCafeOrderable {
                Label("Сейчас pre-order недоступен. Можно собрать корзину, но оформить пока нельзя.",
                      systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
                .padding(.top, 4)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func listSection(scrollToUpsell: @escaping () -> Void) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(cart.lines) { line in
                    CartLineRow(
                        line: line,
                        onIncrement: { cart.increment(lineId: line.id) },
                        onDecrement: { cart.decrement(lineId: line.id) }
                    )
                    .padding(.horizontal)
                }

                upsellCallout(scrollToUpsell: scrollToUpsell)
                    .padding(.horizontal)

                upsellSection
                    .padding(.horizontal)
                    .id(upsellSectionId)
                    .scaleEffect(highlightUpsell ? 1.02 : 1.0)
                    .shadow(color: highlightUpsell ? .orange.opacity(0.25) : .clear, radius: highlightUpsell ? 12 : 0, y: highlightUpsell ? 6 : 0)
            }
            .padding(.vertical, 8)
        }
    }

    private var summarySection: some View {
        VStack(spacing: 16) {
            Divider()
            VStack(spacing: 12) {
                totalRow(label: "Итого", value: cart.subtotalCredits)
                bonusBlock
                totalRow(label: "К оплате", value: max(cart.subtotalCredits - bonusToUse, 0), large: true)
                Button {
                    let payCredits = max(cart.subtotalCredits - bonusToUse, 0)
                    onCheckout(bonusToUse, payCredits)
                } label: {
                    HStack {
                        Text(isCafeOrderable ? "Перейти к оплате" : "Оплата недоступна")
                            .fontWeight(.semibold)
                        if isCafeOrderable {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isCafeOrderable || cart.lines.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
    }

    private var bonusBlock: some View {
        let maxBonus = maxBonusAllowed()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill").foregroundStyle(.green)
                Text("Скидка Bonus+")
                    .font(.headline)
                Spacer()
                Text("\(bonusToUse) / \(maxBonus)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !cart.hasDrink {
                Text("Добавь напиток, чтобы активировать скидки.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if maxBonus == 0 {
                Text("Сейчас нельзя списать бонусы (нет доступных бонусов или лимиты).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Slider(
                    value: Binding(
                        get: { Double(bonusToUse) },
                        set: { bonusToUse = min(maxBonus, Int($0)) }
                    ),
                    in: 0...Double(maxBonus),
                    step: 1
                )

                HStack {
                    Button {
                        bonusToUse = 0
                    } label: {
                        Text("0")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        bonusToUse = maxBonus
                    } label: {
                        Text("Макс")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.08)))
    }

    private func totalRow(label: String, value: Int, large: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(large ? .title3.weight(.semibold) : .headline)
            Spacer()
            Text("\(value) Credits")
                .font(large ? .title2.weight(.bold) : .title3.weight(.semibold))
        }
    }

    private func recalcBonusToUse() {
        let maxBonus = maxBonusAllowed()
        bonusToUse = min(bonusToUse, maxBonus)
    }

    private func maxBonusAllowed() -> Int {
        guard cart.hasDrink else { return 0 }
        return wallet.maxBonusAllowed(for: cart)
    }

    // MARK: - Upsell helpers
    private enum BannerState {
        case noDrink
        case drinkOnly
        case drinkPlusAddon
    }

    private var bannerState: BannerState {
        if !cart.hasDrink { return .noDrink }
        if cart.hasNonDrink { return .drinkPlusAddon }
        return .drinkOnly
    }

    private var upsellItems: [CafeProduct] {
        upsellProducts(menu: menu)
    }

    private var upsellSectionId: String { "upsell-section" }

    private func scrollToUpsell(proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            proxy.scrollTo(upsellSectionId, anchor: .top)
            highlightUpsell = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.25)) {
                highlightUpsell = false
            }
        }
    }

    private func upsellCallout(scrollToUpsell: @escaping () -> Void) -> some View {
        let state = bannerState
        return VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .noDrink:
                Label("Добавьте напиток, чтобы активировать выгодные допы и бонусы", systemImage: "cup.and.saucer.fill")
                    .font(.headline)
                Text("Сначала выберите кофе — тогда допы дадут больше выгоды и кэшбэк.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .drinkOnly:
                Label("Добавьте доп — получите 4% кэшбек", systemImage: "sparkles")
                    .font(.headline)
                Text("И сможете списать больше Bonus+ на этот заказ.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Подобрать допы") {
                    scrollToUpsell()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            case .drinkPlusAddon:
                Label("Кэшбек 4% активирован ✅", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                Text("Bonus+ можно списать по повышенному лимиту.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(state == .drinkPlusAddon ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.15))
        )
    }

    private var upsellSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Рекомендуем к кофе")
                    .font(.headline)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upsellItems) { product in
                        UpsellProductCard(
                            product: product,
                            showBadge: bannerState == .drinkOnly,
                            onAdd: {
                                cart.add(product: product)
                            }
                        )
                        .frame(width: 240)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func upsellProducts(menu: CafeMenu?) -> [CafeProduct] {
        let source = menu ?? MockCafeService.sampleMenu()
        let categories = prioritizedCategories()
        let limits = [6, 3, 3, 2]
        var result: [CafeProduct] = []
        var seen = Set<UUID>()

        func slice(_ category: CafeMenuCategory, limit: Int) {
            guard limit > 0 else { return }
            for product in source.products(for: category) {
                if seen.contains(product.id) { continue }
                result.append(product)
                seen.insert(product.id)
                if result.filter({ $0.category == category }).count >= limit {
                    break
                }
            }
        }

        for (index, category) in categories.enumerated() {
            let limit = index < limits.count ? limits[index] : 2
            slice(category, limit: limit)
        }

        if result.isEmpty {
            // запасной вариант
            result = Array(source.food.prefix(3) + source.syrups.prefix(3))
        }

        return result
    }

    private func prioritizedCategories() -> [CafeMenuCategory] {
        let hasDrink = cart.hasDrink
        let hasFood = cart.hasFood
        let hasSyrup = cart.hasSyrup
        let hasMerch = cart.hasMerch

        if hasMerch {
            return [.merch, .drinks, .food, .syrups]
        }

        if hasDrink && !hasFood {
            return [.food, .syrups, .merch, .drinks]
        }

        if hasFood && !hasDrink {
            return [.drinks, .syrups, .merch, .food]
        }

        if hasDrink && hasFood && !hasSyrup {
            return [.syrups, .merch, .food, .drinks]
        }

        if hasDrink && hasFood && hasSyrup && !hasMerch {
            return [.merch, .food, .drinks, .syrups]
        }

        return [.food, .syrups, .merch, .drinks]
    }
}

private struct CartLineRow: View {
    let line: CartLine
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(line.title)
                    .font(.headline)
                Text(line.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(line.unitPrice) Credits/шт")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(line.lineTotal) Credits")
                    .font(.headline.weight(.bold))
            }
            qtyControl
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    private var qtyControl: some View {
        HStack(spacing: 10) {
            Button(action: onDecrement) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            Text("\(line.quantity)")
                .font(.title3.weight(.semibold))
                .frame(minWidth: 32)
            Button(action: onIncrement) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct UpsellProductCard: View {
    let product: CafeProduct
    let showBadge: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.headline)
                    Text(product.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(product.priceCredits) Credits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if showBadge {
                Text("Активирует 4% кэшбек")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
            }

            Button {
                onAdd()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Добавить")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .overlay(
            Group {
                if showBadge {
                    Text("+4%")
                        .font(.caption2.weight(.bold))
                        .padding(6)
                        .background(Capsule().fill(Color.orange))
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        )
    }
}

private extension CartView {
    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Корзина пустая")
                .font(.title3.weight(.semibold))
            Text("Добавьте напиток или другие товары из меню")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}
