import Foundation

/// Where the notes live on disk. Defaults to `~/Documents/Piece of Paper`
/// and can be changed in Settings (or with `-libraryPath <path>` at launch).
enum LibraryLocation {
    static let defaultsKey = "libraryPath"

    static var defaultURL: URL {
        URL.documentsDirectory.appending(path: "Piece of Paper", directoryHint: .isDirectory)
    }

    static var current: URL {
        guard let path = UserDefaults.standard.string(forKey: defaultsKey), !path.isEmpty else {
            return defaultURL
        }
        return URL(filePath: (path as NSString).expandingTildeInPath, directoryHint: .isDirectory)
    }

    static func save(_ url: URL) {
        UserDefaults.standard.set(url.path(percentEncoded: false), forKey: defaultsKey)
    }
}
