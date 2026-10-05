import Foundation

public struct SearchHit: Identifiable, Hashable, Sendable {
    public var id: UUID { pageID }
    public let folderID: UUID
    public let folderName: String
    public let pageID: UUID
    public let title: String
    public let snippet: String
}

/// Full-text search across all folders, ignoring case and accents.
public enum NoteSearch {
    public static func search(_ query: String, in folders: [Folder]) -> [SearchHit] {
        let terms = query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !terms.isEmpty else { return [] }

        var titleHits: [SearchHit] = []
        var bodyHits: [SearchHit] = []
        for folder in folders {
            for page in folder.pages {
                let haystack = page.displayTitle + "\n" + page.body
                guard terms.allSatisfy({ haystack.range(of: $0, options: options) != nil }) else { continue }
                let hit = SearchHit(
                    folderID: folder.id,
                    folderName: folder.name,
                    pageID: page.id,
                    title: page.displayTitle,
                    snippet: snippet(in: page.body, around: terms)
                )
                if terms.allSatisfy({ page.displayTitle.range(of: $0, options: options) != nil }) {
                    titleHits.append(hit)
                } else {
                    bodyHits.append(hit)
                }
            }
        }
        return titleHits + bodyHits
    }

    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func snippet(in body: String, around terms: [String], radius: Int = 60) -> String {
        guard let match = terms.lazy.compactMap({ body.range(of: $0, options: options) }).first else {
            return IndexBuilder.preview(of: body, maxLength: radius * 2)
        }
        let start = body.index(match.lowerBound, offsetBy: -radius, limitedBy: body.startIndex) ?? body.startIndex
        let end = body.index(match.upperBound, offsetBy: radius, limitedBy: body.endIndex) ?? body.endIndex
        var text = String(body[start..<end])
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        if start > body.startIndex { text = "…" + text }
        if end < body.endIndex { text += "…" }
        return text
    }
}
