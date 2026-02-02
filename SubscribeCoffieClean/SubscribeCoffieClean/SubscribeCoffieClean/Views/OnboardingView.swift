import SwiftUI

struct OnboardingView: View {
    let onChooseCafe: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Подписка на кофе ☕️")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Выберите любимую кофейню на карте и оформите подписку за пару шагов.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Выбрать кофейню") {
                onChooseCafe()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    OnboardingView(onChooseCafe: {})
}
