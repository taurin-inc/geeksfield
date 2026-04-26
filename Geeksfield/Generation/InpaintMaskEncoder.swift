import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

enum MaskStyle {
    /// OpenAI style: PNG with transparent (alpha=0) pixels where the image
    /// should be edited, opaque elsewhere.
    case openAITransparent
    /// White-on-black style: white where edited, black elsewhere. Useful for
    /// providers that expect a binary mask as a separate image.
    case whiteOnBlack
}

enum InpaintMaskEncoder {
    /// Renders the strokes into a PNG mask sized to the original image.
    ///
    /// - Parameters:
    ///   - strokes: stroke paths in view coordinates.
    ///   - viewSize: the size of the canvas view the strokes were drawn in.
    ///   - imageSize: the native pixel size of the image the mask will overlay.
    ///   - imageFrame: the rect inside `viewSize` where the image was actually
    ///     laid out (since AsyncImage uses scaledToFit, the image is centered
    ///     with letterboxing on one axis).
    ///   - style: OpenAI-transparent or white-on-black.
    static func encode(
        strokes: [InpaintStroke],
        viewSize: CGSize,
        imageSize: CGSize,
        imageFrame: CGRect,
        style: MaskStyle
    ) -> Data? {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        guard width > 0, height > 0, imageFrame.width > 0, imageFrame.height > 0 else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        switch style {
        case .openAITransparent:
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            // Draw strokes as fully transparent.
            ctx.setBlendMode(.copy)
            ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        case .whiteOnBlack:
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        }

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Map view coords to image-pixel coords.
        let scaleX = imageSize.width / imageFrame.width
        let scaleY = imageSize.height / imageFrame.height
        let brushScale = (scaleX + scaleY) / 2.0

        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            ctx.setLineWidth(stroke.brushSize * brushScale)
            let mapped = stroke.points.map { p -> CGPoint in
                let localX = p.x - imageFrame.minX
                let localY = p.y - imageFrame.minY
                // CoreGraphics bitmap origin is bottom-left; flip Y.
                return CGPoint(
                    x: localX * scaleX,
                    y: imageSize.height - (localY * scaleY)
                )
            }
            ctx.beginPath()
            ctx.move(to: mapped[0])
            _ = first
            for p in mapped.dropFirst() {
                ctx.addLine(to: p)
            }
            ctx.strokePath()
        }

        guard let cgImage = ctx.makeImage() else { return nil }
        return pngData(from: cgImage)
    }

    /// Computes the letterboxed image frame within a container that uses
    /// scaledToFit.
    static func fittedImageFrame(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (containerSize.width - w) / 2
        let y = (containerSize.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Helpers

    private static func pngData(from cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
