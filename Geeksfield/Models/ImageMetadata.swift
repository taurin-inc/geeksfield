import Foundation

enum ImageOperation: String, Codable, Hashable, Sendable {
    case generate
    case reference
    case inpaint
}

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
    let runID: String?
    let parentImageID: String?
    let variantIndex: Int?
    let operation: ImageOperation?
    var failureReason: String?

    init(
        id: String,
        projectID: String,
        status: ImageStatus,
        createdAt: Date,
        provider: Provider,
        modelID: String,
        prompt: String,
        negativePrompt: String?,
        size: Size?,
        aspectRatio: String?,
        seed: Int?,
        referenceIDs: [String],
        runID: String? = nil,
        parentImageID: String? = nil,
        variantIndex: Int? = nil,
        operation: ImageOperation? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.status = status
        self.createdAt = createdAt
        self.provider = provider
        self.modelID = modelID
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.size = size
        self.aspectRatio = aspectRatio
        self.seed = seed
        self.referenceIDs = referenceIDs
        self.runID = runID
        self.parentImageID = parentImageID
        self.variantIndex = variantIndex
        self.operation = operation
        self.failureReason = failureReason
    }
}
