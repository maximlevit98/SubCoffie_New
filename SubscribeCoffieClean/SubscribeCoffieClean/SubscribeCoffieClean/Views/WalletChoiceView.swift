import SwiftUI

struct WalletChoiceView: View {
    let hasCityPassWallet: Bool
    let onCityPassSelected: () -> Void
    let onCityPassCafes: () -> Void
    let onCafeWalletSelected: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Выберите тип кошелька")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Выберите, как вы хотите оплачивать заказы")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.bottom, 8)
                
                // CityPass Card
                WalletTypeCard(
                    title: "CityPass",
                    subtitle: "Единый кошелёк для сети кофеен",
                    description: "Оплачивайте заказы в любой кофейне сети CityPass. Доступно более 50 кофеен в городе.",
                    icon: "creditcard.fill",
                    iconColor: .blue,
                    primaryAction: hasCityPassWallet ? "Пополнить" : "Создать кошелёк",
                    secondaryAction: "Кофейни в CityPass",
                    onPrimary: onCityPassSelected,
                    onSecondary: onCityPassCafes
                )
                
                // Cafe Wallet Card
                WalletTypeCard(
                    title: "Кошелёк кофейни",
                    subtitle: "Кошелёк для конкретной кофейни или сети",
                    description: "Выберите кофейню или сеть и пополните кошелёк для оплаты заказов в выбранном месте.",
                    icon: "cup.and.saucer.fill",
                    iconColor: .brown,
                    primaryAction: "Выбрать кофейню",
                    secondaryAction: nil,
                    onPrimary: onCafeWalletSelected,
                    onSecondary: nil
                )
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Wallet Type Card

private struct WalletTypeCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let iconColor: Color
    let primaryAction: String
    let secondaryAction: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(iconColor)
                    .frame(width: 56, height: 56)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Description
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    onPrimary()
                } label: {
                    Text(primaryAction)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if let secondaryAction = secondaryAction, let onSecondary = onSecondary {
                    Button {
                        onSecondary()
                    } label: {
                        Text(secondaryAction)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

#Preview {
    WalletChoiceView(
        hasCityPassWallet: false,
        onCityPassSelected: {},
        onCityPassCafes: {},
        onCafeWalletSelected: {}
    )
}
