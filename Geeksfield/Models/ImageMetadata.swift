import Foundation

struct ImageMetadata: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let projectID: String
    var status: ImageStatus
    let createdAt: Date
    let provider: Provider
    let modelID: String
    let prompt: String
    let negativePrompt: String?
    let size: Size?
    let aspectRatio: String?
    let seed: Int?
    let referenceIDs: [String]
    var failureReason: String?
}
