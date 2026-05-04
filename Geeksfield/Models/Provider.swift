import Foundation

enum Provider: String, Codable, Hashable, CaseIterable, Sendable {
    case openai
    case gemini
    case codex

    static var allCases: [Provider] { [.codex] }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI (Legacy)"
        case .gemini: return "Gemini (Legacy)"
        case .codex: return "Codex"
        }
    }

    var apiKeyURL: URL {
        switch self {
        case .openai, .gemini:
            return URL(string: "https://developers.openai.com/codex/cli")!
        case .codex: return URL(string: "https://developers.openai.com/codex/cli")!
        }
    }

    var usesAPIKey: Bool {
        switch self {
        case .openai, .gemini: return false
        case .codex: return false
        }
    }
}
