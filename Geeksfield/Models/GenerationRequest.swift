import Foundation

struct GenerationRequest: Hashable, Sendable {
    let projectID: String
    let prompt: String
    let negativePrompt: String?
    let model: ModelDescriptor
    let size: Size
    let aspectRatio: String?
    let batchSize: Int
    let referenceIDs: [String]
    let parentImageID: String?
    let seed: Int?
}
