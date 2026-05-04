import CoreGraphics
import Foundation
import ImageIO

enum ImageAspectReader {
    static func initialAspect(for asset: ImageAsset) -> CGFloat {
        CGFloat(asset.recordedAspectRatio ?? 1)
    }

    static func aspectRatio(for asset: ImageAsset) async -> CGFloat {
        if let recorded = asset.recordedAspectRatio {
            return clamped(CGFloat(recorded))
        }
        guard let url = asset.fileURL ?? asset.thumbnailURL else { return 1 }
        return await aspectRatio(for: url) ?? 1
    }

    static func clamped(_ aspect: CGFloat) -> CGFloat {
        min(max(aspect, 0.52), 1.9)
    }

    private static func aspectRatio(for url: URL) async -> CGFloat? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let widthNumber = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let heightNumber = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
                return nil
            }
            let width = CGFloat(truncating: widthNumber)
            let height = CGFloat(truncating: heightNumber)
            guard width > 0, height > 0 else { return nil }
            return clamped(width / height)
        }.value
    }
}
