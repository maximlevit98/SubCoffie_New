import SwiftUI

struct CafeMenuItemView: View {

    enum Trailing {
        case right
        case expand(isOpen: Bool)
    }

    let title: String
    let subtitle: String
    let icon: String
    let isPrimary: Bool
    let trailing: Trailing
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isPrimary ? .white : .accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(isPrimary ? .white : .primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isPrimary ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                Image(systemName: trailingSymbol)
                    .foregroundColor(isPrimary ? .white.opacity(0.8) : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isPrimary ? Color.accentColor : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    private var trailingSymbol: String {
        switch trailing {
        case .right:
            return "chevron.right"
        case .expand(let isOpen):
            return isOpen ? "chevron.up" : "chevron.down"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CafeMenuItemView(
            title: "Подписка",
            subtitle: "Выбрать тариф",
            icon: "creditcard.fill",
            isPrimary: true,
            trailing: .expand(isOpen: true),
            action: {}
        )
        CafeMenuItemView(
            title: "Меню напитков",
            subtitle: "Посмотреть ассортимент",
            icon: "menucard.fill",
            isPrimary: false,
            trailing: .right,
            action: {}
        )
    }
    .padding()
}
