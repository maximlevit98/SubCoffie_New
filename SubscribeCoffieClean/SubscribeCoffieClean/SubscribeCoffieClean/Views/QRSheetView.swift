import SwiftUI

struct QRSheetView: View {
    let title: String
    let payload: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            QRCodeView(payload: payload, size: 240)

            Text(payload)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Закрыть") {
                onClose()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}
