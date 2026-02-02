import Foundation

// Extension to SupabaseAPIClient to support custom decoder
extension SupabaseAPIClient {
    func post<T: Decodable>(_ path: String, body: Data, decoder: JSONDecoder) async throws -> T {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: cleanPath, relativeTo: SupabaseConfig.restBaseURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        AppLogger.debug("POST \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.emptyData
        }
        
        let bodyString = String(data: data, encoding: .utf8)
        AppLogger.debugResponse(url: url, statusCode: http.statusCode, body: bodyString)
        
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode, body: bodyString)
        }
        
        guard !data.isEmpty else {
            throw NetworkError.emptyData
        }
        
        return try decoder.decode(T.self, from: data)
    }
}

struct CafeOnboardingService {
    private let apiClient: SupabaseAPIClient
    
    init(apiClient: SupabaseAPIClient = SupabaseAPIClient()) {
        self.apiClient = apiClient
    }
    
    // MARK: - Submit Application
    
    func submitApplication(
        cafeName: String,
        cafeAddress: String,
        cafePhone: String,
        cafeEmail: String,
        cafeDescription: String?,
        businessType: CafeBusinessType?,
        openingHours: String?,
        estimatedDailyOrders: Int?
    ) async throws -> UUID {
        let params: [String: Any?] = [
            "p_cafe_name": cafeName,
            "p_cafe_address": cafeAddress,
            "p_cafe_phone": cafePhone,
            "p_cafe_email": cafeEmail,
            "p_cafe_description": cafeDescription,
            "p_business_type": businessType?.rawValue,
            "p_opening_hours": openingHours,
            "p_estimated_daily_orders": estimatedDailyOrders
        ]
        
        // Filter out nil values
        let cleanParams = params.compactMapValues { $0 }
        let body = try JSONSerialization.data(withJSONObject: cleanParams)
        
        // RPC returns UUID as a string
        let requestId: UUID = try await apiClient.post("rpc/submit_cafe_application", body: body)
        
        AppLogger.debug("Cafe onboarding application submitted: \(requestId)")
        return requestId
    }
    
    // MARK: - Get My Requests
    
    func getMyRequests() async throws -> [CafeOnboardingRequest] {
        let body = try JSONSerialization.data(withJSONObject: [:])
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let requests: [CafeOnboardingRequest] = try await apiClient.post("rpc/get_my_onboarding_requests", body: body, decoder: decoder)
        
        AppLogger.debug("Fetched \(requests.count) onboarding requests")
        return requests
    }
    
    // MARK: - Cancel Request
    
    func cancelRequest(requestId: UUID) async throws {
        let params: [String: Any] = [
            "p_request_id": requestId.uuidString
        ]
        
        let body = try JSONSerialization.data(withJSONObject: params)
        
        // RPC returns boolean
        let success: Bool = try await apiClient.post("rpc/cancel_onboarding_request", body: body)
        
        if !success {
            throw NetworkError.decoding(NSError(domain: "CafeOnboardingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to cancel request"]))
        }
        
        AppLogger.debug("Onboarding request cancelled: \(requestId)")
    }
}
