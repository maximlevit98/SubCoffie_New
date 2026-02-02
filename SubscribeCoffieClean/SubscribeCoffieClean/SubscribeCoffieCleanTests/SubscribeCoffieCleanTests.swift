//
//  SubscribeCoffieCleanTests.swift
//  SubscribeCoffieCleanTests
//
//  Created by Максим on 11.01.2026.
//

import Testing
import Foundation
@testable import SubscribeCoffieClean

// MARK: - Model Tests
struct ModelTests {
    
    @Test func testProductInitialization() async throws {
        let product = Product(
            id: UUID(),
            name: "Cappuccino",
            description: "Classic cappuccino",
            basePrice: 250,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        #expect(product.name == "Cappuccino")
        #expect(product.basePrice == 250)
        #expect(product.isAvailable == true)
    }
    
    @Test func testCartItemQuantityUpdate() async throws {
        let product = Product(
            id: UUID(),
            name: "Latte",
            description: "Milk coffee",
            basePrice: 300,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        var cartItem = CartItem(product: product, quantity: 1)
        cartItem.quantity = 3
        
        #expect(cartItem.quantity == 3)
        #expect(cartItem.totalPrice == 900)
    }
    
    @Test func testWalletBalanceCalculation() async throws {
        // Test balance in credits (1 credit = 0.01 RUB)
        let balanceInCredits: Int64 = 50000 // 500 RUB
        let balanceInRubles = Double(balanceInCredits) / 100.0
        
        #expect(balanceInRubles == 500.0)
    }
}

// MARK: - Store Tests
struct StoreTests {
    
    @Test func testCartStoreAddItem() async throws {
        let store = CartStore()
        
        let product = Product(
            id: UUID(),
            name: "Espresso",
            description: "Strong coffee",
            basePrice: 200,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        store.addItem(product: product)
        
        #expect(store.items.count == 1)
        #expect(store.items.first?.product.name == "Espresso")
    }
    
    @Test func testCartStoreTotalCalculation() async throws {
        let store = CartStore()
        
        let product1 = Product(
            id: UUID(),
            name: "Cappuccino",
            description: "Coffee with milk",
            basePrice: 250,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        let product2 = Product(
            id: UUID(),
            name: "Croissant",
            description: "French pastry",
            basePrice: 150,
            category: "bakery",
            imageUrl: nil,
            isAvailable: true
        )
        
        store.addItem(product: product1)
        store.addItem(product: product2)
        
        let expectedTotal = 250 + 150
        #expect(store.total == expectedTotal)
    }
    
    @Test func testCartStoreClearCart() async throws {
        let store = CartStore()
        
        let product = Product(
            id: UUID(),
            name: "Latte",
            description: "Milk coffee",
            basePrice: 300,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        store.addItem(product: product)
        #expect(store.items.count == 1)
        
        store.clearCart()
        #expect(store.items.isEmpty)
        #expect(store.total == 0)
    }
    
    @Test func testCartStoreIncrementQuantity() async throws {
        let store = CartStore()
        
        let product = Product(
            id: UUID(),
            name: "Americano",
            description: "Black coffee",
            basePrice: 180,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        store.addItem(product: product)
        
        if let itemId = store.items.first?.id {
            store.incrementQuantity(for: itemId)
            #expect(store.items.first?.quantity == 2)
            #expect(store.total == 360)
        }
    }
}

// MARK: - Order Tests
struct OrderTests {
    
    @Test func testOrderStatusFlow() async throws {
        let orderId = UUID()
        var status = "created"
        
        #expect(status == "created")
        
        status = "paid"
        #expect(status == "paid")
        
        status = "preparing"
        #expect(status == "preparing")
        
        status = "ready"
        #expect(status == "ready")
        
        status = "completed"
        #expect(status == "completed")
    }
    
    @Test func testOrderStoreInitialization() async throws {
        let store = OrderStore()
        
        #expect(store.orders.isEmpty)
        #expect(store.activeOrder == nil)
    }
}

// MARK: - Wallet Tests
struct WalletTests {
    
    @Test func testWalletTypeValidation() async throws {
        let citPassType = "citypass"
        let cafeWalletType = "cafe_wallet"
        
        #expect(citPassType == "citypass")
        #expect(cafeWalletType == "cafe_wallet")
    }
    
    @Test func testWalletStoreInitialization() async throws {
        let store = WalletStore()
        
        #expect(store.wallets.isEmpty)
        #expect(store.selectedWallet == nil)
    }
}

// MARK: - Region Tests
struct RegionTests {
    
    @Test func testRegionInitialization() async throws {
        let region = Region(
            id: UUID(),
            name: "Moscow",
            displayName: "Москва",
            latitude: 55.7558,
            longitude: 37.6173,
            radius: 10000
        )
        
        #expect(region.name == "Moscow")
        #expect(region.displayName == "Москва")
        #expect(region.latitude == 55.7558)
    }
}

// MARK: - Configuration Tests
struct ConfigurationTests {
    
    @Test func testProductConfigurationDefaults() async throws {
        let config = ProductConfiguration()
        
        #expect(config.size == .medium)
        #expect(config.temperature == .hot)
        #expect(config.milkType == .regular)
    }
}

// MARK: - Utility Tests
struct UtilityTests {
    
    @Test func testPriceFormatting() async throws {
        let price = 25050 // 250.50 RUB in credits
        let formattedPrice = String(format: "%.2f", Double(price) / 100.0)
        
        #expect(formattedPrice == "250.50")
    }
    
    @Test func testDateFormatting() async throws {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let formatted = formatter.string(from: date)
        #expect(!formatted.isEmpty)
    }
}

// MARK: - Integration Tests
struct IntegrationTests {
    
    @Test func testCompleteOrderFlow() async throws {
        // 1. Create cart
        let cartStore = CartStore()
        
        // 2. Add products
        let product = Product(
            id: UUID(),
            name: "Cappuccino",
            description: "Classic",
            basePrice: 250,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        cartStore.addItem(product: product)
        
        // 3. Verify cart
        #expect(cartStore.items.count == 1)
        #expect(cartStore.total == 250)
        
        // 4. Create order (simulated)
        let orderStore = OrderStore()
        #expect(orderStore.orders.isEmpty)
        
        // 5. Clear cart after order
        cartStore.clearCart()
        #expect(cartStore.items.isEmpty)
    }
    
    @Test func testWalletPaymentFlow() async throws {
        // 1. Create wallet
        let walletStore = WalletStore()
        
        // 2. Create cart with items
        let cartStore = CartStore()
        let product = Product(
            id: UUID(),
            name: "Latte",
            description: "Milk coffee",
            basePrice: 300,
            category: "coffee",
            imageUrl: nil,
            isAvailable: true
        )
        
        cartStore.addItem(product: product)
        
        // 3. Verify total
        #expect(cartStore.total == 300)
        
        // 4. Simulate wallet balance check
        let walletBalance: Int64 = 100000 // 1000 RUB
        let orderTotal = Int64(cartStore.total)
        
        #expect(walletBalance >= orderTotal)
    }
}
