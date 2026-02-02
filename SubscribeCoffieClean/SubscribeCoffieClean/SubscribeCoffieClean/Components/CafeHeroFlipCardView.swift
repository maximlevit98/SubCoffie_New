import SwiftUI

struct CafeHeroFlipCardView: View {
    let isFlipped: Bool

    var body: some View {
        ZStack {
            // Front
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brown.opacity(0.2))

                Image(systemName: "cup.and.saucer.fill")
                    .font(.largeTitle)
                    .foregroundColor(.brown)
            }
            .opacity(isFlipped ? 0 : 1)

            // Back
            VStack(alignment: .leading, spacing: 8) {
                Text("О кофейне")
                    .font(.headline)

                Text("Уютная кофейня рядом с вами. Здесь можно будет разместить адрес, часы работы, описание и фотографии.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Нажмите, чтобы вернуться к фото")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            .opacity(isFlipped ? 1 : 0)
            // чтобы задняя сторона не была зеркальной
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 200)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }
}

#Preview {
    CafeHeroFlipCardView(isFlipped: false)
}
