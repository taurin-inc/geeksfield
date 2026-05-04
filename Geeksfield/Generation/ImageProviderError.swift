import Foundation

enum ImageProviderError: Error, LocalizedError {
    case http(Int, String)
    case emptyResponse
    case unsupportedModel(String)
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            let snippet = body.prefix(200)
            return "HTTP \(code): \(snippet)"
        case .emptyResponse:
            return "Provider returned no images."
        case .unsupportedModel(let id):
            return "Unsupported model: \(id)"
        case .unsupportedOperation(let op):
            return "Unsupported operation: \(op)"
        }
    }
}
