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

    static func aspectRatioString(for asset: ImageAsset) async -> String? {
        if let ratio = validatedAspectRatio(asset.metadata.aspectRatio) {
            return ratio
        }
        if let size = asset.metadata.size,
           !size.isAuto,
           size.width > 0,
           size.height > 0 {
            return reducedRatioString(width: size.width, height: size.height)
        }
        guard let url = asset.fileURL ?? asset.thumbnailURL,
              let size = await pixelSize(for: url) else {
            return nil
        }
        return reducedRatioString(width: size.width, height: size.height)
    }

    static func clamped(_ aspect: CGFloat) -> CGFloat {
        min(max(aspect, 0.52), 1.9)
    }

    private static func aspectRatio(for url: URL) async -> CGFloat? {
        guard let size = await pixelSize(for: url) else { return nil }
        return clamped(CGFloat(size.width) / CGFloat(size.height))
    }

    private static func pixelSize(for url: URL) async -> (width: Int, height: Int)? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let widthNumber = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let heightNumber = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
                return nil
            }
            let width = widthNumber.intValue
            let height = heightNumber.intValue
            guard width > 0, height > 0 else { return nil }
            return (width, height)
        }.value
    }

    private static func validatedAspectRatio(_ raw: String?) -> String? {
        guard let raw,
              raw != "auto",
              parseAspectRatio(raw) != nil else {
            return nil
        }
        return raw
    }

    private static func parseAspectRatio(_ raw: String) -> Double? {
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0 else {
            return nil
        }
        return width / height
    }

    private static func reducedRatioString(width: Int, height: Int) -> String {
        let divisor = greatestCommonDivisor(width, height)
        return "\(width / divisor):\(height / divisor)"
    }

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let next = x % y
            x = y
            y = next
        }
        return max(x, 1)
    }
}
