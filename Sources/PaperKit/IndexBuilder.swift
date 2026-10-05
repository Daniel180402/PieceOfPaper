import Foundation

/// A Markdown heading inside a page.
public struct Heading: Identifiable, Hashable, Sendable {
    public var id: Int { location }
    /// 1 for `#`, 2 for `##`, …
    public let level: Int
    public let text: String
    /// UTF-16 offset of the start of the heading line, usable as an `NSRange` location.
    public let location: Int
}

/// One line of a folder index: a page with its number and outline.
public struct IndexEntry: Identifiable, Hashable, Sendable {
    public var id: UUID { pageID }
    public let number: Int
    public let pageID: UUID
    public let title: String
    public let fileName: String
    public let createdAt: Date
    public let updatedAt: Date
    public let headings: [Heading]
    public let preview: String
    public let openTasks: Int
    public let completedTasks: Int
}

/// Builds the index of a folder: in the app and as the `INDICE.md` file on disk.
public enum IndexBuilder {
    /// Headings deeper than this are left out of the index.
    public static let maxIndexedLevel = 3

    public static func entries(for folder: Folder) -> [IndexEntry] {
        folder.pages.enumerated().map { offset, page in
            let tasks = taskCounts(in: page.body)
            return IndexEntry(
                number: offset + 1,
                pageID: page.id,
                title: page.displayTitle,
                fileName: page.fileName,
                createdAt: page.createdAt,
                updatedAt: page.updatedAt,
                headings: headings(in: page.body).filter { $0.level <= maxIndexedLevel },
                preview: preview(of: page.body),
                openTasks: tasks.open,
                completedTasks: tasks.completed
            )
        }
    }

    // MARK: - Parsing

    /// ATX headings (`# Title`), ignoring fenced code blocks.
    public static func headings(in markdown: String) -> [Heading] {
        var result: [Heading] = []
        var inFence = false
        var location = 0
        for line in markdown.components(separatedBy: "\n") {
            defer { location += (line as NSString).length + 1 }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            guard !inFence, let heading = parseHeading(line) else { continue }
            result.append(Heading(level: heading.level, text: heading.text, location: location))
        }
        return result
    }

    static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        // Up to three spaces of indentation are allowed by CommonMark.
        let leading = line.prefix(while: { $0 == " " }).count
        guard leading <= 3 else { return nil }
        let rest = line.dropFirst(leading)
        let level = rest.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let afterHashes = rest.dropFirst(level)
        guard afterHashes.isEmpty || afterHashes.first == " " || afterHashes.first == "\t" else { return nil }
        var text = afterHashes.trimmingCharacters(in: .whitespaces)
        // Optional closing sequence: `## Title ##`
        if let range = text.range(of: #"\s+#+$"#, options: .regularExpression) {
            text.removeSubrange(range)
        } else if text.allSatisfy({ $0 == "#" }) {
            text = ""
        }
        guard !text.isEmpty else { return nil }
        return (level, stripInlineMarkup(text))
    }

    /// Counts `- [ ]` and `- [x]` task items.
    public static func taskCounts(in markdown: String) -> (open: Int, completed: Int) {
        var open = 0
        var completed = 0
        for line in markdown.components(separatedBy: "\n") {
            guard let marker = ListMarker.parse(line), case .task(_, let checked) = marker.kind else { continue }
            if checked { completed += 1 } else { open += 1 }
        }
        return (open, completed)
    }

    /// The first lines of prose of a page, used when it has no headings.
    public static func preview(of markdown: String, maxLength: Int = 140) -> String {
        var inFence = false
        var parts: [String] = []
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            guard !inFence, !trimmed.isEmpty, parseHeading(line) == nil else { continue }
            var text = trimmed
            if let marker = ListMarker.parse(line) {
                text = String(line.dropFirst(marker.prefixLength)).trimmingCharacters(in: .whitespaces)
            } else if text.hasPrefix(">") {
                text = text.drop(while: { $0 == ">" || $0 == " " }).description
            }
            if !text.isEmpty {
                parts.append(stripInlineMarkup(text))
            }
            if parts.joined(separator: " ").count >= maxLength { break }
        }
        let joined = parts.joined(separator: " ")
        guard joined.count > maxLength else { return joined }
        return String(joined.prefix(maxLength)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Removes the most common inline Markdown markers for display purposes.
    static func stripInlineMarkup(_ text: String) -> String {
        var result = text
        // [label](url) -> label
        result = result.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        for marker in ["**", "__", "~~", "==", "`"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result
    }

    // MARK: - INDICE.md

    /// The Markdown document written as `INDICE.md` in every folder.
    ///
    /// It deliberately contains no generation timestamp, so that the file only
    /// changes on disk when the index itself changes.
    public static func markdownDocument(for folder: Folder, locale: Locale = .current) -> String {
        let entries = entries(for: folder)
        var lines: [String] = [
            "# \(folder.name)",
            "",
            "> Indice generato automaticamente da Piece of Paper: ogni pagina della cartella compare qui. Non modificare questo file a mano.",
            "",
        ]

        if entries.isEmpty {
            lines.append("_Nessuna pagina._")
        }

        let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        for entry in entries {
            let marker = "\(entry.number). "
            var line = "\(marker)[\(escapeLinkText(entry.title))](\(encodeLinkTarget(entry.fileName)))"
            line += " — \(entry.updatedAt.formatted(dateStyle))"
            if entry.openTasks > 0 {
                line += entry.openTasks == 1 ? " · 1 attività aperta" : " · \(entry.openTasks) attività aperte"
            }
            lines.append(line)

            let indent = String(repeating: " ", count: marker.count)
            let minLevel = entry.headings.map(\.level).min() ?? 1
            for heading in entry.headings {
                let depth = String(repeating: "  ", count: heading.level - minLevel)
                lines.append("\(indent)\(depth)- \(heading.text)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func escapeLinkText(_ text: String) -> String {
        text.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
    }

    static func encodeLinkTarget(_ fileName: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fileName.addingPercentEncoding(withAllowedCharacters: allowed) ?? fileName
    }
}
