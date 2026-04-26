import Foundation

enum ImageStatus: String, Codable, Hashable, Sendable {
    case pending
    case draft
    case picked
    case failed
}
