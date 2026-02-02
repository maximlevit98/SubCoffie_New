//
//  SubscriptionService.swift
//  SubscribeCoffieClean
//
//  Service for subscription-related operations
//

import Foundation

enum SubscriptionError: LocalizedError {
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Ошибка обработки данных: \(error.localizedDescription)"
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Неверный ответ сервера"
        }
    }
}

class SubscriptionService {
    private let supabaseURL: String
    private let supabaseKey: String
    
    init() {
        // These should come from your SupabaseClient configuration
        self.supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
        self.supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    }
    
    // MARK: - Get All Plans
    
    func getSubscriptionPlans() async throws -> [SubscriptionPlan] {
        let endpoint = "\(supabaseURL)/rest/v1/rpc/get_subscription_plans"
        
        guard let url = URL(string: endpoint) else {
            throw SubscriptionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.httpBody = "{}".data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SubscriptionError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let plans = try decoder.decode([SubscriptionPlan].self, from: data)
            return plans
            
        } catch let error as SubscriptionError {
            throw error
        } catch {
            if let decodingError = error as? DecodingError {
                throw SubscriptionError.decodingError(decodingError)
            }
            throw SubscriptionError.networkError(error)
        }
    }
    
    // MARK: - Get User Subscription
    
    func getUserSubscription(userId: UUID) async throws -> UserSubscriptionDetails {
        let endpoint = "\(supabaseURL)/rest/v1/rpc/get_user_subscription"
        
        guard let url = URL(string: endpoint) else {
            throw SubscriptionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body = ["p_user_id": userId.uuidString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SubscriptionError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let details = try decoder.decode(UserSubscriptionDetails.self, from: data)
            return details
            
        } catch let error as SubscriptionError {
            throw error
        } catch {
            if let decodingError = error as? DecodingError {
                throw SubscriptionError.decodingError(decodingError)
            }
            throw SubscriptionError.networkError(error)
        }
    }
    
    // MARK: - Subscribe User
    
    func subscribeUser(userId: UUID, planId: UUID, paymentMethodId: UUID?) async throws -> SubscribeResponse {
        let endpoint = "\(supabaseURL)/rest/v1/rpc/subscribe_user"
        
        guard let url = URL(string: endpoint) else {
            throw SubscriptionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        var body: [String: Any] = [
            "p_user_id": userId.uuidString,
            "p_plan_id": planId.uuidString
        ]
        
        if let paymentMethodId = paymentMethodId {
            body["p_payment_method_id"] = paymentMethodId.uuidString
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SubscriptionError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let subscribeResponse = try decoder.decode(SubscribeResponse.self, from: data)
            return subscribeResponse
            
        } catch let error as SubscriptionError {
            throw error
        } catch {
            if let decodingError = error as? DecodingError {
                throw SubscriptionError.decodingError(decodingError)
            }
            throw SubscriptionError.networkError(error)
        }
    }
    
    // MARK: - Cancel Subscription
    
    func cancelSubscription(subscriptionId: UUID, reason: String?) async throws -> CancelSubscriptionResponse {
        let endpoint = "\(supabaseURL)/rest/v1/rpc/cancel_subscription"
        
        guard let url = URL(string: endpoint) else {
            throw SubscriptionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        var body: [String: Any] = [
            "p_subscription_id": subscriptionId.uuidString
        ]
        
        if let reason = reason {
            body["p_cancel_reason"] = reason
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SubscriptionError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cancelResponse = try decoder.decode(CancelSubscriptionResponse.self, from: data)
            return cancelResponse
            
        } catch let error as SubscriptionError {
            throw error
        } catch {
            if let decodingError = error as? DecodingError {
                throw SubscriptionError.decodingError(decodingError)
            }
            throw SubscriptionError.networkError(error)
        }
    }
    
    // MARK: - Check Subscription Benefits
    
    func checkSubscriptionBenefits(userId: UUID) async throws -> SubscriptionBenefitsResponse {
        let endpoint = "\(supabaseURL)/rest/v1/rpc/check_subscription_benefits"
        
        guard let url = URL(string: endpoint) else {
            throw SubscriptionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body = ["p_user_id": userId.uuidString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SubscriptionError.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let benefits = try decoder.decode(SubscriptionBenefitsResponse.self, from: data)
            return benefits
            
        } catch let error as SubscriptionError {
            throw error
        } catch {
            if let decodingError = error as? DecodingError {
                throw SubscriptionError.decodingError(decodingError)
            }
            throw SubscriptionError.networkError(error)
        }
    }
}
