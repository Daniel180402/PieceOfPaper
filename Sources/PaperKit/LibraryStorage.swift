import Foundation

/// Reads and writes the notes library on disk.
///
/// Layout:
///
///     <root>/
///       .library.json          order of the folders
///       Lavoro/
///         .paper.json          folder id, page order and page metadata
///         INDICE.md            generated index of the folder
///         Riunione kickoff.md  one Markdown file per page
///
/// Everything is plain Markdown, so the notes stay readable without the app.
/// Markdown files added to a folder from the Finder are picked up as new pages.
public struct LibraryStorage: Sendable {
    public static let folderManifestName = ".paper.json"
    public static let libraryManifestName = ".library.json"
    public static let indexFileName = "INDICE.md"
    public static let pageExtension = "md"
    public static let defaultFolderName = "Nuova cartella"

    public let rootURL: URL
    /// When true, deleted folders and pages are moved to the Trash instead of being removed.
    public var usesTrash: Bool

    public init(rootURL: URL, usesTrash: Bool = true) {
        self.rootURL = rootURL
        self.usesTrash = usesTrash
    }

    public func folderURL(for folder: Folder) -> URL {
        rootURL.appending(path: folder.name, directoryHint: .isDirectory)
    }

    public func pageURL(for page: Page, in folder: Folder) -> URL {
        folderURL(for: folder).appending(path: page.fileName, directoryHint: .notDirectory)
    }

    public func indexURL(for folder: Folder) -> URL {
        folderURL(for: folder).appending(path: Self.indexFileName, directoryHint: .notDirectory)
    }

    // MARK: - Library

    /// Creates the root directory if needed. Returns `true` if it did not exist yet.
    @discardableResult
    public func prepareRoot() throws -> Bool {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: rootURL.path(percentEncoded: false), isDirectory: &isDirectory),
           isDirectory.boolValue {
            return false
        }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return true
    }

    /// Loads every folder, reconciling manifests with the files actually on disk.
    public func loadFolders() throws -> [Folder] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        )
        var folders: [Folder] = []
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            guard values?.isDirectory == true, values?.isPackage != true else { continue }
            folders.append(try loadFolder(at: url))
        }

        let order = (try? readLibraryManifest().folderOrder) ?? []
        let position = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return folders.sorted { lhs, rhs in
            switch (position[lhs.id], position[rhs.id]) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    public func saveFolderOrder(_ folders: [Folder]) throws {
        let manifest = LibraryManifest(folderOrder: folders.map(\.id))
        try write(manifest, to: rootURL.appending(path: Self.libraryManifestName))
    }

    func readLibraryManifest() throws -> LibraryManifest {
        let data = try Data(contentsOf: rootURL.appending(path: Self.libraryManifestName))
        return try Self.decoder.decode(LibraryManifest.self, from: data)
    }

    func loadFolder(at url: URL) throws -> Folder {
        let fileManager = FileManager.default
        var dirty = false

        let manifest: FolderManifest
        if let data = try? Data(contentsOf: url.appending(path: Self.folderManifestName)),
           let decoded = try? Self.decoder.decode(FolderManifest.self, from: data) {
            manifest = decoded
        } else {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .now
            manifest = FolderManifest(id: UUID(), createdAt: created, pages: [])
            dirty = true
        }

        var pages: [Page] = []
        var known = Set<String>()
        for var page in manifest.pages {
            let fileURL = url.appending(path: page.fileName)
            guard !known.contains(page.fileName.lowercased()),
                  let body = try? String(contentsOf: fileURL, encoding: .utf8) else {
                // The file was deleted or renamed outside the app.
                dirty = true
                continue
            }
            page.body = body
            if let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               modified.timeIntervalSince(page.updatedAt) > 5 {
                // Edited outside the app.
                page.updatedAt = modified
                dirty = true
            }
            known.insert(page.fileName.lowercased())
            pages.append(page)
        }

        // Markdown files added from the Finder become new pages at the end of the index.
        let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .isRegularFileKey]
        let untracked = try fileManager
            .contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
            .filter { file in
                file.pathExtension.lowercased() == Self.pageExtension
                    && file.lastPathComponent.caseInsensitiveCompare(Self.indexFileName) != .orderedSame
                    && !known.contains(file.lastPathComponent.lowercased())
                    && (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            }
            .map { file in (file, try? file.resourceValues(forKeys: Set(keys))) }
            .sorted { ($0.1?.creationDate ?? .distantPast) < ($1.1?.creationDate ?? .distantPast) }

        for (file, values) in untracked {
            pages.append(Page(
                title: file.deletingPathExtension().lastPathComponent,
                fileName: file.lastPathComponent,
                createdAt: values?.creationDate ?? .now,
                updatedAt: values?.contentModificationDate ?? .now,
                body: (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            ))
            dirty = true
        }

        let folder = Folder(id: manifest.id, name: url.lastPathComponent, createdAt: manifest.createdAt, pages: pages)
        if dirty {
            try saveManifest(of: folder)
        }
        try writeIndex(of: folder)
        return folder
    }

    // MARK: - Folders

    public func createFolder(named name: String) throws -> Folder {
        let base = FileNaming.sanitized(name, fallback: Self.defaultFolderName)
        let directoryName = FileNaming.unique(base, extension: nil, in: rootURL)
        let folder = Folder(name: directoryName)
        try FileManager.default.createDirectory(at: folderURL(for: folder), withIntermediateDirectories: true)
        try saveFolder(folder)
        return folder
    }

    /// Renames the folder's directory. The resulting name may differ from
    /// `newName` if it contained invalid characters or was already taken.
    public func renameFolder(_ folder: Folder, to newName: String) throws -> Folder {
        let base = FileNaming.sanitized(newName, fallback: folder.name)
        guard base != folder.name else { return folder }
        let directoryName = FileNaming.unique(base, extension: nil, in: rootURL, current: folder.name)
        var renamed = folder
        renamed.name = directoryName
        try FileManager.default.moveItem(at: folderURL(for: folder), to: folderURL(for: renamed))
        try writeIndex(of: renamed)
        return renamed
    }

    public func deleteFolder(_ folder: Folder) throws {
        try remove(folderURL(for: folder))
    }

    /// Writes the folder manifest and regenerates `INDICE.md`.
    public func saveFolder(_ folder: Folder) throws {
        try saveManifest(of: folder)
        try writeIndex(of: folder)
    }

    public func saveManifest(of folder: Folder) throws {
        let manifest = FolderManifest(id: folder.id, createdAt: folder.createdAt, pages: folder.pages)
        try write(manifest, to: folderURL(for: folder).appending(path: Self.folderManifestName))
    }

    /// Regenerates `INDICE.md`, touching the file only if its content changed.
    public func writeIndex(of folder: Folder) throws {
        let url = indexURL(for: folder)
        let document = IndexBuilder.markdownDocument(for: folder)
        if let existing = try? String(contentsOf: url, encoding: .utf8), existing == document {
            return
        }
        try document.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Pages

    /// Creates the page file and inserts the page into `folder` (at the end by default).
    /// The caller is responsible for persisting the folder with ``saveFolder(_:)``.
    public func createPage(titled title: String, body: String = "", in folder: inout Folder, at position: Int? = nil) throws -> Page {
        let page = Page(title: title, fileName: uniquePageFileName(for: title, in: folder), body: body)
        try body.write(to: pageURL(for: page, in: folder), atomically: true, encoding: .utf8)
        let index = min(max(position ?? folder.pages.count, 0), folder.pages.count)
        folder.pages.insert(page, at: index)
        return page
    }

    /// Writes the page body, renaming its file first if the title changed.
    /// Returns the page with its (possibly new) file name.
    public func savePage(_ page: Page, in folder: Folder) throws -> Page {
        var page = page
        let desired = FileNaming.sanitized(page.title, fallback: Page.untitled)
        let current = (page.fileName as NSString).deletingPathExtension
        if desired != current {
            let newName = uniquePageFileName(for: page.title, in: folder, current: page.fileName)
            if newName != page.fileName {
                let oldURL = pageURL(for: page, in: folder)
                page.fileName = newName
                if FileManager.default.fileExists(atPath: oldURL.path(percentEncoded: false)) {
                    try FileManager.default.moveItem(at: oldURL, to: pageURL(for: page, in: folder))
                }
            }
        }
        try page.body.write(to: pageURL(for: page, in: folder), atomically: true, encoding: .utf8)
        return page
    }

    /// Removes the page file. The caller removes the page from the folder and saves it.
    public func deletePage(_ page: Page, from folder: Folder) throws {
        let url = pageURL(for: page, in: folder)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try remove(url)
    }

    /// Moves the page file into another folder and returns the page with its
    /// file name in the destination. The caller updates and saves both folders.
    public func movePage(_ page: Page, from source: Folder, to destination: Folder) throws -> Page {
        var moved = page
        moved.fileName = uniquePageFileName(for: page.title, in: destination)
        try FileManager.default.moveItem(at: pageURL(for: page, in: source), to: pageURL(for: moved, in: destination))
        return moved
    }

    func uniquePageFileName(for title: String, in folder: Folder, current: String? = nil) -> String {
        FileNaming.unique(
            FileNaming.sanitized(title, fallback: Page.untitled),
            extension: Self.pageExtension,
            in: folderURL(for: folder),
            reserved: [Self.indexFileName, Self.folderManifestName],
            current: current
        )
    }

    // MARK: - Helpers

    private func remove(_ url: URL) throws {
        if usesTrash {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } else {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try Self.encoder.encode(value).write(to: url, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
