import Foundation

enum Provider: String, Codable, Hashable, CaseIterable, Sendable {
    case openai
    case gemini

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        }
    }

    var apiKeyURL: URL {
        switch self {
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/app/apikey")!
        }
    }
}
