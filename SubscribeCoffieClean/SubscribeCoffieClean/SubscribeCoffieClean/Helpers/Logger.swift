import Foundation

enum AppLogger {
    static func debug(_ message: String) {
        #if DEBUG
        print("[Supabase] \(message)")
        #endif
    }
    
    static func error(_ message: String) {
        #if DEBUG
        print("[Supabase ERROR] \(message)")
        #endif
    }

    static func debugResponse(url: URL, statusCode: Int?, body: String?) {
        #if DEBUG
        let codePart = statusCode.map { "status=\($0)" } ?? "status=?"
        let bodyPreview = (body ?? "").prefix(300)
        print("[Supabase] url=\(url.absoluteString) \(codePart) body=\(bodyPreview)")
        #endif
    }
}
