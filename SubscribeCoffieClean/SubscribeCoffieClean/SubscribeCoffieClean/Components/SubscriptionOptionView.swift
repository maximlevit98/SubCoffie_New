import SwiftUI

struct SubscriptionOptionView: View {
    let price: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text("$\(price) / месяц")
                        .font(.headline)

                    Text("Подписка на кофе")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        SubscriptionOptionView(price: 5, isSelected: false, onSelect: {})
        SubscriptionOptionView(price: 10, isSelected: true, onSelect: {})
    }
    .padding()
}
