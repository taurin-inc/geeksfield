import AppKit
import SwiftUI

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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
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
        if textView.string != text {
            textView.string = text
        }
        if textView.font != font {
            textView.font = font
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

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            // User input — safe to update height synchronously so the SwiftUI
            // frame grows in the same render pass as the new line appears.
            parent.recalculateHeight(textView: textView, sync: true)
        }
    }
}
