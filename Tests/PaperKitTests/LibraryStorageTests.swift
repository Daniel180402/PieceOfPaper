import Foundation
import Testing
@testable import PaperKit

@Suite final class LibraryStorageTests {
    let root: URL
    let storage: LibraryStorage

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "PaperKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        storage = LibraryStorage(rootURL: root, usesTrash: false)
        #expect(try storage.prepareRoot())
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test func createsFolderWithManifestAndIndex() throws {
        let folder = try storage.createFolder(named: "Lavoro")
        #expect(folder.name == "Lavoro")
        #expect(exists(storage.folderURL(for: folder).appending(path: LibraryStorage.folderManifestName)))
        #expect(try read(storage.indexURL(for: folder)).contains("# Lavoro"))
    }

    @Test func folderNamesAreSanitizedAndUnique() throws {
        let first = try storage.createFolder(named: "Clienti/2026")
        let second = try storage.createFolder(named: "clienti-2026")
        let hidden = try storage.createFolder(named: ".segreta")
        #expect(first.name == "Clienti-2026")
        #expect(second.name == "clienti-2026 2")
        #expect(hidden.name == "segreta")
    }

    @Test func createdPagesAppearInTheIndex() throws {
        var folder = try storage.createFolder(named: "Lavoro")
        let page = try storage.createPage(titled: "Kickoff", body: "## Decisioni", in: &folder)
        _ = try storage.createPage(titled: "Kickoff", in: &folder)
        try storage.saveFolder(folder)

        #expect(folder.pages.map(\.fileName) == ["Kickoff.md", "Kickoff 2.md"])
        #expect(try read(storage.pageURL(for: page, in: folder)) == "## Decisioni")
        let index = try read(storage.indexURL(for: folder))
        #expect(index.contains("1. [Kickoff](Kickoff.md)"))
        #expect(index.contains("   - Decisioni"))
        #expect(index.contains("2. [Kickoff](Kickoff%202.md)"))
    }

    @Test func pageTitledIndiceDoesNotOverwriteTheIndex() throws {
        var folder = try storage.createFolder(named: "Lavoro")
        let page = try storage.createPage(titled: "indice", in: &folder)
        #expect(page.fileName == "indice 2.md")
    }

    @Test func savingRenamesTheFileWhenTheTitleChanges() throws {
        var folder = try storage.createFolder(named: "Lavoro")
        var page = try storage.createPage(titled: "", in: &folder)
        #expect(page.fileName == "Senza titolo.md")

        page.title = "Call con il cliente: follow-up"
        page.body = "testo"
        let saved = try storage.savePage(page, in: folder)
        #expect(saved.fileName == "Call con il cliente- follow-up.md")
        #expect(!exists(storage.pageURL(for: page, in: folder)))
        #expect(try read(storage.pageURL(for: saved, in: folder)) == "testo")
    }

    @Test func reloadingRestoresOrderAndContent() throws {
        var work = try storage.createFolder(named: "Lavoro")
        let personal = try storage.createFolder(named: "Archivio")
        _ = try storage.createPage(titled: "B", body: "bee", in: &work)
        _ = try storage.createPage(titled: "A", body: "a", in: &work)
        try storage.saveFolder(work)
        try storage.saveFolderOrder([work, personal])

        let loaded = try storage.loadFolders()
        #expect(loaded.map(\.name) == ["Lavoro", "Archivio"])
        #expect(loaded[0].pages.map(\.title) == ["B", "A"])
        #expect(loaded[0].pages.map(\.body) == ["bee", "a"])
        #expect(loaded[0].id == work.id)
    }

    @Test func reconcilesFilesChangedOutsideTheApp() throws {
        var folder = try storage.createFolder(named: "Lavoro")
        let gone = try storage.createPage(titled: "Cancellata", in: &folder)
        _ = try storage.createPage(titled: "Resta", in: &folder)
        try storage.saveFolder(folder)

        try FileManager.default.removeItem(at: storage.pageURL(for: gone, in: folder))
        try "# Da Finder".write(
            to: storage.folderURL(for: folder).appending(path: "Aggiunta.md"),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try #require(try storage.loadFolders().first)
        #expect(loaded.pages.map(\.title) == ["Resta", "Aggiunta"])
        #expect(try read(storage.indexURL(for: loaded)).contains("[Aggiunta](Aggiunta.md)"))
    }

    @Test func adoptsPlainDirectories() throws {
        let url = root.appending(path: "Importata", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try "ciao".write(to: url.appending(path: "Nota.md"), atomically: true, encoding: .utf8)

        let loaded = try #require(try storage.loadFolders().first)
        #expect(loaded.name == "Importata")
        #expect(loaded.pages.map(\.title) == ["Nota"])
        #expect(exists(url.appending(path: LibraryStorage.folderManifestName)))
    }

    @Test func renamesFolders() throws {
        let folder = try storage.createFolder(named: "Lavoro")
        let renamed = try storage.renameFolder(folder, to: "Progetti")
        #expect(renamed.name == "Progetti")
        #expect(renamed.id == folder.id)
        #expect(!exists(storage.folderURL(for: folder)))
        #expect(try read(storage.indexURL(for: renamed)).hasPrefix("# Progetti"))

        let caseOnly = try storage.renameFolder(renamed, to: "progetti")
        #expect(caseOnly.name == "progetti")
    }

    @Test func movesPagesBetweenFolders() throws {
        var source = try storage.createFolder(named: "Lavoro")
        var destination = try storage.createFolder(named: "Archivio")
        _ = try storage.createPage(titled: "Nota", body: "uno", in: &destination)
        let page = try storage.createPage(titled: "Nota", body: "due", in: &source)

        let moved = try storage.movePage(page, from: source, to: destination)
        source.pages.removeAll { $0.id == page.id }
        destination.pages.append(moved)

        #expect(moved.fileName == "Nota 2.md")
        #expect(try read(storage.pageURL(for: moved, in: destination)) == "due")
        #expect(!exists(storage.pageURL(for: page, in: source)))
    }

    @Test func deletesPagesAndFolders() throws {
        var folder = try storage.createFolder(named: "Lavoro")
        let page = try storage.createPage(titled: "Nota", in: &folder)
        try storage.deletePage(page, from: folder)
        #expect(!exists(storage.pageURL(for: page, in: folder)))

        try storage.deleteFolder(folder)
        #expect(!exists(storage.folderURL(for: folder)))
    }
}
