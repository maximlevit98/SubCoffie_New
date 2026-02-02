//
//  PaymentMethodsView.swift
//  SubscribeCoffieClean
//
//  View for managing payment methods (mock cards for MVP)
//

import SwiftUI

struct PaymentMethodsView: View {
    let userId: UUID
    
    @StateObject private var walletService = WalletService()
    @State private var paymentMethods: [PaymentMethod] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddCardSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Demo Mode Banner
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DEMO MODE")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("Карты фиктивные, оплата не производится")
                                .font(.caption2)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
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
                                Task { await loadPaymentMethods() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        // Payment methods list
                        if paymentMethods.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("Нет сохранённых карт")
                                    .font(.headline)
                                Text("Добавьте демо-карту для тестирования оплаты")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(paymentMethods) { method in
                                    PaymentMethodCardView(
                                        method: method,
                                        onDelete: {
                                            Task { await deleteMethod(method) }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Add card button
                        Button {
                            showAddCardSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Добавить демо-карту")
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
            .navigationTitle("Платёжные методы")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadPaymentMethods()
            }
            .task {
                await loadPaymentMethods()
            }
            .sheet(isPresented: $showAddCardSheet) {
                AddCardSheet(
                    userId: userId,
                    onCardAdded: {
                        showAddCardSheet = false
                        Task { await loadPaymentMethods() }
                    }
                )
            }
        }
    }
    
    private func loadPaymentMethods() async {
        isLoading = true
        errorMessage = nil
        
        do {
            paymentMethods = try await walletService.getPaymentMethods(userId: userId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func deleteMethod(_ method: PaymentMethod) async {
        do {
            try await walletService.deletePaymentMethod(methodId: method.id)
            await loadPaymentMethods()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Payment Method Card View
private struct PaymentMethodCardView: View {
    let method: PaymentMethod
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Card icon
            Image(systemName: method.brandIcon)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(method.displayName)
                        .font(.headline)
                    
                    if method.isDemoCard {
                        Text("DEMO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    
                    if method.isDefault {
                        Text("По умолчанию")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text("Добавлена \(method.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Add Card Sheet
private struct AddCardSheet: View {
    let userId: UUID
    let onCardAdded: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletService = WalletService()
    @State private var cardNumber = ""
    @State private var selectedBrand = "visa"
    @State private var isDefault = false
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private let cardBrands = ["visa", "mastercard", "mir"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DEMO MODE")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("Реальная карта не требуется")
                                .font(.caption2)
                        }
                    }
                    .listRowBackground(Color.yellow.opacity(0.15))
                }
                
                Section(header: Text("Данные карты (демо)")) {
                    TextField("Последние 4 цифры", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .onChange(of: cardNumber) { _, newValue in
                            // Limit to 4 digits
                            if newValue.count > 4 {
                                cardNumber = String(newValue.prefix(4))
                            }
                        }
                    
                    Picker("Бренд карты", selection: $selectedBrand) {
                        ForEach(cardBrands, id: \.self) { brand in
                            Text(brand.capitalized).tag(brand)
                        }
                    }
                    
                    Toggle("Установить по умолчанию", isOn: $isDefault)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Добавить демо-карту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        Task { await addCard() }
                    }
                    .disabled(cardNumber.count != 4 || isAdding)
                }
            }
        }
    }
    
    private func addCard() async {
        guard cardNumber.count == 4 else {
            errorMessage = "Введите 4 цифры"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        do {
            _ = try await walletService.addMockPaymentMethod(
                userId: userId,
                cardLast4: cardNumber,
                cardBrand: selectedBrand,
                isDefault: isDefault
            )
            onCardAdded()
        } catch {
            errorMessage = error.localizedDescription
            isAdding = false
        }
    }
}

#Preview {
    PaymentMethodsView(userId: UUID())
}
