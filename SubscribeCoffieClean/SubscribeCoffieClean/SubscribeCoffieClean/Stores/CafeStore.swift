//
//  CafeStore.swift
//  SubscribeCoffieClean
//
//  ObservableObject for managing cafe list, loading, and filtering
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CafeStore: ObservableObject {
    @Published var cafes: [CafeSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isUsingMockData: Bool = false
    
    private var didLoad: Bool = false
    private let repository: CafeRepository
    
    init(repository: CafeRepository = CafeRepository()) {
        self.repository = repository
    }
    
    /// Load cafes from Supabase or fallback to mock data
    /// - Parameter force: Force reload even if already loaded
    func loadCafes(force: Bool = false) async {
        // Prevent duplicate loads
        if isLoading { return }
        if didLoad && !force { return }
        
        isLoading = true
        errorMessage = nil
        
        print("📍 CafeStore: Loading cafes...")
        
        let result = await repository.fetchCafes()
        
        // If Supabase failed, use mock data
        if result.usedFallback || result.cafes.isEmpty {
            print("⚠️ CafeStore: Using mock data (Supabase unavailable or empty)")
            cafes = mockCafesWithExtendedData()
            isUsingMockData = true
            errorMessage = "Supabase недоступен, показываем демо-данные."
        } else {
            print("✅ CafeStore: Loaded \(result.cafes.count) cafes from Supabase")
            cafes = result.cafes
            isUsingMockData = false
            errorMessage = nil
        }
        
        isLoading = false
        didLoad = true
    }
    
    /// Force retry loading cafes
    func retry() async {
        print("🔄 CafeStore: Retrying load...")
        didLoad = false
        await loadCafes(force: true)
    }
    
    /// Get mock cafes with extended data (rating, avgCheckCredits)
    private func mockCafesWithExtendedData() -> [CafeSummary] {
        var cafes = MockCafeService.demoCafes()
        
        // Add realistic rating and avgCheck data
        cafes = cafes.enumerated().map { index, cafe in
            CafeSummary(
                id: cafe.id,
                name: cafe.name,
                address: cafe.address,
                mode: cafe.mode,
                etaMinutes: cafe.etaMinutes,
                activeOrders: cafe.activeOrders,
                maxActiveOrders: cafe.maxActiveOrders,
                distanceMinutes: cafe.distanceMinutes,
                rating: [4.8, 4.5, 4.2, 4.6, 4.3][index % 5],
                avgCheckCredits: [350, 420, 280, 390, 310][index % 5]
            )
        }
        
        return cafes
    }
}
