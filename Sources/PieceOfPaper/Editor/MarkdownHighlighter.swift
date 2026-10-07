import AppKit
import PaperKit

extension NSAttributedString.Key {
    /// URL of a link in the editor, opened with ⌘-click.
    static let paperLink = NSAttributedString.Key("PaperLink")
    /// Markup characters that are laid out as invisible, zero-width glyphs.
    static let paperHidden = NSAttributedString.Key("PaperHidden")
}

/// Styles Markdown source while typing. The syntax stays visible (pages are
/// plain Markdown files) but headings, emphasis, lists and tasks look like
/// what they mean, with the markers themselves dimmed.
///
/// Highlighter marks (`==testo==`) go one step further: their `==` are hidden
/// unless the selection is on that line, so highlights read like a real
/// highlighter pen while staying editable.
final class MarkdownHighlighter: NSObject, NSTextStorageDelegate, NSLayoutManagerDelegate {
    var fontSize: CGFloat = 15 {
        didSet { updateFonts() }
    }

    /// The current selection: markers on the lines it touches stay visible.
    var revealedSelection: NSRange?

    /// Highlighter-pen yellow, toned down in dark mode so white text stays readable.
    let highlightColor = NSColor(name: "PaperHighlight") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.72, green: 0.56, blue: 0.05, alpha: 0.55)
            : NSColor(srgbRed: 1.0, green: 0.88, blue: 0.32, alpha: 0.75)
    }

    static let lineHeightMultiple: CGFloat = 1.22
    static let tabInterval: CGFloat = 28

    private(set) var bodyFont = NSFont.systemFont(ofSize: 15)
    private var monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private var baseParagraphStyle = NSParagraphStyle()
    /// Number of code fence lines in the text at the last full pass.
    private var fenceCount = -1

    private let fenceRegex = try! NSRegularExpression(pattern: #"^[ \t]*(```|~~~)"#, options: [.anchorsMatchLines])
    private let ruleRegex = try! NSRegularExpression(pattern: #"^ {0,3}([-*_])( *\1){2,} *$"#)
    private let codeRegex = try! NSRegularExpression(pattern: #"`[^`\n]+`"#)
    private let boldRegex = try! NSRegularExpression(pattern: #"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private let italicRegex = try! NSRegularExpression(
        pattern: #"(?<![*\w])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![*\w])|(?<![_\w])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![_\w])"#
    )
    private let strikeRegex = try! NSRegularExpression(pattern: #"~~(?=\S)(.+?)(?<=\S)~~"#)
    private let highlightRegex = try! NSRegularExpression(pattern: #"==(?=\S)(.+?)(?<=\S)=="#)
    private let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\s]+)\)"#)
    private let urlRegex = try! NSRegularExpression(pattern: #"(?<![(<])\bhttps?://[^\s<>()\[\]]+[^\s<>()\[\].,;:!?'"]"#)

    override init() {
        super.init()
        updateFonts()
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: baseParagraphStyle,
        ]
    }

    private func updateFonts() {
        bodyFont = NSFont.systemFont(ofSize: fontSize)
        monoFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = Self.lineHeightMultiple
        style.paragraphSpacing = 2
        style.defaultTabInterval = Self.tabInterval
        style.tabStops = []
        baseParagraphStyle = style
    }

    // MARK: - NSTextStorageDelegate

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        let string = textStorage.string as NSString
        let fences = fenceRegex.numberOfMatches(in: textStorage.string, range: NSRange(location: 0, length: string.length))
        let paragraph = string.paragraphRange(for: editedRange)
        let touchesFence = fenceRegex.firstMatch(in: textStorage.string, range: paragraph) != nil

        // Opening or closing a code block restyles everything after it.
        if fences != fenceCount || touchesFence {
            fenceCount = fences
            highlight(textStorage, in: NSRange(location: 0, length: string.length), startsInFence: false)
        } else {
            let before = NSRange(location: 0, length: paragraph.location)
            let inFence = fenceRegex.numberOfMatches(in: textStorage.string, range: before) % 2 == 1
            highlight(textStorage, in: paragraph, startsInFence: inFence)
        }
    }

    /// Restyles the paragraphs touching `ranges`, e.g. to show or hide
    /// highlighter marks when the selection moves to another line.
    func restyleParagraphs(touching ranges: [NSRange], in storage: NSTextStorage) {
        let string = storage.string as NSString
        let paragraphs = Set(ranges.map { range in
            let location = min(range.location, string.length)
            let clamped = NSRange(location: location, length: min(range.length, string.length - location))
            return string.paragraphRange(for: clamped)
        })
        storage.beginEditing()
        for paragraph in paragraphs {
            let before = NSRange(location: 0, length: paragraph.location)
            let inFence = fenceRegex.numberOfMatches(in: storage.string, range: before) % 2 == 1
            highlight(storage, in: paragraph, startsInFence: inFence)
        }
        storage.endEditing()
    }

    /// Restyles the whole text, e.g. after changing the font size.
    func highlightAll(_ storage: NSTextStorage) {
        storage.beginEditing()
        fenceCount = fenceRegex.numberOfMatches(in: storage.string, range: NSRange(location: 0, length: storage.length))
        highlight(storage, in: NSRange(location: 0, length: storage.length), startsInFence: false)
        storage.endEditing()
    }

    // MARK: - Styling

    private func highlight(_ storage: NSTextStorage, in range: NSRange, startsInFence: Bool) {
        guard range.length > 0 else { return }
        storage.setAttributes(baseAttributes, range: range)
        let string = storage.string as NSString
        var inFence = startsInFence
        string.enumerateSubstrings(in: range, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = string.substring(with: lineRange)
            if self.fenceRegex.firstMatch(in: line, range: NSRange(location: 0, length: lineRange.length)) != nil {
                storage.addAttributes([.font: self.monoFont, .foregroundColor: NSColor.tertiaryLabelColor], range: lineRange)
                inFence.toggle()
            } else if inFence {
                storage.addAttributes([.font: self.monoFont, .foregroundColor: NSColor.secondaryLabelColor], range: lineRange)
            } else {
                self.styleLine(line, at: lineRange, in: storage)
            }
        }
    }

    private func styleLine(_ line: String, at lineRange: NSRange, in storage: NSTextStorage) {
        let lineLength = lineRange.length
        let fullLine = NSRange(location: 0, length: lineLength)

        if ruleRegex.firstMatch(in: line, range: fullLine) != nil {
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: lineRange)
            return
        }

        if let heading = headingPrefix(of: line) {
            let font = headingFont(level: heading.level)
            let style = baseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
            style.paragraphSpacingBefore = heading.level == 1 ? 14 : heading.level == 2 ? 10 : 6
            storage.addAttributes([.font: font, .paragraphStyle: style], range: lineRange)
            storage.addAttribute(
                .foregroundColor,
                value: NSColor.tertiaryLabelColor,
                range: NSRange(location: lineRange.location, length: heading.prefixLength)
            )
        } else if let marker = ListMarker.parse(line) {
            styleListItem(marker, at: lineRange, in: storage)
        } else if line.drop(while: { $0 == " " }).hasPrefix(">") {
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
            if let quote = line.range(of: #"^ *>+ ?"#, options: .regularExpression) {
                let length = line.utf16.distance(from: quote.lowerBound, to: quote.upperBound)
                storage.addAttribute(
                    .foregroundColor,
                    value: NSColor.tertiaryLabelColor,
                    range: NSRange(location: lineRange.location, length: length)
                )
            }
        }

        styleInline(line, at: lineRange, in: storage)
    }

    private func styleListItem(_ marker: ListMarker, at lineRange: NSRange, in storage: NSTextStorage) {
        let indentLength = marker.indent.utf16.count
        let markerRange = NSRange(location: lineRange.location + indentLength, length: marker.prefixLength - indentLength)
        storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: markerRange)

        // Wrapped lines align with the text after the marker.
        let style = baseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.headIndent = hangingIndent(for: marker)
        storage.addAttribute(.paragraphStyle, value: style, range: lineRange)

        if case .task(_, let checked) = marker.kind {
            let contentRange = NSRange(
                location: lineRange.location + marker.prefixLength,
                length: lineRange.length - marker.prefixLength
            )
            if checked, contentRange.length > 0 {
                storage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: NSColor.tertiaryLabelColor,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ], range: contentRange)
            }
            if let offset = marker.checkboxOffset {
                storage.addAttribute(
                    .font,
                    value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                    range: NSRange(location: lineRange.location + offset, length: 3)
                )
            }
        }
    }

    /// Width of indentation and marker, so wrapped lines align with the item text.
    private func hangingIndent(for marker: ListMarker) -> CGFloat {
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: bodyFont]).width
        var x: CGFloat = 0
        for character in marker.indent {
            if character == "\t" {
                x = (floor(x / Self.tabInterval) + 1) * Self.tabInterval
            } else {
                x += spaceWidth
            }
        }
        let bullet: String
        switch marker.kind {
        case .bullet(let character), .task(let character, _): bullet = "\(character) "
        case .ordered(let number, let delimiter): bullet = "\(number)\(delimiter) "
        }
        x += (bullet as NSString).size(withAttributes: [.font: bodyFont]).width
        if marker.isTask {
            let box = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
            x += ("[ ]" as NSString).size(withAttributes: [.font: box]).width + spaceWidth
        }
        return x
    }

    private func styleInline(_ line: String, at lineRange: NSRange, in storage: NSTextStorage) {
        let fullLine = NSRange(location: 0, length: lineRange.length)
        let base = lineRange.location
        var codeRanges: [NSRange] = []

        for match in codeRegex.matches(in: line, range: fullLine) {
            let range = NSRange(location: base + match.range.location, length: match.range.length)
            codeRanges.append(match.range)
            storage.addAttributes([
                .font: monoFont,
                .backgroundColor: NSColor.secondarySystemFill,
            ], range: range)
            dimMarkers(length: 1, of: range, in: storage)
        }

        func outsideCode(_ range: NSRange) -> Bool {
            !codeRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }

        for match in boldRegex.matches(in: line, range: fullLine) where outsideCode(match.range) {
            let range = NSRange(location: base + match.range.location, length: match.range.length)
            addTrait(.bold, to: range, in: storage)
            dimMarkers(length: 2, of: range, in: storage)
        }

        for match in italicRegex.matches(in: line, range: fullLine) where outsideCode(match.range) {
            let range = NSRange(location: base + match.range.location, length: match.range.length)
            addTrait(.italic, to: range, in: storage)
            dimMarkers(length: 1, of: range, in: storage)
        }

        for match in strikeRegex.matches(in: line, range: fullLine) where outsideCode(match.range) {
            let range = NSRange(location: base + match.range.location, length: match.range.length)
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor,
            ], range: range)
            dimMarkers(length: 2, of: range, in: storage)
        }

        let revealed = isRevealed(lineRange)
        for match in highlightRegex.matches(in: line, range: fullLine) where outsideCode(match.range) {
            let range = NSRange(location: base + match.range.location, length: match.range.length)
            storage.addAttribute(.backgroundColor, value: highlightColor, range: range)
            if revealed {
                dimMarkers(length: 2, of: range, in: storage)
            } else {
                storage.addAttribute(.paperHidden, value: true, range: NSRange(location: range.location, length: 2))
                storage.addAttribute(.paperHidden, value: true, range: NSRange(location: NSMaxRange(range) - 2, length: 2))
            }
        }

        for match in linkRegex.matches(in: line, range: fullLine) where outsideCode(match.range) {
            let label = match.range(at: 1)
            let target = (line as NSString).substring(with: match.range(at: 2))
            let whole = NSRange(location: base + match.range.location, length: match.range.length)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: whole)
            addLink(target, to: NSRange(location: base + label.location, length: label.length), in: storage)
        }

        for match in urlRegex.matches(in: line, range: fullLine) where outsideCode(match.range) {
            let url = (line as NSString).substring(with: match.range)
            addLink(url, to: NSRange(location: base + match.range.location, length: match.range.length), in: storage)
        }
    }

    // MARK: - NSLayoutManagerDelegate

    /// Lays out characters marked `.paperHidden` as null glyphs: not drawn, no width.
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let storage = layoutManager.textStorage, glyphRange.length > 0 else { return 0 }
        let first = characterIndexes[0]
        let last = characterIndexes[glyphRange.length - 1]
        var hasHidden = false
        storage.enumerateAttribute(.paperHidden, in: NSRange(location: first, length: last - first + 1)) { value, _, stop in
            if value != nil {
                hasHidden = true
                stop.pointee = true
            }
        }
        guard hasHidden else { return 0 }

        let adjusted = (0..<glyphRange.length).map { index -> NSLayoutManager.GlyphProperty in
            let hidden = storage.attribute(.paperHidden, at: characterIndexes[index], effectiveRange: nil) != nil
            return hidden ? .null : properties[index]
        }
        adjusted.withUnsafeBufferPointer { buffer in
            layoutManager.setGlyphs(
                glyphs,
                properties: buffer.baseAddress!,
                characterIndexes: characterIndexes,
                font: font,
                forGlyphRange: glyphRange
            )
        }
        return glyphRange.length
    }

    // MARK: - Helpers

    private func isRevealed(_ lineRange: NSRange) -> Bool {
        guard let selection = revealedSelection else { return false }
        if selection.length > 0, NSIntersectionRange(selection, lineRange).length > 0 {
            return true
        }
        // A caret at the very end of the line still belongs to it.
        return lineRange.location <= selection.location && selection.location <= NSMaxRange(lineRange)
    }

    private func headingPrefix(of line: String) -> (level: Int, prefixLength: Int)? {
        let leading = line.prefix(while: { $0 == " " }).count
        guard leading <= 3 else { return nil }
        let rest = line.dropFirst(leading)
        let level = rest.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let after = rest.dropFirst(level)
        guard after.isEmpty || after.first == " " || after.first == "\t" else { return nil }
        let spaces = after.prefix(while: { $0 == " " || $0 == "\t" }).count
        return (level, leading + level + spaces)
    }

    private func headingFont(level: Int) -> NSFont {
        let size: CGFloat
        switch level {
        case 1: size = fontSize + 11
        case 2: size = fontSize + 6
        case 3: size = fontSize + 3
        default: size = fontSize + 1
        }
        return NSFont.systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
    }

    private func addTrait(_ trait: NSFontDescriptor.SymbolicTraits, to range: NSRange, in storage: NSTextStorage) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? NSFont) ?? bodyFont
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(trait))
            if let converted = NSFont(descriptor: descriptor, size: font.pointSize) {
                storage.addAttribute(.font, value: converted, range: subrange)
            }
        }
    }

    private func dimMarkers(length: Int, of range: NSRange, in storage: NSTextStorage) {
        guard range.length >= 2 * length else { return }
        let color = NSColor.tertiaryLabelColor
        storage.addAttribute(.foregroundColor, value: color, range: NSRange(location: range.location, length: length))
        storage.addAttribute(.foregroundColor, value: color, range: NSRange(location: NSMaxRange(range) - length, length: length))
    }

    private func addLink(_ target: String, to range: NSRange, in storage: NSTextStorage) {
        guard let url = URL(string: target), url.scheme != nil else {
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            return
        }
        storage.addAttributes([
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: NSColor.linkColor.withAlphaComponent(0.4),
            .paperLink: url,
            .toolTip: "⌘-clic per aprire \(target)",
        ], range: range)
    }
}
