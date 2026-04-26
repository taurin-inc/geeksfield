import Foundation

struct ImageSpec: Codable, Hashable, Sendable {
    let sizes: [Size]
    let aspectRatios: [String]
    let maxBatch: Int
    let supportsInpaint: Bool
    let supportsReference: Bool
}

struct ChatSpec: Codable, Hashable, Sendable {
    let supportsVision: Bool
    let contextWindow: Int?
}

enum ModelCapability: Hashable, Sendable {
    case image(ImageSpec)
    case chat(ChatSpec)

    var isImage: Bool { if case .image = self { return true } else { return false } }
    var isChat: Bool { if case .chat = self { return true } else { return false } }
}

struct ModelDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let provider: Provider
    let displayName: String
    let capability: ModelCapability

    static func == (lhs: ModelDescriptor, rhs: ModelDescriptor) -> Bool {
        lhs.id == rhs.id && lhs.provider == rhs.provider
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(provider)
    }
}
