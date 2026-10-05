import AppKit
import SwiftUI

/// SwiftUI wrapper around ``PaperTextView``.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    /// Scroll request coming from a heading clicked in the index.
    var jump: JumpRequest?
    /// Incremented to move the keyboard focus into the editor.
    var focusRequest: Int
    var onJumpHandled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, focusRequest: focusRequest)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PaperTextView.make()
        textView.fontSize = fontSize
        textView.string = text
        textView.delegate = context.coordinator

        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PaperTextView else { return }
        let coordinator = context.coordinator
        coordinator.text = $text

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }

        textView.fontSize = fontSize

        if focusRequest != coordinator.focusRequest {
            coordinator.focusRequest = focusRequest
            Task { @MainActor in
                textView.window?.makeFirstResponder(textView)
            }
        }

        if let jump, jump.id != coordinator.lastJumpID {
            coordinator.lastJumpID = jump.id
            let onJumpHandled = onJumpHandled
            Task { @MainActor in
                // A page opened from the index may not be on screen yet.
                for _ in 0..<20 where textView.window == nil || scrollView.bounds.height == 0 {
                    try? await Task.sleep(for: .milliseconds(25))
                }
                scrollView.layoutSubtreeIfNeeded()
                textView.reveal(location: jump.location)
                onJumpHandled()
            }
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        // Undo actions refer to this text view, which is going away with its page.
        if let textView = scrollView.documentView as? NSTextView {
            textView.undoManager?.removeAllActions(withTarget: textView)
            if let storage = textView.textStorage {
                textView.undoManager?.removeAllActions(withTarget: storage)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var focusRequest: Int
        var lastJumpID: UUID?

        init(text: Binding<String>, focusRequest: Int) {
            self.text = text
            self.focusRequest = focusRequest
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
