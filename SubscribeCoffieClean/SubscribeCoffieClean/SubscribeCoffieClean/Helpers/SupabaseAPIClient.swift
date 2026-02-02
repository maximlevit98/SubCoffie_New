import Foundation
import Supabase

struct SupabaseAPIClient {
    static let shared = SupabaseAPIClient()
    
    let baseURL: URL
    private let anonKey: String
    private let session: URLSession

    init(
        baseURL: URL = SupabaseConfig.restBaseURL,
        anonKey: String = SupabaseConfig.anonKey,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = SupabaseConfig.requestTimeout
            config.timeoutIntervalForResource = SupabaseConfig.requestTimeout
            self.session = URLSession(configuration: config)
        }
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(url: baseURL.appendingPathComponent(cleanPath), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        AppLogger.debug("GET \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.emptyData
        }

        let bodyString = String(data: data, encoding: .utf8)
        AppLogger.debugResponse(url: url, statusCode: http.statusCode, body: bodyString)
        if cleanPath == "menu_items" {
            let previewData = data.prefix(2048)
            let preview = String(data: previewData, encoding: .utf8) ?? "<non-utf8>"
            AppLogger.debug("menu_items raw status=\(http.statusCode) body=\(preview)")
            menuDebugLog(
                hypothesisId: "H1",
                location: "SupabaseAPIClient.get:menu_items",
                message: "Raw menu_items response",
                data: [
                    "status": http.statusCode,
                    "bodyPreview": preview
                ]
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode, body: bodyString)
        }

        guard !data.isEmpty else { throw NetworkError.emptyData }

        let decoder = JSONDecoder()
        // НЕ используем .convertFromSnakeCase, так как у нас явные CodingKeys
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    func post<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], body: Data) async throws -> T {
        try await request(method: "POST", path: path, queryItems: queryItems, body: body)
    }
    
    func post<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], body: [[String: Any]]) async throws -> T {
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        return try await post(path, queryItems: queryItems, body: jsonData)
    }

    func patch<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], body: Data) async throws -> T {
        try await request(method: "PATCH", path: path, queryItems: queryItems, body: body)
    }
    
    func delete(_ path: String, queryItems: [URLQueryItem] = []) async throws {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(url: baseURL.appendingPathComponent(cleanPath), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        AppLogger.debug("DELETE \(url.absoluteString)")

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.emptyData
        }

        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode, body: nil)
        }
    }
    
    // MARK: - RPC Support
    
    /// Call a Supabase RPC function
    func rpc<T: Decodable>(_ functionName: String, params: [String: Any] = [:]) async throws -> T {
        // Construct RPC URL: baseURL is already .../rest/v1, so append rpc/functionName
        let rpcURL = baseURL.appendingPathComponent("rpc").appendingPathComponent(functionName)
        
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        if !params.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: params)
        }
        
        AppLogger.debug("RPC \(functionName) with params: \(params)")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.emptyData
        }
        
        let bodyString = String(data: data, encoding: .utf8)
        AppLogger.debugResponse(url: rpcURL, statusCode: http.statusCode, body: bodyString)
        
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode, body: bodyString)
        }
        
        guard !data.isEmpty else { throw NetworkError.emptyData }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLogger.debug("Failed to decode RPC response: \(error)")
            throw NetworkError.decoding(error)
        }
    }

    // MARK: - Internal request
    private func request<T: Decodable>(method: String, path: String, queryItems: [URLQueryItem], body: Data) async throws -> T {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(url: baseURL.appendingPathComponent(cleanPath), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        AppLogger.debug("\(method) \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.emptyData
        }

        let bodyString = String(data: data, encoding: .utf8)
        AppLogger.debugResponse(url: url, statusCode: http.statusCode, body: bodyString)

        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode, body: bodyString)
        }

        guard !data.isEmpty else { throw NetworkError.emptyData }

        let decoder = JSONDecoder()
        // НЕ используем .convertFromSnakeCase, так как у нас явные CodingKeys
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }
    
    // MARK: - Auth Support
    
    /// Get current user ID from Supabase session
    func getCurrentUserId() async throws -> UUID {
        let supabase = SupabaseClientProvider.client
        let session = try await supabase.auth.session
        guard let uuidString = session.user.id.uuidString as? String,
              let uuid = UUID(uuidString: uuidString) else {
            throw NetworkError.invalidResponse("Invalid user ID format")
        }
        return uuid
    }
}
