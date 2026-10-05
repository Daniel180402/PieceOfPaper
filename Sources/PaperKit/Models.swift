import Foundation

/// A single page of notes.
///
/// The body lives in its own Markdown file inside the folder; everything else
/// is stored in the folder manifest (see ``LibraryStorage``).
public struct Page: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    /// Name of the Markdown file inside the folder, e.g. `Riunione kickoff.md`.
    public var fileName: String
    public let createdAt: Date
    public var updatedAt: Date
    /// Markdown content. Not part of the manifest: it is read from `fileName`.
    public var body: String = ""

    enum CodingKeys: String, CodingKey {
        case id, title, fileName, createdAt, updatedAt
    }

    public init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        body: String = ""
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.body = body
    }

    public static let untitled = "Senza titolo"

    /// The title to show in the UI: empty titles become "Senza titolo".
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.untitled : trimmed
    }

    public var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

/// A folder of pages. Its pages, in order, make up the folder index.
public struct Folder: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Display name, always equal to the directory name on disk.
    public var name: String
    public let createdAt: Date
    public var pages: [Page]

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now, pages: [Page] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.pages = pages
    }
}

/// Contents of the `.paper.json` file stored in each folder.
struct FolderManifest: Codable {
    var version: Int
    var id: UUID
    var createdAt: Date
    var pages: [Page]

    init(id: UUID, createdAt: Date, pages: [Page]) {
        self.version = 1
        self.id = id
        self.createdAt = createdAt
        self.pages = pages
    }
}

/// Contents of the `.library.json` file stored in the library root.
struct LibraryManifest: Codable {
    var version: Int
    var folderOrder: [UUID]

    init(folderOrder: [UUID]) {
        self.version = 1
        self.folderOrder = folderOrder
    }
}
