import AppKit
import PaperKit

/// The text view behind the page editor: plain Markdown text with live
/// styling, list continuation, clickable checkboxes and the Format menu actions.
final class PaperTextView: NSTextView {
    let highlighter = MarkdownHighlighter()

    static let readableWidth: CGFloat = 720
    static let minimumInset: CGFloat = 32
    static let verticalInset: CGFloat = 18

    /// Builds a TextKit 1 text view (predictable attribute handling for live styling).
    static func make() -> PaperTextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let textView = PaperTextView(frame: .zero, textContainer: container)
        storage.delegate = textView.highlighter
        textView.configure()
        return textView
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = true
        smartInsertDeleteEnabled = false
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        textContainerInset = NSSize(width: Self.minimumInset, height: Self.verticalInset)
        typingAttributes = highlighter.baseAttributes
    }

    var fontSize: CGFloat {
        get { highlighter.fontSize }
        set {
            guard newValue != highlighter.fontSize else { return }
            highlighter.fontSize = newValue
            typingAttributes = highlighter.baseAttributes
            if let textStorage {
                highlighter.highlightAll(textStorage)
            }
        }
    }

    // MARK: - Layout

    override func setFrameSize(_ newSize: NSSize) {
        var size = newSize
        // Fill the visible area so clicks below the last line still land in the text.
        if let clipView = enclosingScrollView?.contentView {
            size.height = max(size.height, clipView.bounds.height)
        }
        super.setFrameSize(size)
        updateInsets()
    }

    /// Keeps a comfortable line length by centering the text column.
    private func updateInsets() {
        let width = bounds.width
        let textWidth = min(width - 2 * Self.minimumInset, Self.readableWidth)
        let horizontal = max(Self.minimumInset, ((width - textWidth) / 2).rounded())
        if textContainerInset.width != horizontal {
            textContainerInset = NSSize(width: horizontal, height: Self.verticalInset)
        }
    }

    // MARK: - Editing helpers

    private var nsString: NSString { string as NSString }

    /// Range of the line containing `location`, without the trailing newline.
    private func lineRange(at location: Int) -> NSRange {
        var range = nsString.lineRange(for: NSRange(location: min(location, nsString.length), length: 0))
        if range.length > 0, nsString.character(at: NSMaxRange(range) - 1) == 0x0A {
            range.length -= 1
        }
        return range
    }

    @discardableResult
    private func replace(_ range: NSRange, with replacement: String) -> Bool {
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
        return true
    }

    /// Applies `transform` to the lines touched by the selection.
    private func transformSelectedLines(_ transform: ([String]) -> [String]) {
        let selection = selectedRange()
        var range = nsString.lineRange(for: selection)
        if range.length > 0, nsString.character(at: NSMaxRange(range) - 1) == 0x0A {
            range.length -= 1
        }
        let lines = nsString.substring(with: range).components(separatedBy: "\n")
        let replacement = transform(lines).joined(separator: "\n")
        guard replace(range, with: replacement) else { return }
        let length = (replacement as NSString).length
        if lines.count == 1, selection.length == 0 {
            setSelectedRange(NSRange(location: range.location + length, length: 0))
        } else {
            setSelectedRange(NSRange(location: range.location, length: length))
        }
    }

    private func wrapSelection(with marker: String) {
        let edit = MarkdownFormatting.toggleWrap(marker: marker, in: nsString, selection: selectedRange())
        if replace(edit.range, with: edit.replacement) {
            setSelectedRange(edit.selection)
        }
    }

    // MARK: - Lists

    override func insertNewline(_ sender: Any?) {
        let selection = selectedRange()
        let line = lineRange(at: selection.location)
        guard selection.length == 0,
              let marker = ListMarker.parse(nsString.substring(with: line)),
              selection.location - line.location >= marker.prefixLength else {
            super.insertNewline(sender)
            return
        }
        if marker.content.trimmingCharacters(in: .whitespaces).isEmpty {
            // Return on an empty item ends the list.
            insertText("", replacementRange: line)
        } else {
            insertText("\n" + marker.continuation, replacementRange: selection)
        }
    }

    override func insertTab(_ sender: Any?) {
        let selection = selectedRange()
        let line = lineRange(at: selection.location)
        guard ListMarker.parse(nsString.substring(with: line)) != nil else {
            super.insertTab(sender)
            return
        }
        if replace(NSRange(location: line.location, length: 0), with: "\t") {
            setSelectedRange(NSRange(location: selection.location + 1, length: selection.length))
        }
    }

    override func insertBacktab(_ sender: Any?) {
        let selection = selectedRange()
        let line = lineRange(at: selection.location)
        guard let marker = ListMarker.parse(nsString.substring(with: line)), !marker.indent.isEmpty else {
            super.insertBacktab(sender)
            return
        }
        let removable = marker.indent.hasPrefix("\t") ? 1 : min(4, marker.indent.prefix(while: { $0 == " " }).count)
        if replace(NSRange(location: line.location, length: removable), with: "") {
            setSelectedRange(NSRange(location: max(line.location, selection.location - removable), length: selection.length))
        }
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command), let url = link(at: point) {
            NSWorkspace.shared.open(url)
            return
        }
        if event.clickCount == 1, event.modifierFlags.intersection([.shift, .command, .option]).isEmpty,
           toggleCheckbox(at: point) {
            return
        }
        super.mouseDown(with: event)
    }

    private func characterIndex(at point: NSPoint) -> Int? {
        guard let layoutManager, let textContainer, nsString.length > 0 else { return nil }
        let containerPoint = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        return index < nsString.length ? index : nil
    }

    private func link(at point: NSPoint) -> URL? {
        guard let index = characterIndex(at: point) else { return nil }
        return textStorage?.attribute(.paperLink, at: index, effectiveRange: nil) as? URL
    }

    /// Clicking the `[ ]` of a task checks or unchecks it.
    private func toggleCheckbox(at point: NSPoint) -> Bool {
        guard let index = characterIndex(at: point), let layoutManager, let textContainer else { return false }
        let line = lineRange(at: index)
        let text = nsString.substring(with: line)
        guard let offset = ListMarker.parse(text)?.checkboxOffset else { return false }

        let box = NSRange(location: line.location + offset, length: 3)
        let glyphs = layoutManager.glyphRange(forCharacterRange: box, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            .insetBy(dx: -4, dy: -3)
        guard rect.contains(point) else { return false }

        let selection = selectedRange()
        replace(line, with: MarkdownFormatting.toggleTask(text))
        setSelectedRange(selection)
        return true
    }

    // MARK: - Navigation

    /// Scrolls the line at `location` to the top and briefly highlights it.
    func reveal(location: Int) {
        let line = lineRange(at: max(0, location))
        setSelectedRange(NSRange(location: NSMaxRange(line), length: 0))
        window?.makeFirstResponder(self)
        guard let layoutManager, let textContainer, let scrollView = enclosingScrollView else { return }

        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: NSMaxRange(line)))
        let glyphs = layoutManager.glyphRange(forCharacterRange: line, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        let clipView = scrollView.contentView
        let maxY = max(0, frame.height - clipView.bounds.height)
        let y = min(max(0, rect.minY + textContainerOrigin.y - 24), maxY)
        clipView.scroll(to: NSPoint(x: 0, y: y))
        scrollView.reflectScrolledClipView(clipView)

        if line.length > 0 {
            showFindIndicator(for: line)
        }
    }

    // MARK: - Format menu

    @objc func paperHeading1(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.heading(1), to: $0) } }
    @objc func paperHeading2(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.heading(2), to: $0) } }
    @objc func paperHeading3(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.heading(3), to: $0) } }
    @objc func paperBodyText(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.body, to: $0) } }
    @objc func paperBulletList(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.bullet, to: $0) } }
    @objc func paperNumberedList(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.numbered, to: $0) } }
    @objc func paperChecklist(_ sender: Any?) { transformSelectedLines { MarkdownFormatting.apply(.task, to: $0) } }

    @objc func paperToggleTask(_ sender: Any?) {
        transformSelectedLines { lines in
            lines.map { line in
                lines.count > 1 && line.trimmingCharacters(in: .whitespaces).isEmpty
                    ? line
                    : MarkdownFormatting.toggleTask(line)
            }
        }
    }

    @objc func paperBold(_ sender: Any?) { wrapSelection(with: "**") }
    @objc func paperItalic(_ sender: Any?) { wrapSelection(with: "_") }
    @objc func paperStrikethrough(_ sender: Any?) { wrapSelection(with: "~~") }
    @objc func paperHighlight(_ sender: Any?) { wrapSelection(with: "==") }
    @objc func paperCode(_ sender: Any?) { wrapSelection(with: "`") }

    @objc func paperInsertDate(_ sender: Any?) {
        insertText(Date.now.formatted(.dateTime.day().month(.wide).year()), replacementRange: selectedRange())
    }
}
