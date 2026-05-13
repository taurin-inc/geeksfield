import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageOutputNormalizer {
    static func normalizedPNG(_ data: Data, size: Size, aspectRatio: String?) -> Data {
        guard let targetAspect = targetAspect(size: size, aspectRatio: aspectRatio),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return data
        }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return data }

        let currentAspect = Double(width) / Double(height)
        guard abs(currentAspect - targetAspect) / targetAspect > 0.015 else {
            return data
        }

        let rect: CGRect
        if currentAspect > targetAspect {
            let cropWidth = min(width, max(1, Int((Double(height) * targetAspect).rounded(.down))))
            rect = CGRect(
                x: CGFloat((width - cropWidth) / 2),
                y: 0,
                width: CGFloat(cropWidth),
                height: CGFloat(height)
            )
        } else {
            let cropHeight = min(height, max(1, Int((Double(width) / targetAspect).rounded(.down))))
            rect = CGRect(
                x: 0,
                y: CGFloat((height - cropHeight) / 2),
                width: CGFloat(width),
                height: CGFloat(cropHeight)
            )
        }

        guard let cropped = image.cropping(to: rect),
              let png = encodePNG(cropped) else {
            return data
        }
        return png
    }

    private static func targetAspect(size: Size, aspectRatio: String?) -> Double? {
        if let aspectRatio,
           aspectRatio != "auto",
           let parsed = parseAspectRatio(aspectRatio) {
            return parsed
        }
        guard !size.isAuto, size.width > 0, size.height > 0 else { return nil }
        return Double(size.width) / Double(size.height)
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

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
