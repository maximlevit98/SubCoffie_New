//
//  LoyaltyModels.swift
//  SubscribeCoffieClean
//
//  Models for loyalty program, levels, and achievements
//

import Foundation
import SwiftUI

// MARK: - Loyalty Level Domain Model

struct LoyaltyLevel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let levelName: String
    let levelOrder: Int
    let pointsRequired: Int
    let cashbackPercent: Double
    let benefits: [String]
    let badgeColor: String
    let createdAt: Date
    
    var color: Color {
        return Color(hex: badgeColor) ?? .gray
    }
    
    var icon: String {
        switch levelOrder {
        case 1: return "🥉"
        case 2: return "🥈"
        case 3: return "🥇"
        case 4: return "💎"
        default: return "⭐"
        }
    }
}

// MARK: - User Loyalty Status

struct UserLoyalty: Codable, Equatable {
    let userId: UUID
    let currentLevelId: UUID?
    let totalPoints: Int
    let pointsToNextLevel: Int
    let lifetimeOrders: Int
    let lifetimeSpendCredits: Int
    let currentStreakDays: Int
    let longestStreakDays: Int
    let lastOrderDate: Date?
    let createdAt: Date
    let updatedAt: Date
    
    var progressToNextLevel: Double {
        guard pointsToNextLevel > 0 else { return 1.0 }
        // Calculate progress based on points earned towards next level
        // This is an approximation since we don't have previous level threshold
        let progress = 1.0 - (Double(pointsToNextLevel) / Double(max(totalPoints, 1)))
        return max(0, min(1.0, progress))
    }
}

// MARK: - Achievement Domain Model

struct Achievement: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let achievementKey: String
    let title: String
    let description: String
    let icon: String
    let pointsReward: Int
    let achievementType: String
    let requirementValue: Int?
    let isHidden: Bool
    let createdAt: Date
    
    var displayProgress: String? {
        guard let requirement = requirementValue else { return nil }
        
        switch achievementType {
        case "order_count":
            return "Заказов: \(requirement)"
        case "cafe_count":
            return "Кофеен: \(requirement)"
        case "spend":
            return "Потрачено: \(requirement) ₽"
        case "streak":
            return "Дней подряд: \(requirement)"
        default:
            return nil
        }
    }
}

// MARK: - User Achievement (unlocked)

struct UserAchievement: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let achievementId: UUID
    let unlockedAt: Date
    let notified: Bool
}

// MARK: - Loyalty Points History

struct LoyaltyPointsHistory: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let pointsChange: Int
    let reason: String
    let orderId: UUID?
    let achievementId: UUID?
    let notes: String?
    let createdAt: Date
    
    var displayReason: String {
        switch reason {
        case "order_completed":
            return "Заказ выполнен"
        case "achievement_unlocked":
            return "Достижение получено"
        case "level_upgrade":
            return "Повышение уровня"
        case "admin_adjustment":
            return "Корректировка администратором"
        default:
            return reason
        }
    }
    
    var isPositive: Bool {
        return pointsChange > 0
    }
}

// MARK: - Loyalty Dashboard Response

struct LoyaltyDashboard: Codable {
    let userLoyalty: UserLoyalty?
    let currentLevel: LoyaltyLevel?
    let unlockedAchievements: [AchievementWithDate]
    let lockedAchievements: [Achievement]
    let recentPointsHistory: [LoyaltyPointsHistory]
    
    struct AchievementWithDate: Codable, Identifiable {
        let achievement: Achievement
        let unlockedAt: Date
        
        var id: UUID { achievement.id }
    }
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let rank: Int
    let userId: UUID
    let totalPoints: Int
    let levelName: String
    let lifetimeOrders: Int
    
    var id: UUID { userId }
}

// MARK: - Supabase DTOs

struct SupabaseLoyaltyLevelDTO: Codable {
    let id: UUID?
    let level_name: String?
    let level_order: Int?
    let points_required: Int?
    let cashback_percent: Double?
    let benefits: [String]?
    let badge_color: String?
    let created_at: String?
    
    func asDomain() -> LoyaltyLevel? {
        guard let id = id,
              let name = level_name,
              let order = level_order,
              let points = points_required,
              let cashback = cashback_percent,
              let color = badge_color else {
            return nil
        }
        
        let date: Date
        if let createdAtString = created_at {
            date = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            date = Date()
        }
        
        return LoyaltyLevel(
            id: id,
            levelName: name,
            levelOrder: order,
            pointsRequired: points,
            cashbackPercent: cashback,
            benefits: benefits ?? [],
            badgeColor: color,
            createdAt: date
        )
    }
}

struct SupabaseUserLoyaltyDTO: Codable {
    let user_id: UUID?
    let current_level_id: UUID?
    let total_points: Int?
    let points_to_next_level: Int?
    let lifetime_orders: Int?
    let lifetime_spend_credits: Int?
    let current_streak_days: Int?
    let longest_streak_days: Int?
    let last_order_date: String?
    let created_at: String?
    let updated_at: String?
    
    func asDomain() -> UserLoyalty? {
        guard let userId = user_id else { return nil }
        
        let dateFormatter = ISO8601DateFormatter()
        
        let lastOrderDate: Date?
        if let dateStr = last_order_date {
            lastOrderDate = dateFormatter.date(from: dateStr)
        } else {
            lastOrderDate = nil
        }
        
        let createdAt = created_at.flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = updated_at.flatMap { dateFormatter.date(from: $0) } ?? Date()
        
        return UserLoyalty(
            userId: userId,
            currentLevelId: current_level_id,
            totalPoints: total_points ?? 0,
            pointsToNextLevel: points_to_next_level ?? 0,
            lifetimeOrders: lifetime_orders ?? 0,
            lifetimeSpendCredits: lifetime_spend_credits ?? 0,
            currentStreakDays: current_streak_days ?? 0,
            longestStreakDays: longest_streak_days ?? 0,
            lastOrderDate: lastOrderDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct SupabaseAchievementDTO: Codable {
    let id: UUID?
    let achievement_key: String?
    let title: String?
    let description: String?
    let icon: String?
    let points_reward: Int?
    let achievement_type: String?
    let requirement_value: Int?
    let is_hidden: Bool?
    let created_at: String?
    
    func asDomain() -> Achievement? {
        guard let id = id,
              let key = achievement_key,
              let title = title,
              let desc = description,
              let type = achievement_type else {
            return nil
        }
        
        let date: Date
        if let createdAtString = created_at {
            date = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            date = Date()
        }
        
        return Achievement(
            id: id,
            achievementKey: key,
            title: title,
            description: desc,
            icon: icon ?? "🏆",
            pointsReward: points_reward ?? 0,
            achievementType: type,
            requirementValue: requirement_value,
            isHidden: is_hidden ?? false,
            createdAt: date
        )
    }
}

struct SupabaseLoyaltyPointsHistoryDTO: Codable {
    let id: UUID?
    let user_id: UUID?
    let points_change: Int?
    let reason: String?
    let order_id: UUID?
    let achievement_id: UUID?
    let notes: String?
    let created_at: String?
    
    func asDomain() -> LoyaltyPointsHistory? {
        guard let id = id,
              let userId = user_id,
              let pointsChange = points_change,
              let reason = reason else {
            return nil
        }
        
        let date: Date
        if let createdAtString = created_at {
            date = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            date = Date()
        }
        
        return LoyaltyPointsHistory(
            id: id,
            userId: userId,
            pointsChange: pointsChange,
            reason: reason,
            orderId: order_id,
            achievementId: achievement_id,
            notes: notes,
            createdAt: date
        )
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
