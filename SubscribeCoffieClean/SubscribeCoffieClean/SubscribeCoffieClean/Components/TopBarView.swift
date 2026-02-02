import SwiftUI

struct TopBarView: View {
    let title: String
    let canGoBack: Bool
    let onBack: () -> Void
    let showsLogout: Bool
    let onLogout: () -> Void
    let showsProfile: Bool
    let onProfile: (() -> Void)?
    let showsWalletButton: Bool
    let onWallet: (() -> Void)?

    init(
        title: String,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        showsLogout: Bool = true,
        onLogout: @escaping () -> Void,
        showsProfile: Bool = true,
        onProfile: (() -> Void)? = nil,
        showsWalletButton: Bool = false,
        onWallet: (() -> Void)? = nil
    ) {
        self.title = title
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.showsLogout = showsLogout
        self.onLogout = onLogout
        self.showsProfile = showsProfile
        self.onProfile = onProfile
        self.showsWalletButton = showsWalletButton
        self.onWallet = onWallet
    }

    var body: some View {
        HStack(spacing: 12) {
            if canGoBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 60, height: 1)
            }

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            if showsWalletButton, let onWallet {
                Button(action: onWallet) {
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if showsProfile, let onProfile {
                Button(action: onProfile) {
                    Image(systemName: "person.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if showsLogout {
                Button(action: onLogout) {
                    Label("Выход", systemImage: "rectangle.portrait.and.arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}
