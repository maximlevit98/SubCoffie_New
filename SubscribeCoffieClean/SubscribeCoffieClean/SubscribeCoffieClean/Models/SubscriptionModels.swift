//
//  SubscriptionModels.swift
//  SubscribeCoffieClean
//
//  Models for subscription plans and user subscriptions
//

import Foundation

// MARK: - Subscription Plan

struct SubscriptionPlan: Identifiable, Codable {
    let id: UUID
    let name: String
    let nameRu: String
    let description: String?
    let descriptionRu: String?
    let priceCredits: Int
    let billingPeriod: String
    let displayOrder: Int
    let benefits: [SubscriptionBenefit]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameRu = "name_ru"
        case description
        case descriptionRu = "description_ru"
        case priceCredits = "price_credits"
        case billingPeriod = "billing_period"
        case displayOrder = "display_order"
        case benefits
    }
    
    var priceFormatted: String {
        let rubles = priceCredits / 100
        return "\(rubles)₽"
    }
    
    var billingPeriodRu: String {
        switch billingPeriod {
        case "monthly": return "месяц"
        case "yearly": return "год"
        default: return billingPeriod
        }
    }
    
    var color: String {
        switch name {
        case "basic": return "blue"
        case "premium": return "purple"
        case "vip": return "orange"
        default: return "blue"
        }
    }
    
    var icon: String {
        switch name {
        case "basic": return "🥉"
        case "premium": return "🥈"
        case "vip": return "🥇"
        default: return "⭐️"
        }
    }
}

// MARK: - Subscription Benefit

struct SubscriptionBenefit: Codable, Identifiable {
    var id: UUID?
    let benefitType: String
    let benefitName: String
    let benefitNameRu: String
    let benefitValue: String
    let description: String?
    let descriptionRu: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case benefitType = "benefit_type"
        case benefitName = "benefit_name"
        case benefitNameRu = "benefit_name_ru"
        case benefitValue = "benefit_value"
        case description
        case descriptionRu = "description_ru"
    }
    
    var icon: String {
        switch benefitType {
        case "cashback": return "percent"
        case "free_delivery": return "shippingbox.fill"
        case "priority_support": return "headphones"
        case "exclusive_promos": return "gift.fill"
        case "discount": return "tag.fill"
        default: return "star.fill"
        }
    }
}

// MARK: - User Subscription

struct UserSubscription: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let planId: UUID
    let status: String
    let startedAt: Date
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelledAt: Date?
    let cancelReason: String?
    let autoRenew: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planId = "plan_id"
        case status
        case startedAt = "started_at"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelledAt = "cancelled_at"
        case cancelReason = "cancel_reason"
        case autoRenew = "auto_renew"
    }
    
    var isActive: Bool {
        status == "active" && currentPeriodEnd > Date()
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: currentPeriodEnd).day ?? 0
        return max(0, days)
    }
}

// MARK: - User Subscription Details

struct UserSubscriptionDetails: Codable {
    let hasSubscription: Bool
    let data: SubscriptionData?
    
    enum CodingKeys: String, CodingKey {
        case hasSubscription = "has_subscription"
        case data
    }
}

struct SubscriptionData: Codable {
    let subscription: UserSubscriptionInfo
    let plan: PlanInfo
    let benefits: [SubscriptionBenefit]
}

struct UserSubscriptionInfo: Codable {
    let id: UUID
    let status: String
    let startedAt: Date
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelledAt: Date?
    let autoRenew: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case startedAt = "started_at"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelledAt = "cancelled_at"
        case autoRenew = "auto_renew"
    }
}

struct PlanInfo: Codable {
    let id: UUID
    let name: String
    let nameRu: String
    let description: String?
    let descriptionRu: String?
    let priceCredits: Int
    let billingPeriod: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameRu = "name_ru"
        case description
        case descriptionRu = "description_ru"
        case priceCredits = "price_credits"
        case billingPeriod = "billing_period"
    }
}

// MARK: - Subscription Benefits Response

struct SubscriptionBenefitsResponse: Codable {
    let hasSubscription: Bool
    let subscriptionId: UUID?
    let planId: UUID?
    let periodEnd: Date?
    let benefits: [SubscriptionBenefit]
    
    enum CodingKeys: String, CodingKey {
        case hasSubscription = "has_subscription"
        case subscriptionId = "subscription_id"
        case planId = "plan_id"
        case periodEnd = "period_end"
        case benefits
    }
    
    func hasBenefit(type: String) -> Bool {
        benefits.contains { $0.benefitType == type }
    }
    
    func getBenefitValue(type: String) -> String? {
        benefits.first { $0.benefitType == type }?.benefitValue
    }
}

// MARK: - Subscribe Response

struct SubscribeResponse: Codable {
    let success: Bool
    let subscriptionId: UUID?
    let paymentId: UUID?
    let periodEnd: Date?
    let amountPaid: Int?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case subscriptionId = "subscription_id"
        case paymentId = "payment_id"
        case periodEnd = "period_end"
        case amountPaid = "amount_paid"
        case error
    }
}

// MARK: - Cancel Subscription Response

struct CancelSubscriptionResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}
