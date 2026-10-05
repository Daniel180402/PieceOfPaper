import AppKit
import Observation
import PaperKit
import SwiftUI

/// A request to scroll the editor to a heading, issued from the index.
struct JumpRequest: Equatable {
    let id = UUID()
    let pageID: Page.ID
    let location: Int
}

/// App state: the library loaded in memory plus the current selection.
///
/// Every change is applied in memory immediately and written to disk right
/// away (structure changes) or shortly after the user stops typing (page edits).
@Observable
@MainActor
final class LibraryStore {
    private(set) var folders: [Folder] = []
    private(set) var rootURL: URL

    var selectedFolderID: Folder.ID?
    var selectedPageID: Page.ID?
    var searchText = ""
    var renamingFolderID: Folder.ID?
    /// Set right after a page is created so the editor can focus its title.
    var newlyCreatedPageID: Page.ID?
    var jumpRequest: JumpRequest?
    var errorMessage: String?

    @ObservationIgnored private var storage: LibraryStorage
    @ObservationIgnored private var pendingSaves: [Page.ID: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastOpenedPage: [Folder.ID: Page.ID] = [:]

    static let saveDelay: Duration = .milliseconds(600)

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.storage = LibraryStorage(rootURL: rootURL)
        load()

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushPendingSaves() }
        }
    }

    // MARK: - Lookup

    var selectedFolder: Folder? {
        folders.first { $0.id == selectedFolderID }
    }

    var selectedPage: Page? {
        guard let selectedPageID, let location = locate(selectedPageID) else { return nil }
        return folders[location.folder].pages[location.page]
    }

    func folder(containing pageID: Page.ID) -> Folder? {
        locate(pageID).map { folders[$0.folder] }
    }

    func pageURL(for pageID: Page.ID) -> URL? {
        guard let location = locate(pageID) else { return nil }
        let folder = folders[location.folder]
        return storage.pageURL(for: folder.pages[location.page], in: folder)
    }

    func folderURL(for folderID: Folder.ID) -> URL? {
        folders.first { $0.id == folderID }.map(storage.folderURL(for:))
    }

    private func locate(_ pageID: Page.ID) -> (folder: Int, page: Int)? {
        for (folderIndex, folder) in folders.enumerated() {
            if let pageIndex = folder.pages.firstIndex(where: { $0.id == pageID }) {
                return (folderIndex, pageIndex)
            }
        }
        return nil
    }

    private func folderIndex(_ folderID: Folder.ID) -> Int? {
        folders.firstIndex { $0.id == folderID }
    }

    // MARK: - Loading

    func load() {
        do {
            if try storage.prepareRoot() {
                try WelcomeContent.install(using: storage)
            }
            folders = try storage.loadFolders()
        } catch {
            folders = []
            report(error)
        }

        if selectedFolder == nil {
            selectedFolderID = folders.first?.id
        }
        folderSelectionDidChange()
    }

    /// Re-reads the library, picking up changes made in the Finder.
    func reload() {
        flushPendingSaves()
        load()
    }

    func changeRoot(to url: URL) {
        flushPendingSaves()
        rootURL = url
        storage = LibraryStorage(rootURL: url)
        selectedFolderID = nil
        selectedPageID = nil
        lastOpenedPage = [:]
        load()
    }

    // MARK: - Selection

    /// Keeps the page selection consistent with the selected folder,
    /// reopening the page that was last open in it.
    func folderSelectionDidChange() {
        guard let folder = selectedFolder else {
            selectedPageID = nil
            return
        }
        if let selectedPageID, folder.pages.contains(where: { $0.id == selectedPageID }) {
            return
        }
        let remembered = lastOpenedPage[folder.id].flatMap { id in folder.pages.first { $0.id == id } }
        selectedPageID = (remembered ?? folder.pages.first)?.id
    }

    func pageSelectionDidChange() {
        guard let selectedPageID, let folder = folder(containing: selectedPageID) else { return }
        lastOpenedPage[folder.id] = selectedPageID
    }

    /// Opens a page from anywhere (search results, links), selecting its folder too.
    func open(pageID: Page.ID) {
        guard let folder = folder(containing: pageID) else { return }
        selectedFolderID = folder.id
        selectedPageID = pageID
    }

    func jump(to heading: Heading, in pageID: Page.ID) {
        open(pageID: pageID)
        jumpRequest = JumpRequest(pageID: pageID, location: heading.location)
    }

    // MARK: - Folders

    func createFolder() {
        do {
            let folder = try storage.createFolder(named: LibraryStorage.defaultFolderName)
            folders.append(folder)
            try storage.saveFolderOrder(folders)
            searchText = ""
            selectedFolderID = folder.id
            selectedPageID = nil
            renamingFolderID = folder.id
        } catch {
            report(error)
        }
    }

    func renameFolder(_ folderID: Folder.ID, to name: String) {
        if renamingFolderID == folderID {
            renamingFolderID = nil
        }
        guard let index = folderIndex(folderID),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        flushPendingSaves()
        do {
            folders[index] = try storage.renameFolder(folders[index], to: name)
        } catch {
            report(error)
        }
    }

    func deleteFolder(_ folderID: Folder.ID) {
        guard let index = folderIndex(folderID) else { return }
        flushPendingSaves()
        do {
            try storage.deleteFolder(folders[index])
            folders.remove(at: index)
            try storage.saveFolderOrder(folders)
        } catch {
            report(error)
        }
        if selectedFolderID == folderID {
            selectedFolderID = folders.indices.contains(index) ? folders[index].id : folders.last?.id
            folderSelectionDidChange()
        }
    }

    func moveFolders(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        do {
            try storage.saveFolderOrder(folders)
        } catch {
            report(error)
        }
    }

    // MARK: - Pages

    /// Adds a new page at the end of the selected folder's index.
    func createPage() {
        searchText = ""
        if selectedFolder == nil {
            if folders.isEmpty {
                createFolder()
                renamingFolderID = nil
            } else {
                selectedFolderID = folders.first?.id
            }
        }
        guard let folderID = selectedFolderID, let index = folderIndex(folderID) else { return }
        do {
            let page = try storage.createPage(titled: "", in: &folders[index])
            try storage.saveFolder(folders[index])
            newlyCreatedPageID = page.id
            selectedPageID = page.id
        } catch {
            report(error)
        }
    }

    func updateBody(_ body: String, of pageID: Page.ID) {
        guard let location = locate(pageID),
              folders[location.folder].pages[location.page].body != body else { return }
        folders[location.folder].pages[location.page].body = body
        folders[location.folder].pages[location.page].updatedAt = .now
        scheduleSave(pageID)
    }

    func updateTitle(_ title: String, of pageID: Page.ID) {
        guard let location = locate(pageID),
              folders[location.folder].pages[location.page].title != title else { return }
        folders[location.folder].pages[location.page].title = title
        folders[location.folder].pages[location.page].updatedAt = .now
        scheduleSave(pageID)
    }

    func deletePage(_ pageID: Page.ID) {
        guard let location = locate(pageID) else { return }
        pendingSaves.removeValue(forKey: pageID)?.cancel()
        let folder = folders[location.folder]
        do {
            try storage.deletePage(folder.pages[location.page], from: folder)
            folders[location.folder].pages.remove(at: location.page)
            try storage.saveFolder(folders[location.folder])
        } catch {
            report(error)
        }
        if selectedPageID == pageID {
            let pages = folders[location.folder].pages
            selectedPageID = pages.indices.contains(location.page) ? pages[location.page].id : pages.last?.id
        }
    }

    func movePages(in folderID: Folder.ID, from source: IndexSet, to destination: Int) {
        guard let index = folderIndex(folderID) else { return }
        folders[index].pages.move(fromOffsets: source, toOffset: destination)
        do {
            try storage.saveFolder(folders[index])
        } catch {
            report(error)
        }
    }

    func movePage(_ pageID: Page.ID, toFolder destinationID: Folder.ID) {
        guard let source = locate(pageID),
              let destination = folderIndex(destinationID),
              destination != source.folder else { return }
        persist(pageID)
        do {
            let page = folders[source.folder].pages[source.page]
            let moved = try storage.movePage(page, from: folders[source.folder], to: folders[destination])
            folders[source.folder].pages.remove(at: source.page)
            folders[destination].pages.append(moved)
            try storage.saveFolder(folders[source.folder])
            try storage.saveFolder(folders[destination])
        } catch {
            report(error)
        }
        open(pageID: pageID)
    }

    // MARK: - Finder

    func revealInFinder(pageID: Page.ID) {
        persist(pageID)
        if let url = pageURL(for: pageID) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func revealInFinder(folderID: Folder.ID) {
        if let url = folderURL(for: folderID) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func revealSelection() {
        if let selectedPageID {
            revealInFinder(pageID: selectedPageID)
        } else if let selectedFolderID {
            revealInFinder(folderID: selectedFolderID)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([rootURL])
        }
    }

    // MARK: - Saving

    private func scheduleSave(_ pageID: Page.ID) {
        pendingSaves[pageID]?.cancel()
        pendingSaves[pageID] = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.persist(pageID)
        }
    }

    /// Writes a page with pending changes to disk, along with its folder index.
    private func persist(_ pageID: Page.ID) {
        guard let task = pendingSaves.removeValue(forKey: pageID) else { return }
        task.cancel()
        guard let location = locate(pageID) else { return }
        do {
            let folder = folders[location.folder]
            let saved = try storage.savePage(folder.pages[location.page], in: folder)
            folders[location.folder].pages[location.page].fileName = saved.fileName
            try storage.saveFolder(folders[location.folder])
        } catch {
            report(error)
        }
    }

    func flushPendingSaves() {
        for pageID in Array(pendingSaves.keys) {
            persist(pageID)
        }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
