import SwiftUI

struct ProductDetailView: View {
    let product: Product
    let onAdd: (_ configuration: ProductConfiguration, _ qty: Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var qty: Int = 1

    // Кастомизация только для напитков (MVP)
    enum DrinkSize: String, CaseIterable, Identifiable {
        case s = "S", m = "M", l = "L"
        var id: String { rawValue }
        var delta: Int { self == .s ? 0 : (self == .m ? 30 : 60) }
    }

    enum Milk: String, CaseIterable, Identifiable {
        case regular = "Обычное"
        case oat = "Овсяное"
        case almond = "Миндальное"
        var id: String { rawValue }
        var delta: Int { self == .regular ? 0 : 20 }
    }

    enum Syrup: String, CaseIterable, Identifiable {
        case none = "Без сиропа"
        case vanilla = "Ваниль"
        case caramel = "Карамель"
        var id: String { rawValue }
        var delta: Int { self == .none ? 0 : 15 }
    }

    @State private var size: DrinkSize = .m
    @State private var milk: Milk = .regular
    @State private var syrup: Syrup = .none
    @State private var extraShot: Bool = false

    private var unitPrice: Int {
        var p = product.basePriceCredits
        if product.type == .drink {
            p += size.delta
            p += milk.delta
            p += syrup.delta
            p += (extraShot ? 30 : 0)
        }
        return p
    }

    private var totalPrice: Int { unitPrice * qty }

    private var suffix: String {
        guard product.type == .drink else { return "" }
        var parts: [String] = []
        parts.append(size.rawValue)
        if milk != .regular { parts.append(milk == .oat ? "oat" : "almond") }
        if syrup != .none { parts.append(syrup == .vanilla ? "vanilla" : "caramel") }
        if extraShot { parts.append("extra shot") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(product.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Закрыть") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            Text(product.subtitle)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if product.type == .drink {
                VStack(spacing: 12) {
                    Picker("Размер", selection: $size) {
                        ForEach(DrinkSize.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Молоко", selection: $milk) {
                        ForEach(Milk.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Сироп", selection: $syrup) {
                        ForEach(Syrup.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Доп. шот эспрессо (+30)", isOn: $extraShot)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(14)
            }

            Stepper("Количество: \(qty)", value: $qty, in: 1...10)

            HStack {
                Text("Итого:")
                Spacer()
                Text("\(totalPrice) Credits")
                    .fontWeight(.semibold)
            }

            Button("Добавить в корзину") {
                let config = ProductConfiguration(titleSuffix: suffix, unitPriceCredits: unitPrice)
                onAdd(config, qty)
                dismiss()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ProductDetailView(
        product: Product(id: "latte", categoryId: "coffee", title: "Латте", subtitle: "Мягкий кофе с молоком", type: .drink, basePriceCredits: 240, isAvailable: true),
        onAdd: { _, _ in }
    )
}
