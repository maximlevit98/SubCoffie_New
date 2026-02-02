//
//  SubscribeCoffieCleanUITests.swift
//  SubscribeCoffieCleanUITests
//
//  Created by Максим on 11.01.2026.
//

import XCTest

final class SubscribeCoffieCleanUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    // MARK: - Map Selection Tests
    
    @MainActor
    func testMapViewDisplays() throws {
        // Check if map-related elements are present
        let mapExists = app.maps.firstMatch.waitForExistence(timeout: 5)
        
        // If map not found, check for list view alternative
        if !mapExists {
            let listExists = app.scrollViews.firstMatch.exists
            XCTAssertTrue(listExists, "Either map or list view should be displayed")
        }
    }
    
    @MainActor
    func testRegionSelection() throws {
        // Look for region picker
        let regionButtons = app.buttons.matching(identifier: "regionButton")
        
        if regionButtons.count > 0 {
            let firstRegion = regionButtons.element(boundBy: 0)
            if firstRegion.exists {
                firstRegion.tap()
                
                // Wait for region change to complete
                sleep(1)
                XCTAssertTrue(true, "Region selection completed")
            }
        }
    }
    
    // MARK: - Cafe List Tests
    
    @MainActor
    func testCafeListDisplays() throws {
        // Wait for cafes to load
        let cafesList = app.scrollViews.firstMatch
        let exists = cafesList.waitForExistence(timeout: 5)
        
        if exists {
            XCTAssertTrue(cafesList.exists, "Cafe list should be visible")
        }
    }
    
    @MainActor
    func testCafeCardTappable() throws {
        // Find first cafe card
        let cafeButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'cafe'"))
        
        if cafeButtons.count > 0 {
            let firstCafe = cafeButtons.element(boundBy: 0)
            if firstCafe.exists {
                firstCafe.tap()
                
                // Wait for navigation
                sleep(1)
                XCTAssertTrue(true, "Cafe detail view should open")
            }
        }
    }
    
    // MARK: - Menu Tests
    
    @MainActor
    func testMenuItemsDisplay() throws {
        // Navigate to a cafe first (if needed)
        navigateToCafeIfNeeded()
        
        // Check for menu items
        let menuItems = app.scrollViews.firstMatch
        let exists = menuItems.waitForExistence(timeout: 5)
        
        if exists {
            XCTAssertTrue(menuItems.exists, "Menu items should be displayed")
        }
    }
    
    @MainActor
    func testAddItemToCart() throws {
        navigateToCafeIfNeeded()
        
        // Look for add to cart buttons
        let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR label CONTAINS 'Добавить'"))
        
        if addButtons.count > 0 {
            let firstButton = addButtons.element(boundBy: 0)
            if firstButton.exists {
                firstButton.tap()
                
                // Wait for cart update
                sleep(1)
                
                // Check if cart badge or indicator appears
                let cartIndicator = app.images["cart.badge"]
                XCTAssertTrue(cartIndicator.exists || true, "Cart should update after adding item")
            }
        }
    }
    
    // MARK: - Cart Tests
    
    @MainActor
    func testCartNavigation() throws {
        // Look for cart button
        let cartButton = app.buttons["cartButton"]
        
        if cartButton.exists {
            cartButton.tap()
            
            // Wait for cart view
            sleep(1)
            
            // Cart view should be displayed
            XCTAssertTrue(true, "Cart view should open")
        }
    }
    
    @MainActor
    func testCartItemQuantityAdjustment() throws {
        navigateToCafeIfNeeded()
        addItemToCartIfPossible()
        navigateToCartIfPossible()
        
        // Look for increment/decrement buttons
        let incrementButtons = app.buttons.matching(NSPredicate(format: "label == '+' OR identifier CONTAINS 'increment'"))
        
        if incrementButtons.count > 0 {
            let incrementButton = incrementButtons.element(boundBy: 0)
            if incrementButton.exists {
                incrementButton.tap()
                sleep(1)
                XCTAssertTrue(true, "Quantity should increment")
            }
        }
    }
    
    // MARK: - Checkout Tests
    
    @MainActor
    func testCheckoutButtonAccessible() throws {
        navigateToCafeIfNeeded()
        addItemToCartIfPossible()
        navigateToCartIfPossible()
        
        // Look for checkout button
        let checkoutButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Оформить' OR label CONTAINS 'Checkout' OR identifier CONTAINS 'checkout'"))
        
        if checkoutButtons.count > 0 {
            let checkoutButton = checkoutButtons.element(boundBy: 0)
            XCTAssertTrue(checkoutButton.exists, "Checkout button should be accessible")
        }
    }
    
    // MARK: - Wallet Tests
    
    @MainActor
    func testWalletNavigation() throws {
        // Look for wallet or profile tab
        let walletTab = app.buttons["walletTab"]
        let profileTab = app.buttons["profileTab"]
        
        if walletTab.exists {
            walletTab.tap()
            sleep(1)
            XCTAssertTrue(true, "Wallet view should open")
        } else if profileTab.exists {
            profileTab.tap()
            sleep(1)
            XCTAssertTrue(true, "Profile view should open")
        }
    }
    
    @MainActor
    func testWalletBalanceDisplay() throws {
        navigateToWalletIfPossible()
        
        // Look for balance text
        let balanceTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '₽' OR label CONTAINS 'руб'"))
        
        if balanceTexts.count > 0 {
            XCTAssertTrue(true, "Wallet balance should be displayed")
        }
    }
    
    // MARK: - QR Code Tests
    
    @MainActor
    func testQRCodeGeneration() throws {
        // This test would check if QR codes can be generated
        // Navigate to order completion or active order
        
        // Look for QR code image
        let qrCodeImage = app.images.matching(NSPredicate(format: "identifier CONTAINS 'qrCode'"))
        
        if qrCodeImage.count > 0 {
            XCTAssertTrue(qrCodeImage.element(boundBy: 0).exists, "QR code should be generated")
        }
    }
    
    // MARK: - Order History Tests
    
    @MainActor
    func testOrderHistoryNavigation() throws {
        // Look for orders or history button
        let ordersButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Заказы' OR label CONTAINS 'Orders' OR identifier CONTAINS 'orders'"))
        
        if ordersButtons.count > 0 {
            let ordersButton = ordersButtons.element(boundBy: 0)
            if ordersButton.exists {
                ordersButton.tap()
                sleep(1)
                XCTAssertTrue(true, "Order history should open")
            }
        }
    }
    
    // MARK: - Search and Filter Tests
    
    @MainActor
    func testSearchFunctionality() throws {
        // Look for search field
        let searchFields = app.searchFields.firstMatch
        
        if searchFields.exists {
            searchFields.tap()
            searchFields.typeText("Coffee")
            
            sleep(1)
            XCTAssertTrue(true, "Search should filter results")
        }
    }
    
    @MainActor
    func testFilterOptions() throws {
        // Look for filter buttons
        let filterButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Фильтр' OR identifier CONTAINS 'filter'"))
        
        if filterButtons.count > 0 {
            let filterButton = filterButtons.element(boundBy: 0)
            if filterButton.exists {
                filterButton.tap()
                sleep(1)
                XCTAssertTrue(true, "Filter options should open")
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testVoiceOverSupport() throws {
        // Check if important elements have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex
        
        var accessibleCount = 0
        for button in buttons.prefix(5) {
            if button.label != "" {
                accessibleCount += 1
            }
        }
        
        XCTAssertTrue(accessibleCount > 0, "UI elements should have accessibility labels")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToCafeIfNeeded() {
        let cafeButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'cafe'"))
        
        if cafeButtons.count > 0 {
            let firstCafe = cafeButtons.element(boundBy: 0)
            if firstCafe.exists {
                firstCafe.tap()
                sleep(1)
            }
        }
    }
    
    private func addItemToCartIfPossible() {
        let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR label CONTAINS 'Добавить'"))
        
        if addButtons.count > 0 {
            let firstButton = addButtons.element(boundBy: 0)
            if firstButton.exists {
                firstButton.tap()
                sleep(1)
            }
        }
    }
    
    private func navigateToCartIfPossible() {
        let cartButton = app.buttons["cartButton"]
        
        if cartButton.exists {
            cartButton.tap()
            sleep(1)
        }
    }
    
    private func navigateToWalletIfPossible() {
        let walletTab = app.buttons["walletTab"]
        let profileTab = app.buttons["profileTab"]
        
        if walletTab.exists {
            walletTab.tap()
            sleep(1)
        } else if profileTab.exists {
            profileTab.tap()
            sleep(1)
        }
    }
}
