import Combine
//
//  SubscriptionPlansView.swift
//  SubscribeCoffieClean
//
//  View for browsing and subscribing to subscription plans
//

import SwiftUI

struct SubscriptionPlansView: View {
    let userId: UUID
    
    @StateObject private var viewModel = SubscriptionPlansViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showSubscribeConfirmation = false
    @State private var showCancelConfirmation = false
    @State private var cancelReason = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Загрузка...")
                } else if let error = viewModel.error {
                    SubscriptionErrorView(error: error) {
                        Task {
                            await viewModel.loadData(userId: userId)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Current subscription status
                            if let currentSubscription = viewModel.currentSubscription {
                                currentSubscriptionCard(subscription: currentSubscription)
                            }
                            
                            // Available plans
                            plansSection
                            
                            // Demo badge
                            demoBadge
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadData(userId: userId)
                    }
                }
            }
            .navigationTitle("Подписка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Подтвердите подписку",
                isPresented: $showSubscribeConfirmation,
                presenting: selectedPlan
            ) { plan in
                Button("Подписаться на \(plan.nameRu) (\(plan.priceFormatted)/\(plan.billingPeriodRu))") {
                    Task {
                        await viewModel.subscribe(userId: userId, planId: plan.id)
                    }
                }
                Button("Отмена", role: .cancel) { }
            } message: { plan in
                Text("Оплата будет происходить автоматически каждый \(plan.billingPeriodRu).")
            }
            .alert("Отменить подписку", isPresented: $showCancelConfirmation) {
                TextField("Причина (необязательно)", text: $cancelReason)
                Button("Отменить подписку", role: .destructive) {
                    Task {
                        await viewModel.cancelSubscription(reason: cancelReason.isEmpty ? nil : cancelReason)
                        cancelReason = ""
                    }
                }
                Button("Закрыть", role: .cancel) {
                    cancelReason = ""
                }
            } message: {
                Text("Подписка останется активной до конца текущего периода.")
            }
        }
        .task {
            await viewModel.loadData(userId: userId)
        }
    }
    
    // MARK: - Current Subscription Card
    
    @ViewBuilder
    private func currentSubscriptionCard(subscription: UserSubscriptionDetails) -> some View {
        if let data = subscription.data {
            VStack(spacing: 16) {
                // Status badge
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Активная подписка")
                            .font(.headline)
                        Text(data.plan.nameRu)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                }
                
                // Period info
                VStack(spacing: 8) {
                    infoRow(label: "Активна до", value: data.subscription.currentPeriodEnd.formatted(date: .long, time: .omitted))
                    
                    let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: data.subscription.currentPeriodEnd).day ?? 0
                    infoRow(label: "Осталось дней", value: "\(max(0, daysRemaining))")
                    
                    infoRow(
                        label: "Автопродление",
                        value: data.subscription.autoRenew ? "Включено" : "Выключено"
                    )
                }
                
                // Benefits
                if !data.benefits.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ваши преимущества")
                            .font(.headline)
                        
                        ForEach(data.benefits) { benefit in
                            HStack(spacing: 8) {
                                Image(systemName: benefit.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                Text(benefit.benefitNameRu)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                
                // Cancel button
                if data.subscription.autoRenew {
                    Button(role: .destructive) {
                        showCancelConfirmation = true
                    } label: {
                        Text("Отменить подписку")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Plans Section
    
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.currentSubscription?.hasSubscription == true ? "Другие планы" : "Выберите план")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 4)
            
            ForEach(viewModel.plans) { plan in
                PlanCard(
                    plan: plan,
                    isCurrentPlan: viewModel.currentSubscription?.data?.plan.id == plan.id,
                    onSubscribe: {
                        selectedPlan = plan
                        showSubscribeConfirmation = true
                    }
                )
            }
        }
    }
    
    // MARK: - Demo Badge
    
    private var demoBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("DEMO MODE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("Оплата симулируется. Реальные платежи будут доступны после запуска.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Views
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isCurrentPlan: Bool
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(plan.icon)
                            .font(.title)
                        
                        Text(plan.nameRu)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    if let description = plan.descriptionRu {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isCurrentPlan {
                    Text("Текущий")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
            
            // Price
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(plan.priceFormatted)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(colorForPlan(plan.name))
                
                Text("/ \(plan.billingPeriodRu)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Benefits
            VStack(alignment: .leading, spacing: 10) {
                Text("Что входит:")
                    .font(.headline)
                
                ForEach(plan.benefits) { benefit in
                    HStack(spacing: 12) {
                        Image(systemName: benefit.icon)
                            .foregroundColor(colorForPlan(plan.name))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(benefit.benefitNameRu)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let description = benefit.descriptionRu {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Subscribe button
            if !isCurrentPlan {
                Button(action: onSubscribe) {
                    HStack {
                        Spacer()
                        Text("Подписаться")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(colorForPlan(plan.name))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentPlan ? Color.green : Color.clear, lineWidth: 2)
        )
    }
    
    private func colorForPlan(_ name: String) -> Color {
        switch name {
        case "basic": return .blue
        case "premium": return .purple
        case "vip": return .orange
        default: return .accentColor
        }
    }
}

// MARK: - Error View

private struct SubscriptionErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Ошибка загрузки")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - View Model

@MainActor
class SubscriptionPlansViewModel: ObservableObject {
    @Published var plans: [SubscriptionPlan] = []
    @Published var currentSubscription: UserSubscriptionDetails?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let subscriptionService = SubscriptionService()
    
    func loadData(userId: UUID) async {
        isLoading = true
        error = nil
        
        do {
            async let plansTask = subscriptionService.getSubscriptionPlans()
            async let subscriptionTask = subscriptionService.getUserSubscription(userId: userId)
            
            plans = try await plansTask
            currentSubscription = try await subscriptionTask
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func subscribe(userId: UUID, planId: UUID) async {
        do {
            let response = try await subscriptionService.subscribeUser(
                userId: userId,
                planId: planId,
                paymentMethodId: nil // Mock payment for MVP
            )
            
            if response.success {
                // Reload data to show new subscription
                await loadData(userId: userId)
            } else if let error = response.error {
                self.error = SubscriptionError.apiError(error)
            }
        } catch {
            self.error = error
        }
    }
    
    func cancelSubscription(reason: String?) async {
        guard let subscriptionId = currentSubscription?.data?.subscription.id else {
            return
        }
        
        do {
            let response = try await subscriptionService.cancelSubscription(
                subscriptionId: subscriptionId,
                reason: reason
            )
            
            if response.success {
                // Reload data to show updated subscription
                if let userId = currentSubscription?.data?.subscription.id {
                    await loadData(userId: userId)
                }
            } else if let error = response.error {
                self.error = SubscriptionError.apiError(error)
            }
        } catch {
            self.error = error
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPlansView(userId: UUID())
}
