import Foundation

struct ImageAsset: Hashable, Identifiable, Sendable {
    let metadata: ImageMetadata
    let fileURL: URL?
    let thumbnailURL: URL?

    var id: String { metadata.id }
    var status: ImageStatus { metadata.status }
    var hasFile: Bool { fileURL != nil }
    var recordedAspectRatio: Double? {
        guard let size = metadata.size,
              !size.isAuto,
              size.width > 0,
              size.height > 0 else { return nil }
        return Double(size.width) / Double(size.height)
    }
}
