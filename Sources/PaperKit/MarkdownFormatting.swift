import Foundation

/// The block-level style of a line of Markdown.
public enum BlockStyle: Equatable, Sendable {
    case body
    case heading(Int)
    case bullet
    case numbered
    case task
}

/// A replacement to apply to a text buffer, plus the selection to restore afterwards.
public struct TextEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let selection: NSRange
}

/// Pure text transformations behind the Format menu.
public enum MarkdownFormatting {
    public static func style(of line: String) -> BlockStyle {
        if let heading = IndexBuilder.parseHeading(line) {
            return .heading(heading.level)
        }
        guard let marker = ListMarker.parse(line) else { return .body }
        switch marker.kind {
        case .bullet: return .bullet
        case .ordered: return .numbered
        case .task: return .task
        }
    }

    /// Splits a line into indentation and content, dropping any heading or list marker.
    public static func strippingBlockPrefix(_ line: String) -> (indent: String, content: String) {
        let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
        let rest = line.dropFirst(leading.count)
        if rest.hasPrefix("#"), IndexBuilder.parseHeading(line) != nil {
            let content = rest.drop(while: { $0 == "#" }).drop(while: { $0 == " " || $0 == "\t" })
            return ("", String(content))
        }
        if let marker = ListMarker.parse(line) {
            return (marker.indent, marker.content)
        }
        return (String(leading), String(rest))
    }

    /// Applies `style` to every line. If all non-empty lines already have that
    /// style, it is toggled off and the lines go back to plain text.
    public static func apply(_ style: BlockStyle, to lines: [String]) -> [String] {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let alreadyStyled = !nonEmpty.isEmpty && nonEmpty.allSatisfy { self.style(of: $0) == style }
        let target: BlockStyle = alreadyStyled ? .body : style

        var number = 0
        return lines.map { line in
            if lines.count > 1, line.trimmingCharacters(in: .whitespaces).isEmpty {
                return line
            }
            let (indent, content) = strippingBlockPrefix(line)
            switch target {
            case .body:
                return indent + content
            case .heading(let level):
                return String(repeating: "#", count: level) + " " + content
            case .bullet:
                return indent + "- " + content
            case .numbered:
                number += 1
                return indent + "\(number). " + content
            case .task:
                return indent + "- [ ] " + content
            }
        }
    }

    /// Checks or unchecks a task; turns any other line into an open task.
    public static func toggleTask(_ line: String) -> String {
        if let marker = ListMarker.parse(line), case .task(_, let checked) = marker.kind,
           let offset = marker.checkboxOffset {
            var chars = Array(line)
            chars[offset + 1] = checked ? " " : "x"
            return String(chars)
        }
        let (indent, content) = strippingBlockPrefix(line)
        return indent + "- [ ] " + content
    }

    /// Wraps the selection in `marker` (e.g. `**`), or unwraps it if it is already wrapped.
    public static func toggleWrap(marker: String, in text: NSString, selection: NSRange) -> TextEdit {
        let m = (marker as NSString).length
        let selected = text.substring(with: selection)
        let end = selection.location + selection.length

        // Markers just outside the selection: **|word|**
        if selection.location >= m, end + m <= text.length,
           text.substring(with: NSRange(location: selection.location - m, length: m)) == marker,
           text.substring(with: NSRange(location: end, length: m)) == marker {
            return TextEdit(
                range: NSRange(location: selection.location - m, length: selection.length + 2 * m),
                replacement: selected,
                selection: NSRange(location: selection.location - m, length: selection.length)
            )
        }

        // Markers inside the selection: |**word**|
        let selectedLength = (selected as NSString).length
        if selectedLength >= 2 * m, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = (selected as NSString).substring(with: NSRange(location: m, length: selectedLength - 2 * m))
            return TextEdit(
                range: selection,
                replacement: inner,
                selection: NSRange(location: selection.location, length: selectedLength - 2 * m)
            )
        }

        // Selection somewhere inside a wrapped span: **wo|rd** removes the whole span.
        if let span = enclosingSpan(marker: marker, in: text, containing: selection) {
            let innerStart = span.location
            let innerEnd = NSMaxRange(span) - 2 * m
            let newStart = min(max(selection.location - m, innerStart), innerEnd)
            let newEnd = min(max(end - m, innerStart), innerEnd)
            return TextEdit(
                range: span,
                replacement: text.substring(with: NSRange(location: span.location + m, length: span.length - 2 * m)),
                selection: NSRange(location: newStart, length: newEnd - newStart)
            )
        }

        return TextEdit(
            range: selection,
            replacement: marker + selected + marker,
            selection: NSRange(location: selection.location + m, length: selection.length)
        )
    }

    /// The `marker…marker` span (markers included) on the selection's line that
    /// contains the selection. A bare caret must be strictly inside the span, so
    /// that it can still start a new span right before or after an existing one.
    public static func enclosingSpan(marker: String, in text: NSString, containing selection: NSRange) -> NSRange? {
        let line = text.lineRange(for: NSRange(location: selection.location, length: 0))
        guard NSMaxRange(selection) <= NSMaxRange(line) else { return nil }

        let escaped = NSRegularExpression.escapedPattern(for: marker)
        let pattern = marker.count == 1
            ? "(?<!\(escaped))\(escaped)(?=[^\\s\(escaped)])(.+?)(?<=[^\\s\(escaped)])\(escaped)(?!\(escaped))"
            : "\(escaped)(?=\\S)(.+?)(?<=\\S)\(escaped)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        return regex.matches(in: text as String, range: line).map(\.range).first { span in
            if selection.length == 0 {
                return span.location < selection.location && selection.location < NSMaxRange(span)
            }
            return span.location <= selection.location && NSMaxRange(selection) <= NSMaxRange(span)
        }
    }
}
