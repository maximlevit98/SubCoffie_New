import SwiftUI

struct QRBottomBarView: View {
    let onTap: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)

                    Text("QR")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

#Preview {
    QRBottomBarView(onTap: {})
}
