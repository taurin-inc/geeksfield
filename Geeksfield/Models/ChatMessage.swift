import Foundation

enum ChatRole: String, Codable, Hashable, Sendable {
    case user
    case assistant
    case system
}

struct ChatAttachment: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let mimeType: String
    let path: String
}

struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let role: ChatRole
    let content: String
    let createdAt: Date
    let provider: Provider?
    let modelID: String?
    let attachments: [ChatAttachment]
}
