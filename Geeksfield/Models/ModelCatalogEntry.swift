import Foundation

struct ModelCatalog: Codable, Sendable {
    let version: String
    let imageModels: [ImageModelEntry]
    let chatModels: [ChatModelEntry]

    enum CodingKeys: String, CodingKey {
        case version
        case imageModels = "image_models"
        case chatModels = "chat_models"
    }
}

struct ImageModelEntry: Codable, Sendable {
    let provider: Provider
    let idPatterns: [String]
    let excludePatterns: [String]?
    let displayNameTemplate: String
    let sizes: [String]
    let aspectRatios: [String]
    let maxBatch: Int
    let supportsInpaint: Bool
    let supportsReference: Bool

    enum CodingKeys: String, CodingKey {
        case provider
        case idPatterns = "id_patterns"
        case excludePatterns = "exclude_patterns"
        case displayNameTemplate = "display_name_template"
        case sizes
        case aspectRatios = "aspect_ratios"
        case maxBatch = "max_batch"
        case supportsInpaint = "supports_inpaint"
        case supportsReference = "supports_reference"
    }
}

struct ChatModelEntry: Codable, Sendable {
    let provider: Provider
    let idPatterns: [String]
    let excludePatterns: [String]?
    let displayNameTemplate: String
    let supportsVision: Bool
    let contextWindow: Int?

    enum CodingKeys: String, CodingKey {
        case provider
        case idPatterns = "id_patterns"
        case excludePatterns = "exclude_patterns"
        case displayNameTemplate = "display_name_template"
        case supportsVision = "supports_vision"
        case contextWindow = "context_window"
    }
}
