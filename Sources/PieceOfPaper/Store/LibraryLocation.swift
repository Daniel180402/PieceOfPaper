import Foundation
import PaperKit

/// Where the notes live on disk. Defaults to `~/Documents/Piece of Paper`
/// and can be changed in Settings (or with `-libraryPath <path>` at launch).
enum LibraryLocation {
    static let defaultsKey = "libraryPath"
    static let folderName = "Piece of Paper"

    static var defaultURL: URL {
        URL.documentsDirectory.appending(path: folderName, directoryHint: .isDirectory)
    }

    static var current: URL {
        guard let path = UserDefaults.standard.string(forKey: defaultsKey), !path.isEmpty else {
            return defaultURL
        }
        return URL(filePath: (path as NSString).expandingTildeInPath, directoryHint: .isDirectory)
    }

    static func save(_ url: URL) {
        if url.standardizedFileURL == defaultURL.standardizedFileURL {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } else {
            UserDefaults.standard.set(url.path(percentEncoded: false), forKey: defaultsKey)
        }
    }

    /// The library directory to use for a folder picked by the user: the folder
    /// itself if it is empty or already a library, otherwise a "Piece of Paper"
    /// subfolder, so that unrelated directories are never turned into notebooks.
    static func libraryURL(forChosen url: URL) -> URL {
        let fileManager = FileManager.default
        let isLibrary = fileManager.fileExists(
            atPath: url.appending(path: LibraryStorage.libraryManifestName).path(percentEncoded: false)
        )
        let contents = (try? fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []
        let isEmpty = contents.allSatisfy { $0.hasPrefix(".") }
        if isLibrary || isEmpty || url.lastPathComponent == folderName {
            return url
        }
        return url.appending(path: folderName, directoryHint: .isDirectory)
    }
}
