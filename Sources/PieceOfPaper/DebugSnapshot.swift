#if DEBUG
import AppKit
import PaperKit

/// Development aid: launched with `-snapshotPath /tmp/shot.png`, the app
/// renders its main window to a PNG once loaded and quits. Lets the UI be
/// checked from scripts without screen-recording permissions.
///
/// Optional `-snapshotDelay <seconds>` (default 1.5),
/// `-snapshotAppearance dark|light`, `-snapshotPage <page title>` and
/// `-snapshotJump <heading>` (jumps to a heading as if clicked in the index).
@MainActor
enum DebugSnapshot {
    static weak var store: LibraryStore?

    static var isEnabled: Bool {
        UserDefaults.standard.string(forKey: "snapshotPath") != nil
    }

    static func scheduleIfRequested() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "snapshotPath") else { return }
        // Keep the window invisible on screen: it is only rendered offscreen.
        NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                NSApp.windows.forEach { $0.alphaValue = 0 }
            }
        }
        switch defaults.string(forKey: "snapshotAppearance") {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: break
        }
        let delay = defaults.object(forKey: "snapshotDelay") as? Double
            ?? Double(defaults.string(forKey: "snapshotDelay") ?? "") ?? 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay / 2) {
            performScriptedActions()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            capture(to: URL(filePath: path))
            NSApp.terminate(nil)
        }
    }

    private static func performScriptedActions() {
        guard let store else { return }
        let defaults = UserDefaults.standard
        if let title = defaults.string(forKey: "snapshotPage"),
           let page = store.folders.flatMap(\.pages).first(where: { $0.displayTitle == title }) {
            store.open(pageID: page.id)
        }
        if let text = defaults.string(forKey: "snapshotJump"),
           let page = store.selectedPage,
           let heading = IndexBuilder.headings(in: page.body).first(where: { $0.text == text }) {
            store.jump(to: heading, in: page.id)
        }
    }

    private static func capture(to url: URL) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            FileHandle.standardError.write(Data("snapshot: no window\n".utf8))
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        do {
            try bitmap.representation(using: .png, properties: [:])?.write(to: url)
        } catch {
            FileHandle.standardError.write(Data("snapshot: \(error)\n".utf8))
        }
    }
}
#endif
