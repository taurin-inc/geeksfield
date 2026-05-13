import Foundation

enum ImageGenerationSizePolicy {
    static let apiMaxPixels = 8_294_400
    static let apiMaxLongEdge = 3_840
    static let sizeStep = 16

    static func targetSize(longEdge: Int, aspectRatio rawAspectRatio: String?) -> Size {
        let ratio = rawAspectRatio.flatMap(parseAspectRatio) ?? 1
        return targetSize(longEdge: longEdge, aspectRatio: ratio)
    }

    static func apiConstrainedSize(longEdge: Int = apiMaxLongEdge, aspectRatio rawAspectRatio: String?) -> Size {
        let ratio = rawAspectRatio.flatMap(parseAspectRatio) ?? 1
        return apiConstrainedSize(longEdge: longEdge, aspectRatio: ratio)
    }

    static func apiToolSize(forFinalSize size: Size) -> Size? {
        guard !size.isAuto,
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        let ratio = Double(size.width) / Double(size.height)
        let longEdge = min(Swift.max(size.width, size.height), apiMaxLongEdge)
        return apiConstrainedSize(longEdge: longEdge, aspectRatio: ratio)
    }

    private static func targetSize(longEdge: Int, aspectRatio ratio: Double) -> Size {
        let edge = Double(longEdge)
        let width: Double
        let height: Double

        if ratio >= 1 {
            width = edge
            height = edge / ratio
        } else {
            width = edge * ratio
            height = edge
        }

        return Size(
            width: steppedDimension(width),
            height: steppedDimension(height)
        )
    }

    private static func apiConstrainedSize(longEdge: Int, aspectRatio ratio: Double) -> Size {
        let edge = Double(min(longEdge, apiMaxLongEdge))
        let maxPixels = Double(apiMaxPixels)
        let width: Double
        let height: Double

        if ratio >= 1 {
            let unconstrainedWidth = edge
            let unconstrainedHeight = edge / ratio
            if unconstrainedWidth * unconstrainedHeight > maxPixels {
                width = sqrt(maxPixels * ratio)
                height = width / ratio
            } else {
                width = unconstrainedWidth
                height = unconstrainedHeight
            }
        } else {
            let unconstrainedHeight = edge
            let unconstrainedWidth = edge * ratio
            if unconstrainedWidth * unconstrainedHeight > maxPixels {
                height = sqrt(maxPixels / ratio)
                width = height * ratio
            } else {
                width = unconstrainedWidth
                height = unconstrainedHeight
            }
        }

        return Size(
            width: steppedDimension(width),
            height: steppedDimension(height)
        )
    }

    private static func steppedDimension(_ value: Double) -> Int {
        let stepped = Int(value.rounded(.down)) / sizeStep * sizeStep
        return Swift.max(sizeStep, stepped)
    }

    private static func parseAspectRatio(_ raw: String) -> Double? {
        guard raw != "auto" else { return nil }
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
}
