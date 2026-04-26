import Foundation
import AppKit
import UniformTypeIdentifiers
import ImageIO

final class ThumbnailStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager
    let maxDimension: CGFloat

    init(paths: AppPaths = .shared, fileManager: FileManager = .default, maxDimension: CGFloat = 512) {
        self.paths = paths
        self.fileManager = fileManager
        self.maxDimension = maxDimension
    }

    func thumbnailURL(projectID: String, imageID: String) -> URL {
        paths.thumbsDir(projectID).appendingPathComponent("\(imageID).jpg")
    }

    @discardableResult
    func generate(for imageURL: URL, projectID: String, imageID: String) throws -> URL {
        let dir = paths.thumbsDir(projectID)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = thumbnailURL(projectID: projectID, imageID: imageID)

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let src = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return dest
        }

        guard let destination = CGImageDestinationCreateWithURL(
            dest as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return dest
        }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, cg, props as CFDictionary)
        CGImageDestinationFinalize(destination)
        return dest
    }
}
