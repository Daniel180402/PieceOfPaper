import Foundation
import PaperKit
import Testing
@testable import PieceOfPaper

@Suite final class LibraryLocationTests {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "LibraryLocationTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func usesAnEmptyFolderAsIs() {
        #expect(LibraryLocation.libraryURL(forChosen: directory) == directory)
    }

    @Test func usesAnExistingLibraryAsIs() throws {
        try Data().write(to: directory.appending(path: "Altro.txt"))
        try Data().write(to: directory.appending(path: LibraryStorage.libraryManifestName))
        #expect(LibraryLocation.libraryURL(forChosen: directory) == directory)
    }

    @Test func usesASubfolderOfABusyFolder() throws {
        try Data().write(to: directory.appending(path: "Altro.txt"))
        #expect(LibraryLocation.libraryURL(forChosen: directory) == directory.appending(path: "Piece of Paper", directoryHint: .isDirectory))
    }
}
