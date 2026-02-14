//
//  CheckoutView.swift
//  SubscribeCoffieClean
//
//  Checkout view for order finalization
//

import SwiftUI

struct CheckoutView: View {
    @Binding var isPresented: Bool
    let cart: CartStore
    let wallet: WalletStore  // Deprecated: kept for compatibility
    let selectedCafe: CafeSummary?
    let onOrderSuccess: (UUID) -> Void
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var realWalletStore: RealWalletStore
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Оформление заказа")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let cafe = selectedCafe {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cafe.name)
                                .font(.headline)
                            Text(cafe.address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Cart summary
                    cartSummaryView
                }
                .padding()
            }
            .navigationBarItems(
                leading: Button("Закрыть") {
                    isPresented = false
                },
                trailing: Button(action: {
                    handleCheckout()
                }) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Оформить")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(cart.lines.isEmpty || isProcessing)
            )
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private var cartSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ваш заказ:")
                .font(.headline)
            
            cartItemsList
            
            Divider()
            
            HStack {
                Text("Итого:")
                    .fontWeight(.bold)
                Spacer()
                Text("\(cart.subtotalCredits) ₽")
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var cartItemsList: some View {
        let cartLines = cart.lines
        ForEach(Array(cartLines.enumerated()), id: \.offset) { index, line in
            HStack {
                Text("\(line.quantity)x")
                    .foregroundColor(.secondary)
                Text(line.product.name)
                Spacer()
                Text("\(line.lineTotal) ₽")
            }
        }
    }
    
    private func handleCheckout() {
        guard let cafe = selectedCafe else {
            errorMessage = "Не выбрана кофейня"
            showError = true
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Convert cart items to order items
                let items = cart.lines.map { line in
                    OrderItemRequest(
                        menuItemId: line.product.id,
                        quantity: line.quantity,
                        modifiers: []
                    )
                }
                
                #if DEBUG
                print("🛒 [CheckoutView] Creating order for cafe: \(cafe.name)")
                print("🛒 [CheckoutView] Items count: \(items.count)")
                print("🛒 [CheckoutView] Total: \(cart.subtotalCredits) credits")
                #endif
                
                // Create order using OrderService with real user data
                let customerName = authService.userProfile?.fullName ?? "Unknown User"
                let customerPhone = authService.userProfile?.phone ?? ""
                
                let result = try await OrderService.shared.createOrder(
                    cafeId: cafe.id,
                    orderType: "now",
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerNotes: nil,
                    paymentMethod: "wallet",
                    items: items
                )
                
                #if DEBUG
                print("✅ [CheckoutView] Order created successfully: \(result.orderId)")
                print("✅ [CheckoutView] Order number: \(result.orderNumber)")
                #endif
                
                await MainActor.run {
                    onOrderSuccess(result.orderId)
                    isPresented = false
                    isProcessing = false
                }
                
            } catch {
                #if DEBUG
                print("❌ [CheckoutView] Failed to create order: \(error)")
                #endif
                
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Не удалось создать заказ: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
