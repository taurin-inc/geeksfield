import Foundation

struct ImageAsset: Hashable, Identifiable, Sendable {
    let metadata: ImageMetadata
    let fileURL: URL?
    let thumbnailURL: URL?

    var id: String { metadata.id }
    var status: ImageStatus { metadata.status }
    var hasFile: Bool { fileURL != nil }
}
