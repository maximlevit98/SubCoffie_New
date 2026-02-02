//
//  WalletSelectionView.swift
//  SubscribeCoffieClean
//
//  View for selecting and managing wallets
//

import SwiftUI

struct WalletSelectionView: View {
    let userId: UUID
    
    @StateObject private var walletService = WalletService()
    @State private var wallets: [Wallet] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateWalletSheet = false
    @State private var selectedWalletType: WalletType = .citypass
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with demo badge
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Мои кошельки")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Управление балансом")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("DEMO")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    .padding()
                    
                    if isLoading {
                        ProgressView("Загрузка...")
                            .padding()
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Ошибка загрузки")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Повторить") {
                                Task { await loadWallets() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        // Wallets list
                        if wallets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "wallet.pass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("У вас пока нет кошельков")
                                    .font(.headline)
                                Text("Создайте первый кошелёк для удобной оплаты")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(wallets) { wallet in
                                WalletCardView(wallet: wallet)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Create wallet button
                        Button {
                            showCreateWalletSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Создать кошелёк")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .refreshable {
                await loadWallets()
            }
            .task {
                await loadWallets()
            }
            .sheet(isPresented: $showCreateWalletSheet) {
                CreateWalletSheet(
                    userId: userId,
                    onWalletCreated: {
                        showCreateWalletSheet = false
                        Task { await loadWallets() }
                    }
                )
            }
        }
    }
    
    private func loadWallets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            wallets = try await walletService.getUserWallets(userId: userId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Wallet Card View
private struct WalletCardView: View {
    let wallet: Wallet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: wallet.walletType.icon)
                    .font(.title2)
                    .foregroundColor(colorFor(wallet.walletType))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.displayTitle)
                        .font(.headline)
                    if let subtitle = wallet.displaySubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(wallet.walletType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorFor(wallet.walletType).opacity(0.2))
                    .foregroundColor(colorFor(wallet.walletType))
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Balance
            HStack {
                VStack(alignment: .leading) {
                    Text("Баланс")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(wallet.balanceCredits) ₽")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Всего пополнений")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(wallet.lifetimeTopUpCredits) ₽")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Top-up button
            NavigationLink {
                WalletTopUpView(wallet: wallet)
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Пополнить")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func colorFor(_ type: WalletType) -> Color {
        switch type {
        case .citypass:
            return .blue
        case .cafe_wallet:
            return .green
        }
    }
}

// MARK: - Create Wallet Sheet
private struct CreateWalletSheet: View {
    let userId: UUID
    let onWalletCreated: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletService = WalletService()
    @State private var selectedType: WalletType = .citypass
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showCafeSelection = false
    @State private var selectedCafeId: UUID?
    @State private var selectedNetworkId: UUID?
    @State private var selectionName: String?
    
    var canCreate: Bool {
        switch selectedType {
        case .citypass:
            return true
        case .cafe_wallet:
            return selectedCafeId != nil || selectedNetworkId != nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Type selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Выберите тип кошелька")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(WalletType.allCases, id: \.self) { type in
                            WalletTypeOption(
                                type: type,
                                isSelected: selectedType == type,
                                onTap: { 
                                    selectedType = type
                                    if type == .cafe_wallet {
                                        // Reset selection when switching to cafe wallet
                                        selectedCafeId = nil
                                        selectedNetworkId = nil
                                        selectionName = nil
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Cafe/Network selection for cafe_wallet
                    if selectedType == .cafe_wallet {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Выберите кофейню или сеть")
                                .font(.headline)
                            
                            if let name = selectionName {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Выбрано:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                    Button("Изменить") {
                                        showCafeSelection = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Button {
                                    showCafeSelection = true
                                } label: {
                                    HStack {
                                        Image(systemName: "building.2")
                                        Text("Выбрать кофейню/сеть")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("Cafe Wallet будет работать только в выбранной кофейне или во всех точках выбранной сети.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            // Create button (fixed at bottom)
            VStack {
                Button {
                    Task { await createWallet() }
                } label: {
                    if isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Создать кошелёк")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(canCreate ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!canCreate || isCreating)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
            
            .navigationTitle("Новый кошелёк")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCafeSelection) {
                CafeNetworkSelectionView(
                    selectedCafeId: $selectedCafeId,
                    selectedNetworkId: $selectedNetworkId,
                    selectionName: $selectionName
                )
            }
        }
    }
    
    private func createWallet() async {
        isCreating = true
        errorMessage = nil
        
        do {
            switch selectedType {
            case .citypass:
                _ = try await walletService.createCityPassWallet(userId: userId)
            case .cafe_wallet:
                _ = try await walletService.createCafeWallet(
                    userId: userId,
                    cafeId: selectedCafeId,
                    networkId: selectedNetworkId
                )
            }
            
            onWalletCreated()
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}

// MARK: - Wallet Type Option
private struct WalletTypeOption: View {
    let type: WalletType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : colorFor(type))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? colorFor(type) : colorFor(type).opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? colorFor(type) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func colorFor(_ type: WalletType) -> Color {
        switch type {
        case .citypass:
            return .blue
        case .cafe_wallet:
            return .green
        }
    }
}

// MARK: - Cafe/Network Selection View
private struct CafeNetworkSelectionView: View {
    @Binding var selectedCafeId: UUID?
    @Binding var selectedNetworkId: UUID?
    @Binding var selectionName: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cafeService = CafeRemoteService()
    @StateObject private var walletService = WalletService()
    
    @State private var cafes: [CafeSummary] = []
    @State private var networksWithCafes: [(network: NetworkInfo, cafes: [NetworkCafe])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSegment = 0 // 0 = Cafes, 1 = Networks
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker
                Picker("Тип", selection: $selectedSegment) {
                    Text("Кофейни").tag(0)
                    Text("Сети").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if isLoading {
                    ProgressView("Загрузка...")
                        .frame(maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Ошибка загрузки")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Повторить") {
                            Task { await loadData() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if selectedSegment == 0 {
                                // Cafes list
                                if cafes.isEmpty {
                                    Text("Нет доступных кофеен")
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    ForEach(cafes) { cafe in
                                        CafeSelectionRow(
                                            cafe: cafe,
                                            isSelected: selectedCafeId == cafe.id,
                                            onTap: {
                                                selectedCafeId = cafe.id
                                                selectedNetworkId = nil
                                                selectionName = cafe.name
                                                dismiss()
                                            }
                                        )
                                    }
                                }
                            } else {
                                // Networks list
                                if networksWithCafes.isEmpty {
                                    Text("Нет доступных сетей")
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    ForEach(networksWithCafes, id: \.network.id) { item in
                                        NetworkSelectionRow(
                                            network: item.network,
                                            cafes: item.cafes,
                                            isSelected: selectedNetworkId == item.network.id,
                                            onTap: {
                                                selectedNetworkId = item.network.id
                                                selectedCafeId = nil
                                                selectionName = "Сеть: \(item.network.name)"
                                                dismiss()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Выбор кофейни/сети")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load cafes
            cafes = try await cafeService.fetchCafes()
            
            // Load networks by checking each cafe
            var networksMap: [UUID: (network: NetworkInfo, cafes: Set<UUID>)] = [:]
            
            for cafe in cafes {
                if let network = try? await walletService.getCafeNetwork(cafeId: cafe.id) {
                    if networksMap[network.id] != nil {
                        networksMap[network.id]?.cafes.insert(cafe.id)
                    } else {
                        networksMap[network.id] = (network: network, cafes: [cafe.id])
                    }
                }
            }
            
            // Load cafe details for each network
            var result: [(network: NetworkInfo, cafes: [NetworkCafe])] = []
            for (_, value) in networksMap {
                let networkCafes = try await walletService.getNetworkCafes(networkId: value.network.id)
                result.append((network: value.network, cafes: networkCafes))
            }
            
            networksWithCafes = result.sorted { $0.network.name < $1.network.name }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Cafe Selection Row
private struct CafeSelectionRow: View {
    let cafe: CafeSummary
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(cafe.address)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Network Selection Row
private struct NetworkSelectionRow: View {
    let network: NetworkInfo
    let cafes: [NetworkCafe]
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .green)
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Color.green : Color.green.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(network.name)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        Text("\(network.cafeCount) кофе\(network.cafeCount == 1 ? "йня" : network.cafeCount < 5 ? "йни" : "ен") в сети")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }
                
                // Show some cafe names
                if !cafes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Кофейни:")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        ForEach(cafes.prefix(3)) { cafe in
                            Text("• \(cafe.name)")
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        if cafes.count > 3 {
                            Text("и ещё \(cafes.count - 3)...")
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }
                    }
                    .padding(.leading, 56)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WalletSelectionView(userId: UUID())
}
