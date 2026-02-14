//
//  WalletCreateStepView.swift
//  SubscribeCoffieClean
//
//  Explicit wallet creation step before top-up
//

import SwiftUI

struct WalletCreateStepView: View {
    let walletType: WalletType
    let scopeName: String? // Cafe/Network name for cafe_wallet
    let onCreate: () async throws -> Void
    let onCancel: () -> Void
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: iconForWalletType)
                        .font(.system(size: 60))
                        .foregroundColor(colorForWalletType)
                        .padding()
                        .background(colorForWalletType.opacity(0.1))
                        .clipShape(Circle())
                    
                    // Title
                    Text(titleText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text(descriptionText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Info cards
                    VStack(spacing: 12) {
                        infoCard(
                            icon: "checkmark.circle.fill",
                            title: "Быстрое создание",
                            description: "Кошелёк создаётся моментально"
                        )
                        
                        if walletType == .citypass {
                            infoCard(
                                icon: "building.2.fill",
                                title: "Для всех кофеен",
                                description: "Используйте в любой кофейне сети"
                            )
                        } else {
                            if let name = scopeName {
                                infoCard(
                                    icon: "cup.and.saucer.fill",
                                    title: name,
                                    description: "Персональный кошелёк для этой кофейни"
                                )
                            }
                        }
                        
                        infoCard(
                            icon: "arrow.right.circle.fill",
                            title: "Сразу к пополнению",
                            description: "После создания сможете пополнить баланс"
                        )
                    }
                    .padding(.top, 8)
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 32)
                    
                    // Create button
                    Button {
                        Task { await handleCreate() }
                    } label: {
                        if isCreating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Создать кошелёк")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isCreating)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Создание кошелька")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onCancel()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }
    
    // MARK: - Info Card
    
    private func infoCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(colorForWalletType)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Handle Create
    
    private func handleCreate() async {
        isCreating = true
        errorMessage = nil
        
        do {
            try await onCreate()
            // onCreate will handle navigation, no need to dismiss here
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var titleText: String {
        switch walletType {
        case .citypass:
            return "Создайте CityPass кошелёк"
        case .cafe_wallet:
            if let name = scopeName {
                return "Создайте кошелёк\n\"\(name)\""
            }
            return "Создайте кошелёк кофейни"
        }
    }
    
    private var descriptionText: String {
        switch walletType {
        case .citypass:
            return "CityPass позволяет использовать один баланс во всех кофейнях партнёрской сети"
        case .cafe_wallet:
            return "Персональный кошелёк для удобной оплаты в этой кофейне"
        }
    }
    
    private var iconForWalletType: String {
        switch walletType {
        case .citypass:
            return "creditcard.fill"
        case .cafe_wallet:
            return "cup.and.saucer.fill"
        }
    }
    
    private var colorForWalletType: Color {
        switch walletType {
        case .citypass:
            return .blue
        case .cafe_wallet:
            return .green
        }
    }
}

// MARK: - Preview

#Preview("CityPass") {
    WalletCreateStepView(
        walletType: .citypass,
        scopeName: nil,
        onCreate: {
            try await Task.sleep(for: .seconds(1))
        },
        onCancel: {}
    )
}

#Preview("Cafe Wallet") {
    WalletCreateStepView(
        walletType: .cafe_wallet,
        scopeName: "Кофейня на Невском",
        onCreate: {
            try await Task.sleep(for: .seconds(1))
        },
        onCancel: {}
    )
}
