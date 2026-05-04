import Foundation

protocol ModelLister: Sendable {
    var provider: Provider { get }
    func listAvailableModelIDs(apiKey: String) async throws -> [String]
}

enum ModelListerError: Error, LocalizedError {
    case invalidKey
    case network(Error)
    case http(Int, String)
    case decode(Error)

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Credentials were rejected."
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .http(let code, _): return "HTTP \(code)"
        case .decode(let e): return "Decode error: \(e.localizedDescription)"
        }
    }
}
