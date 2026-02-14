//
//  RealWalletStore.swift
//  SubscribeCoffieClean
//
//  Store for managing real wallets from Supabase (replaces demo WalletStore and CafeWalletStore)
//

import Foundation
import Combine
import SwiftUI
import Auth

@MainActor
final class RealWalletStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All wallets for the current user
    @Published private(set) var wallets: [Wallet] = []
    
    /// Currently selected wallet
    @Published private(set) var selectedWallet: Wallet?
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Error message
    @Published private(set) var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let walletService: WalletService
    private let authService: AuthService
    private var loadedUserId: UUID?
    
    // MARK: - Persistence (AppStorage keys for selected wallet)
    
    @AppStorage("sc_selectedWalletId") private var selectedWalletId: String = ""
    @AppStorage("sc_selectedWalletType") private var selectedWalletType: String = ""
    
    // Legacy keys (migration)
    @AppStorage("sc_selected_wallet_id") private var legacySelectedWalletId: String = ""
    @AppStorage("sc_selected_wallet_type") private var legacySelectedWalletType: String = ""
    
    // MARK: - Initialization
    
    init(walletService: WalletService? = nil, authService: AuthService = .shared) {
        self.walletService = walletService ?? WalletService()
        self.authService = authService
    }
    
    // MARK: - Public API
    
    /// Load all wallets for the current user
    func loadWallets() async {
        guard let userId = authService.currentUser?.id else {
            wallets = []
            selectedWallet = nil
            clearSelection()
            loadedUserId = nil
            errorMessage = "User not authenticated"
            return
        }
        
        // Important for multi-account sessions:
        // do not keep previous user's wallets while a new user's data is loading.
        if loadedUserId != userId {
            wallets = []
            selectedWallet = nil
            clearSelection()
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedWallets = try await walletService.getUserWallets(userId: userId)
            
            await MainActor.run {
                self.wallets = loadedWallets
                self.isLoading = false
                self.loadedUserId = userId
                
                // Restore selected wallet from AppStorage
                restoreSelectedWallet()
                
                AppLogger.debug("✅ Loaded \(loadedWallets.count) wallets from Supabase")
            }
        } catch {
            await MainActor.run {
                // If this was a user switch and load failed, keep UI in "no wallets" state
                // instead of showing a previous account's wallets.
                if self.loadedUserId != userId {
                    self.wallets = []
                    self.selectedWallet = nil
                    self.clearSelection()
                }
                self.errorMessage = "Failed to load wallets: \(error.localizedDescription)"
                self.isLoading = false
                AppLogger.debug("❌ Failed to load wallets: \(error)")
            }
        }
    }
    
    /// Create a new CityPass wallet
    func createCityPassWallet() async throws -> Wallet {
        guard let userId = authService.currentUser?.id else {
            throw NetworkError.unauthorized
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let walletId = try await walletService.createCityPassWallet(userId: userId)
            
            // Reload wallets to get the new one
            await loadWallets()
            
            // Find and select the new wallet
            if let newWallet = wallets.first(where: { $0.id == walletId }) {
                selectWallet(newWallet)
                AppLogger.debug("✅ Created CityPass wallet: \(walletId)")
                return newWallet
            }
            
            throw NetworkError.decoding(NSError(domain: "RealWalletStore", code: -1))
        } catch let error as WalletServiceError {
            await MainActor.run {
                switch error {
                case .authenticationRequired, .userNotFoundInDatabase:
                    self.errorMessage = error.localizedDescription
                    // Session already cleared by WalletService
                case .networkError(let underlyingError):
                    self.errorMessage = "Ошибка сети: \(underlyingError.localizedDescription)"
                case .unknown(let message):
                    self.errorMessage = message
                }
                self.isLoading = false
            }
            throw error
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create CityPass wallet: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Create a new Cafe Wallet
    func createCafeWallet(cafeId: UUID?, networkId: UUID?) async throws -> Wallet {
        guard let userId = authService.currentUser?.id else {
            throw NetworkError.unauthorized
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let walletId = try await walletService.createCafeWallet(userId: userId, cafeId: cafeId, networkId: networkId)
            
            // Reload wallets to get the new one
            await loadWallets()
            
            // Find and select the new wallet
            if let newWallet = wallets.first(where: { $0.id == walletId }) {
                selectWallet(newWallet)
                AppLogger.debug("✅ Created Cafe wallet: \(walletId) for cafe: \(cafeId?.uuidString ?? "nil") network: \(networkId?.uuidString ?? "nil")")
                return newWallet
            }
            
            throw NetworkError.decoding(NSError(domain: "RealWalletStore", code: -1))
        } catch let error as WalletServiceError {
            await MainActor.run {
                switch error {
                case .authenticationRequired, .userNotFoundInDatabase:
                    self.errorMessage = error.localizedDescription
                    // Session already cleared by WalletService
                case .networkError(let underlyingError):
                    self.errorMessage = "Ошибка сети: \(underlyingError.localizedDescription)"
                case .unknown(let message):
                    self.errorMessage = message
                }
                self.isLoading = false
            }
            throw error
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create Cafe wallet: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Select a wallet (persists to AppStorage)
    func selectWallet(_ wallet: Wallet) {
        selectedWallet = wallet
        selectedWalletId = wallet.id.uuidString
        selectedWalletType = wallet.walletType.rawValue
        
        AppLogger.debug("✅ Selected wallet: \(wallet.id) type: \(wallet.walletType)")
    }
    
    /// Clear wallet selection
    func clearSelection() {
        selectedWallet = nil
        selectedWalletId = ""
        selectedWalletType = ""
        legacySelectedWalletId = ""
        legacySelectedWalletType = ""
        
        AppLogger.debug("🗑️ Cleared wallet selection")
    }
    
    /// Reset all wallet state on logout/account switch.
    func resetForSignOut() {
        wallets = []
        selectedWallet = nil
        errorMessage = nil
        isLoading = false
        loadedUserId = nil
        clearSelection()
    }
    
    /// Get CityPass wallet (or nil if not exists)
    var cityPassWallet: Wallet? {
        wallets.first(where: { $0.walletType == .citypass })
    }
    
    /// Get Cafe Wallet for a specific cafe (or nil if not exists)
    func cafeWallet(forCafe cafeId: UUID) -> Wallet? {
        wallets.first(where: {
            $0.walletType == .cafe_wallet && $0.cafeId == cafeId
        })
    }
    
    /// Get Cafe Wallet for a specific network (or nil if not exists)
    func cafeWallet(forNetwork networkId: UUID) -> Wallet? {
        wallets.first(where: {
            $0.walletType == .cafe_wallet && $0.networkId == networkId
        })
    }
    
    /// Get all Cafe Wallets
    var cafeWallets: [Wallet] {
        wallets.filter { $0.walletType == .cafe_wallet }
    }
    
    /// Refresh wallet data (after top-up, payment, etc.)
    func refreshWallets() async {
        await loadWallets()
    }
    
    // MARK: - Private Helpers
    
    /// Restore selected wallet from AppStorage
    private func restoreSelectedWallet() {
        // Migrate legacy keys if present
        if selectedWalletId.isEmpty, !legacySelectedWalletId.isEmpty {
            selectedWalletId = legacySelectedWalletId
            selectedWalletType = legacySelectedWalletType
            legacySelectedWalletId = ""
            legacySelectedWalletType = ""
        }
        
        guard !selectedWalletId.isEmpty,
              let walletId = UUID(uuidString: selectedWalletId) else {
            // No saved selection, try to auto-select CityPass
            if let cityPass = cityPassWallet {
                selectWallet(cityPass)
            } else if let firstWallet = wallets.first {
                selectWallet(firstWallet)
            }
            return
        }
        
        // Find wallet by saved ID
        if let wallet = wallets.first(where: { $0.id == walletId }) {
            selectedWallet = wallet
            AppLogger.debug("✅ Restored selected wallet: \(walletId)")
        } else {
            // Saved wallet not found, clear selection
            clearSelection()
            
            // Try to auto-select CityPass or first wallet
            if let cityPass = cityPassWallet {
                selectWallet(cityPass)
            } else if let firstWallet = wallets.first {
                selectWallet(firstWallet)
            }
        }
    }
}

// MARK: - Helper Extensions

extension RealWalletStore {
    /// Check if user has a CityPass wallet
    var hasCityPass: Bool {
        cityPassWallet != nil
    }
    
    /// Check if user has any Cafe Wallets
    var hasCafeWallets: Bool {
        !cafeWallets.isEmpty
    }
    
    /// Check if user has any wallets
    var hasWallets: Bool {
        !wallets.isEmpty
    }
    
    /// Get wallet by ID
    func wallet(by id: UUID) -> Wallet? {
        wallets.first(where: { $0.id == id })
    }
}
