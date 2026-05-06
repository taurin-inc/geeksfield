import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PastedImagePayload: Hashable {
    let data: Data
    let preferredExtension: String
}

/// Multiline text input with zero insets — used so an external placeholder
/// Text overlay can sit at (0, 0) and align exactly with the cursor and the
/// first glyph. SwiftUI's TextEditor adds opaque text container insets that
/// vary across macOS versions, which makes manual alignment unreliable.
struct MultilineTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var contentHeight: CGFloat
    var font: NSFont
    var minHeight: CGFloat
    var maxHeight: CGFloat
    var placeholder: String? = nil
    var onPasteImages: ([PastedImagePayload]) -> Void = { _ in }
    var onCommandReturn: () -> Void = {}
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let textView = PastingTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView

        textView.delegate = context.coordinator
        textView.onPasteImages = context.coordinator.handlePasteImages
        textView.onCommandReturn = context.coordinator.handleCommandReturn
        textView.placeholder = placeholder
        textView.font = font
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textColor = .labelColor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        textView.delegate = context.coordinator
        if let textView = textView as? PastingTextView {
            textView.onPasteImages = context.coordinator.handlePasteImages
            textView.onCommandReturn = context.coordinator.handleCommandReturn
        }
        if textView.string != text {
            textView.string = text
        }
        if textView.font != font {
            textView.font = font
        }
        if let textView = textView as? PastingTextView {
            textView.placeholder = placeholder
            textView.needsDisplay = true
        }
        // External text changes go through async to avoid mutating during view update.
        recalculateHeight(textView: textView, sync: false)
    }

    fileprivate func recalculateHeight(textView: NSTextView, sync: Bool) {
        guard let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container).height
        let clamped = max(minHeight, min(maxHeight, used))

        // Pin scroll to top whenever content fits within the visible frame.
        // Without this, when a new line is added the scroll view briefly scrolls
        // the first line out of view before SwiftUI can grow the frame —
        // looking like the top gets clipped.
        if used <= maxHeight, let scroll = textView.enclosingScrollView {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
        }

        guard abs(contentHeight - clamped) > 0.5 else { return }
        if sync {
            contentHeight = clamped
        } else {
            DispatchQueue.main.async {
                contentHeight = clamped
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextEditor
        init(_ parent: MultilineTextEditor) { self.parent = parent }

        @MainActor
        func handlePasteImages(_ payloads: [PastedImagePayload]) {
            parent.onPasteImages(payloads)
        }

        @MainActor
        func handleCommandReturn() {
            parent.onCommandReturn()
        }

        @MainActor
        func handleFocusChange(_ focused: Bool) {
            parent.onFocusChange(focused)
        }

        func textDidBeginEditing(_ notification: Notification) {
            Task { @MainActor in
                handleFocusChange(true)
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            Task { @MainActor in
                handleFocusChange(false)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            textView.needsDisplay = true
            // User input — safe to update height synchronously so the SwiftUI
            // frame grows in the same render pass as the new line appears.
            parent.recalculateHeight(textView: textView, sync: true)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let commands: Set<Selector> = [
                #selector(NSResponder.insertNewline(_:)),
                #selector(NSResponder.insertLineBreak(_:))
            ]
            guard commands.contains(commandSelector),
                  NSApp.currentEvent?.modifierFlags
                    .intersection(.deviceIndependentFlagsMask)
                    .contains(.command) == true else {
                return false
            }
            parent.onCommandReturn()
            return true
        }
    }
}

private final class PastingTextView: NSTextView {
    var onPasteImages: ([PastedImagePayload]) -> Void = { _ in }
    var onCommandReturn: () -> Void = {}
    var placeholder: String?

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        Array(Set(super.readablePasteboardTypes + [.png, .tiff]))
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)), Self.hasImagePayload(in: NSPasteboard.general) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           let character = event.charactersIgnoringModifiers?.lowercased() {
            if character == "v", pasteImagesIfAvailable() {
                return true
            }
            if character == "\r" || character == "\n" {
                onCommandReturn()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           let character = event.charactersIgnoringModifiers,
           character == "\r" || character == "\n" {
            onCommandReturn()
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if pasteImagesIfAvailable() { return }
        super.paste(sender)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty,
              let placeholder,
              !placeholder.isEmpty else { return }

        let color = NSColor.placeholderTextColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: color
        ]
        let origin = textContainerOrigin
        placeholder.draw(at: origin, withAttributes: attributes)
    }

    private func pasteImagesIfAvailable() -> Bool {
        let payloads = Self.imagePayloads(from: NSPasteboard.general)
        guard !payloads.isEmpty else { return false }
        onPasteImages(payloads)
        return true
    }

    private static func hasImagePayload(in pasteboard: NSPasteboard) -> Bool {
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) {
            return true
        }
        return pasteboard.pasteboardItems?.contains { item in
            item.types.contains(where: isImagePasteboardType)
        } ?? false
    }

    private static func imagePayloads(from pasteboard: NSPasteboard) -> [PastedImagePayload] {
        var payloads: [PastedImagePayload] = []
        var seen: Set<Data> = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls where isImageURL(url) {
                if let data = try? Data(contentsOf: url) {
                    appendUnique(PastedImagePayload(
                        data: data,
                        preferredExtension: normalizedExtension(url.pathExtension)
                    ), to: &payloads, seen: &seen)
                }
            }
        }

        for item in pasteboard.pasteboardItems ?? [] {
            if let payload = imagePayload(from: item) {
                appendUnique(payload, to: &payloads, seen: &seen)
            }
        }

        if payloads.isEmpty,
           let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] {
            for image in images {
                if let data = pngData(from: image) {
                    appendUnique(PastedImagePayload(data: data, preferredExtension: "png"), to: &payloads, seen: &seen)
                }
            }
        }

        return payloads
    }

    private static func imagePayload(from item: NSPasteboardItem) -> PastedImagePayload? {
        for type in item.types {
            guard isImagePasteboardType(type),
                  let data = item.data(forType: type) else {
                continue
            }

            if type == .tiff, let png = pngData(from: data) {
                return PastedImagePayload(data: png, preferredExtension: "png")
            }

            let ext = preferredExtension(for: type)
            return PastedImagePayload(data: data, preferredExtension: ext)
        }
        return nil
    }

    private static func isImagePasteboardType(_ pasteboardType: NSPasteboard.PasteboardType) -> Bool {
        guard let type = UTType(pasteboardType.rawValue) else { return false }
        return type.conforms(to: .image)
    }

    private static func preferredExtension(for pasteboardType: NSPasteboard.PasteboardType) -> String {
        guard let type = UTType(pasteboardType.rawValue) else { return "png" }
        if type.conforms(to: .png) { return "png" }
        if type.conforms(to: .jpeg) { return "jpg" }
        if type.conforms(to: .heic) { return "heic" }
        return type.preferredFilenameExtension.map(normalizedExtension) ?? "png"
    }

    private static func isImageURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private static func normalizedExtension(_ ext: String) -> String {
        let lower = ext.lowercased()
        return lower == "jpeg" ? "jpg" : (lower.isEmpty ? "png" : lower)
    }

    private static func pngData(from data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let png = pngData(from: image) else { return nil }
        return png
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func appendUnique(
        _ payload: PastedImagePayload,
        to payloads: inout [PastedImagePayload],
        seen: inout Set<Data>
    ) {
        guard !seen.contains(payload.data) else { return }
        seen.insert(payload.data)
        payloads.append(payload)
    }
}
