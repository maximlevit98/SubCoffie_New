import SwiftUI

struct ConfirmationView: View {
    let cafeName: String
    let selectedPlan: Int?
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Подтверждение подписки ☕️")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(cafeName)
                .font(.headline)

            Text(selectedPlan == nil ? "Тариф не выбран" : "$\(selectedPlan!) / месяц")
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 8) {
                Text("Что входит в подписку:")
                    .font(.headline)

                Text("""
• Любимый кофе каждый день
• Без очередей
• Фиксированная цена
• Можно отменить в любой момент
""")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            }

            Button("Подтвердить") {
                onConfirm()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ConfirmationView(cafeName: "Coffee Point", selectedPlan: 10, onConfirm: {})
}
