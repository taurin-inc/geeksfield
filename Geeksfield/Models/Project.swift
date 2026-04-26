import Foundation

struct Project: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var name: String
    let createdAt: Date
    var updatedAt: Date

    static func makeNew(name: String) -> Project {
        let now = Date()
        return Project(
            id: UUID().uuidString.lowercased(),
            name: name,
            createdAt: now,
            updatedAt: now
        )
    }
}
