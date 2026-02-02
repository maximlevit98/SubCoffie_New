//
//  WalletModels.swift
//  SubscribeCoffieClean
//
//  Models for wallet types and payment methods
//

import Foundation

// MARK: - Wallet Type Enum
enum WalletType: String, Codable, CaseIterable {
    case citypass
    case cafe_wallet = "cafe_wallet"
    
    var displayName: String {
        switch self {
        case .citypass:
            return "CityPass"
        case .cafe_wallet:
            return "Cafe Wallet"
        }
    }
    
    var description: String {
        switch self {
        case .citypass:
            return "Универсальный кошелёк для всех кофеен"
        case .cafe_wallet:
            return "Привязан к конкретной кофейне или сети"
        }
    }
    
    var icon: String {
        switch self {
        case .citypass:
            return "creditcard.circle.fill"
        case .cafe_wallet:
            return "cup.and.saucer.fill"
        }
    }
    
    var color: String {
        switch self {
        case .citypass:
            return "blue"
        case .cafe_wallet:
            return "green"
        }
    }
}

// MARK: - Wallet Domain Model
struct Wallet: Identifiable, Codable, Equatable {
    let id: UUID
    let walletType: WalletType
    let balanceCredits: Int
    let lifetimeTopUpCredits: Int
    let cafeId: UUID?
    let cafeName: String?
    let networkId: UUID?
    let networkName: String?
    let createdAt: Date
    
    var displayTitle: String {
        switch walletType {
        case .citypass:
            return "CityPass"
        case .cafe_wallet:
            if let networkName = networkName {
                return "Сеть: \(networkName)"
            } else if let cafeName = cafeName {
                return cafeName
            } else {
                return "Cafe Wallet"
            }
        }
    }
    
    var displaySubtitle: String? {
        switch walletType {
        case .citypass:
            return "Работает во всех кофейнях"
        case .cafe_wallet:
            if networkName != nil {
                return "Работает во всех точках сети"
            } else {
                return "Работает только в этой кофейне"
            }
        }
    }
}

// MARK: - Payment Method Domain Model
struct PaymentMethod: Identifiable, Codable, Equatable {
    let id: UUID
    let cardLast4: String
    let cardBrand: String
    let isDefault: Bool
    let paymentProvider: String
    let createdAt: Date
    
    var displayName: String {
        return "\(cardBrand.capitalized) •••• \(cardLast4)"
    }
    
    var brandIcon: String {
        switch cardBrand.lowercased() {
        case "visa":
            return "creditcard"
        case "mastercard":
            return "creditcard"
        case "mir":
            return "creditcard"
        case "mock":
            return "creditcard.trianglebadge.exclamationmark"
        default:
            return "creditcard"
        }
    }
    
    var isDemoCard: Bool {
        return paymentProvider == "mock"
    }
}

// MARK: - Payment Transaction Domain Model
struct PaymentTransaction: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID?
    let walletId: UUID?
    let orderId: UUID?
    let amountCredits: Int
    let commissionCredits: Int
    let transactionType: String
    let status: String
    let providerTransactionId: String?
    let createdAt: Date
    let completedAt: Date?
    
    var displayType: String {
        switch transactionType {
        case "topup":
            return "Пополнение"
        case "order_payment":
            return "Оплата заказа"
        case "refund":
            return "Возврат"
        default:
            return transactionType
        }
    }
    
    var displayStatus: String {
        switch status {
        case "completed":
            return "Завершено"
        case "pending":
            return "В обработке"
        case "failed":
            return "Ошибка"
        default:
            return status
        }
    }
    
    var statusColor: String {
        switch status {
        case "completed":
            return "green"
        case "pending":
            return "yellow"
        case "failed":
            return "red"
        default:
            return "gray"
        }
    }
}

// MARK: - Supabase DTOs
struct SupabaseWalletDTO: Codable {
    let id: UUID?
    let wallet_type: String?
    let balance_credits: Int?
    let lifetime_top_up_credits: Int?
    let cafe_id: UUID?
    let cafe_name: String?
    let network_id: UUID?
    let network_name: String?
    let created_at: String?
    
    func asDomain() -> Wallet? {
        guard let id = id,
              let walletTypeString = wallet_type,
              let walletType = WalletType(rawValue: walletTypeString),
              let balance = balance_credits,
              let lifetime = lifetime_top_up_credits else {
            return nil
        }
        
        let date: Date
        if let createdAtString = created_at {
            date = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            date = Date()
        }
        
        return Wallet(
            id: id,
            walletType: walletType,
            balanceCredits: balance,
            lifetimeTopUpCredits: lifetime,
            cafeId: cafe_id,
            cafeName: cafe_name,
            networkId: network_id,
            networkName: network_name,
            createdAt: date
        )
    }
}

struct SupabasePaymentMethodDTO: Codable {
    let id: UUID?
    let card_last4: String?
    let card_brand: String?
    let is_default: Bool?
    let payment_provider: String?
    let created_at: String?
    
    func asDomain() -> PaymentMethod? {
        guard let id = id,
              let last4 = card_last4,
              let brand = card_brand,
              let provider = payment_provider else {
            return nil
        }
        
        let date: Date
        if let createdAtString = created_at {
            date = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            date = Date()
        }
        
        return PaymentMethod(
            id: id,
            cardLast4: last4,
            cardBrand: brand,
            isDefault: is_default ?? false,
            paymentProvider: provider,
            createdAt: date
        )
    }
}

struct MockTopupResponse: Codable {
    let success: Bool
    let transaction_id: UUID?
    let amount: Int?
    let commission: Int?
    let amount_credited: Int?
    let provider_transaction_id: String?
}

// MARK: - Payment Intent Response

enum PaymentProvider: String, Codable {
    case mock
    case yookassa
    case stripe
}

struct PaymentIntentResponse: Codable {
    let success: Bool
    let transactionId: UUID
    let provider: PaymentProvider
    let amount: Int
    let commission: Int
    let amountCredited: Int
    
    // Stripe-specific
    let clientSecret: String?
    let paymentIntentId: String?
    
    // YooKassa-specific
    let confirmationUrl: String?
    let paymentId: String?
    
    // Mock
    let mock: Bool?
    
    enum CodingKeys: String, CodingKey {
        case success
        case transactionId = "transaction_id"
        case provider
        case amount
        case commission
        case amountCredited = "amount_credited"
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case confirmationUrl = "confirmation_url"
        case paymentId = "payment_id"
        case mock
    }
}

struct TransactionStatusResponse: Codable {
    let id: UUID
    let status: String
    let amountCredits: Int
    let commissionCredits: Int
    let transactionType: String
    let providerTransactionId: String?
    let providerPaymentIntentId: String?
    let providerErrorCode: String?
    let providerErrorMessage: String?
    let createdAt: String
    let completedAt: String?
    let walletId: UUID?
    let currentBalance: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case amountCredits = "amount_credits"
        case commissionCredits = "commission_credits"
        case transactionType = "transaction_type"
        case providerTransactionId = "provider_transaction_id"
        case providerPaymentIntentId = "provider_payment_intent_id"
        case providerErrorCode = "provider_error_code"
        case providerErrorMessage = "provider_error_message"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case walletId = "wallet_id"
        case currentBalance = "current_balance"
    }
}

// MARK: - Network Models

struct NetworkInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let commissionRate: Double
    let cafeCount: Int
    let createdAt: Date
    
    var displayCommission: String {
        return String(format: "%.1f%%", commissionRate)
    }
}

struct NetworkDetails: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let ownerUserId: UUID?
    let ownerEmail: String?
    let commissionRate: Double
    let cafeCount: Int
    let totalWallets: Int
    let createdAt: Date
    let updatedAt: Date
    
    var displayCommission: String {
        return String(format: "%.1f%%", commissionRate)
    }
}

struct NetworkCafe: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let mode: String
    let joinedAt: Date
}

// MARK: - Supabase Network DTOs

struct SupabaseNetworkDTO: Codable {
    let network_id: UUID?
    let network_name: String?
    let commission_rate: Double?
    let cafe_count: Int?
    let created_at: String?
    
    func asDomain() -> NetworkInfo? {
        guard let id = network_id,
              let name = network_name,
              let rate = commission_rate,
              let count = cafe_count else {
            return nil
        }
        
        let date: Date
        if let createdAtString = created_at {
            date = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            date = Date()
        }
        
        return NetworkInfo(
            id: id,
            name: name,
            commissionRate: rate,
            cafeCount: count,
            createdAt: date
        )
    }
}
