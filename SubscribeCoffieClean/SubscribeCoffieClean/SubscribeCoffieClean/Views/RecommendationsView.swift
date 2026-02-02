//
//  RecommendationsView.swift
//  SubscribeCoffieClean
//
//  View for displaying cafe recommendations
//

import SwiftUI

struct CafeRecommendationsView: View {
    let recommendations: [CafeRecommendation]
    let onSelectCafe: (UUID) -> Void
    
    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("Рекомендуем попробовать")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendations) { recommendation in
                            RecommendationCard(recommendation: recommendation) {
                                onSelectCafe(recommendation.cafeId)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: CafeRecommendation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Icon and name
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.cafeName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(recommendation.recommendationReason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Address
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(recommendation.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Score indicator
                HStack {
                    Spacer()
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("\(Int(recommendation.relevanceScore))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trending Items View

struct TrendingItemsView: View {
    let items: [TrendingItem]
    let onSelectItem: (TrendingItem) -> Void
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("Сейчас в тренде")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            TrendingItemCard(item: item) {
                                onSelectItem(item)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct TrendingItemCard: View {
    let item: TrendingItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                        .frame(height: 60)
                    
                    Image(systemName: categoryIcon)
                        .font(.title)
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(CafeProduct.normalizedTitle(title: item.title, name: item.name))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(item.cafeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(item.priceCredits) ₽")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(item.orderCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(10)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch item.category {
        case .drinks: return .blue
        case .food: return .orange
        case .syrups: return .purple
        case .merch: return .pink
        }
    }
    
    private var categoryIcon: String {
        switch item.category {
        case .drinks: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .syrups: return "drop.fill"
        case .merch: return "gift.fill"
        }
    }
}
