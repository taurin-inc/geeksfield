import Foundation

struct ChatSession: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String
    let createdAt: Date
    var updatedAt: Date
}
