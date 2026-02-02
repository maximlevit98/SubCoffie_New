import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case emptyData
    case transport(Error)
    case httpStatus(Int, body: String?)
    case decoding(Error)
    case invalidResponse(String)
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL для запроса"
        case .emptyData:
            return "Сервер вернул пустой ответ"
        case .transport(let error):
            return "Сетевая ошибка: \(error.localizedDescription)"
        case .httpStatus(let code, let body):
            if let body, !body.isEmpty {
                return "HTTP \(code): \(body)"
            }
            return "HTTP статус \(code)"
        case .decoding(let error):
            return "Ошибка декодирования: \(error.localizedDescription)"
        case .invalidResponse(let message):
            return "Неверный ответ сервера: \(message)"
        case .unauthorized:
            return "Необходима авторизация"
        case .serverError(let message):
            return "Ошибка сервера: \(message)"
        }
    }
}
